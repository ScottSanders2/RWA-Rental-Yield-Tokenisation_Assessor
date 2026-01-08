"""
Governance API Router for On-Chain Governance Endpoints

FastAPI router handling governance proposal creation, voting, and execution.
Includes time metrics tracking for dissertation analysis.
"""

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List, Optional
import time
import logging
from datetime import datetime

from schemas.governance import (
    GovernanceProposalCreateRequest,
    GovernanceProposalCreateResponse,
    VoteCastRequest,
    VoteCastResponse,
    ProposalDetailResponse,
    ProposalExecuteRequest,
    ProposalExecuteResponse,
    VotingPowerResponse,
    VoteCheckResponse
)
from services.governance_service import GovernanceService
from config.database import get_db  # Import proper database dependency
from config.web3_config import get_web3_service  # Import Web3 service like all other routes

logger = logging.getLogger(__name__)

router = APIRouter(
    prefix="/governance",
    tags=["governance"],
    responses={404: {"description": "Not found"}},
)


@router.get(
    "/proposals",
    response_model=List[ProposalDetailResponse],
    summary="Get All Proposals",
    description="Retrieve all governance proposals"
)
async def get_all_proposals(db: Session = Depends(get_db)):
    """
    Get all governance proposals
    
    Returns list of all proposals with their current status, vote counts, and metadata.
    Vote counts are dynamically aggregated from the governance_votes table.
    """
    try:
        from models.governance_proposal import GovernanceProposal
        from models.governance_vote import GovernanceVote
        from datetime import datetime
        from sqlalchemy import func
        
        proposals = db.query(GovernanceProposal).order_by(GovernanceProposal.created_at.desc()).all()
        
        # Convert to response format
        response_proposals = []
        for proposal in proposals:
            now = datetime.now()
            
            # Update status based on timestamps
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
            
            # Aggregate votes from governance_votes table for THIS proposal
            vote_counts = db.query(
                GovernanceVote.support,
                func.sum(GovernanceVote.voting_power).label('total_power')
            ).filter(
                GovernanceVote.proposal_id == proposal.id
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
            
            # Calculate quorum dynamically from agreement's total token supply
            total_votes = for_votes + against_votes + abstain_votes
            
            # Get agreement for this proposal
            from models.yield_agreement import YieldAgreement
            agreement = db.query(YieldAgreement).filter(
                YieldAgreement.id == proposal.agreement_id
            ).first()
            
            # Calculate quorum: (total_supply × 10%) / 100%
            if agreement:
                quorum_percentage = 1000  # 10% in basis points
                quorum_required = (agreement.total_token_supply * quorum_percentage) // 10000
            else:
                # Fallback if agreement not found
                quorum_required = 10000
            
            quorum_reached = total_votes >= quorum_required
            
            response_proposals.append(ProposalDetailResponse(
                proposal_id=proposal.id,
                blockchain_proposal_id=proposal.blockchain_proposal_id,
                proposer=proposal.proposer,
                agreement_id=proposal.agreement_id,
                proposal_type=proposal.proposal_type,
                target_value=int(proposal.target_value),
                description=proposal.description,
                voting_start=proposal.voting_start,
                voting_end=proposal.voting_end,
                for_votes=for_votes,
                against_votes=against_votes,
                abstain_votes=abstain_votes,
                status=current_status,
                executed=proposal.executed,
                defeated=proposal.defeated,
                quorum_reached=quorum_reached,
                quorum_required=quorum_required
            ))
        
        return response_proposals
        
    except Exception as e:
        logger.error(f"Error retrieving proposals: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to retrieve proposals: {str(e)}"
        )


@router.post(
    "/proposals",
    response_model=GovernanceProposalCreateResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create Governance Proposal",
    description="Create a new governance proposal for ROI adjustment, reserve allocation, or parameter update"
)
async def create_governance_proposal(
    request: GovernanceProposalCreateRequest,
    db: Session = Depends(get_db),
    web3_service = Depends(get_web3_service)
):
    """
    Create a new governance proposal

    **Proposal Types:**
    - ROI_ADJUSTMENT: Modify agreement ROI within ±5% bounds
    - RESERVE_ALLOCATION: Allocate ETH reserve (≤20% of capital)
    - RESERVE_WITHDRAWAL: Return unused reserves to investors
    - PARAMETER_UPDATE: Modify grace periods, penalty rates, etc.

    **Validation:**
    - Proposer must hold ≥1% of tokens (proposal threshold)
    - ROI must be within 100-5000 basis points (1-50%)
    - ROI adjustment must be within ±5% of original
    - Reserve allocation must be ≤20% of upfront capital
    - Description must be 10-500 characters

    **Returns:**
    - Proposal ID (on-chain and database)
    - Transaction hash
    - Voting period details (1 day delay, 7 day voting)
    - Quorum and threshold requirements
    """
    start_time = time.time()

    try:
        # Create governance service
        governance_service = GovernanceService(db, web3_service)

        # Create proposal
        response = await governance_service.create_proposal(request)

        # Log metrics
        api_time = time.time() - start_time
        logger.info(f"Proposal created in {api_time:.2f}s - Agreement: {request.agreement_id}")

        return response

    except ValueError as e:
        # Validation errors (agreement not found, invalid parameters)
        logger.error(f"Validation error: {e}")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )
    except Exception as e:
        # Blockchain or database errors
        logger.error(f"Error creating proposal: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to create proposal: {str(e)}"
        )


@router.post(
    "/proposals/{proposal_id}/vote",
    response_model=VoteCastResponse,
    summary="Cast Vote on Proposal",
    description="Cast a vote (For/Against/Abstain) on an active governance proposal"
)
async def cast_vote_on_proposal(
    proposal_id: int,
    request: VoteCastRequest,
    voter_address: str = "0x0000000000000000000000000000000000000000",  # Placeholder
    db: Session = Depends(get_db),
    web3_service = Depends(get_web3_service)
):
    """
    Cast a vote on a governance proposal

    **Vote Options:**
    - 0: Against
    - 1: For
    - 2: Abstain

    **Validation:**
    - Proposal must be in active voting period (after delay, before end)
    - Voter must hold tokens (voting power > 0)
    - Voter cannot vote twice on same proposal

    **Voting Power:**
    - 1 token = 1 vote (token-weighted voting)
    - Voting power calculated from token balance at time of vote

    **Returns:**
    - Vote details (proposal, voter, support, voting power)
    - Transaction hash
    """
    start_time = time.time()

    try:
        # Update request with proposal_id
        request.proposal_id = proposal_id

        # Create governance service
        governance_service = GovernanceService(db, web3_service)

        # Cast vote
        response = await governance_service.cast_vote(request, voter_address)

        # Log metrics
        vote_time = time.time() - start_time
        logger.info(f"Vote cast in {vote_time:.2f}s - Proposal: {proposal_id}")

        return response

    except ValueError as e:
        logger.error(f"Validation error: {e}")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )
    except Exception as e:
        logger.error(f"Error casting vote: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to cast vote: {str(e)}"
        )


@router.post(
    "/proposals/{proposal_id}/execute",
    response_model=ProposalExecuteResponse,
    summary="Execute Proposal",
    description="Execute a successful governance proposal after voting period ends"
)
async def execute_governance_proposal(
    proposal_id: int,
    db: Session = Depends(get_db),
    web3_service = Depends(get_web3_service)
):
    """
    Execute a governance proposal

    **Execution Requirements:**
    - Voting period must have ended
    - Quorum must be reached (≥10% participation)
    - Simple majority must approve (for_votes > against_votes)
    - Proposal not already executed or defeated

    **Actions:**
    - ROI_ADJUSTMENT: Updates YieldBase.annualROIBasisPoints
    - RESERVE_ALLOCATION: Transfers ETH to YieldBase for reserve
    - RESERVE_WITHDRAWAL: Transfers reserve back to governance controller
    - PARAMETER_UPDATE: Updates governance parameters

    **Returns:**
    - Execution status (executed or defeated)
    - Transaction hash
    - Success/failure message
    """
    start_time = time.time()

    try:
        # Create governance service
        governance_service = GovernanceService(db, web3_service)

        # Execute proposal
        response = await governance_service.execute_proposal(proposal_id)

        # Log metrics
        exec_time = time.time() - start_time
        logger.info(f"Proposal executed in {exec_time:.2f}s - Proposal: {proposal_id}")

        return response

    except ValueError as e:
        logger.error(f"Validation error: {e}")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )
    except Exception as e:
        logger.error(f"Error executing proposal: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to execute proposal: {str(e)}"
        )




@router.get(
    "/proposals/{proposal_id}",
    response_model=ProposalDetailResponse,
    summary="Get Proposal Details",
    description="Retrieve detailed information about a specific governance proposal"
)
async def get_proposal_details(
    proposal_id: int,
    db: Session = Depends(get_db),
    web3_service = Depends(get_web3_service)
):
    """
    Get governance proposal details

    **Returns:**
    - Complete proposal information
    - Current vote counts
    - Voting period status
    - Execution status
    - Quorum reached status
    """
    try:
        # Create governance service
        governance_service = GovernanceService(db, web3_service)

        # Get proposal
        proposal = await governance_service.get_proposal(proposal_id)

        return proposal

    except Exception as e:
        logger.error(f"Error getting proposal {proposal_id}: {e}")
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Proposal not found: {str(e)}"
        )


@router.get(
    "/proposals/{proposal_id}/my-vote",
    response_model=VoteCheckResponse,
    summary="Check If User Has Voted",
    description="Check if a specific user has already voted on a proposal"
)
async def check_user_vote(
    proposal_id: int,
    voter_address: str = "0x0000000000000000000000000000000000000000",  # Placeholder until wallet auth
    db: Session = Depends(get_db)
):
    """
    Check if a user has voted on a proposal
    
    **Parameters:**
    - `proposal_id`: Database ID of the proposal
    - `voter_address`: Ethereum address of the voter (from auth in production)
    
    **Returns:**
    - `has_voted`: Boolean indicating if user has voted
    - `support`: Vote choice if voted (0=Against, 1=For, 2=Abstain)
    - `voting_power`: Voting power used (if voted)
    - `voted_at`: Timestamp when vote was cast (if voted)
    
    **Use Case:**
    Frontend calls this to show "You have already voted" message
    and disable voting buttons for users who have already voted.
    """
    try:
        from models.governance_vote import GovernanceVote
        
        # Query for existing vote
        vote = db.query(GovernanceVote).filter(
            GovernanceVote.proposal_id == proposal_id,
            GovernanceVote.voter_address == voter_address
        ).first()
        
        if vote:
            # User has voted
            return VoteCheckResponse(
                has_voted=True,
                support=vote.support,
                voting_power=vote.voting_power,
                voted_at=vote.voted_at
            )
        else:
            # User has not voted
            return VoteCheckResponse(
                has_voted=False,
                support=None,
                voting_power=None,
                voted_at=None
            )
    
    except Exception as e:
        logger.error(f"Error checking vote status for proposal {proposal_id}, voter {voter_address}: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to check vote status: {str(e)}"
        )


@router.get(
    "/voting-power/{voter_address}/{agreement_id}",
    response_model=VotingPowerResponse,
    summary="Get Voting Power",
    description="Get voting power for a voter on a specific agreement"
)
async def get_voting_power(
    voter_address: str,
    agreement_id: int,
    token_standard: str = "ERC721",
    db: Session = Depends(get_db),
    web3_service = Depends(get_web3_service)
):
    """
    Get voting power for a voter

    **Voting Power Calculation:**
    - ERC-721+ERC-20: YieldSharesToken.balanceOf(voter)
    - ERC-1155: CombinedPropertyYieldToken.balanceOf(voter, yieldTokenId)
    - 1 token = 1 vote (token-weighted voting)

    **Returns:**
    - Voter address
    - Agreement ID
    - Voting power (token balance)
    - Token standard used
    """
    try:
        # Create governance service
        governance_service = GovernanceService(db, web3_service)

        # Get voting power
        voting_power = await governance_service.get_voting_power(
            voter_address,
            agreement_id,
            token_standard
        )

        return voting_power

    except Exception as e:
        logger.error(f"Error getting voting power: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to get voting power: {str(e)}"
        )


@router.get(
    "/data-integrity/check",
    summary="Data Integrity Audit",
    description="Perform data integrity audit to detect proposals with 0 voting power or missing token balances"
)
async def data_integrity_audit(db: Session = Depends(get_db)):
    """
    **Data Integrity Audit Endpoint**
    
    Performs comprehensive checks to detect data inconsistencies:
    - Proposals with agreements that have 0 token holders
    - Proposals with agreements that have 0 total voting power
    - Agreements with proposals but no token distribution
    
    **Returns:**
    - Total proposals checked
    - Number of issues found
    - Detailed list of problematic proposals with remediation steps
    
    **Use Cases:**
    - Periodic automated health checks
    - Pre-migration validation
    - Troubleshooting voting power issues
    - Detecting proposals created before token seeding was implemented
    """
    try:
        from models.governance_proposal import GovernanceProposal
        from models.yield_agreement import YieldAgreement
        from models.user_share_balance import UserShareBalance
        from sqlalchemy import func
        
        logger.info("🔍 Starting data integrity audit...")
        
        # Get all proposals with their agreement info
        proposals = db.query(
            GovernanceProposal.id,
            GovernanceProposal.blockchain_proposal_id,
            GovernanceProposal.agreement_id,
            GovernanceProposal.description,
            GovernanceProposal.status,
            GovernanceProposal.created_at,
            YieldAgreement.total_token_supply,
            YieldAgreement.token_standard,
            YieldAgreement.property_id
        ).join(
            YieldAgreement,
            GovernanceProposal.agreement_id == YieldAgreement.id
        ).all()
        
        total_proposals = len(proposals)
        issues_found = []
        
        for proposal in proposals:
            # Check token balances for this agreement (Iteration 12: use user_share_balances)
            token_check = db.query(
                func.count(UserShareBalance.id).label('holder_count'),
                func.sum(UserShareBalance.balance_wei).label('total_tokens')
            ).filter(
                UserShareBalance.agreement_id == proposal.agreement_id
            ).first()
            
            holder_count = token_check.holder_count or 0
            total_tokens = int(token_check.total_tokens or 0)
            
            # Flag if no token holders or 0 total voting power
            if holder_count == 0 or total_tokens == 0:
                issues_found.append({
                    "proposal_id": proposal.id,
                    "blockchain_proposal_id": proposal.blockchain_proposal_id,
                    "agreement_id": proposal.agreement_id,
                    "property_id": proposal.property_id,
                    "description": proposal.description[:50] + "..." if len(proposal.description) > 50 else proposal.description,
                    "status": proposal.status,
                    "created_at": proposal.created_at.isoformat() if proposal.created_at else None,
                    "token_holders": holder_count,
                    "total_voting_power": total_tokens,
                    "expected_total_supply": proposal.total_token_supply,
                    "token_standard": proposal.token_standard,
                    "issue_type": "NO_TOKEN_DISTRIBUTION" if holder_count == 0 else "ZERO_VOTING_POWER",
                    "severity": "CRITICAL",
                    "impact": "Users cannot vote on this proposal (0 voting power)",
                    "remediation": f"Seed token balances for agreement {proposal.agreement_id} using established distribution pattern"
                })
                logger.warning(
                    f"⚠️ Issue found: Proposal {proposal.id} (Agreement {proposal.agreement_id}) - "
                    f"{holder_count} holders, {total_tokens:,} total tokens"
                )
        
        result = {
            "audit_timestamp": datetime.now().isoformat() + "Z",
            "total_proposals_checked": total_proposals,
            "issues_found_count": len(issues_found),
            "health_status": "HEALTHY" if len(issues_found) == 0 else "UNHEALTHY",
            "issues": issues_found
        }
        
        if len(issues_found) == 0:
            logger.info(f"✅ Data integrity audit passed: {total_proposals} proposals checked, 0 issues found")
        else:
            logger.warning(
                f"⚠️ Data integrity audit found {len(issues_found)} issue(s) "
                f"out of {total_proposals} proposals checked"
            )
        
        return result
        
    except Exception as e:
        logger.error(f"Error during data integrity audit: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Data integrity audit failed: {str(e)}"
        )

