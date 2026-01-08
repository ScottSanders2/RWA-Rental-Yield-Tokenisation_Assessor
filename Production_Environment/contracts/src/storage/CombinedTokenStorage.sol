// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title CombinedTokenStorage
/// @notice ERC-7201 namespaced storage library for CombinedPropertyYieldToken contract
/// @dev Provides collision-free storage for both property metadata and yield agreement data
/// @custom:namespace rwa.storage.CombinedToken
library CombinedTokenStorage {
    /// @notice ERC-7201 namespace identifier for combined token storage
    /// @dev Calculated as keccak256(abi.encode(uint256(keccak256("rwa.storage.CombinedToken")) - 1)) & ~bytes32(uint256(0xff))
    /// This ensures no collision with YieldStorage (rwa.storage.Yield), YieldSharesStorage (rwa.storage.YieldShares), or PropertyStorage (rwa.storage.Property)
    bytes32 private constant COMBINED_TOKEN_STORAGE_LOCATION =
        bytes32(uint256(keccak256(abi.encode(uint256(keccak256("rwa.storage.CombinedToken")) - 1))) & ~uint256(0xff));

    /// @notice Property metadata structure stored on-chain
    /// @dev Minimal data for verification and linking, detailed docs stored off-chain via IPFS
    struct PropertyMetadata {
        bytes32 propertyAddressHash;    // keccak256 hash of property address for verification
        uint256 verificationTimestamp;  // timestamp when property was verified
        string metadataURI;            // IPFS URI containing detailed property documents
        bool isVerified;               // whether property has been verified by authorized verifier
        address verifierAddress;       // address of the verifier who approved the property
    }

    /// @notice Yield agreement data structure
    /// @dev Enhanced to mirror YieldStorage.YieldData with advanced autonomous yield management features
    struct YieldAgreementData {
        uint256 upfrontCapital;           // amount of capital requested upfront by the property owner
        uint16 repaymentTermMonths;       // repayment term in months
        uint16 annualROIBasisPoints;      // annual return on investment in basis points (e.g., 500 = 5%)
        uint256 totalRepaid;              // total amount repaid so far
        uint256 lastRepaymentTimestamp;   // timestamp of last repayment
        bool isActive;                   // whether the agreement is still active
        uint8 missedPaymentCount;         // consecutive missed monthly payments for default determination
        uint16 gracePeriodDays;           // configurable grace period before default penalties apply
        uint256 accumulatedArrears;       // unpaid amounts from partial/missed payments
        uint256 overpaymentCredit;        // excess payments that can offset future obligations
        uint256 prepaymentAmount;         // lump-sum early repayments for rebate calculations
        uint16 defaultPenaltyRate;        // penalty rate in basis points for late payments
        uint256 lastMissedPaymentTimestamp; // timestamp of last missed payment for grace period tracking
        uint256 gracePeriodExpiryTimestamp; // when the current grace period expires (0 if not active)
        bool isInDefault;                 // default status flag
        bool allowPartialRepayments;      // configuration flag for partial payment acceptance
        bool allowEarlyRepayment;         // configuration flag for early repayment incentives
        uint8 defaultThreshold;           // number of missed payments before default (e.g., 3)
    }

    /// @notice Pooled contribution data structure for multi-investor capital
    /// @dev Tracks capital contributed by multiple investors during agreement creation
    struct PooledContributionData {
        mapping(address => uint256) contributorBalances; // capital contributed per investor
        address[] contributorAddresses;    // array of contributors
        uint256 totalPooledCapital;       // sum of contributions
    }

    /// @notice Storage layout for combined token data
    /// @dev ERC-7201 compliant storage structure with dual mappings and holder tracking
    struct CombinedTokenStorageLayout {
        uint256 propertyTokenIdCounter;                    // counter for property token IDs (1-999,999)
        uint256 yieldTokenIdCounter;                       // counter for yield token IDs (1,000,000+)
        mapping(uint256 => uint256) propertyToYieldMapping; // propertyTokenId => yieldTokenId
        mapping(uint256 => uint256) yieldToPropertyMapping; // yieldTokenId => propertyTokenId
        mapping(uint256 => PropertyMetadata) propertyMetadata; // tokenId => property metadata (for property tokens)
        mapping(uint256 => YieldAgreementData) yieldAgreementData; // tokenId => yield data (for yield tokens)
        mapping(uint256 => PooledContributionData) yieldPooledContributions; // yieldTokenId => pooled contribution data
        mapping(uint256 => address[]) yieldHolders;        // tokenId => list of addresses holding the token
        mapping(uint256 => mapping(address => bool)) isHolder; // tokenId => address => is holder
        mapping(uint256 => uint256) totalSupply;          // tokenId => total supply of tokens
        mapping(address => uint256) unclaimedRemainder;   // address => unclaimed ETH from failed transfers
    }

    /// @notice Get the combined token storage location
    /// @dev Returns pointer to ERC-7201 namespaced storage
    /// @return layout Pointer to CombinedTokenStorageLayout struct in namespaced storage
    function getCombinedTokenStorage()
        internal
        pure
        returns (CombinedTokenStorageLayout storage layout)
    {
        bytes32 position = COMBINED_TOKEN_STORAGE_LOCATION;
        assembly {
            layout.slot := position
        }
    }

    /// @notice Get the computed storage slot for testing purposes
    /// @dev Returns the ERC-7201 computed slot value for validation in tests
    /// @return The computed storage slot
    function getStorageSlot() internal pure returns (bytes32) {
        return COMBINED_TOKEN_STORAGE_LOCATION;
    }

    /// @notice Add a holder to the yield token holder tracking
    /// @dev Internal function to add an address to the holder list if not already present
    /// @param layout The storage layout reference
    /// @param tokenId The token ID
    /// @param holder The address to add as a holder
    function addHolder(CombinedTokenStorageLayout storage layout, uint256 tokenId, address holder) internal {
        if (!layout.isHolder[tokenId][holder]) {
            layout.isHolder[tokenId][holder] = true;
            layout.yieldHolders[tokenId].push(holder);
        }
    }

    /// @notice Remove a holder from the yield token holder tracking
    /// @dev Internal function to remove an address from the holder list
    /// @param layout The storage layout reference
    /// @param tokenId The token ID
    /// @param holder The address to remove as a holder
    function removeHolder(CombinedTokenStorageLayout storage layout, uint256 tokenId, address holder) internal {
        if (layout.isHolder[tokenId][holder]) {
            layout.isHolder[tokenId][holder] = false;
            // Remove from array (swap with last element and pop for gas efficiency)
            address[] storage holders = layout.yieldHolders[tokenId];
            for (uint256 i = 0; i < holders.length; i++) {
                if (holders[i] == holder) {
                    holders[i] = holders[holders.length - 1];
                    holders.pop();
                    break;
                }
            }
        }
    }

    /// @notice Get the list of holders for a token
    /// @dev Returns the array of addresses holding the specified token
    /// @param layout The storage layout reference
    /// @param tokenId The token ID
    /// @return Array of holder addresses
    function getHolders(CombinedTokenStorageLayout storage layout, uint256 tokenId)
        internal
        view
        returns (address[] memory)
    {
        return layout.yieldHolders[tokenId];
    }
}
