"""
KYC Service Layer

Business logic for KYC verification, document management, and blockchain integration.
Coordinates between database (SQLAlchemy), blockchain (Web3Service), and external
services (IPFS for document storage).
"""

from sqlalchemy.orm import Session
from models.kyc_verification import KYCVerification, KYCStatus, KYCTier
from models.kyc_document import KYCDocument, DocumentType
from services.web3_service import Web3Service
from datetime import datetime, timedelta
from typing import Optional, List, Dict
import logging

logger = logging.getLogger(__name__)


class KYCService:
    """KYC verification service for managing compliance workflows"""
    
    def __init__(self, db: Session, web3_service: Web3Service):
        """
        Initialize KYC service
        
        Args:
            db: SQLAlchemy database session
            web3_service: Web3 service for blockchain interactions
        """
        self.db = db
        self.web3_service = web3_service
    
    def submit_kyc(
        self,
        wallet_address: str,
        full_name: str,
        email: str,
        country: str,
        tier: KYCTier,
        signature: str
    ) -> KYCVerification:
        """
        Submit new KYC application with signature verification
        
        Args:
            wallet_address: Ethereum address to verify
            full_name: Full legal name
            email: Email address
            country: Country of residence
            tier: Verification tier (basic/accredited/institutional)
            signature: Signed message proving wallet ownership
        
        Returns:
            KYCVerification: Created verification record
        
        Raises:
            ValueError: If signature is invalid or address already verified
        """
        # Verify signature proves wallet ownership
        message = f"KYC submission for {wallet_address}"
        if not self.web3_service.verify_signature(wallet_address, message, signature):
            raise ValueError("Invalid signature - wallet ownership not proven")
        
        # Check for existing submission
        existing = self.db.query(KYCVerification).filter(
            KYCVerification.wallet_address == wallet_address.lower()
        ).first()
        
        if existing and existing.status == KYCStatus.APPROVED:
            raise ValueError("Address already KYC verified")
        
        # If existing record is PENDING or REJECTED, update it instead of creating a new one
        if existing:
            logger.info(f"Updating existing KYC submission {existing.id} for {wallet_address} (previous status: {existing.status})")
            existing.full_name = full_name
            existing.email = email
            existing.country = country
            existing.tier = tier
            existing.status = KYCStatus.PENDING  # Reset to PENDING for re-review
            existing.review_date = None  # Clear previous review
            existing.reviewer_address = None
            existing.rejection_reason = None
            
            self.db.commit()
            self.db.refresh(existing)
            
            logger.info(f"KYC submission updated: {existing.id} for {wallet_address}")
            return existing
        
        # Create new verification record if no existing record
        kyc = KYCVerification(
            wallet_address=wallet_address.lower(),
            full_name=full_name,
            email=email,
            country=country,
            tier=tier,
            status=KYCStatus.PENDING
        )
        
        self.db.add(kyc)
        self.db.commit()
        self.db.refresh(kyc)
        
        logger.info(f"KYC submission created: {kyc.id} for {wallet_address}")
        return kyc
    
    def upload_document(
        self,
        kyc_id: int,
        document_type: DocumentType,
        file_name: str,
        file_hash: str,
        file_size: int,
        mime_type: str,
        ipfs_uri: Optional[str] = None
    ) -> KYCDocument:
        """
        Upload KYC document metadata (actual file stored in IPFS)
        
        Args:
            kyc_id: KYC verification ID
            document_type: Type of document
            file_name: Original file name
            file_hash: SHA-256 hash for integrity
            file_size: File size in bytes
            mime_type: MIME type
            ipfs_uri: IPFS URI if uploaded
        
        Returns:
            KYCDocument: Created document record
        """
        # Validate KYC exists
        kyc = self.db.query(KYCVerification).filter(KYCVerification.id == kyc_id).first()
        if not kyc:
            raise ValueError(f"KYC verification {kyc_id} not found")
        
        doc = KYCDocument(
            kyc_verification_id=kyc_id,
            document_type=document_type,
            file_name=file_name,
            file_hash=file_hash,
            file_size=file_size,
            mime_type=mime_type,
            ipfs_uri=ipfs_uri
        )
        
        self.db.add(doc)
        self.db.commit()
        self.db.refresh(doc)
        
        logger.info(f"Document uploaded for KYC {kyc_id}: {doc.id} ({document_type.value})")
        return doc
    
    def review_kyc(
        self,
        kyc_id: int,
        status: KYCStatus,
        reviewer_address: str,
        rejection_reason: Optional[str] = None,
        add_to_whitelist: bool = True
    ) -> Dict:
        """
        Admin reviews KYC and optionally adds to on-chain whitelist
        
        Args:
            kyc_id: KYC verification ID
            status: New status (approved/rejected)
            reviewer_address: Admin wallet address
            rejection_reason: Reason for rejection (if applicable)
            add_to_whitelist: Add to blockchain whitelist if approved
        
        Returns:
            Dict: Review result with KYC data and whitelist status
        
        Raises:
            ValueError: If KYC not found or invalid status transition
        """
        kyc = self.db.query(KYCVerification).filter(KYCVerification.id == kyc_id).first()
        if not kyc:
            raise ValueError(f"KYC verification {kyc_id} not found")
        
        # Update KYC status
        kyc.status = status
        kyc.review_date = datetime.utcnow()
        kyc.reviewer_address = reviewer_address.lower()
        
        if status == KYCStatus.APPROVED:
            # Set expiry date (1 year from approval)
            kyc.expiry_date = datetime.utcnow() + timedelta(days=365)
            
            # Add to on-chain whitelist if requested
            if add_to_whitelist:
                try:
                    tx_hash = self.web3_service.add_to_kyc_whitelist(kyc.wallet_address)
                    kyc.whitelisted_on_chain = True
                    kyc.whitelist_tx_hash = tx_hash
                    logger.info(f"Address {kyc.wallet_address} added to whitelist: {tx_hash}")
                except Exception as e:
                    logger.error(f"Failed to add {kyc.wallet_address} to whitelist: {e}")
                    # Continue with approval even if whitelist addition fails
                    # Admin can manually retry
                    
        elif status == KYCStatus.REJECTED:
            if not rejection_reason:
                raise ValueError("Rejection reason required for rejected applications")
            kyc.rejection_reason = rejection_reason
        
        self.db.commit()
        self.db.refresh(kyc)
        
        logger.info(f"KYC {kyc_id} reviewed: {status.value} by {reviewer_address}")
        
        return {
            'kyc_verification': kyc.to_dict(),
            'whitelisted': kyc.whitelisted_on_chain,
            'tx_hash': kyc.whitelist_tx_hash
        }
    
    def get_kyc_status(self, wallet_address: str) -> Optional[KYCVerification]:
        """
        Get KYC status for a wallet address
        
        Args:
            wallet_address: Ethereum address to query
        
        Returns:
            KYCVerification or None if not found
        """
        return self.db.query(KYCVerification).filter(
            KYCVerification.wallet_address == wallet_address.lower()
        ).first()
    
    def get_pending_kyc(self, limit: int = 100) -> List[KYCVerification]:
        """
        Get pending KYC applications for admin review
        
        Args:
            limit: Maximum number of records to return
        
        Returns:
            List of pending KYC verifications
        """
        return self.db.query(KYCVerification).filter(
            KYCVerification.status == KYCStatus.PENDING
        ).order_by(KYCVerification.submission_date.asc()).limit(limit).all()
    
    def get_approval_metrics(self) -> Dict:
        """
        Calculate KYC approval rate metrics for dissertation analysis
        
        Returns:
            Dict: Metrics including approval rate, review time, etc.
        """
        total = self.db.query(KYCVerification).count()
        approved = self.db.query(KYCVerification).filter(
            KYCVerification.status == KYCStatus.APPROVED
        ).count()
        rejected = self.db.query(KYCVerification).filter(
            KYCVerification.status == KYCStatus.REJECTED
        ).count()
        pending = self.db.query(KYCVerification).filter(
            KYCVerification.status == KYCStatus.PENDING
        ).count()
        
        # Calculate average review time
        reviewed = self.db.query(KYCVerification).filter(
            KYCVerification.review_date.isnot(None)
        ).all()
        
        avg_review_time = 0.0
        if reviewed:
            total_hours = sum([
                (kyc.review_date - kyc.submission_date).total_seconds() / 3600
                for kyc in reviewed
                if kyc.review_date and kyc.submission_date
            ])
            avg_review_time = total_hours / len(reviewed) if reviewed else 0
        
        approval_rate = (approved / total * 100) if total > 0 else 0
        rejection_rate = (rejected / total * 100) if total > 0 else 0
        
        return {
            'total_submissions': total,
            'approved': approved,
            'rejected': rejected,
            'pending': pending,
            'approval_rate': round(approval_rate, 2),
            'rejection_rate': round(rejection_rate, 2),
            'avg_review_time_hours': round(avg_review_time, 2)
        }
    
    def batch_review_kyc(
        self,
        kyc_ids: List[int],
        status: KYCStatus,
        reviewer_address: str,
        add_to_whitelist: bool = True
    ) -> Dict:
        """
        Batch review multiple KYC applications
        
        Args:
            kyc_ids: List of KYC verification IDs
            status: Status to apply to all
            reviewer_address: Admin wallet address
            add_to_whitelist: Add approved addresses to whitelist
        
        Returns:
            Dict: Summary of batch review results
        """
        results = {
            'successful': [],
            'failed': []
        }
        
        for kyc_id in kyc_ids:
            try:
                result = self.review_kyc(
                    kyc_id,
                    status,
                    reviewer_address,
                    add_to_whitelist=add_to_whitelist
                )
                results['successful'].append(kyc_id)
            except Exception as e:
                logger.error(f"Failed to review KYC {kyc_id}: {e}")
                results['failed'].append({'kyc_id': kyc_id, 'error': str(e)})
        
        return results

