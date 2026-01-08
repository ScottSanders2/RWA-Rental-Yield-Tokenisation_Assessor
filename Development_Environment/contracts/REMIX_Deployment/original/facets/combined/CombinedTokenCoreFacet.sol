// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC1155Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

import "../../storage/CombinedTokenStorage.sol";
import "../../storage/TransferRestrictionsStorage.sol";
import "../../libraries/CombinedTokenDistribution.sol";
import "../../libraries/TransferRestrictions.sol";
import "../../KYCRegistry.sol";

/// @title CombinedTokenCoreFacet
/// @notice Core facet for CombinedPropertyYieldToken Diamond, handling ERC-1155 base functionality
/// @dev Implements initialization, URI management, and ERC-1155 core functions
///      Uses ERC-7201 namespaced storage via CombinedTokenStorage
contract CombinedTokenCoreFacet is ERC1155Upgradeable, OwnableUpgradeable, AccessControlUpgradeable, ReentrancyGuardUpgradeable {
    using CombinedTokenStorage for CombinedTokenStorage.CombinedTokenStorageLayout;
    
    // ============ Role Definitions ============
    
    /// @notice Role identifier for platform minters (backend operators)
    bytes32 public constant PLATFORM_MINTER_ROLE = keccak256("PLATFORM_MINTER_ROLE");

    // ============ Events ============
    
    /// @notice Check if contract supports an interface
    /// @dev Override required due to multiple inheritance (ERC1155 + AccessControl)
    /// @param interfaceId The interface identifier
    /// @return bool True if interface is supported
    function supportsInterface(bytes4 interfaceId) 
        public 
        view 
        virtual 
        override(ERC1155Upgradeable, AccessControlUpgradeable) 
        returns (bool) 
    {
        return super.supportsInterface(interfaceId);
    }
    
    event PropertyTokenMinted(
        uint256 indexed tokenId,
        bytes32 propertyAddressHash,
        string metadataURI
    );

    // ============ Custom Errors ============
    
    error AlreadyInitialized();
    error InvalidInitialOwner();
    error InvalidPropertyToken(uint256 tokenId);
    error YieldTokenTransferRestricted(uint256 tokenId, address from, address to);
    error KYCRegistryNotSet();
    error AddressNotKYCVerified(address account);
    error AddressBlacklisted(address account);

    // ============ Initialization ============

    /// @notice Initialize the CombinedToken Diamond
    /// @dev Called once during Diamond deployment
    /// @param initialOwner The address that will own the Diamond
    /// @param yieldBaseAddress Address of YieldBase Diamond (for integration)
    /// @param baseURI Base URI for token metadata
    function initializeCombinedToken(
        address initialOwner,
        address yieldBaseAddress,
        string memory baseURI
    ) external initializer {
        CombinedTokenStorage.CombinedTokenStorageLayout storage layout = 
            CombinedTokenStorage.getCombinedTokenStorage();
        
        // Prevent re-initialization (check if property counter has been initialized)
        if (layout.propertyTokenIdCounter > 0) revert AlreadyInitialized();
        if (initialOwner == address(0)) revert InvalidInitialOwner();
        
        // Initialize counters
        layout.propertyTokenIdCounter = 0;
        layout.yieldTokenIdCounter = 1000000; // Yield tokens start at 1,000,000
        
        // Initialize base contracts (would normally use __init but in Diamond we handle differently)
        // Note: In a full Diamond implementation, initialization might be handled by the Diamond itself
        // For now, we'll just set the base URI and owner in our storage
        
        __ERC1155_init(baseURI);
        __Ownable_init(initialOwner);
        __AccessControl_init();
        __ReentrancyGuard_init();
        
        // Grant PLATFORM_MINTER_ROLE to the initial owner (backend deployer)
        // This allows the platform to mint yield tokens on behalf of property owners
        // following off-chain verification and compliance checks (RWA standard practice)
        _grantRole(PLATFORM_MINTER_ROLE, initialOwner);
        _grantRole(DEFAULT_ADMIN_ROLE, initialOwner); // Admin can manage roles
    }

    // ============ Admin Functions ============

    /// @notice Set token ID counters after Diamond redeployment
    /// @dev Emergency function to prevent token ID collisions with existing database records
    ///      Should be called immediately after Diamond deployment if migrating from previous deployment
    /// @param nextPropertyTokenId Next property token ID to use (highest existing ID + 1)
    /// @param nextYieldTokenId Next yield token ID to use (highest existing ID + 1)
    function setTokenCounters(uint256 nextPropertyTokenId, uint256 nextYieldTokenId) 
        external 
        onlyOwner 
    {
        CombinedTokenStorage.CombinedTokenStorageLayout storage layout = 
            CombinedTokenStorage.getCombinedTokenStorage();
        
        require(nextYieldTokenId >= 1000000, "Yield tokens must start at 1,000,000");
        
        layout.propertyTokenIdCounter = nextPropertyTokenId;
        layout.yieldTokenIdCounter = nextYieldTokenId;
        
        emit CountersUpdated(nextPropertyTokenId, nextYieldTokenId);
    }
    
    /// @notice Get current counter values
    /// @return propertyCounter Current property token counter
    /// @return yieldCounter Current yield token counter
    function getTokenCounters() external view returns (uint256 propertyCounter, uint256 yieldCounter) {
        CombinedTokenStorage.CombinedTokenStorageLayout storage layout = 
            CombinedTokenStorage.getCombinedTokenStorage();
        return (layout.propertyTokenIdCounter, layout.yieldTokenIdCounter);
    }

    // ============ Events ============

    event CountersUpdated(uint256 propertyTokenIdCounter, uint256 yieldTokenIdCounter);
    event KYCRegistrySet(address indexed kycRegistry);

    // ============ Admin Functions ============

    /// @notice Set the KYCRegistry contract reference for compliance checks
    /// @dev Only owner can set for security. Required for KYC verification in transfers
    /// @param kycRegistryAddress Address of the KYCRegistry contract
    function setKYCRegistry(address kycRegistryAddress) external onlyOwner {
        require(kycRegistryAddress != address(0), "Invalid KYCRegistry address");
        
        CombinedTokenStorage.CombinedTokenStorageLayout storage layout = 
            CombinedTokenStorage.getCombinedTokenStorage();
        layout.kycRegistry = kycRegistryAddress;
        
        emit KYCRegistrySet(kycRegistryAddress);
    }

    // ============ ERC-1155 URI Override ============

    /// @notice Returns the URI for a token
    /// @dev Overrides ERC1155 to provide custom URIs for property vs yield tokens
    /// @param tokenId The token ID to query
    /// @return The URI string for the token
    function uri(uint256 tokenId) public view override returns (string memory) {
        CombinedTokenStorage.CombinedTokenStorageLayout storage layout = 
            CombinedTokenStorage.getCombinedTokenStorage();

        if (CombinedTokenDistribution.isPropertyToken(tokenId)) {
            // Property token - return stored metadata URI
            return layout.propertyMetadata[tokenId].metadataURI;
        } else {
            // Yield token - return generated URI
            return string(abi.encodePacked(super.uri(tokenId), Strings.toString(tokenId)));
        }
    }

    // ============ ERC-1155 Transfer Hook Override ============

    /// @notice Internal function called before any token transfer
    /// @dev Overrides ERC1155 to implement yield token transfer restrictions
    /// @param from The address tokens are being transferred from
    /// @param to The address tokens are being transferred to
    /// @param ids Array of token IDs being transferred
    /// @param values Array of amounts being transferred
    function _update(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory values
    ) internal override {
        CombinedTokenStorage.CombinedTokenStorageLayout storage layout = 
            CombinedTokenStorage.getCombinedTokenStorage();
        TransferRestrictionsStorage.YieldTokenRestrictionsStorage storage restrictions = 
            TransferRestrictionsStorage.getYieldTokenRestrictionsStorage();

        // ============ KYC CHECKS (Highest Priority) ============
        // Check KYC verification for actual transfers (not mint/burn)
        if (from != address(0) && to != address(0)) {
            // Validate KYC for both sender and recipient
            if (layout.kycRegistry != address(0)) {
                KYCRegistry registry = KYCRegistry(layout.kycRegistry);
                
                // Check sender KYC status
                if (!registry.isWhitelisted(from)) {
                    revert AddressNotKYCVerified(from);
                }
                if (registry.isBlacklisted(from)) {
                    revert AddressBlacklisted(from);
                }
                
                // Check recipient KYC status
                if (!registry.isWhitelisted(to)) {
                    revert AddressNotKYCVerified(to);
                }
                if (registry.isBlacklisted(to)) {
                    revert AddressBlacklisted(to);
                }
            }
        }
        
        // ============ TRANSFER RESTRICTIONS ============
        // Validate yield token transfer restrictions AFTER KYC checks
        // Only check restrictions for actual transfers (not mint/burn) of yield tokens
        if (from != address(0) && to != address(0)) {
            for (uint256 i = 0; i < ids.length; i++) {
                uint256 tokenId = ids[i];
                
                // Only check restrictions for yield tokens
                if (!CombinedTokenDistribution.isPropertyToken(tokenId)) {
                    // Check if restrictions are enabled for this yield token
                    TransferRestrictionsStorage.TransferRestrictionData storage tokenRestrictions = 
                        restrictions.restrictionsById[tokenId];
                    
                    // Validate transfer using TransferRestrictions library
                    (bool allowed, ) = TransferRestrictions.validateAllRestrictions(
                        from,
                        to,
                        values[i],
                        balanceOf(to, tokenId),
                        layout.totalSupply[tokenId],
                        tokenRestrictions
                    );
                    
                    if (!allowed) {
                        revert YieldTokenTransferRestricted(tokenId, from, to);
                    }
                }
            }
        }

        // Call parent implementation to perform the transfer
        super._update(from, to, ids, values);

        // Update holder tracking AFTER transfer
        for (uint256 i = 0; i < ids.length; i++) {
            uint256 tokenId = ids[i];
            
            // Only track holders for yield tokens
            if (!CombinedTokenDistribution.isPropertyToken(tokenId)) {
                // Update FROM holder
                if (from != address(0) && balanceOf(from, tokenId) == 0) {
                    layout.removeHolder(tokenId, from);
                }
                
                // Update TO holder
                if (to != address(0) && values[i] > 0) {
                    layout.addHolder(tokenId, to);
                }
            }
        }

        // Update total supply tracking
        for (uint256 i = 0; i < ids.length; i++) {
            if (from == address(0)) {
                // Minting
                layout.totalSupply[ids[i]] += values[i];
            } else if (to == address(0)) {
                // Burning
                layout.totalSupply[ids[i]] -= values[i];
            }
        }
    }

    // ============ ERC-1155 View Functions ============

    /// @notice Get the total supply of a token
    /// @param tokenId The token ID to query
    /// @return The total supply of the token
    function totalSupply(uint256 tokenId) external view returns (uint256) {
        CombinedTokenStorage.CombinedTokenStorageLayout storage layout = 
            CombinedTokenStorage.getCombinedTokenStorage();
        return layout.totalSupply[tokenId];
    }

    /// @notice Get the list of holders for a token
    /// @param tokenId The token ID to query
    /// @return Array of holder addresses
    function getTokenHolders(uint256 tokenId) external view returns (address[] memory) {
        CombinedTokenStorage.CombinedTokenStorageLayout storage layout = 
            CombinedTokenStorage.getCombinedTokenStorage();
        return layout.getHolders(tokenId);
    }

    // ============ Burn Function ============

    /// @notice Burn tokens
    /// @dev Allows token holders to burn their own tokens
    /// @param tokenId The token ID to burn
    /// @param amount The amount to burn
    function burn(uint256 tokenId, uint256 amount) external {
        _burn(msg.sender, tokenId, amount);
    }

}

