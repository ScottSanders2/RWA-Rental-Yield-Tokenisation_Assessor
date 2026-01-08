// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./storage/KYCStorage.sol";

/**
 * @title KYCRegistry
 * @notice Central registry for KYC (Know Your Customer) verification and compliance management
 * @dev Implements UUPS upgradeable proxy pattern with ERC-7201 namespaced storage
 * 
 * PURPOSE:
 * This contract serves as the authoritative source for KYC verification status, enabling
 * regulatory compliance for security token offerings while maintaining decentralized governance.
 * It addresses the need to balance investor protection with financial inclusion, ensuring
 * only verified participants can engage in real estate yield tokenization.
 * 
 * REGULATORY ALIGNMENT:
 * - SEC Regulation D: Supports accredited investor verification for private placements
 * - AML/KYC Requirements: Implements whitelist/blacklist for compliance with anti-money laundering regulations
 * - Democratic Control: Integrates with GovernanceController for token-weighted whitelist proposals
 * 
 * AUTONOMOUS ENFORCEMENT MODEL:
 * Once addresses are whitelisted, smart contract modifiers autonomously enforce access control
 * without manual intervention, ensuring consistent compliance across all platform operations.
 */
contract KYCRegistry is Initializable, UUPSUpgradeable, OwnableUpgradeable {
    using KYCStorage for KYCStorage.KYCData;

    // Events
    event AddressWhitelisted(address indexed account, string tier, uint256 timestamp);
    event AddressRemovedFromWhitelist(address indexed account, uint256 timestamp);
    event AddressBlacklisted(address indexed account, uint256 timestamp);
    event AddressRemovedFromBlacklist(address indexed account, uint256 timestamp);
    event GovernanceControllerSet(address indexed governanceController);
    event WhitelistEnabledChanged(bool enabled);
    event BlacklistEnabledChanged(bool enabled);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initialize the KYC Registry contract
     * @param initialOwner Address that will own the contract
     */
    function initialize(address initialOwner) public initializer {
        __Ownable_init(initialOwner);
        __UUPSUpgradeable_init();
        
        KYCStorage.KYCData storage $ = KYCStorage.getKYCStorage();
        $.whitelistEnabled = true;
        $.blacklistEnabled = true;
    }

    /**
     * @notice Add an address to the KYC whitelist
     * @dev Only owner or governance controller can call
     * @param account Address to whitelist
     */
    function addToWhitelist(address account) external onlyOwnerOrGovernance {
        require(account != address(0), "KYCRegistry: Cannot whitelist zero address");
        
        KYCStorage.KYCData storage $ = KYCStorage.getKYCStorage();
        require(!$.whitelistedAddresses[account], "KYCRegistry: Address already whitelisted");
        
        $.whitelistedAddresses[account] = true;
        $.verificationTimestamp[account] = block.timestamp;
        
        emit AddressWhitelisted(account, $.kycTier[account], block.timestamp);
    }

    /**
     * @notice Remove an address from the KYC whitelist
     * @dev Only owner or governance controller can call
     * @param account Address to remove from whitelist
     */
    function removeFromWhitelist(address account) external onlyOwnerOrGovernance {
        require(account != address(0), "KYCRegistry: Cannot remove zero address");
        
        KYCStorage.KYCData storage $ = KYCStorage.getKYCStorage();
        require($.whitelistedAddresses[account], "KYCRegistry: Address not whitelisted");
        
        $.whitelistedAddresses[account] = false;
        
        emit AddressRemovedFromWhitelist(account, block.timestamp);
    }

    /**
     * @notice Add an address to the blacklist
     * @dev Only owner or governance controller can call. Blacklist overrides whitelist.
     * @param account Address to blacklist
     */
    function addToBlacklist(address account) external onlyOwnerOrGovernance {
        require(account != address(0), "KYCRegistry: Cannot blacklist zero address");
        
        KYCStorage.KYCData storage $ = KYCStorage.getKYCStorage();
        require(!$.blacklistedAddresses[account], "KYCRegistry: Address already blacklisted");
        
        $.blacklistedAddresses[account] = true;
        
        emit AddressBlacklisted(account, block.timestamp);
    }

    /**
     * @notice Remove an address from the blacklist
     * @dev Only owner or governance controller can call
     * @param account Address to remove from blacklist
     */
    function removeFromBlacklist(address account) external onlyOwnerOrGovernance {
        require(account != address(0), "KYCRegistry: Cannot remove zero address");
        
        KYCStorage.KYCData storage $ = KYCStorage.getKYCStorage();
        require($.blacklistedAddresses[account], "KYCRegistry: Address not blacklisted");
        
        $.blacklistedAddresses[account] = false;
        
        emit AddressRemovedFromBlacklist(account, block.timestamp);
    }

    /**
     * @notice Batch add addresses to whitelist (gas efficient)
     * @dev Only owner or governance controller can call
     * @param accounts Array of addresses to whitelist
     */
    function batchAddToWhitelist(address[] calldata accounts) external onlyOwnerOrGovernance {
        require(accounts.length <= 100, "KYCRegistry: Batch size exceeds maximum (100 addresses)");
        
        KYCStorage.KYCData storage $ = KYCStorage.getKYCStorage();
        
        for (uint256 i = 0; i < accounts.length; i++) {
            address account = accounts[i];
            require(account != address(0), "KYCRegistry: Cannot whitelist zero address");
            
            if (!$.whitelistedAddresses[account]) {
                $.whitelistedAddresses[account] = true;
                $.verificationTimestamp[account] = block.timestamp;
                emit AddressWhitelisted(account, $.kycTier[account], block.timestamp);
            }
        }
    }

    /**
     * @notice Batch remove addresses from whitelist
     * @dev Only owner or governance controller can call
     * @param accounts Array of addresses to remove from whitelist
     */
    function batchRemoveFromWhitelist(address[] calldata accounts) external onlyOwnerOrGovernance {
        require(accounts.length <= 100, "KYCRegistry: Batch size exceeds maximum (100 addresses)");
        
        KYCStorage.KYCData storage $ = KYCStorage.getKYCStorage();
        
        for (uint256 i = 0; i < accounts.length; i++) {
            address account = accounts[i];
            if ($.whitelistedAddresses[account]) {
                $.whitelistedAddresses[account] = false;
                emit AddressRemovedFromWhitelist(account, block.timestamp);
            }
        }
    }

    /**
     * @notice Check if an address is whitelisted
     * @param account Address to check
     * @return bool True if address is whitelisted
     */
    function isWhitelisted(address account) external view returns (bool) {
        KYCStorage.KYCData storage $ = KYCStorage.getKYCStorage();
        if (!$.whitelistEnabled) return true;
        return $.whitelistedAddresses[account];
    }

    /**
     * @notice Check if an address is blacklisted
     * @param account Address to check
     * @return bool True if address is blacklisted
     */
    function isBlacklisted(address account) external view returns (bool) {
        KYCStorage.KYCData storage $ = KYCStorage.getKYCStorage();
        if (!$.blacklistEnabled) return false;
        return $.blacklistedAddresses[account];
    }

    /**
     * @notice Get verification timestamp for an address
     * @param account Address to query
     * @return uint256 Timestamp when address was verified
     */
    function getVerificationTimestamp(address account) external view returns (uint256) {
        KYCStorage.KYCData storage $ = KYCStorage.getKYCStorage();
        return $.verificationTimestamp[account];
    }

    /**
     * @notice Set KYC tier for an address
     * @dev Only owner can call. Tiers: 'basic', 'accredited', 'institutional'
     * @param account Address to set tier for
     * @param tier KYC tier string
     */
    function setKYCTier(address account, string calldata tier) external onlyOwner {
        KYCStorage.KYCData storage $ = KYCStorage.getKYCStorage();
        $.kycTier[account] = tier;
    }

    /**
     * @notice Get KYC tier for an address
     * @param account Address to query
     * @return string KYC tier
     */
    function getKYCTier(address account) external view returns (string memory) {
        KYCStorage.KYCData storage $ = KYCStorage.getKYCStorage();
        return $.kycTier[account];
    }

    /**
     * @notice Set the governance controller address
     * @dev Only owner can call. Governance controller can modify whitelist via proposals.
     * @param governanceController Address of the governance controller
     */
    function setGovernanceController(address governanceController) external onlyOwner {
        require(governanceController != address(0), "KYCRegistry: Invalid governance controller");
        KYCStorage.KYCData storage $ = KYCStorage.getKYCStorage();
        $.governanceController = governanceController;
        emit GovernanceControllerSet(governanceController);
    }

    /**
     * @notice Get the governance controller address
     * @return address Governance controller address
     */
    function getGovernanceController() external view returns (address) {
        KYCStorage.KYCData storage $ = KYCStorage.getKYCStorage();
        return $.governanceController;
    }

    /**
     * @notice Enable or disable whitelist enforcement
     * @dev Only owner can call
     * @param enabled True to enable whitelist enforcement
     */
    function setWhitelistEnabled(bool enabled) external onlyOwner {
        KYCStorage.KYCData storage $ = KYCStorage.getKYCStorage();
        $.whitelistEnabled = enabled;
        emit WhitelistEnabledChanged(enabled);
    }

    /**
     * @notice Enable or disable blacklist enforcement
     * @dev Only owner can call
     * @param enabled True to enable blacklist enforcement
     */
    function setBlacklistEnabled(bool enabled) external onlyOwner {
        KYCStorage.KYCData storage $ = KYCStorage.getKYCStorage();
        $.blacklistEnabled = enabled;
        emit BlacklistEnabledChanged(enabled);
    }

    /**
     * @dev Modifier to restrict function access to owner or governance controller
     */
    modifier onlyOwnerOrGovernance() {
        KYCStorage.KYCData storage $ = KYCStorage.getKYCStorage();
        require(
            msg.sender == owner() || msg.sender == $.governanceController,
            "KYCRegistry: Caller is not owner or governance"
        );
        _;
    }

    /**
     * @dev Authorize upgrade (required by UUPSUpgradeable)
     * @param newImplementation Address of new implementation
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}

