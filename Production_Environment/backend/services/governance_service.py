"""
Governance Service for On-Chain Governance Operations

Handles governance proposal creation, voting, and execution with blockchain integration.
Includes database tracking, Web3 integration, and error handling.
"""

from sqlalchemy.orm import Session
from datetime import datetime, timedelta
from typing import List, Optional
import logging

from schemas.governance import (
    GovernanceProposalCreateRequest,
    GovernanceProposalCreateResponse,
    VoteCastRequest,
    VoteCastResponse,
    ProposalDetailResponse,
    ProposalExecuteResponse,
    VotingPowerResponse
)
from models.governance_proposal import GovernanceProposal, ProposalStatus

logger = logging.getLogger(__name__)


class GovernanceService:
    """Service class for governance operations"""

    def __init__(self, db: Session, web3_service):
        """
        Initialize governance service

        Args:
            db: Database session
            web3_service: Web3 service for blockchain interaction (always present, handles testing_mode internally)
        """
        self.db = db
        self.web3_service = web3_service

    async def create_proposal(
        self,
        request: GovernanceProposalCreateRequest
    ) -> GovernanceProposalCreateResponse:
        """
        Create a new governance proposal

        Args:
            request: Proposal creation request data

        Returns:
            Governance proposal creation response with blockchain details

        Raises:
            ValueError: If agreement doesn't exist or parameters invalid
            Exception: If blockchain transaction fails
        """
        try:
            from models.yield_agreement import YieldAgreement
            from models.user_share_balance import UserShareBalance
            from sqlalchemy import func
            
            # Validate agreement exists
            agreement = self.db.query(YieldAgreement).filter_by(id=request.agreement_id).first()
            if not agreement:
                logger.error(f"❌ Agreement {request.agreement_id} not found")
                raise ValueError(f"Agreement {request.agreement_id} not found")
            
            logger.info(f"✅ Agreement {request.agreement_id} exists (Property ID: {agreement.property_id}, Token Standard: {agreement.token_standard})")
            
            # 🔴 CRITICAL VALIDATION: Check if agreement has token balances (Iteration 12: use user_share_balances)
            token_balance_check = self.db.query(
                func.count(UserShareBalance.id).label('holder_count'),
                func.sum(UserShareBalance.balance_wei).label('total_tokens')
            ).filter(
                UserShareBalance.agreement_id == request.agreement_id
            ).first()
            
            token_holder_count = token_balance_check.holder_count or 0
            total_tokens = int(token_balance_check.total_tokens or 0)
            
            logger.info(f"📊 Token Balance Check - Agreement {request.agreement_id}: {token_holder_count} holders, {total_tokens:,} total tokens")
            
            if token_holder_count == 0 or total_tokens == 0:
                logger.error(
                    f"❌ PROPOSAL CREATION BLOCKED: Agreement {request.agreement_id} has NO token balances! "
                    f"Token holders: {token_holder_count}, Total tokens: {total_tokens}. "
                    f"Cannot create proposal without token distribution."
                )
                raise ValueError(
                    f"Agreement {request.agreement_id} has no token distribution. "
                    f"Token holders: {token_holder_count}, Total supply: {agreement.total_token_supply:,}. "
                    f"Tokens must be distributed before creating governance proposals."
                )
            
            logger.info(
                f"✅ Token balance validation passed - Agreement {request.agreement_id} has {token_holder_count} holders "
                f"with {total_tokens:,} / {agreement.total_token_supply:,} tokens distributed "
                f"({(total_tokens / agreement.total_token_supply * 100):.1f}%)"
            )

            # Convert USD to wei if provided (for reserve allocation proposals)
            target_value_wei = request.target_value
            
            if request.target_value_usd and request.proposal_type.value in ["RESERVE_ALLOCATION", "RESERVE_WITHDRAWAL"]:
                # Get current ETH price and convert
                eth_price = await self.web3_service.get_eth_price()
                target_value_wei = int((request.target_value_usd / eth_price) * 10**18)

            # Handle parameter update encoding
            agreement_id_or_param_id = request.agreement_id
            if request.proposal_type.value == "GOVERNANCE_PARAMETER_UPDATE":
                # For governance params, use param_id as agreement_id in contract call
                if request.param_id is not None:
                    agreement_id_or_param_id = request.param_id
                    target_value_wei = request.target_value
                else:
                    raise ValueError("param_id required for governance parameter updates")
            elif request.proposal_type.value == "AGREEMENT_PARAMETER_UPDATE":
                # For agreement params, encode param_id and value into target_value
                if request.param_id is not None:
                    # Encode: (parameterId << 128) | value
                    encoded_value = (request.param_id << 128) | request.target_value
                    target_value_wei = encoded_value
                else:
                    raise ValueError("param_id required for agreement parameter updates")

            # Call Web3 service to create proposal on blockchain (handles testing_mode internally)
            tx_hash, blockchain_proposal_id = await self.web3_service.create_governance_proposal(
                agreement_id=agreement_id_or_param_id,
                proposal_type=request.proposal_type.value,
                target_value=target_value_wei,
                description=request.description
            )

            # Get governance parameters from contract
            voting_delay, voting_period, quorum_percentage_bp, threshold_percentage_bp = await self.web3_service.get_governance_params()
            
            # Calculate voting timestamps using actual governance params
            voting_start = datetime.now() + timedelta(seconds=voting_delay)
            voting_end = voting_start + timedelta(seconds=voting_period)

            # Get total token supply for the agreement
            total_supply = await self.web3_service.get_total_supply(
                agreement_id=request.agreement_id,
                token_standard=request.token_standard
            )

            # Calculate dynamic quorum and threshold
            # quorum_required = (total_supply * quorum_percentage_bp) / 10000
            quorum_required = (total_supply * quorum_percentage_bp) // 10000
            
            # proposal_threshold = (total_supply * threshold_percentage_bp) / 10000
            proposal_threshold = (total_supply * threshold_percentage_bp) // 10000
            
            logger.info(
                f"📊 Dynamic governance params - "
                f"Total Supply: {total_supply:,}, "
                f"Quorum: {quorum_required:,} ({quorum_percentage_bp/100}%), "
                f"Threshold: {proposal_threshold:,} ({threshold_percentage_bp/100}%)"
            )

            # Create database record with computed quorum/threshold
            db_proposal = GovernanceProposal(
                blockchain_proposal_id=blockchain_proposal_id,
                agreement_id=request.agreement_id,
                proposer="0x0000000000000000000000000000000000000000",  # Placeholder - should come from wallet
                proposal_type=request.proposal_type.value,
                target_value=target_value_wei,
                parameter_name=request.parameter_name if hasattr(request, 'parameter_name') else None,
                description=request.description,
                voting_start=voting_start,
                voting_end=voting_end,
                status=ProposalStatus.PENDING,
                tx_hash=tx_hash,
                for_votes=0,
                against_votes=0,
                abstain_votes=0,
                executed=False,
                defeated=False,
                quorum_reached=False,
                quorum_required=quorum_required,
                proposal_threshold=proposal_threshold
            )
            self.db.add(db_proposal)
            self.db.commit()
            self.db.refresh(db_proposal)

            logger.info(f"Created governance proposal {blockchain_proposal_id} for agreement {request.agreement_id}")

            return GovernanceProposalCreateResponse(
                proposal_id=db_proposal.id,
                blockchain_proposal_id=blockchain_proposal_id,
                tx_hash=tx_hash,
                voting_start=voting_start,
                voting_end=voting_end,
                quorum_required=quorum_required,
                proposal_threshold=proposal_threshold,
                status="PENDING",
                message=f"Proposal created successfully. Voting starts in 1 day."
            )

        except ValueError as e:
            logger.error(f"Validation error creating proposal: {e}")
            raise
        except Exception as e:
            logger.error(f"Error creating governance proposal: {e}")
            raise Exception(f"Failed to create proposal: {str(e)}")

    async def cast_vote(
        self,
        request: VoteCastRequest,
        voter_address: str
    ) -> VoteCastResponse:
        """
        Cast a vote on a governance proposal

        Args:
            request: Vote casting request data
            voter_address: Wallet address of voter

        Returns:
            Vote cast response with blockchain details

        Raises:
            ValueError: If proposal doesn't exist or voting period invalid
            Exception: If blockchain transaction fails
        """
        try:
            from models.governance_vote import GovernanceVote
            from models.user_share_balance import UserShareBalance
            from sqlalchemy.exc import IntegrityError
            
            support_labels = {0: "Against", 1: "For", 2: "Abstain"}

            # Check if user has already voted
            existing_vote = self.db.query(GovernanceVote).filter(
                GovernanceVote.proposal_id == request.proposal_id,
                GovernanceVote.voter_address == voter_address
            ).first()
            
            if existing_vote:
                raise ValueError(f"You have already voted on this proposal (vote cast: {support_labels[existing_vote.support]})")

            # Fetch the proposal to get agreement_id
            proposal = self.db.query(GovernanceProposal).filter(
                GovernanceProposal.id == request.proposal_id
            ).first()
            
            if not proposal:
                raise ValueError(f"Proposal {request.proposal_id} not found")
            
            # Fetch voter's voting power from user_share_balances (Iteration 12)
            user_balance = self.db.query(UserShareBalance).filter(
                UserShareBalance.user_address == voter_address.lower(),
                UserShareBalance.agreement_id == proposal.agreement_id
            ).first()
            
            if not user_balance or user_balance.balance_wei <= 0:
                raise ValueError(f"You do not own any tokens for Agreement #{proposal.agreement_id}")
            
            voting_power_from_db = int(user_balance.balance_wei)
            logger.info(f"✅ Retrieved voting power for {voter_address[:10]}... on agreement #{proposal.agreement_id}: {voting_power_from_db:,} tokens")

            # Call Web3 service to cast vote (handles testing_mode internally)
            # Pass the voting_power so it doesn't need to fetch it again
            tx_hash, voting_power = await self.web3_service.cast_vote(
                proposal_id=request.proposal_id,
                support=request.support,
                voter_address=voter_address,
                voting_power=voting_power_from_db
            )

            # Record vote in database (after successful blockchain interaction)
            try:
                vote_record = GovernanceVote(
                    proposal_id=request.proposal_id,
                    voter_address=voter_address,
                    support=request.support,
                    voting_power=voting_power
                )
                self.db.add(vote_record)
                self.db.commit()
                self.db.refresh(vote_record)
                logger.info(f"✅ Vote recorded in database: proposal={request.proposal_id}, voter={voter_address}, support={support_labels[request.support]}")
            except IntegrityError as ie:
                self.db.rollback()
                logger.error(f"Database integrity error (duplicate vote?): {ie}")
                raise ValueError(f"You have already voted on this proposal")

            logger.info(f"Vote cast by {voter_address} on proposal {request.proposal_id}: {support_labels[request.support]}")

            return VoteCastResponse(
                proposal_id=request.proposal_id,
                voter_address=voter_address,
                support=support_labels[request.support],
                voting_power=voting_power,
                tx_hash=tx_hash,
                status="PENDING"
            )

        except ValueError as e:
            logger.error(f"Validation error casting vote: {e}")
            raise
        except Exception as e:
            logger.error(f"Error casting vote: {e}")
            raise Exception(f"Failed to cast vote: {str(e)}")

    async def execute_proposal(
        self,
        proposal_id: int
    ) -> ProposalExecuteResponse:
        """
        Execute a governance proposal after voting ends

        Args:
            proposal_id: Proposal ID to execute

        Returns:
            Proposal execution response

        Raises:
            ValueError: If proposal doesn't exist or voting not ended
            Exception: If blockchain transaction fails
        """
        try:
            # Call Web3 service to execute proposal (handles testing_mode internally)
            tx_hash = await self.web3_service.execute_proposal(proposal_id)

            logger.info(f"Executed proposal {proposal_id}")

            return ProposalExecuteResponse(
                proposal_id=proposal_id,
                executed=True,
                tx_hash=tx_hash,
                message="Proposal executed successfully"
            )

        except ValueError as e:
            logger.error(f"Validation error executing proposal: {e}")
            raise
        except Exception as e:
            logger.error(f"Error executing proposal: {e}")
            raise Exception(f"Failed to execute proposal: {str(e)}")

    async def get_proposal(
        self,
        proposal_id: int
    ) -> ProposalDetailResponse:
        """
        Get governance proposal details

        Args:
            proposal_id: Proposal ID to query

        Returns:
            Proposal detail response

        Raises:
            ValueError: If proposal doesn't exist
        """
        try:
            from models.governance_proposal import GovernanceProposal
            from models.governance_vote import GovernanceVote
            from sqlalchemy import func
            
            # Query database directly (web3_service doesn't have db access!)
            proposal = self.db.query(GovernanceProposal).filter(
                GovernanceProposal.id == proposal_id
            ).first()
            
            if not proposal:
                raise Exception(f"Proposal {proposal_id} not found in database")
            
            # Aggregate votes from governance_votes table
            # Group by support type and SUM the voting_power
            vote_counts = self.db.query(
                GovernanceVote.support,
                func.sum(GovernanceVote.voting_power).label('total_power')
            ).filter(
                GovernanceVote.proposal_id == proposal_id
            ).group_by(GovernanceVote.support).all()
            
            # Initialize vote tallies
            for_votes = 0
            against_votes = 0
            abstain_votes = 0
            
            # Map aggregated votes: support 0=Against, 1=For, 2=Abstain
            for support, total_power in vote_counts:
                if support == 1:
                    for_votes = int(total_power)
                elif support == 0:
                    against_votes = int(total_power)
                elif support == 2:
                    abstain_votes = int(total_power)
            
            # Calculate total votes and quorum
            total_votes = for_votes + against_votes + abstain_votes
            
            # Get agreement to calculate dynamic quorum
            from models.yield_agreement import YieldAgreement
            agreement = self.db.query(YieldAgreement).filter(
                YieldAgreement.id == proposal.agreement_id
            ).first()
            
            if not agreement:
                raise Exception(f"Agreement {proposal.agreement_id} not found for proposal {proposal_id}")
            
            # Calculate quorum: (total_supply × 10%) / 100%
            # Default quorum_percentage = 1000 basis points (10%)
            quorum_percentage = 1000  # TODO: Get from governance contract parameters
            quorum_required = (agreement.total_token_supply * quorum_percentage) // 10000
            quorum_reached = total_votes >= quorum_required
            
            logger.debug(f"Proposal {proposal_id} vote tally: For={for_votes}, Against={against_votes}, Abstain={abstain_votes}, Total={total_votes}/{quorum_required} ({100*total_votes//quorum_required if quorum_required > 0 else 0}%), Quorum={quorum_reached}")
            
            # Calculate current status based on timestamps (same logic as GET /proposals)
            # Get current time from database to ensure timezone consistency
            from sqlalchemy import text
            result = self.db.execute(text("SELECT NOW()")).scalar()
            # Convert to naive datetime (remove timezone) for comparison with database timestamps
            now = result.replace(tzinfo=None) if result.tzinfo else result
            
            if now < proposal.voting_start:
                current_status = "PENDING"
            elif now <= proposal.voting_end:
                current_status = "ACTIVE"
            elif proposal.executed:
                current_status = "EXECUTED"
            elif proposal.defeated:
                current_status = "DEFEATED"
            else:
                current_status = "SUCCEEDED"  # Voting ended, passed, not executed yet

            return ProposalDetailResponse(
                proposal_id=proposal.id,
                blockchain_proposal_id=proposal.blockchain_proposal_id,
                proposer=proposal.proposer,
                agreement_id=proposal.agreement_id,
                proposal_type=proposal.proposal_type,
                target_value=int(proposal.target_value) if proposal.target_value else 0,
                description=proposal.description,
                voting_start=proposal.voting_start,
                voting_end=proposal.voting_end,
                for_votes=for_votes,
                against_votes=against_votes,
                abstain_votes=abstain_votes,
                executed=proposal.executed,
                defeated=proposal.defeated,
                quorum_reached=quorum_reached,
                status=current_status,
                quorum_required=quorum_required
            )

        except Exception as e:
            logger.error(f"Error getting proposal {proposal_id}: {e}")
            raise Exception(f"Failed to get proposal: {str(e)}")

    async def get_proposals(self) -> List[ProposalDetailResponse]:
        """
        Get all governance proposals

        Returns:
            List of proposal detail responses
        """
        try:
            # Query database for all proposals
            # proposals = self.db.query(GovernanceProposal).all()
            # return [ProposalDetailResponse.from_orm(p) for p in proposals]
            return []  # Placeholder

        except Exception as e:
            logger.error(f"Error getting proposals: {e}")
            raise Exception(f"Failed to get proposals: {str(e)}")

    async def get_voting_power(
        self,
        voter_address: str,
        agreement_id: int,
        token_standard: str = "ERC721"
    ) -> VotingPowerResponse:
        """
        Get voting power for a voter on a specific agreement

        Args:
            voter_address: Wallet address of voter
            agreement_id: Agreement ID to check voting power for
            token_standard: Token standard (ERC721 or ERC1155)

        Returns:
            Voting power response

        Raises:
            Exception: If query fails
        """
        try:
            # Call Web3 service to get voting power (handles testing_mode internally)
            voting_power = await self.web3_service.get_voting_power(
                voter_address,
                agreement_id,
                token_standard,
                self.db  # Pass database session for testing mode
            )

            return VotingPowerResponse(
                voter_address=voter_address,
                agreement_id=agreement_id,
                voting_power=voting_power,
                token_standard=token_standard
            )

        except Exception as e:
            logger.error(f"Error getting voting power for {voter_address}: {e}")
            raise Exception(f"Failed to get voting power: {str(e)}")
