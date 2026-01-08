// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title PropertyStorage
/// @notice ERC-7201 namespaced storage library for PropertyNFT contract
/// @dev Provides collision-free storage for property metadata using ERC-7201 namespace
/// @custom:namespace rwa.storage.Property
library PropertyStorage {
    /// @notice ERC-7201 namespace identifier for property storage
    /// @dev Calculated as keccak256(abi.encode(uint256(keccak256("rwa.storage.Property")) - 1)) & ~bytes32(uint256(0xff))
    /// This ensures no collision with YieldStorage (rwa.storage.Yield) and YieldSharesStorage (rwa.storage.YieldShares)
    bytes32 private constant PROPERTY_STORAGE_LOCATION =
        bytes32(uint256(keccak256(abi.encode(uint256(keccak256("rwa.storage.Property")) - 1))) & ~uint256(0xff));

    /// @notice Property metadata structure stored on-chain
    /// @dev Minimal data for verification and linking, detailed docs stored off-chain via IPFS
    struct PropertyData {
        bytes32 propertyAddressHash;    // keccak256 hash of property address for verification
        uint256 verificationTimestamp;  // timestamp when property was verified
        string metadataURI;            // IPFS URI containing detailed property documents
        uint256 yieldAgreementId;      // ID of linked yield agreement (0 if no agreement)
        bool isVerified;               // whether property has been verified by authorized verifier
        address verifierAddress;       // address of the verifier who approved the property
    }

    /// @notice Storage layout for property data
    /// @dev ERC-7201 compliant storage structure
    struct PropertyStorageLayout {
        uint256 nextTokenId;                    // counter for token IDs
        mapping(uint256 => PropertyData) properties;  // tokenId => property data
    }

    /// @notice Get the property storage location
    /// @dev Returns pointer to ERC-7201 namespaced storage
    /// @return layout Pointer to PropertyStorageLayout struct in namespaced storage
    function getPropertyStorage()
        internal
        pure
        returns (PropertyStorageLayout storage layout)
    {
        bytes32 position = PROPERTY_STORAGE_LOCATION;
        assembly {
            layout.slot := position
        }
    }

    /// @notice Get the computed storage slot for testing purposes
    /// @dev Returns the ERC-7201 computed slot value for validation in tests
    /// @return The computed storage slot
    function getStorageSlot() internal pure returns (bytes32) {
        return PROPERTY_STORAGE_LOCATION;
    }
}
