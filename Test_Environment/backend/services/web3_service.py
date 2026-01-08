"""
Web3 service class for blockchain interaction abstraction.

This service provides a clean interface for smart contract interactions,
handling ABI loading, transaction signing, gas estimation, and event parsing.
Supports both ERC-721+ERC-20 and ERC-1155 approaches for comparative analysis.
"""

import json
import logging
from pathlib import Path
from typing import Dict, Tuple, Optional, Any, List
from web3 import Web3
from web3.contract import Contract
from eth_account import Account
from eth_account.signers.local import LocalAccount
from sqlalchemy.orm import Session

from config.web3_config import get_web3, get_deployer_account, get_contract_addresses
from utils.metrics import track_time
from config.settings import settings
import os

# Configure logger
logger = logging.getLogger(__name__)


class Web3Service:
    """
    Service class for blockchain interactions with deployed smart contracts.

    Abstracts Web3 complexity and provides clean methods for property registration,
    verification, and yield agreement creation across different token standards.
    """

    def __init__(self, testing_mode: bool = None, db: Session = None):
        """
        Initialize Web3Service with contract connections.

        Args:
            testing_mode: Override testing mode (defaults to environment variable)
            db: Database session (required for testing mode)
        """
        # Check testing mode from environment or parameter
        self.testing_mode = testing_mode if testing_mode is not None else os.getenv('WEB3_TESTING_MODE', 'false').lower() == 'true'
        self.event_monitoring_enabled = os.getenv('WEB3_EVENT_MONITORING', 'false').lower() == 'true'
        self.db = db  # Store database session for testing mode

        if not self.testing_mode:
            self.w3: Web3 = get_web3()
            self.deployer_account: LocalAccount = get_deployer_account()
            self.contract_addresses: Dict[str, str] = get_contract_addresses()

            # Load contract instances
            self.property_nft: Contract = self._get_contract_instance(
                self.contract_addresses["PropertyNFT"], "PropertyNFT"
            )
            self.yield_base: Contract = self._get_contract_instance(
                self.contract_addresses["YieldBase"], "YieldBase"
            )
            self.combined_token: Contract = self._get_contract_instance(
                self.contract_addresses["CombinedPropertyYieldToken"], "CombinedPropertyYieldToken"
            )
        else:
            # Testing mode - initialize with mock data
            self.w3 = None
            self.deployer_account = None
            self.contract_addresses = {
                "PropertyNFT": "0x5FbDB2315678afecb367f032d93F642f64180aa3",
                "YieldBase": "0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512",
                "CombinedPropertyYieldToken": "0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0"
            }
            self.property_nft = None
            self.yield_base = None
            self.combined_token = None

        # Event monitoring and audit trail
        self.event_logs = []
        self.transaction_history = []
        self.audit_trail = []

    def _load_contract_abi(self, contract_name: str) -> Dict[str, Any]:
        """
        Load contract ABI from Foundry artifacts.

        Args:
            contract_name: Name of the contract (without .sol extension)

        Returns:
            Dict containing contract ABI

        Raises:
            FileNotFoundError: If ABI file not found
            ValueError: If ABI parsing fails
        """
        # Path to Foundry artifacts (mounted at /contracts)
        artifacts_dir = Path("/contracts/out")
        abi_path = artifacts_dir / f"{contract_name}.sol" / f"{contract_name}.json"

        if not abi_path.exists():
            raise FileNotFoundError(f"Contract ABI not found: {abi_path}")

        try:
            with open(abi_path, 'r') as f:
                artifact = json.load(f)
                return artifact["abi"]
        except (json.JSONDecodeError, KeyError) as e:
            raise ValueError(f"Invalid contract artifact: {e}")

    def _get_contract_instance(self, address: str, contract_name: str) -> Contract:
        """
        Create Web3 contract instance.

        Args:
            address: Contract address
            contract_name: Contract name for ABI loading

        Returns:
            Web3 contract instance
        """
        abi = self._load_contract_abi(contract_name)
        return self.w3.eth.contract(address=address, abi=abi)

    def _send_transaction(self, contract_function, *args, **kwargs) -> Tuple[str, int, Dict[str, Any]]:
        """
        Send signed transaction and wait for confirmation.

        Args:
            contract_function: Web3 contract function to call
            *args: Function arguments
            **kwargs: Additional transaction parameters

        Returns:
            Tuple of (transaction_hash, gas_used, receipt)

        Raises:
            Exception: For transaction failures
        """
        # Build transaction
        tx = contract_function(*args, **kwargs).build_transaction({
            'from': self.deployer_account.address,
            'nonce': self.w3.eth.get_transaction_count(self.deployer_account.address),
            'gasPrice': self.w3.eth.gas_price,
        })

        # Estimate gas
        try:
            gas_estimate = contract_function(*args, **kwargs).estimate_gas({
                'from': self.deployer_account.address
            })
            tx['gas'] = int(gas_estimate * 1.2)  # Add 20% buffer
        except Exception as e:
            # Fallback gas limit
            tx['gas'] = 5000000
            print(f"Gas estimation failed, using fallback: {e}")

        # Sign and send transaction
        signed_tx = self.deployer_account.sign_transaction(tx)
        tx_hash = self.w3.eth.send_raw_transaction(signed_tx.rawTransaction)

        # Wait for transaction receipt
        receipt = self.w3.eth.wait_for_transaction_receipt(tx_hash)

        if receipt['status'] != 1:
            raise Exception(f"Transaction failed: {tx_hash.hex()}")

        return tx_hash.hex(), receipt['gasUsed'], receipt

    def _parse_property_minted_event(self, receipt: Dict[str, Any]) -> int:
        """
        Parse PropertyMinted event from transaction receipt to extract token ID.

        Args:
            receipt: Transaction receipt

        Returns:
            Token ID from the PropertyMinted event

        Raises:
            Exception: If PropertyMinted event not found or parsing fails
        """
        if self.testing_mode:
            # In testing mode, extract from mock receipt structure
            if 'events' in receipt and 'PropertyMinted' in receipt['events']:
                return receipt['events']['PropertyMinted']['tokenId']
            else:
                raise Exception("PropertyMinted event not found in mock transaction receipt")
        else:
            # Production mode - use real Web3 event parsing
            property_minted_event = self.property_nft.events.PropertyMinted()
            logs = property_minted_event.process_receipt(receipt)

            if not logs:
                raise Exception("PropertyMinted event not found in transaction receipt")

            # Return the tokenId from the first (and should be only) PropertyMinted event
            return logs[0]['args']['tokenId']

    def _create_mock_receipt(self, event_name: str, event_data: Dict[str, Any]) -> Dict[str, Any]:
        """
        Create a mock transaction receipt with simulated event logs.

        Args:
            event_name: Name of the event to simulate
            event_data: Event data to include

        Returns:
            Mock receipt dictionary
        """
        return {
            'transactionHash': f"0x{hash(str(event_data)):064x}",
            'blockNumber': 12345,
            'gasUsed': 21000,
            'status': 1,
            'events': {
                event_name: event_data
            },
            'logs': []  # Would contain raw log data in production
        }

    def _log_transaction(self, operation: str, data: Dict[str, Any]):
        """
        Log transaction for audit trail and monitoring.

        Args:
            operation: Operation name
            data: Transaction data
        """
        import datetime
        log_entry = {
            'timestamp': datetime.datetime.utcnow().isoformat() + 'Z',
            'operation': operation,
            'data': data
        }

        self.transaction_history.append(log_entry)
        self.audit_trail.append(log_entry)

        if self.event_monitoring_enabled:
            self.event_logs.append(log_entry)

    def get_audit_trail(self) -> List[Dict[str, Any]]:
        """
        Get complete audit trail of all transactions.

        Returns:
            List of audit trail entries
        """
        return self.audit_trail.copy()

    def get_event_logs(self) -> List[Dict[str, Any]]:
        """
        Get event monitoring logs.

        Returns:
            List of event log entries
        """
        return self.event_logs.copy()

    def validate_transaction_integrity(self, tx_hash: str) -> bool:
        """
        Validate transaction integrity for audit purposes.

        Args:
            tx_hash: Transaction hash to validate

        Returns:
            True if transaction is valid and recorded
        """
        for entry in self.audit_trail:
            if entry['data'].get('tx_hash') == tx_hash:
                return True
        return False

    def _parse_yield_agreement_created_event(self, receipt: Dict[str, Any]) -> int:
        """
        Parse YieldAgreementCreated event from transaction receipt to extract agreement ID.

        Args:
            receipt: Transaction receipt

        Returns:
            Agreement ID from the YieldAgreementCreated event

        Raises:
            Exception: If YieldAgreementCreated event not found or parsing fails
        """
        # Get YieldBase contract events
        yield_agreement_created_event = self.yield_base.events.YieldAgreementCreated()

        # Parse logs for YieldAgreementCreated events
        logs = yield_agreement_created_event.process_receipt(receipt)

        if not logs:
            raise Exception("YieldAgreementCreated event not found in transaction receipt")

        # Return the agreementId from the first (and should be only) YieldAgreementCreated event
        return logs[0]['args']['agreementId']

    def _parse_property_token_minted_event(self, receipt: Dict[str, Any]) -> int:
        """
        Parse PropertyTokenMinted event from transaction receipt to extract token ID.

        Args:
            receipt: Transaction receipt

        Returns:
            Token ID from the PropertyTokenMinted event

        Raises:
            Exception: If PropertyTokenMinted event not found or parsing fails
        """
        # Get CombinedPropertyYieldToken contract events
        property_token_minted_event = self.combined_token.events.PropertyTokenMinted()

        # Parse logs for PropertyTokenMinted events
        logs = property_token_minted_event.process_receipt(receipt)

        if not logs:
            raise Exception("PropertyTokenMinted event not found in transaction receipt")

        # Return the tokenId from the first (and should be only) PropertyTokenMinted event
        return logs[0]['args']['tokenId']

    @track_time("web3_mint_property_nft", lambda self, pah, uri: {"contract": "PropertyNFT"})
    def mint_property_nft(self, property_address_hash: bytes, metadata_uri: str) -> Tuple[int, str, int]:
        """
        Mint PropertyNFT token for property registration.

        Args:
            property_address_hash: Keccak256 hash of property address (bytes32)
            metadata_uri: IPFS URI for property metadata

        Returns:
            Tuple of (token_id, tx_hash, gas_used)
        """
        if self.testing_mode:
            return self._mint_property_nft_testing(property_address_hash, metadata_uri)
        else:
            return self._mint_property_nft_production(property_address_hash, metadata_uri)

    def _mint_property_nft_production(self, property_address_hash: bytes, metadata_uri: str) -> Tuple[int, str, int]:
        """
        Production implementation of property NFT minting.
        """
        # Send the transaction
        tx_hash, gas_used, receipt = self._send_transaction(
            self.property_nft.functions.mintProperty,
            property_address_hash,
            metadata_uri
        )

        # Parse PropertyMinted event from receipt to get the actual token ID
        token_id = self._parse_property_minted_event(receipt)

        # Log for audit trail
        self._log_transaction("mint_property_nft", {
            "token_id": token_id,
            "property_address_hash": property_address_hash.hex(),
            "metadata_uri": metadata_uri,
            "tx_hash": tx_hash,
            "gas_used": gas_used
        })

        return token_id, tx_hash, gas_used

    def _mint_property_nft_testing(self, property_address_hash: bytes, metadata_uri: str) -> Tuple[int, str, int]:
        """
        Testing implementation with simulated transaction and event emission.
        """
        # Generate mock token ID from property hash (deterministic for testing)
        token_id = int.from_bytes(property_address_hash[:4], byteorder='big') % 1000000 + 1

        # Mock transaction hash
        tx_hash = f"0x{token_id:064x}"

        # Mock gas used
        gas_used = 21000 + (len(metadata_uri) * 10)  # Variable gas based on URI length

        # Create mock receipt with PropertyMinted event
        mock_receipt = self._create_mock_receipt("PropertyMinted", {
            "tokenId": token_id,
            "propertyHash": property_address_hash,
            "metadataUri": metadata_uri,
            "minter": "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"  # Default Anvil account
        })

        # Simulate event parsing (test the parsing logic)
        parsed_token_id = self._parse_property_minted_event(mock_receipt)

        # Ensure consistency
        if parsed_token_id != token_id:
            raise Exception(f"Event parsing inconsistency: expected {token_id}, got {parsed_token_id}")

        # Log for audit trail
        self._log_transaction("mint_property_nft_test", {
            "token_id": token_id,
            "property_address_hash": property_address_hash.hex(),
            "metadata_uri": metadata_uri,
            "tx_hash": tx_hash,
            "gas_used": gas_used,
            "testing_mode": True
        })

        return token_id, tx_hash, gas_used

    def verify_property_nft(self, token_id: int) -> Tuple[str, int]:
        """
        Verify property by calling PropertyNFT.verifyProperty().

        Args:
            token_id: PropertyNFT token ID

        Returns:
            Tuple of (tx_hash, gas_used)
        """
        tx_hash, gas_used, _ = self._send_transaction(
            self.property_nft.functions.verifyProperty,
            token_id
        )
        return tx_hash, gas_used

    def create_yield_agreement(
        self,
        property_token_id: int,
        upfront_capital: int,
        term_months: int,
        annual_roi: int,
        payer: Optional[str],
        grace_period: int,
        penalty_rate: int,
        threshold: int,
        allow_partial: bool,
        allow_early: bool
    ) -> Tuple[int, str, str, int]:
        """
        Create yield agreement via YieldBase.createYieldAgreement().

        Args:
            property_token_id: PropertyNFT token ID
            upfront_capital: Initial capital amount (wei)
            term_months: Agreement term in months
            annual_roi: Annual ROI in basis points
            payer: Property payer address (optional)
            grace_period: Grace period in days
            penalty_rate: Penalty rate in basis points
            threshold: Default threshold in months
            allow_partial: Whether partial repayments allowed
            allow_early: Whether early repayment allowed

        Returns:
            Tuple of (agreement_id, token_contract_address, tx_hash, gas_used)
        """
        # Send the transaction
        tx_hash, gas_used, receipt = self._send_transaction(
            self.yield_base.functions.createYieldAgreement,
            property_token_id,
            upfront_capital,
            term_months,
            annual_roi,
            payer or self.deployer_account.address,  # Use deployer if no payer specified
            grace_period,
            penalty_rate,
            threshold,
            allow_partial,
            allow_early
        )

        # Parse YieldAgreementCreated event from receipt to get the actual agreement ID
        agreement_id = self._parse_yield_agreement_created_event(receipt)

        # Get the token address for the agreement
        try:
            token_address = self.yield_base.functions.agreementTokens(agreement_id).call()
        except:
            # Fallback: if we can't get the token address, return zero address
            token_address = "0x0000000000000000000000000000000000000000"

        return agreement_id, token_address, tx_hash, gas_used

    @track_time("web3_mint_combined_property_token", lambda self, pah, uri: {"contract": "CombinedPropertyYieldToken"})
    def mint_combined_property_token(self, property_address_hash: bytes, metadata_uri: str) -> Tuple[int, str, int]:
        """
        Mint combined property token via CombinedPropertyYieldToken.mintPropertyToken().

        Args:
            property_address_hash: Keccak256 hash of property address (bytes32)
            metadata_uri: IPFS URI for property metadata

        Returns:
            Tuple of (token_id, tx_hash, gas_used)
        """
        # Send the transaction
        tx_hash, gas_used, receipt = self._send_transaction(
            self.combined_token.functions.mintPropertyToken,
            property_address_hash,
            metadata_uri
        )

        # Parse PropertyTokenMinted event from receipt to get the actual token ID
        token_id = self._parse_property_token_minted_event(receipt)
        return token_id, tx_hash, gas_used

    def mint_combined_yield_tokens(
        self,
        property_token_id: int,
        capital: int,
        term: int,
        roi: int,
        **kwargs
    ) -> Tuple[int, str, str, int]:
        """
        Mint combined yield tokens via CombinedPropertyYieldToken.mintYieldTokens().

        Args:
            property_token_id: Property token ID
            capital: Initial capital amount (wei)
            term: Agreement term in months
            roi: Annual ROI in basis points
            **kwargs: Additional parameters for ERC-1155 variant

        Returns:
            Tuple of (yield_token_id, contract_address, tx_hash, gas_used)
        """
        # Note: Adjust function call based on actual CombinedPropertyYieldToken interface
        tx_hash, gas_used, receipt = self._send_transaction(
            self.combined_token.functions.mintYieldTokens,
            property_token_id,
            capital,
            term,
            roi,
            # Add other required parameters based on contract interface
        )

        # Extract token ID and address from event
        logs = self.combined_token.events.YieldTokenMinted().process_receipt(receipt)

        if not logs:
            raise Exception("YieldTokenMinted event not found in transaction receipt")

        args = logs[0]['args']
        return args['yieldTokenId'], self.contract_addresses["CombinedPropertyYieldToken"], tx_hash, gas_used

    # ========================================
    # Governance Methods
    # ========================================

    async def create_governance_proposal(
        self,
        agreement_id: int,
        proposal_type: str,
        target_value: int,
        description: str
    ) -> Tuple[str, int]:
        """
        Create a governance proposal on-chain.
        
        Args:
            agreement_id: Agreement ID
            proposal_type: Type of proposal (ROI_ADJUSTMENT, RESERVE_ALLOCATION, etc.)
            target_value: Target value for the proposal
            description: Proposal description
            
        Returns:
            Tuple of (tx_hash, blockchain_proposal_id)
        """
        if self.testing_mode:
            return self._create_governance_proposal_testing(agreement_id, proposal_type, target_value, description)
        else:
            return self._create_governance_proposal_production(agreement_id, proposal_type, target_value, description)

    def _create_governance_proposal_testing(
        self,
        agreement_id: int,
        proposal_type: str,
        target_value: int,
        description: str
    ) -> Tuple[str, int]:
        """Testing mode implementation for creating governance proposal"""
        import hashlib
        from datetime import datetime
        
        # Generate mock transaction hash
        tx_hash = "0x" + hashlib.sha256(f"proposal_{agreement_id}_{datetime.now()}".encode()).hexdigest()
        
        # Generate mock proposal ID
        blockchain_proposal_id = hash(f"{agreement_id}{proposal_type}{description}") % 10000
        
        self.audit_trail.append({
            "action": "create_governance_proposal",
            "agreement_id": agreement_id,
            "proposal_type": proposal_type,
            "target_value": target_value,
            "tx_hash": tx_hash,
            "blockchain_proposal_id": blockchain_proposal_id,
            "testing_mode": True
        })
        
        return tx_hash, blockchain_proposal_id

    async def _create_governance_proposal_production(
        self,
        agreement_id: int,
        proposal_type: str,
        target_value: int,
        description: str
    ) -> Tuple[str, int]:
        """Production mode implementation for creating governance proposal"""
        # TODO: Implement when GovernanceController is deployed
        # For now, return mock data
        import hashlib
        from datetime import datetime
        
        tx_hash = "0x" + hashlib.sha256(f"proposal_{agreement_id}_{datetime.now()}".encode()).hexdigest()
        blockchain_proposal_id = hash(f"{agreement_id}{proposal_type}{description}") % 10000
        
        return tx_hash, blockchain_proposal_id

    async def cast_vote(
        self,
        proposal_id: int,
        support: int,
        voter_address: str,
        voting_power: Optional[int] = None
    ) -> Tuple[str, int]:
        """
        Cast a vote on a governance proposal.
        
        Args:
            proposal_id: Proposal ID
            support: Vote support (0=Against, 1=For, 2=Abstain)
            voter_address: Address of the voter
            voting_power: Optional pre-fetched voting power (if provided, skips database query)
            
        Returns:
            Tuple of (tx_hash, voting_power)
        """
        if self.testing_mode:
            return self._cast_vote_testing(proposal_id, support, voter_address, voting_power)
        else:
            return await self._cast_vote_production(proposal_id, support, voter_address, voting_power)

    def _cast_vote_testing(
        self,
        proposal_id: int,
        support: int,
        voter_address: str,
        voting_power: Optional[int] = None
    ) -> Tuple[str, int]:
        """Testing mode implementation for casting vote"""
        import hashlib
        from datetime import datetime
        
        # Generate mock transaction hash
        tx_hash = "0x" + hashlib.sha256(f"vote_{proposal_id}_{voter_address}_{datetime.now()}".encode()).hexdigest()
        
        # Use provided voting_power (fetched by GovernanceService from database)
        if voting_power is None:
            # Fallback: This should never happen now, but keeping for safety
            logger.warning(f"⚠️ No voting power provided for {voter_address[:10]}... - using fallback 10,000")
            voting_power = 10000
        
        self.audit_trail.append({
            "action": "cast_vote",
            "proposal_id": proposal_id,
            "support": support,
            "voter_address": voter_address,
            "voting_power": voting_power,
            "tx_hash": tx_hash,
            "testing_mode": True
        })
        
        return tx_hash, voting_power

    async def _cast_vote_production(
        self,
        proposal_id: int,
        support: int,
        voter_address: str,
        voting_power: Optional[int] = None
    ) -> Tuple[str, int]:
        """Production mode implementation for casting vote"""
        # TODO: Implement when GovernanceController is deployed
        # For now, use database as fallback (same as testing mode)
        import hashlib
        from datetime import datetime
        
        tx_hash = "0x" + hashlib.sha256(f"vote_{proposal_id}_{voter_address}_{datetime.now()}".encode()).hexdigest()
        
        # Use provided voting_power (fetched by GovernanceService from database)
        if voting_power is None:
            # Fallback: This should never happen now, but keeping for safety
            logger.warning(f"⚠️ No voting power provided for {voter_address[:10]}... - using fallback 10,000")
            voting_power = 10000
        
        return tx_hash, voting_power

    async def execute_proposal(self, proposal_id: int) -> str:
        """
        Execute a governance proposal.
        
        Args:
            proposal_id: Proposal ID to execute
            
        Returns:
            Transaction hash
        """
        if self.testing_mode:
            return self._execute_proposal_testing(proposal_id)
        else:
            return await self._execute_proposal_production(proposal_id)

    def _execute_proposal_testing(self, proposal_id: int) -> str:
        """Testing mode implementation for executing proposal"""
        import hashlib
        from datetime import datetime
        
        # Generate mock transaction hash
        tx_hash = "0x" + hashlib.sha256(f"execute_{proposal_id}_{datetime.now()}".encode()).hexdigest()
        
        self.audit_trail.append({
            "action": "execute_proposal",
            "proposal_id": proposal_id,
            "tx_hash": tx_hash,
            "testing_mode": True
        })
        
        return tx_hash

    async def _execute_proposal_production(self, proposal_id: int) -> str:
        """Production mode implementation for executing proposal"""
        # TODO: Implement when GovernanceController is deployed
        import hashlib
        from datetime import datetime
        
        tx_hash = "0x" + hashlib.sha256(f"execute_{proposal_id}_{datetime.now()}".encode()).hexdigest()
        
        return tx_hash

    async def get_proposal(self, proposal_id: int) -> Dict[str, Any]:
        """
        Get governance proposal details from blockchain.
        
        Args:
            proposal_id: Proposal ID
            
        Returns:
            Dictionary containing proposal details
        """
        if self.testing_mode:
            return self._get_proposal_testing(proposal_id)
        else:
            return await self._get_proposal_production(proposal_id)

    def _get_proposal_testing(self, proposal_id: int) -> Dict[str, Any]:
        """Testing mode implementation for getting proposal"""
        from datetime import datetime, timedelta
        from models.governance_proposal import GovernanceProposal
        
        # Try to fetch real proposal data from database
        try:
            # Query by database ID (proposal_id), not blockchain_proposal_id!
            proposal = self.db.query(GovernanceProposal).filter(
                GovernanceProposal.id == proposal_id
            ).first()
            
            if proposal:
                # Return real proposal data
                return {
                    "blockchain_proposal_id": proposal.blockchain_proposal_id,
                    "status": proposal.status if hasattr(proposal, 'status') else "ACTIVE",
                    "for_votes": int(proposal.for_votes) if proposal.for_votes else 0,
                    "against_votes": int(proposal.against_votes) if proposal.against_votes else 0,
                    "abstain_votes": int(proposal.abstain_votes) if proposal.abstain_votes else 0,
                    "quorum_required": 10000,
                    "voting_start": proposal.voting_start,
                    "voting_end": proposal.voting_end,
                    "agreement_id": proposal.agreement_id,
                    "proposal_type": proposal.proposal_type,
                    "proposer": proposal.proposer,
                    "description": proposal.description,
                    "target_value": int(proposal.target_value) if proposal.target_value else 0,
                    "executed": proposal.executed,
                    "defeated": proposal.defeated,
                    "quorum_reached": proposal.quorum_reached
                }
        except Exception as e:
            print(f"Warning: Could not fetch proposal {proposal_id} from database: {e}")
        
        # Fallback to mock data if database query fails
        return {
            "blockchain_proposal_id": proposal_id,
            "status": "ACTIVE",
            "for_votes": 0,  # Changed from 15000 to 0 for new proposals
            "against_votes": 0,  # Changed from 5000 to 0
            "abstain_votes": 0,  # Changed from 2000 to 0
            "quorum_required": 10000,
            "voting_start": datetime.now() + timedelta(days=1),  # Respect 1-day delay
            "voting_end": datetime.now() + timedelta(days=8)
        }

    async def _get_proposal_production(self, proposal_id: int) -> Dict[str, Any]:
        """Production mode implementation for getting proposal"""
        # TODO: Implement when GovernanceController is deployed
        return {
            "status": "ACTIVE",
            "for_votes": 0,
            "against_votes": 0,
            "abstain_votes": 0,
            "quorum_required": 10000
        }

    async def get_voting_power(
        self,
        voter_address: str,
        agreement_id: int,
        token_standard: str = "ERC721",
        db: Session = None
    ) -> int:
        """
        Get voting power for an address on a specific agreement.
        
        Args:
            voter_address: Address to check voting power for
            agreement_id: Agreement ID
            token_standard: Token standard (ERC721 or ERC1155)
            db: Database session (required for testing mode)
            
        Returns:
            Voting power (token balance)
        """
        if self.testing_mode:
            return self._get_voting_power_testing(voter_address, agreement_id, token_standard, db)
        else:
            return await self._get_voting_power_production(voter_address, agreement_id, token_standard)

    def _get_voting_power_testing(
        self,
        voter_address: str,
        agreement_id: int,
        token_standard: str,
        db: Session = None
    ) -> int:
        """Testing mode implementation for getting voting power"""
        from models.token_balance import TokenBalance
        
        if not db:
            logger.error(f"Database session not provided for voting power query in testing mode")
            return 10000
        
        try:
            # Query actual token balance for this voter in this agreement
            token_balance = db.query(TokenBalance).filter(
                TokenBalance.wallet_address == voter_address,
                TokenBalance.agreement_id == agreement_id
            ).first()
            
            if token_balance:
                voting_power = int(token_balance.balance)
                logger.info(f"✅ Retrieved voting power for {voter_address[:10]}... on agreement #{agreement_id}: {voting_power:,} tokens")
                return voting_power
            else:
                logger.warning(f"⚠️ No token balance found for {voter_address[:10]}... on agreement #{agreement_id}")
                return 0
        except Exception as e:
            logger.error(f"Error fetching voting power from database: {e}")
            # Fallback to default only if database query fails
            return 10000

    async def _get_voting_power_production(
        self,
        voter_address: str,
        agreement_id: int,
        token_standard: str
    ) -> int:
        """Production mode implementation for getting voting power"""
        # TODO: Implement when contracts are deployed
        # Should query YieldSharesToken balance for ERC721 or CombinedPropertyYieldToken for ERC1155
        return 10000

    async def get_eth_price(self) -> float:
        """
        Get current ETH price in USD.
        
        Returns:
            ETH price in USD
        """
        if self.testing_mode:
            return 2000.0  # Mock price
        else:
            # TODO: Implement price oracle integration
            return 2000.0  # Placeholder

    async def get_governance_params(self) -> Tuple[int, int, int, int]:
        """
        Get governance parameters from GovernanceController contract.
        
        Returns:
            Tuple of (votingDelay, votingPeriod, quorumPercentage, proposalThreshold)
        """
        if self.testing_mode:
            return self._get_governance_params_testing()
        else:
            return await self._get_governance_params_production()

    def _get_governance_params_testing(self) -> Tuple[int, int, int, int]:
        """Testing mode implementation for getting governance params"""
        # Return default governance parameters
        # votingDelay=1 day, votingPeriod=7 days, quorumPercentage=1000 (10%), proposalThreshold=100 (1%)
        return (86400, 604800, 1000, 100)

    async def _get_governance_params_production(self) -> Tuple[int, int, int, int]:
        """Production mode implementation for getting governance params"""
        try:
            # Load GovernanceController contract
            governance_abi = self._load_contract_abi("GovernanceController")
            governance_address = self.contract_addresses.get("GovernanceController")
            
            if not governance_address:
                logger.warning("GovernanceController address not found, using defaults")
                return (86400, 604800, 1000, 100)
            
            governance_contract = self.w3.eth.contract(address=governance_address, abi=governance_abi)
            
            # Call getGovernanceParams()
            result = governance_contract.functions.getGovernanceParams().call()
            
            # result is tuple: (votingDelay, votingPeriod, quorumPercentage, proposalThreshold)
            return (int(result[0]), int(result[1]), int(result[2]), int(result[3]))
        except Exception as e:
            logger.error(f"Error fetching governance params: {e}")
            # Return defaults on error
            return (86400, 604800, 1000, 100)

    async def get_total_supply(self, agreement_id: int, token_standard: str = "ERC721") -> int:
        """
        Get total token supply for a specific agreement.
        
        Args:
            agreement_id: Agreement ID
            token_standard: Token standard (ERC721 or ERC1155)
            
        Returns:
            Total supply of tokens for the agreement
        """
        if self.testing_mode:
            return self._get_total_supply_testing(agreement_id, token_standard)
        else:
            return await self._get_total_supply_production(agreement_id, token_standard)

    def _get_total_supply_testing(self, agreement_id: int, token_standard: str) -> int:
        """Testing mode implementation for getting total supply"""
        from models.yield_agreement import YieldAgreement
        
        try:
            # Query database for agreement's total token supply
            agreement = self.db.query(YieldAgreement).filter_by(id=agreement_id).first()
            if agreement and agreement.total_token_supply:
                total_supply = int(agreement.total_token_supply)
                logger.info(f"✅ Retrieved total supply for agreement #{agreement_id}: {total_supply:,} tokens")
                return total_supply
            else:
                logger.warning(f"⚠️ No agreement found with ID {agreement_id}, using default supply")
                return 1000000  # Default 1M tokens
        except Exception as e:
            logger.error(f"Error fetching total supply from database: {e}")
            return 1000000

    async def _get_total_supply_production(self, agreement_id: int, token_standard: str) -> int:
        """Production mode implementation for getting total supply"""
        try:
            if token_standard == "ERC1155":
                # For ERC-1155, get totalSupply(yieldTokenId) from CombinedPropertyYieldToken
                # First, get yieldTokenId mapping from GovernanceController
                governance_abi = self._load_contract_abi("GovernanceController")
                governance_address = self.contract_addresses.get("GovernanceController")
                
                if not governance_address:
                    logger.warning("GovernanceController address not found")
                    return 1000000
                
                governance_contract = self.w3.eth.contract(address=governance_address, abi=governance_abi)
                yield_token_id = governance_contract.functions.agreementToYieldTokenId(agreement_id).call()
                
                if yield_token_id == 0:
                    logger.warning(f"No yield token ID mapping for agreement {agreement_id}")
                    return 1000000
                
                # Now get totalSupply from CombinedPropertyYieldToken
                total_supply = self.combined_token.functions.totalSupply(yield_token_id).call()
                return int(total_supply)
            else:
                # For ERC-721+ERC-20, get totalSupply() from YieldSharesToken
                # First get token address from YieldBase
                token_address = self.yield_base.functions.getYieldSharesToken(agreement_id).call()
                
                if token_address == "0x0000000000000000000000000000000000000000":
                    logger.warning(f"No token found for agreement {agreement_id}")
                    return 1000000
                
                # Load YieldSharesToken and get totalSupply
                token_abi = self._load_contract_abi("YieldSharesToken")
                token_contract = self.w3.eth.contract(address=token_address, abi=token_abi)
                total_supply = token_contract.functions.totalSupply().call()
                return int(total_supply)
        except Exception as e:
            logger.error(f"Error fetching total supply: {e}")
            return 1000000
