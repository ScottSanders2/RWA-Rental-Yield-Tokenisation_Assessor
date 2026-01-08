Warning: This is a nightly build of Foundry. It is recommended to use the latest stable version. To mute this warning set `FOUNDRY_DISABLE_NIGHTLY_WARNING` in your environment. 

// SPDX-License-Identifier: MIT
pragma solidity <0.9.0 >=0.4.11 >=0.4.16 >=0.4.22 >=0.6.2 >=0.8.4 ^0.8.20 ^0.8.21 ^0.8.22 ^0.8.24;

// lib/openzeppelin-contracts/contracts/utils/Errors.sol

// OpenZeppelin Contracts (last updated v5.1.0) (utils/Errors.sol)

/**
 * @dev Collection of common custom errors used in multiple contracts
 *
 * IMPORTANT: Backwards compatibility is not guaranteed in future versions of the library.
 * It is recommended to avoid relying on the error API for critical functionality.
 *
 * _Available since v5.1._
 */
library Errors {
    /**
     * @dev The ETH balance of the account is not enough to perform the operation.
     */
    error InsufficientBalance(uint256 balance, uint256 needed);

    /**
     * @dev A call to an address target failed. The target may have reverted.
     */
    error FailedCall();

    /**
     * @dev The deployment failed.
     */
    error FailedDeployment();

    /**
     * @dev A necessary precompile is missing.
     */
    error MissingPrecompile(address);
}

// lib/openzeppelin-contracts/contracts/proxy/beacon/IBeacon.sol

// OpenZeppelin Contracts (last updated v5.4.0) (proxy/beacon/IBeacon.sol)

/**
 * @dev This is the interface that {BeaconProxy} expects of its beacon.
 */
interface IBeacon {
    /**
     * @dev Must return an address that can be used as a delegate call target.
     *
     * {UpgradeableBeacon} will check that this address is a contract.
     */
    function implementation() external view returns (address);
}

// lib/openzeppelin-contracts/contracts/interfaces/IERC1967.sol

// OpenZeppelin Contracts (last updated v5.4.0) (interfaces/IERC1967.sol)

/**
 * @dev ERC-1967: Proxy Storage Slots. This interface contains the events defined in the ERC.
 */
interface IERC1967 {
    /**
     * @dev Emitted when the implementation is upgraded.
     */
    event Upgraded(address indexed implementation);

    /**
     * @dev Emitted when the admin account has changed.
     */
    event AdminChanged(address previousAdmin, address newAdmin);

    /**
     * @dev Emitted when the beacon is changed.
     */
    event BeaconUpgraded(address indexed beacon);
}

// lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol

// OpenZeppelin Contracts (last updated v5.4.0) (token/ERC20/IERC20.sol)

/**
 * @dev Interface of the ERC-20 standard as defined in the ERC.
 */
interface IERC20 {
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @dev Returns the value of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the value of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves a `value` amount of tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 value) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets a `value` amount of tokens as the allowance of `spender` over the
     * caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 value) external returns (bool);

    /**
     * @dev Moves a `value` amount of tokens from `from` to `to` using the
     * allowance mechanism. `value` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

// lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol

// OpenZeppelin Contracts (last updated v5.3.0) (proxy/utils/Initializable.sol)

/**
 * @dev This is a base contract to aid in writing upgradeable contracts, or any kind of contract that will be deployed
 * behind a proxy. Since proxied contracts do not make use of a constructor, it's common to move constructor logic to an
 * external initializer function, usually called `initialize`. It then becomes necessary to protect this initializer
 * function so it can only be called once. The {initializer} modifier provided by this contract will have this effect.
 *
 * The initialization functions use a version number. Once a version number is used, it is consumed and cannot be
 * reused. This mechanism prevents re-execution of each "step" but allows the creation of new initialization steps in
 * case an upgrade adds a module that needs to be initialized.
 *
 * For example:
 *
 * [.hljs-theme-light.nopadding]
 * ```solidity
 * contract MyToken is ERC20Upgradeable {
 *     function initialize() initializer public {
 *         __ERC20_init("MyToken", "MTK");
 *     }
 * }
 *
 * contract MyTokenV2 is MyToken, ERC20PermitUpgradeable {
 *     function initializeV2() reinitializer(2) public {
 *         __ERC20Permit_init("MyToken");
 *     }
 * }
 * ```
 *
 * TIP: To avoid leaving the proxy in an uninitialized state, the initializer function should be called as early as
 * possible by providing the encoded function call as the `_data` argument to {ERC1967Proxy-constructor}.
 *
 * CAUTION: When used with inheritance, manual care must be taken to not invoke a parent initializer twice, or to ensure
 * that all initializers are idempotent. This is not verified automatically as constructors are by Solidity.
 *
 * [CAUTION]
 * ====
 * Avoid leaving a contract uninitialized.
 *
 * An uninitialized contract can be taken over by an attacker. This applies to both a proxy and its implementation
 * contract, which may impact the proxy. To prevent the implementation contract from being used, you should invoke
 * the {_disableInitializers} function in the constructor to automatically lock it when it is deployed:
 *
 * [.hljs-theme-light.nopadding]
 * ```
 * /// @custom:oz-upgrades-unsafe-allow constructor
 * constructor() {
 *     _disableInitializers();
 * }
 * ```
 * ====
 */
abstract contract Initializable {
    /**
     * @dev Storage of the initializable contract.
     *
     * It's implemented on a custom ERC-7201 namespace to reduce the risk of storage collisions
     * when using with upgradeable contracts.
     *
     * @custom:storage-location erc7201:openzeppelin.storage.Initializable
     */
    struct InitializableStorage {
        /**
         * @dev Indicates that the contract has been initialized.
         */
        uint64 _initialized;
        /**
         * @dev Indicates that the contract is in the process of being initialized.
         */
        bool _initializing;
    }

    // keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.Initializable")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant INITIALIZABLE_STORAGE = 0xf0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00;

    /**
     * @dev The contract is already initialized.
     */
    error InvalidInitialization();

    /**
     * @dev The contract is not initializing.
     */
    error NotInitializing();

    /**
     * @dev Triggered when the contract has been initialized or reinitialized.
     */
    event Initialized(uint64 version);

    /**
     * @dev A modifier that defines a protected initializer function that can be invoked at most once. In its scope,
     * `onlyInitializing` functions can be used to initialize parent contracts.
     *
     * Similar to `reinitializer(1)`, except that in the context of a constructor an `initializer` may be invoked any
     * number of times. This behavior in the constructor can be useful during testing and is not expected to be used in
     * production.
     *
     * Emits an {Initialized} event.
     */
    modifier initializer() {
        // solhint-disable-next-line var-name-mixedcase
        InitializableStorage storage $ = _getInitializableStorage();

        // Cache values to avoid duplicated sloads
        bool isTopLevelCall = !$._initializing;
        uint64 initialized = $._initialized;

        // Allowed calls:
        // - initialSetup: the contract is not in the initializing state and no previous version was
        //                 initialized
        // - construction: the contract is initialized at version 1 (no reinitialization) and the
        //                 current contract is just being deployed
        bool initialSetup = initialized == 0 && isTopLevelCall;
        bool construction = initialized == 1 && address(this).code.length == 0;

        if (!initialSetup && !construction) {
            revert InvalidInitialization();
        }
        $._initialized = 1;
        if (isTopLevelCall) {
            $._initializing = true;
        }
        _;
        if (isTopLevelCall) {
            $._initializing = false;
            emit Initialized(1);
        }
    }

    /**
     * @dev A modifier that defines a protected reinitializer function that can be invoked at most once, and only if the
     * contract hasn't been initialized to a greater version before. In its scope, `onlyInitializing` functions can be
     * used to initialize parent contracts.
     *
     * A reinitializer may be used after the original initialization step. This is essential to configure modules that
     * are added through upgrades and that require initialization.
     *
     * When `version` is 1, this modifier is similar to `initializer`, except that functions marked with `reinitializer`
     * cannot be nested. If one is invoked in the context of another, execution will revert.
     *
     * Note that versions can jump in increments greater than 1; this implies that if multiple reinitializers coexist in
     * a contract, executing them in the right order is up to the developer or operator.
     *
     * WARNING: Setting the version to 2**64 - 1 will prevent any future reinitialization.
     *
     * Emits an {Initialized} event.
     */
    modifier reinitializer(uint64 version) {
        // solhint-disable-next-line var-name-mixedcase
        InitializableStorage storage $ = _getInitializableStorage();

        if ($._initializing || $._initialized >= version) {
            revert InvalidInitialization();
        }
        $._initialized = version;
        $._initializing = true;
        _;
        $._initializing = false;
        emit Initialized(version);
    }

    /**
     * @dev Modifier to protect an initialization function so that it can only be invoked by functions with the
     * {initializer} and {reinitializer} modifiers, directly or indirectly.
     */
    modifier onlyInitializing() {
        _checkInitializing();
        _;
    }

    /**
     * @dev Reverts if the contract is not in an initializing state. See {onlyInitializing}.
     */
    function _checkInitializing() internal view virtual {
        if (!_isInitializing()) {
            revert NotInitializing();
        }
    }

    /**
     * @dev Locks the contract, preventing any future reinitialization. This cannot be part of an initializer call.
     * Calling this in the constructor of a contract will prevent that contract from being initialized or reinitialized
     * to any version. It is recommended to use this to lock implementation contracts that are designed to be called
     * through proxies.
     *
     * Emits an {Initialized} event the first time it is successfully executed.
     */
    function _disableInitializers() internal virtual {
        // solhint-disable-next-line var-name-mixedcase
        InitializableStorage storage $ = _getInitializableStorage();

        if ($._initializing) {
            revert InvalidInitialization();
        }
        if ($._initialized != type(uint64).max) {
            $._initialized = type(uint64).max;
            emit Initialized(type(uint64).max);
        }
    }

    /**
     * @dev Returns the highest version that has been initialized. See {reinitializer}.
     */
    function _getInitializedVersion() internal view returns (uint64) {
        return _getInitializableStorage()._initialized;
    }

    /**
     * @dev Returns `true` if the contract is currently initializing. See {onlyInitializing}.
     */
    function _isInitializing() internal view returns (bool) {
        return _getInitializableStorage()._initializing;
    }

    /**
     * @dev Pointer to storage slot. Allows integrators to override it with a custom storage location.
     *
     * NOTE: Consider following the ERC-7201 formula to derive storage locations.
     */
    function _initializableStorageSlot() internal pure virtual returns (bytes32) {
        return INITIALIZABLE_STORAGE;
    }

    /**
     * @dev Returns a pointer to the storage namespace.
     */
    // solhint-disable-next-line var-name-mixedcase
    function _getInitializableStorage() private pure returns (InitializableStorage storage $) {
        bytes32 slot = _initializableStorageSlot();
        assembly {
            $.slot := slot
        }
    }
}

// src/storage/KYCStorage.sol

/**
 * @title KYCStorage
 * @notice ERC-7201 namespaced storage library for KYC verification data
 * @dev Implements collision-free storage isolation using ERC-7201 standard
 * 
 * Storage namespace: "rwa.storage.KYC"
 * This namespace is isolated from:
 * - YieldStorage ("rwa.storage.Yield")
 * - YieldSharesStorage ("rwa.storage.YieldShares")
 * - PropertyStorage ("rwa.storage.Property")
 * - GovernanceStorage ("rwa.storage.Governance")
 * - TransferRestrictionsStorage ("rwa.storage.TransferRestrictions")
 * - CombinedTokenStorage ("rwa.storage.CombinedToken")
 * 
 * The storage location is calculated using:
 * keccak256(abi.encode(uint256(keccak256("rwa.storage.KYC")) - 1)) & ~bytes32(uint256(0xff))
 * This ensures no collisions with standard contract storage slots or other namespaced storage.
 */
library KYCStorage {
    /// @dev Storage namespace identifier
    /// @custom:storage-location erc7201:rwa.storage.KYC
    bytes32 private constant KYC_STORAGE_LOCATION = 
        0x8d6e9e2c5a1b3f4e7d8c9a0b1c2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d;

    /**
     * @dev KYC verification data structure
     * @param whitelistedAddresses Mapping of addresses that have completed KYC verification
     * @param blacklistedAddresses Mapping of addresses that are blocked from platform participation
     * @param verificationTimestamp Timestamp when address was verified (for expiry tracking)
     * @param kycTier Verification tier: 'basic' (individual), 'accredited' (accredited investor), 'institutional'
     * @param governanceController Reference to governance contract for democratic whitelist control
     * @param whitelistEnabled Global flag to enable/disable whitelist enforcement
     * @param blacklistEnabled Global flag to enable/disable blacklist enforcement
     */
    struct KYCData {
        mapping(address => bool) whitelistedAddresses;
        mapping(address => bool) blacklistedAddresses;
        mapping(address => uint256) verificationTimestamp;
        mapping(address => string) kycTier;
        address governanceController;
        bool whitelistEnabled;
        bool blacklistEnabled;
    }

    /**
     * @notice Get the storage pointer for KYC data
     * @dev Uses assembly to access the ERC-7201 namespaced storage location
     * @return $ Storage pointer to KYCData struct
     */
    function getKYCStorage() internal pure returns (KYCData storage $) {
        assembly {
            $.slot := KYC_STORAGE_LOCATION
        }
    }
}

// lib/openzeppelin-contracts/contracts/utils/StorageSlot.sol

// OpenZeppelin Contracts (last updated v5.1.0) (utils/StorageSlot.sol)
// This file was procedurally generated from scripts/generate/templates/StorageSlot.js.

/**
 * @dev Library for reading and writing primitive types to specific storage slots.
 *
 * Storage slots are often used to avoid storage conflict when dealing with upgradeable contracts.
 * This library helps with reading and writing to such slots without the need for inline assembly.
 *
 * The functions in this library return Slot structs that contain a `value` member that can be used to read or write.
 *
 * Example usage to set ERC-1967 implementation slot:
 * ```solidity
 * contract ERC1967 {
 *     // Define the slot. Alternatively, use the SlotDerivation library to derive the slot.
 *     bytes32 internal constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
 *
 *     function _getImplementation() internal view returns (address) {
 *         return StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value;
 *     }
 *
 *     function _setImplementation(address newImplementation) internal {
 *         require(newImplementation.code.length > 0);
 *         StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value = newImplementation;
 *     }
 * }
 * ```
 *
 * TIP: Consider using this library along with {SlotDerivation}.
 */
library StorageSlot {
    struct AddressSlot {
        address value;
    }

    struct BooleanSlot {
        bool value;
    }

    struct Bytes32Slot {
        bytes32 value;
    }

    struct Uint256Slot {
        uint256 value;
    }

    struct Int256Slot {
        int256 value;
    }

    struct StringSlot {
        string value;
    }

    struct BytesSlot {
        bytes value;
    }

    /**
     * @dev Returns an `AddressSlot` with member `value` located at `slot`.
     */
    function getAddressSlot(bytes32 slot) internal pure returns (AddressSlot storage r) {
        assembly ("memory-safe") {
            r.slot := slot
        }
    }

    /**
     * @dev Returns a `BooleanSlot` with member `value` located at `slot`.
     */
    function getBooleanSlot(bytes32 slot) internal pure returns (BooleanSlot storage r) {
        assembly ("memory-safe") {
            r.slot := slot
        }
    }

    /**
     * @dev Returns a `Bytes32Slot` with member `value` located at `slot`.
     */
    function getBytes32Slot(bytes32 slot) internal pure returns (Bytes32Slot storage r) {
        assembly ("memory-safe") {
            r.slot := slot
        }
    }

    /**
     * @dev Returns a `Uint256Slot` with member `value` located at `slot`.
     */
    function getUint256Slot(bytes32 slot) internal pure returns (Uint256Slot storage r) {
        assembly ("memory-safe") {
            r.slot := slot
        }
    }

    /**
     * @dev Returns a `Int256Slot` with member `value` located at `slot`.
     */
    function getInt256Slot(bytes32 slot) internal pure returns (Int256Slot storage r) {
        assembly ("memory-safe") {
            r.slot := slot
        }
    }

    /**
     * @dev Returns a `StringSlot` with member `value` located at `slot`.
     */
    function getStringSlot(bytes32 slot) internal pure returns (StringSlot storage r) {
        assembly ("memory-safe") {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `StringSlot` representation of the string storage pointer `store`.
     */
    function getStringSlot(string storage store) internal pure returns (StringSlot storage r) {
        assembly ("memory-safe") {
            r.slot := store.slot
        }
    }

    /**
     * @dev Returns a `BytesSlot` with member `value` located at `slot`.
     */
    function getBytesSlot(bytes32 slot) internal pure returns (BytesSlot storage r) {
        assembly ("memory-safe") {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `BytesSlot` representation of the bytes storage pointer `store`.
     */
    function getBytesSlot(bytes storage store) internal pure returns (BytesSlot storage r) {
        assembly ("memory-safe") {
            r.slot := store.slot
        }
    }
}

// src/storage/TransferRestrictionsStorage.sol

/**
 * @title TransferRestrictionsStorage
 * @notice ERC-7201 namespaced storage library for transfer restriction rules
 * @dev Provides collision-free storage separate from YieldStorage, YieldSharesStorage,
 * PropertyStorage, GovernanceStorage, and CombinedTokenStorage using ERC-7201 pattern.
 * Enables autonomous enforcement of lockup periods, concentration limits, minimum holding
 * periods, and emergency pause controls through transfer hooks without breaking ERC-20/ERC-1155
 * standard compliance.
 *
 * Architecture:
 * - ERC-7201 namespace ensures no storage collisions with UUPS upgradeable contracts
 * - Transfer restrictions validated in _update hook before every transfer
 * - Governance integration enables democratic control over restriction parameters
 * - Restrictions are optional (disabled by default) per agreement for regulatory compliance
 *
 * Restriction Types:
 * 1. Lockup Period: Prevents immediate flipping after minting (e.g., 30 days)
 * 2. Concentration Limit: Prevents whale dominance (e.g., max 20% of supply per investor)
 * 3. Minimum Holding Period: Anti-churn mechanism (e.g., 7 days minimum hold before transfer)
 * 4. Emergency Pause: Owner or governance can pause all transfers during security incidents
 *
 * Standard Compliance:
 * - Restrictions are additional validation checks, not modifications to ERC-20/ERC-1155 interfaces
 * - Mint and burn operations bypass restrictions (from/to == address(0))
 * - Transfer, transferFrom, safeTransferFrom remain compliant with token standards
 */
library TransferRestrictionsStorage {
    /**
     * @notice Transfer restriction data structure
     * @dev Contains all configurable restriction parameters per agreement
     */
    struct TransferRestrictionData {
        /// @notice Timestamp when lockup period ends (0 = no lockup)
        uint256 lockupEndTimestamp;
        
        /// @notice Emergency pause flag controlled by owner or governance
        bool isTransferPaused;
        
        /// @notice Maximum shares per investor in basis points (e.g., 2000 = 20%)
        uint256 maxSharesPerInvestor;
        
        /// @notice Minimum holding period in seconds before transfer allowed (e.g., 7 days)
        uint256 minHoldingPeriod;
        
        /// @notice Whitelisted addresses that can receive transfers (optional, deferred to Iteration 14 KYC)
        mapping(address => bool) whitelistedAddresses;
        
        /// @notice Blacklisted addresses that cannot receive transfers (optional)
        mapping(address => bool) blacklistedAddresses;
        
        /// @notice Transfer count per investor for rate limiting (optional)
        mapping(address => uint256) transferCount;
        
        /// @notice Last transfer timestamp per address for holding period enforcement
        mapping(address => uint256) lastTransferTimestamp;
        
        /// @notice Whether whitelist is enabled (false by default)
        bool whitelistEnabled;
        
        /// @notice Whether blacklist is enabled (false by default)
        bool blacklistEnabled;
    }

    /**
     * @notice Per-yield-token restriction storage for ERC-1155
     * @dev Maps yieldTokenId to its specific restriction parameters
     */
    struct YieldTokenRestrictionsStorage {
        /// @notice Mapping from yieldTokenId to restriction data
        mapping(uint256 => TransferRestrictionData) restrictionsById;
    }

    /// @custom:storage-location erc7201:rwa.storage.TransferRestrictions
    /// keccak256(abi.encode(uint256(keccak256("rwa.storage.TransferRestrictions")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant TRANSFER_RESTRICTIONS_STORAGE_LOCATION = 
        0x43c39570a45a5d3dc0bba8859663155f33e33210cd87b04924328494bbfbaa00;

    /// @custom:storage-location erc7201:rwa.storage.YieldTokenRestrictions
    /// keccak256(abi.encode(uint256(keccak256("rwa.storage.YieldTokenRestrictions")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant YIELD_TOKEN_RESTRICTIONS_STORAGE_LOCATION = 
        0xf76f648740fb3b29b1bc1c5645ebe4e3f37188b193d1e9364144ecdc769d1100;

    /**
     * @notice Get storage pointer for transfer restrictions using ERC-7201 (for ERC-20)
     * @return $ Storage pointer to TransferRestrictionData
     */
    function getTransferRestrictionsStorage() internal pure returns (TransferRestrictionData storage $) {
        assembly {
            $.slot := TRANSFER_RESTRICTIONS_STORAGE_LOCATION
        }
    }

    /**
     * @notice Get storage pointer for per-yield-token restrictions using ERC-7201 (for ERC-1155)
     * @return $ Storage pointer to YieldTokenRestrictionsStorage
     */
    function getYieldTokenRestrictionsStorage() internal pure returns (YieldTokenRestrictionsStorage storage $) {
        assembly {
            $.slot := YIELD_TOKEN_RESTRICTIONS_STORAGE_LOCATION
        }
    }
}

// src/storage/YieldSharesStorage.sol

/// @title Yield Shares Storage Library
/// @notice Implements ERC-7201 namespaced storage pattern for ERC-20 token data
/// @dev ERC-7201 ensures storage isolation during contract upgrades by using deterministic namespace calculation
/// This prevents collisions between inherited ERC20Upgradeable storage and custom token storage variables
/// Separate namespace from YieldStorage enables independent upgradeability of both contracts
library YieldSharesStorage {
    /// @dev ERC-7201 namespace identifier for yield shares token data
    /// @notice Calculated as: keccak256(abi.encode(uint256(keccak256("rwa.storage.YieldShares")) - 1)) & ~bytes32(uint256(0xff))
    /// This creates a deterministic, collision-resistant storage slot independent from YieldStorage
    bytes32 private constant YIELD_SHARES_STORAGE_SLOT = keccak256(abi.encode(uint256(keccak256("rwa.storage.YieldShares")) - 1)) & ~bytes32(uint256(0xff));

    /// @dev Storage structure for yield shares token data
    /// @notice Enhanced with pooled capital contribution tracking to support multi-investor upfront capital
    /// @dev SINGLE AGREEMENT CONSTRAINT: This token instance supports only one agreement to prevent bookkeeping complexity
    struct YieldSharesData {
        // Slot 0
        address yieldBaseContract;        // Reference to YieldBase contract for access control validation
        uint256 currentAgreementId;       // The single agreement ID this token instance supports

        // Slot 1 - Shares and shareholder tracking (scoped to single agreement)
        uint256 totalShares;              // Total shares minted for the current agreement
        uint256 shareholderCount;         // Number of unique shareholders for the current agreement

        // Slot 2 - Shareholder tracking arrays
        address[] shareholderAddresses;   // Array of shareholder addresses for the current agreement

        // Slot 3 - Shareholder-to-shares mappings
        mapping(address => uint256) shareholderShares;  // Shares held by each address for the current agreement

        // Slot 4 - Shareholder membership mapping (for O(1) lookups)
        mapping(address => bool) isShareholder;  // Whether an address is a shareholder for the current agreement

        // Slot 5 - Unclaimed remainder tracking
        mapping(address => uint256) unclaimedRemainder;  // Unclaimed ETH due to failed transfers or rounding dust

        // Slot 6 - Pooled capital contribution tracking
        mapping(address => uint256) pooledContributions; // Capital contributed by each investor during agreement creation
        address[] contributorAddresses;    // Array of addresses who contributed to upfront capital pool
        uint256 totalPooledCapital;       // Sum of all pooled contributions for validation

        // Slot 7 - Contributor membership tracking (for O(1) lookups)
        mapping(address => bool) isContributor; // Whether an address is a contributor to the capital pool
        uint256 contributorCount;         // Number of unique contributors to the capital pool
    }

    /// @notice Returns a storage pointer to the namespaced YieldSharesData location
    /// @dev Uses inline assembly to access the predetermined storage slot
    /// @return data Storage pointer to the YieldSharesData struct
    function getYieldSharesStorage() internal pure returns (YieldSharesData storage data) {
        bytes32 slot = YIELD_SHARES_STORAGE_SLOT;
        assembly {
            data.slot := slot
        }
    }
}

// lib/forge-std/src/console.sol

library console {
    address constant CONSOLE_ADDRESS =
        0x000000000000000000636F6e736F6c652e6c6f67;

    function _sendLogPayloadImplementation(bytes memory payload) internal view {
        address consoleAddress = CONSOLE_ADDRESS;
        /// @solidity memory-safe-assembly
        assembly {
            pop(
                staticcall(
                    gas(),
                    consoleAddress,
                    add(payload, 32),
                    mload(payload),
                    0,
                    0
                )
            )
        }
    }

    function _castToPure(
      function(bytes memory) internal view fnIn
    ) internal pure returns (function(bytes memory) pure fnOut) {
        assembly {
            fnOut := fnIn
        }
    }

    function _sendLogPayload(bytes memory payload) internal pure {
        _castToPure(_sendLogPayloadImplementation)(payload);
    }

    function log() internal pure {
        _sendLogPayload(abi.encodeWithSignature("log()"));
    }

    function logInt(int256 p0) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(int256)", p0));
    }

    function logUint(uint256 p0) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(uint256)", p0));
    }

    function logString(string memory p0) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(string)", p0));
    }

    function logBool(bool p0) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(bool)", p0));
    }

    function logAddress(address p0) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(address)", p0));
    }

    function logBytes(bytes memory p0) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(bytes)", p0));
    }

    function logBytes1(bytes1 p0) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(bytes1)", p0));
    }

    function logBytes2(bytes2 p0) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(bytes2)", p0));
    }

    function logBytes3(bytes3 p0) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(bytes3)", p0));
    }

    function logBytes4(bytes4 p0) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(bytes4)", p0));
    }

    function logBytes5(bytes5 p0) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(bytes5)", p0));
    }

    function logBytes6(bytes6 p0) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(bytes6)", p0));
    }

    function logBytes7(bytes7 p0) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(bytes7)", p0));
    }

    function logBytes8(bytes8 p0) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(bytes8)", p0));
    }

    function logBytes9(bytes9 p0) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(bytes9)", p0));
    }

    function logBytes10(bytes10 p0) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(bytes10)", p0));
    }

    function logBytes11(bytes11 p0) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(bytes11)", p0));
    }

    function logBytes12(bytes12 p0) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(bytes12)", p0));
    }

    function logBytes13(bytes13 p0) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(bytes13)", p0));
    }

    function logBytes14(bytes14 p0) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(bytes14)", p0));
    }

    function logBytes15(bytes15 p0) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(bytes15)", p0));
    }

    function logBytes16(bytes16 p0) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(bytes16)", p0));
    }

    function logBytes17(bytes17 p0) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(bytes17)", p0));
    }

    function logBytes18(bytes18 p0) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(bytes18)", p0));
    }

    function logBytes19(bytes19 p0) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(bytes19)", p0));
    }

    function logBytes20(bytes20 p0) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(bytes20)", p0));
    }

    function logBytes21(bytes21 p0) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(bytes21)", p0));
    }

    function logBytes22(bytes22 p0) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(bytes22)", p0));
    }

    function logBytes23(bytes23 p0) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(bytes23)", p0));
    }

    function logBytes24(bytes24 p0) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(bytes24)", p0));
    }

    function logBytes25(bytes25 p0) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(bytes25)", p0));
    }

    function logBytes26(bytes26 p0) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(bytes26)", p0));
    }

    function logBytes27(bytes27 p0) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(bytes27)", p0));
    }

    function logBytes28(bytes28 p0) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(bytes28)", p0));
    }

    function logBytes29(bytes29 p0) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(bytes29)", p0));
    }

    function logBytes30(bytes30 p0) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(bytes30)", p0));
    }

    function logBytes31(bytes31 p0) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(bytes31)", p0));
    }

    function logBytes32(bytes32 p0) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(bytes32)", p0));
    }

    function log(uint256 p0) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(uint256)", p0));
    }

    function log(int256 p0) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(int256)", p0));
    }

    function log(string memory p0) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(string)", p0));
    }

    function log(bool p0) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(bool)", p0));
    }

    function log(address p0) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(address)", p0));
    }

    function log(uint256 p0, uint256 p1) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(uint256,uint256)", p0, p1));
    }

    function log(uint256 p0, string memory p1) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(uint256,string)", p0, p1));
    }

    function log(uint256 p0, bool p1) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(uint256,bool)", p0, p1));
    }

    function log(uint256 p0, address p1) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(uint256,address)", p0, p1));
    }

    function log(string memory p0, uint256 p1) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(string,uint256)", p0, p1));
    }

    function log(string memory p0, int256 p1) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(string,int256)", p0, p1));
    }

    function log(string memory p0, string memory p1) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(string,string)", p0, p1));
    }

    function log(string memory p0, bool p1) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(string,bool)", p0, p1));
    }

    function log(string memory p0, address p1) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(string,address)", p0, p1));
    }

    function log(bool p0, uint256 p1) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(bool,uint256)", p0, p1));
    }

    function log(bool p0, string memory p1) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(bool,string)", p0, p1));
    }

    function log(bool p0, bool p1) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(bool,bool)", p0, p1));
    }

    function log(bool p0, address p1) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(bool,address)", p0, p1));
    }

    function log(address p0, uint256 p1) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(address,uint256)", p0, p1));
    }

    function log(address p0, string memory p1) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(address,string)", p0, p1));
    }

    function log(address p0, bool p1) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(address,bool)", p0, p1));
    }

    function log(address p0, address p1) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(address,address)", p0, p1));
    }

    function log(uint256 p0, uint256 p1, uint256 p2) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(uint256,uint256,uint256)", p0, p1, p2));
    }

    function log(uint256 p0, uint256 p1, string memory p2) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(uint256,uint256,string)", p0, p1, p2));
    }

    function log(uint256 p0, uint256 p1, bool p2) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(uint256,uint256,bool)", p0, p1, p2));
    }

    function log(uint256 p0, uint256 p1, address p2) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(uint256,uint256,address)", p0, p1, p2));
    }

    function log(uint256 p0, string memory p1, uint256 p2) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(uint256,string,uint256)", p0, p1, p2));
    }

    function log(uint256 p0, string memory p1, string memory p2) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(uint256,string,string)", p0, p1, p2));
    }

    function log(uint256 p0, string memory p1, bool p2) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(uint256,string,bool)", p0, p1, p2));
    }

    function log(uint256 p0, string memory p1, address p2) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(uint256,string,address)", p0, p1, p2));
    }

    function log(uint256 p0, bool p1, uint256 p2) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(uint256,bool,uint256)", p0, p1, p2));
    }

    function log(uint256 p0, bool p1, string memory p2) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(uint256,bool,string)", p0, p1, p2));
    }

    function log(uint256 p0, bool p1, bool p2) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(uint256,bool,bool)", p0, p1, p2));
    }

    function log(uint256 p0, bool p1, address p2) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(uint256,bool,address)", p0, p1, p2));
    }

    function log(uint256 p0, address p1, uint256 p2) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(uint256,address,uint256)", p0, p1, p2));
    }

    function log(uint256 p0, address p1, string memory p2) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(uint256,address,string)", p0, p1, p2));
    }

    function log(uint256 p0, address p1, bool p2) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(uint256,address,bool)", p0, p1, p2));
    }

    function log(uint256 p0, address p1, address p2) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(uint256,address,address)", p0, p1, p2));
    }

    function log(string memory p0, uint256 p1, uint256 p2) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(string,uint256,uint256)", p0, p1, p2));
    }

    function log(string memory p0, uint256 p1, string memory p2) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(string,uint256,string)", p0, p1, p2));
    }

    function log(string memory p0, uint256 p1, bool p2) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(string,uint256,bool)", p0, p1, p2));
    }

    function log(string memory p0, uint256 p1, address p2) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(string,uint256,address)", p0, p1, p2));
    }

    function log(string memory p0, string memory p1, uint256 p2) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(string,string,uint256)", p0, p1, p2));
    }

    function log(string memory p0, string memory p1, string memory p2) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(string,string,string)", p0, p1, p2));
    }

    function log(string memory p0, string memory p1, bool p2) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(string,string,bool)", p0, p1, p2));
    }

    function log(string memory p0, string memory p1, address p2) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(string,string,address)", p0, p1, p2));
    }

    function log(string memory p0, bool p1, uint256 p2) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(string,bool,uint256)", p0, p1, p2));
    }

    function log(string memory p0, bool p1, string memory p2) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(string,bool,string)", p0, p1, p2));
    }

    function log(string memory p0, bool p1, bool p2) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(string,bool,bool)", p0, p1, p2));
    }

    function log(string memory p0, bool p1, address p2) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(string,bool,address)", p0, p1, p2));
    }

    function log(string memory p0, address p1, uint256 p2) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(string,address,uint256)", p0, p1, p2));
    }

    function log(string memory p0, address p1, string memory p2) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(string,address,string)", p0, p1, p2));
    }

    function log(string memory p0, address p1, bool p2) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(string,address,bool)", p0, p1, p2));
    }

    function log(string memory p0, address p1, address p2) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(string,address,address)", p0, p1, p2));
    }

    function log(bool p0, uint256 p1, uint256 p2) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(bool,uint256,uint256)", p0, p1, p2));
    }

    function log(bool p0, uint256 p1, string memory p2) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(bool,uint256,string)", p0, p1, p2));
    }

    function log(bool p0, uint256 p1, bool p2) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(bool,uint256,bool)", p0, p1, p2));
    }

    function log(bool p0, uint256 p1, address p2) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(bool,uint256,address)", p0, p1, p2));
    }

    function log(bool p0, string memory p1, uint256 p2) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(bool,string,uint256)", p0, p1, p2));
    }

    function log(bool p0, string memory p1, string memory p2) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(bool,string,string)", p0, p1, p2));
    }

    function log(bool p0, string memory p1, bool p2) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(bool,string,bool)", p0, p1, p2));
    }

    function log(bool p0, string memory p1, address p2) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(bool,string,address)", p0, p1, p2));
    }

    function log(bool p0, bool p1, uint256 p2) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(bool,bool,uint256)", p0, p1, p2));
    }

    function log(bool p0, bool p1, string memory p2) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(bool,bool,string)", p0, p1, p2));
    }

    function log(bool p0, bool p1, bool p2) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(bool,bool,bool)", p0, p1, p2));
    }

    function log(bool p0, bool p1, address p2) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(bool,bool,address)", p0, p1, p2));
    }

    function log(bool p0, address p1, uint256 p2) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(bool,address,uint256)", p0, p1, p2));
    }

    function log(bool p0, address p1, string memory p2) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(bool,address,string)", p0, p1, p2));
    }

    function log(bool p0, address p1, bool p2) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(bool,address,bool)", p0, p1, p2));
    }

    function log(bool p0, address p1, address p2) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(bool,address,address)", p0, p1, p2));
    }

    function log(address p0, uint256 p1, uint256 p2) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(address,uint256,uint256)", p0, p1, p2));
    }

    function log(address p0, uint256 p1, string memory p2) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(address,uint256,string)", p0, p1, p2));
    }

    function log(address p0, uint256 p1, bool p2) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(address,uint256,bool)", p0, p1, p2));
    }

    function log(address p0, uint256 p1, address p2) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(address,uint256,address)", p0, p1, p2));
    }

    function log(address p0, string memory p1, uint256 p2) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(address,string,uint256)", p0, p1, p2));
    }

    function log(address p0, string memory p1, string memory p2) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(address,string,string)", p0, p1, p2));
    }

    function log(address p0, string memory p1, bool p2) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(address,string,bool)", p0, p1, p2));
    }

    function log(address p0, string memory p1, address p2) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(address,string,address)", p0, p1, p2));
    }

    function log(address p0, bool p1, uint256 p2) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(address,bool,uint256)", p0, p1, p2));
    }

    function log(address p0, bool p1, string memory p2) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(address,bool,string)", p0, p1, p2));
    }

    function log(address p0, bool p1, bool p2) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(address,bool,bool)", p0, p1, p2));
    }

    function log(address p0, bool p1, address p2) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(address,bool,address)", p0, p1, p2));
    }

    function log(address p0, address p1, uint256 p2) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(address,address,uint256)", p0, p1, p2));
    }

    function log(address p0, address p1, string memory p2) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(address,address,string)", p0, p1, p2));
    }

    function log(address p0, address p1, bool p2) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(address,address,bool)", p0, p1, p2));
    }

    function log(address p0, address p1, address p2) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(address,address,address)", p0, p1, p2));
    }

    function log(uint256 p0, uint256 p1, uint256 p2, uint256 p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(uint256,uint256,uint256,uint256)", p0, p1, p2, p3));
    }

    function log(uint256 p0, uint256 p1, uint256 p2, string memory p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(uint256,uint256,uint256,string)", p0, p1, p2, p3));
    }

    function log(uint256 p0, uint256 p1, uint256 p2, bool p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(uint256,uint256,uint256,bool)", p0, p1, p2, p3));
    }

    function log(uint256 p0, uint256 p1, uint256 p2, address p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(uint256,uint256,uint256,address)", p0, p1, p2, p3));
    }

    function log(uint256 p0, uint256 p1, string memory p2, uint256 p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(uint256,uint256,string,uint256)", p0, p1, p2, p3));
    }

    function log(uint256 p0, uint256 p1, string memory p2, string memory p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(uint256,uint256,string,string)", p0, p1, p2, p3));
    }

    function log(uint256 p0, uint256 p1, string memory p2, bool p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(uint256,uint256,string,bool)", p0, p1, p2, p3));
    }

    function log(uint256 p0, uint256 p1, string memory p2, address p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(uint256,uint256,string,address)", p0, p1, p2, p3));
    }

    function log(uint256 p0, uint256 p1, bool p2, uint256 p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(uint256,uint256,bool,uint256)", p0, p1, p2, p3));
    }

    function log(uint256 p0, uint256 p1, bool p2, string memory p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(uint256,uint256,bool,string)", p0, p1, p2, p3));
    }

    function log(uint256 p0, uint256 p1, bool p2, bool p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(uint256,uint256,bool,bool)", p0, p1, p2, p3));
    }

    function log(uint256 p0, uint256 p1, bool p2, address p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(uint256,uint256,bool,address)", p0, p1, p2, p3));
    }

    function log(uint256 p0, uint256 p1, address p2, uint256 p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(uint256,uint256,address,uint256)", p0, p1, p2, p3));
    }

    function log(uint256 p0, uint256 p1, address p2, string memory p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(uint256,uint256,address,string)", p0, p1, p2, p3));
    }

    function log(uint256 p0, uint256 p1, address p2, bool p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(uint256,uint256,address,bool)", p0, p1, p2, p3));
    }

    function log(uint256 p0, uint256 p1, address p2, address p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(uint256,uint256,address,address)", p0, p1, p2, p3));
    }

    function log(uint256 p0, string memory p1, uint256 p2, uint256 p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(uint256,string,uint256,uint256)", p0, p1, p2, p3));
    }

    function log(uint256 p0, string memory p1, uint256 p2, string memory p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(uint256,string,uint256,string)", p0, p1, p2, p3));
    }

    function log(uint256 p0, string memory p1, uint256 p2, bool p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(uint256,string,uint256,bool)", p0, p1, p2, p3));
    }

    function log(uint256 p0, string memory p1, uint256 p2, address p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(uint256,string,uint256,address)", p0, p1, p2, p3));
    }

    function log(uint256 p0, string memory p1, string memory p2, uint256 p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(uint256,string,string,uint256)", p0, p1, p2, p3));
    }

    function log(uint256 p0, string memory p1, string memory p2, string memory p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(uint256,string,string,string)", p0, p1, p2, p3));
    }

    function log(uint256 p0, string memory p1, string memory p2, bool p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(uint256,string,string,bool)", p0, p1, p2, p3));
    }

    function log(uint256 p0, string memory p1, string memory p2, address p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(uint256,string,string,address)", p0, p1, p2, p3));
    }

    function log(uint256 p0, string memory p1, bool p2, uint256 p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(uint256,string,bool,uint256)", p0, p1, p2, p3));
    }

    function log(uint256 p0, string memory p1, bool p2, string memory p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(uint256,string,bool,string)", p0, p1, p2, p3));
    }

    function log(uint256 p0, string memory p1, bool p2, bool p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(uint256,string,bool,bool)", p0, p1, p2, p3));
    }

    function log(uint256 p0, string memory p1, bool p2, address p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(uint256,string,bool,address)", p0, p1, p2, p3));
    }

    function log(uint256 p0, string memory p1, address p2, uint256 p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(uint256,string,address,uint256)", p0, p1, p2, p3));
    }

    function log(uint256 p0, string memory p1, address p2, string memory p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(uint256,string,address,string)", p0, p1, p2, p3));
    }

    function log(uint256 p0, string memory p1, address p2, bool p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(uint256,string,address,bool)", p0, p1, p2, p3));
    }

    function log(uint256 p0, string memory p1, address p2, address p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(uint256,string,address,address)", p0, p1, p2, p3));
    }

    function log(uint256 p0, bool p1, uint256 p2, uint256 p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(uint256,bool,uint256,uint256)", p0, p1, p2, p3));
    }

    function log(uint256 p0, bool p1, uint256 p2, string memory p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(uint256,bool,uint256,string)", p0, p1, p2, p3));
    }

    function log(uint256 p0, bool p1, uint256 p2, bool p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(uint256,bool,uint256,bool)", p0, p1, p2, p3));
    }

    function log(uint256 p0, bool p1, uint256 p2, address p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(uint256,bool,uint256,address)", p0, p1, p2, p3));
    }

    function log(uint256 p0, bool p1, string memory p2, uint256 p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(uint256,bool,string,uint256)", p0, p1, p2, p3));
    }

    function log(uint256 p0, bool p1, string memory p2, string memory p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(uint256,bool,string,string)", p0, p1, p2, p3));
    }

    function log(uint256 p0, bool p1, string memory p2, bool p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(uint256,bool,string,bool)", p0, p1, p2, p3));
    }

    function log(uint256 p0, bool p1, string memory p2, address p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(uint256,bool,string,address)", p0, p1, p2, p3));
    }

    function log(uint256 p0, bool p1, bool p2, uint256 p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(uint256,bool,bool,uint256)", p0, p1, p2, p3));
    }

    function log(uint256 p0, bool p1, bool p2, string memory p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(uint256,bool,bool,string)", p0, p1, p2, p3));
    }

    function log(uint256 p0, bool p1, bool p2, bool p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(uint256,bool,bool,bool)", p0, p1, p2, p3));
    }

    function log(uint256 p0, bool p1, bool p2, address p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(uint256,bool,bool,address)", p0, p1, p2, p3));
    }

    function log(uint256 p0, bool p1, address p2, uint256 p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(uint256,bool,address,uint256)", p0, p1, p2, p3));
    }

    function log(uint256 p0, bool p1, address p2, string memory p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(uint256,bool,address,string)", p0, p1, p2, p3));
    }

    function log(uint256 p0, bool p1, address p2, bool p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(uint256,bool,address,bool)", p0, p1, p2, p3));
    }

    function log(uint256 p0, bool p1, address p2, address p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(uint256,bool,address,address)", p0, p1, p2, p3));
    }

    function log(uint256 p0, address p1, uint256 p2, uint256 p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(uint256,address,uint256,uint256)", p0, p1, p2, p3));
    }

    function log(uint256 p0, address p1, uint256 p2, string memory p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(uint256,address,uint256,string)", p0, p1, p2, p3));
    }

    function log(uint256 p0, address p1, uint256 p2, bool p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(uint256,address,uint256,bool)", p0, p1, p2, p3));
    }

    function log(uint256 p0, address p1, uint256 p2, address p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(uint256,address,uint256,address)", p0, p1, p2, p3));
    }

    function log(uint256 p0, address p1, string memory p2, uint256 p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(uint256,address,string,uint256)", p0, p1, p2, p3));
    }

    function log(uint256 p0, address p1, string memory p2, string memory p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(uint256,address,string,string)", p0, p1, p2, p3));
    }

    function log(uint256 p0, address p1, string memory p2, bool p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(uint256,address,string,bool)", p0, p1, p2, p3));
    }

    function log(uint256 p0, address p1, string memory p2, address p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(uint256,address,string,address)", p0, p1, p2, p3));
    }

    function log(uint256 p0, address p1, bool p2, uint256 p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(uint256,address,bool,uint256)", p0, p1, p2, p3));
    }

    function log(uint256 p0, address p1, bool p2, string memory p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(uint256,address,bool,string)", p0, p1, p2, p3));
    }

    function log(uint256 p0, address p1, bool p2, bool p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(uint256,address,bool,bool)", p0, p1, p2, p3));
    }

    function log(uint256 p0, address p1, bool p2, address p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(uint256,address,bool,address)", p0, p1, p2, p3));
    }

    function log(uint256 p0, address p1, address p2, uint256 p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(uint256,address,address,uint256)", p0, p1, p2, p3));
    }

    function log(uint256 p0, address p1, address p2, string memory p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(uint256,address,address,string)", p0, p1, p2, p3));
    }

    function log(uint256 p0, address p1, address p2, bool p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(uint256,address,address,bool)", p0, p1, p2, p3));
    }

    function log(uint256 p0, address p1, address p2, address p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(uint256,address,address,address)", p0, p1, p2, p3));
    }

    function log(string memory p0, uint256 p1, uint256 p2, uint256 p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(string,uint256,uint256,uint256)", p0, p1, p2, p3));
    }

    function log(string memory p0, uint256 p1, uint256 p2, string memory p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(string,uint256,uint256,string)", p0, p1, p2, p3));
    }

    function log(string memory p0, uint256 p1, uint256 p2, bool p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(string,uint256,uint256,bool)", p0, p1, p2, p3));
    }

    function log(string memory p0, uint256 p1, uint256 p2, address p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(string,uint256,uint256,address)", p0, p1, p2, p3));
    }

    function log(string memory p0, uint256 p1, string memory p2, uint256 p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(string,uint256,string,uint256)", p0, p1, p2, p3));
    }

    function log(string memory p0, uint256 p1, string memory p2, string memory p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(string,uint256,string,string)", p0, p1, p2, p3));
    }

    function log(string memory p0, uint256 p1, string memory p2, bool p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(string,uint256,string,bool)", p0, p1, p2, p3));
    }

    function log(string memory p0, uint256 p1, string memory p2, address p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(string,uint256,string,address)", p0, p1, p2, p3));
    }

    function log(string memory p0, uint256 p1, bool p2, uint256 p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(string,uint256,bool,uint256)", p0, p1, p2, p3));
    }

    function log(string memory p0, uint256 p1, bool p2, string memory p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(string,uint256,bool,string)", p0, p1, p2, p3));
    }

    function log(string memory p0, uint256 p1, bool p2, bool p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(string,uint256,bool,bool)", p0, p1, p2, p3));
    }

    function log(string memory p0, uint256 p1, bool p2, address p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(string,uint256,bool,address)", p0, p1, p2, p3));
    }

    function log(string memory p0, uint256 p1, address p2, uint256 p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(string,uint256,address,uint256)", p0, p1, p2, p3));
    }

    function log(string memory p0, uint256 p1, address p2, string memory p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(string,uint256,address,string)", p0, p1, p2, p3));
    }

    function log(string memory p0, uint256 p1, address p2, bool p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(string,uint256,address,bool)", p0, p1, p2, p3));
    }

    function log(string memory p0, uint256 p1, address p2, address p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(string,uint256,address,address)", p0, p1, p2, p3));
    }

    function log(string memory p0, string memory p1, uint256 p2, uint256 p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(string,string,uint256,uint256)", p0, p1, p2, p3));
    }

    function log(string memory p0, string memory p1, uint256 p2, string memory p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(string,string,uint256,string)", p0, p1, p2, p3));
    }

    function log(string memory p0, string memory p1, uint256 p2, bool p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(string,string,uint256,bool)", p0, p1, p2, p3));
    }

    function log(string memory p0, string memory p1, uint256 p2, address p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(string,string,uint256,address)", p0, p1, p2, p3));
    }

    function log(string memory p0, string memory p1, string memory p2, uint256 p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(string,string,string,uint256)", p0, p1, p2, p3));
    }

    function log(string memory p0, string memory p1, string memory p2, string memory p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(string,string,string,string)", p0, p1, p2, p3));
    }

    function log(string memory p0, string memory p1, string memory p2, bool p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(string,string,string,bool)", p0, p1, p2, p3));
    }

    function log(string memory p0, string memory p1, string memory p2, address p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(string,string,string,address)", p0, p1, p2, p3));
    }

    function log(string memory p0, string memory p1, bool p2, uint256 p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(string,string,bool,uint256)", p0, p1, p2, p3));
    }

    function log(string memory p0, string memory p1, bool p2, string memory p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(string,string,bool,string)", p0, p1, p2, p3));
    }

    function log(string memory p0, string memory p1, bool p2, bool p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(string,string,bool,bool)", p0, p1, p2, p3));
    }

    function log(string memory p0, string memory p1, bool p2, address p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(string,string,bool,address)", p0, p1, p2, p3));
    }

    function log(string memory p0, string memory p1, address p2, uint256 p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(string,string,address,uint256)", p0, p1, p2, p3));
    }

    function log(string memory p0, string memory p1, address p2, string memory p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(string,string,address,string)", p0, p1, p2, p3));
    }

    function log(string memory p0, string memory p1, address p2, bool p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(string,string,address,bool)", p0, p1, p2, p3));
    }

    function log(string memory p0, string memory p1, address p2, address p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(string,string,address,address)", p0, p1, p2, p3));
    }

    function log(string memory p0, bool p1, uint256 p2, uint256 p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(string,bool,uint256,uint256)", p0, p1, p2, p3));
    }

    function log(string memory p0, bool p1, uint256 p2, string memory p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(string,bool,uint256,string)", p0, p1, p2, p3));
    }

    function log(string memory p0, bool p1, uint256 p2, bool p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(string,bool,uint256,bool)", p0, p1, p2, p3));
    }

    function log(string memory p0, bool p1, uint256 p2, address p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(string,bool,uint256,address)", p0, p1, p2, p3));
    }

    function log(string memory p0, bool p1, string memory p2, uint256 p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(string,bool,string,uint256)", p0, p1, p2, p3));
    }

    function log(string memory p0, bool p1, string memory p2, string memory p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(string,bool,string,string)", p0, p1, p2, p3));
    }

    function log(string memory p0, bool p1, string memory p2, bool p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(string,bool,string,bool)", p0, p1, p2, p3));
    }

    function log(string memory p0, bool p1, string memory p2, address p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(string,bool,string,address)", p0, p1, p2, p3));
    }

    function log(string memory p0, bool p1, bool p2, uint256 p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(string,bool,bool,uint256)", p0, p1, p2, p3));
    }

    function log(string memory p0, bool p1, bool p2, string memory p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(string,bool,bool,string)", p0, p1, p2, p3));
    }

    function log(string memory p0, bool p1, bool p2, bool p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(string,bool,bool,bool)", p0, p1, p2, p3));
    }

    function log(string memory p0, bool p1, bool p2, address p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(string,bool,bool,address)", p0, p1, p2, p3));
    }

    function log(string memory p0, bool p1, address p2, uint256 p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(string,bool,address,uint256)", p0, p1, p2, p3));
    }

    function log(string memory p0, bool p1, address p2, string memory p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(string,bool,address,string)", p0, p1, p2, p3));
    }

    function log(string memory p0, bool p1, address p2, bool p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(string,bool,address,bool)", p0, p1, p2, p3));
    }

    function log(string memory p0, bool p1, address p2, address p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(string,bool,address,address)", p0, p1, p2, p3));
    }

    function log(string memory p0, address p1, uint256 p2, uint256 p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(string,address,uint256,uint256)", p0, p1, p2, p3));
    }

    function log(string memory p0, address p1, uint256 p2, string memory p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(string,address,uint256,string)", p0, p1, p2, p3));
    }

    function log(string memory p0, address p1, uint256 p2, bool p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(string,address,uint256,bool)", p0, p1, p2, p3));
    }

    function log(string memory p0, address p1, uint256 p2, address p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(string,address,uint256,address)", p0, p1, p2, p3));
    }

    function log(string memory p0, address p1, string memory p2, uint256 p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(string,address,string,uint256)", p0, p1, p2, p3));
    }

    function log(string memory p0, address p1, string memory p2, string memory p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(string,address,string,string)", p0, p1, p2, p3));
    }

    function log(string memory p0, address p1, string memory p2, bool p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(string,address,string,bool)", p0, p1, p2, p3));
    }

    function log(string memory p0, address p1, string memory p2, address p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(string,address,string,address)", p0, p1, p2, p3));
    }

    function log(string memory p0, address p1, bool p2, uint256 p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(string,address,bool,uint256)", p0, p1, p2, p3));
    }

    function log(string memory p0, address p1, bool p2, string memory p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(string,address,bool,string)", p0, p1, p2, p3));
    }

    function log(string memory p0, address p1, bool p2, bool p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(string,address,bool,bool)", p0, p1, p2, p3));
    }

    function log(string memory p0, address p1, bool p2, address p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(string,address,bool,address)", p0, p1, p2, p3));
    }

    function log(string memory p0, address p1, address p2, uint256 p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(string,address,address,uint256)", p0, p1, p2, p3));
    }

    function log(string memory p0, address p1, address p2, string memory p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(string,address,address,string)", p0, p1, p2, p3));
    }

    function log(string memory p0, address p1, address p2, bool p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(string,address,address,bool)", p0, p1, p2, p3));
    }

    function log(string memory p0, address p1, address p2, address p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(string,address,address,address)", p0, p1, p2, p3));
    }

    function log(bool p0, uint256 p1, uint256 p2, uint256 p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(bool,uint256,uint256,uint256)", p0, p1, p2, p3));
    }

    function log(bool p0, uint256 p1, uint256 p2, string memory p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(bool,uint256,uint256,string)", p0, p1, p2, p3));
    }

    function log(bool p0, uint256 p1, uint256 p2, bool p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(bool,uint256,uint256,bool)", p0, p1, p2, p3));
    }

    function log(bool p0, uint256 p1, uint256 p2, address p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(bool,uint256,uint256,address)", p0, p1, p2, p3));
    }

    function log(bool p0, uint256 p1, string memory p2, uint256 p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(bool,uint256,string,uint256)", p0, p1, p2, p3));
    }

    function log(bool p0, uint256 p1, string memory p2, string memory p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(bool,uint256,string,string)", p0, p1, p2, p3));
    }

    function log(bool p0, uint256 p1, string memory p2, bool p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(bool,uint256,string,bool)", p0, p1, p2, p3));
    }

    function log(bool p0, uint256 p1, string memory p2, address p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(bool,uint256,string,address)", p0, p1, p2, p3));
    }

    function log(bool p0, uint256 p1, bool p2, uint256 p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(bool,uint256,bool,uint256)", p0, p1, p2, p3));
    }

    function log(bool p0, uint256 p1, bool p2, string memory p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(bool,uint256,bool,string)", p0, p1, p2, p3));
    }

    function log(bool p0, uint256 p1, bool p2, bool p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(bool,uint256,bool,bool)", p0, p1, p2, p3));
    }

    function log(bool p0, uint256 p1, bool p2, address p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(bool,uint256,bool,address)", p0, p1, p2, p3));
    }

    function log(bool p0, uint256 p1, address p2, uint256 p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(bool,uint256,address,uint256)", p0, p1, p2, p3));
    }

    function log(bool p0, uint256 p1, address p2, string memory p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(bool,uint256,address,string)", p0, p1, p2, p3));
    }

    function log(bool p0, uint256 p1, address p2, bool p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(bool,uint256,address,bool)", p0, p1, p2, p3));
    }

    function log(bool p0, uint256 p1, address p2, address p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(bool,uint256,address,address)", p0, p1, p2, p3));
    }

    function log(bool p0, string memory p1, uint256 p2, uint256 p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(bool,string,uint256,uint256)", p0, p1, p2, p3));
    }

    function log(bool p0, string memory p1, uint256 p2, string memory p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(bool,string,uint256,string)", p0, p1, p2, p3));
    }

    function log(bool p0, string memory p1, uint256 p2, bool p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(bool,string,uint256,bool)", p0, p1, p2, p3));
    }

    function log(bool p0, string memory p1, uint256 p2, address p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(bool,string,uint256,address)", p0, p1, p2, p3));
    }

    function log(bool p0, string memory p1, string memory p2, uint256 p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(bool,string,string,uint256)", p0, p1, p2, p3));
    }

    function log(bool p0, string memory p1, string memory p2, string memory p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(bool,string,string,string)", p0, p1, p2, p3));
    }

    function log(bool p0, string memory p1, string memory p2, bool p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(bool,string,string,bool)", p0, p1, p2, p3));
    }

    function log(bool p0, string memory p1, string memory p2, address p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(bool,string,string,address)", p0, p1, p2, p3));
    }

    function log(bool p0, string memory p1, bool p2, uint256 p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(bool,string,bool,uint256)", p0, p1, p2, p3));
    }

    function log(bool p0, string memory p1, bool p2, string memory p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(bool,string,bool,string)", p0, p1, p2, p3));
    }

    function log(bool p0, string memory p1, bool p2, bool p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(bool,string,bool,bool)", p0, p1, p2, p3));
    }

    function log(bool p0, string memory p1, bool p2, address p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(bool,string,bool,address)", p0, p1, p2, p3));
    }

    function log(bool p0, string memory p1, address p2, uint256 p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(bool,string,address,uint256)", p0, p1, p2, p3));
    }

    function log(bool p0, string memory p1, address p2, string memory p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(bool,string,address,string)", p0, p1, p2, p3));
    }

    function log(bool p0, string memory p1, address p2, bool p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(bool,string,address,bool)", p0, p1, p2, p3));
    }

    function log(bool p0, string memory p1, address p2, address p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(bool,string,address,address)", p0, p1, p2, p3));
    }

    function log(bool p0, bool p1, uint256 p2, uint256 p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(bool,bool,uint256,uint256)", p0, p1, p2, p3));
    }

    function log(bool p0, bool p1, uint256 p2, string memory p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(bool,bool,uint256,string)", p0, p1, p2, p3));
    }

    function log(bool p0, bool p1, uint256 p2, bool p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(bool,bool,uint256,bool)", p0, p1, p2, p3));
    }

    function log(bool p0, bool p1, uint256 p2, address p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(bool,bool,uint256,address)", p0, p1, p2, p3));
    }

    function log(bool p0, bool p1, string memory p2, uint256 p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(bool,bool,string,uint256)", p0, p1, p2, p3));
    }

    function log(bool p0, bool p1, string memory p2, string memory p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(bool,bool,string,string)", p0, p1, p2, p3));
    }

    function log(bool p0, bool p1, string memory p2, bool p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(bool,bool,string,bool)", p0, p1, p2, p3));
    }

    function log(bool p0, bool p1, string memory p2, address p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(bool,bool,string,address)", p0, p1, p2, p3));
    }

    function log(bool p0, bool p1, bool p2, uint256 p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(bool,bool,bool,uint256)", p0, p1, p2, p3));
    }

    function log(bool p0, bool p1, bool p2, string memory p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(bool,bool,bool,string)", p0, p1, p2, p3));
    }

    function log(bool p0, bool p1, bool p2, bool p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(bool,bool,bool,bool)", p0, p1, p2, p3));
    }

    function log(bool p0, bool p1, bool p2, address p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(bool,bool,bool,address)", p0, p1, p2, p3));
    }

    function log(bool p0, bool p1, address p2, uint256 p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(bool,bool,address,uint256)", p0, p1, p2, p3));
    }

    function log(bool p0, bool p1, address p2, string memory p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(bool,bool,address,string)", p0, p1, p2, p3));
    }

    function log(bool p0, bool p1, address p2, bool p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(bool,bool,address,bool)", p0, p1, p2, p3));
    }

    function log(bool p0, bool p1, address p2, address p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(bool,bool,address,address)", p0, p1, p2, p3));
    }

    function log(bool p0, address p1, uint256 p2, uint256 p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(bool,address,uint256,uint256)", p0, p1, p2, p3));
    }

    function log(bool p0, address p1, uint256 p2, string memory p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(bool,address,uint256,string)", p0, p1, p2, p3));
    }

    function log(bool p0, address p1, uint256 p2, bool p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(bool,address,uint256,bool)", p0, p1, p2, p3));
    }

    function log(bool p0, address p1, uint256 p2, address p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(bool,address,uint256,address)", p0, p1, p2, p3));
    }

    function log(bool p0, address p1, string memory p2, uint256 p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(bool,address,string,uint256)", p0, p1, p2, p3));
    }

    function log(bool p0, address p1, string memory p2, string memory p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(bool,address,string,string)", p0, p1, p2, p3));
    }

    function log(bool p0, address p1, string memory p2, bool p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(bool,address,string,bool)", p0, p1, p2, p3));
    }

    function log(bool p0, address p1, string memory p2, address p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(bool,address,string,address)", p0, p1, p2, p3));
    }

    function log(bool p0, address p1, bool p2, uint256 p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(bool,address,bool,uint256)", p0, p1, p2, p3));
    }

    function log(bool p0, address p1, bool p2, string memory p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(bool,address,bool,string)", p0, p1, p2, p3));
    }

    function log(bool p0, address p1, bool p2, bool p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(bool,address,bool,bool)", p0, p1, p2, p3));
    }

    function log(bool p0, address p1, bool p2, address p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(bool,address,bool,address)", p0, p1, p2, p3));
    }

    function log(bool p0, address p1, address p2, uint256 p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(bool,address,address,uint256)", p0, p1, p2, p3));
    }

    function log(bool p0, address p1, address p2, string memory p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(bool,address,address,string)", p0, p1, p2, p3));
    }

    function log(bool p0, address p1, address p2, bool p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(bool,address,address,bool)", p0, p1, p2, p3));
    }

    function log(bool p0, address p1, address p2, address p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(bool,address,address,address)", p0, p1, p2, p3));
    }

    function log(address p0, uint256 p1, uint256 p2, uint256 p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(address,uint256,uint256,uint256)", p0, p1, p2, p3));
    }

    function log(address p0, uint256 p1, uint256 p2, string memory p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(address,uint256,uint256,string)", p0, p1, p2, p3));
    }

    function log(address p0, uint256 p1, uint256 p2, bool p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(address,uint256,uint256,bool)", p0, p1, p2, p3));
    }

    function log(address p0, uint256 p1, uint256 p2, address p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(address,uint256,uint256,address)", p0, p1, p2, p3));
    }

    function log(address p0, uint256 p1, string memory p2, uint256 p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(address,uint256,string,uint256)", p0, p1, p2, p3));
    }

    function log(address p0, uint256 p1, string memory p2, string memory p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(address,uint256,string,string)", p0, p1, p2, p3));
    }

    function log(address p0, uint256 p1, string memory p2, bool p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(address,uint256,string,bool)", p0, p1, p2, p3));
    }

    function log(address p0, uint256 p1, string memory p2, address p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(address,uint256,string,address)", p0, p1, p2, p3));
    }

    function log(address p0, uint256 p1, bool p2, uint256 p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(address,uint256,bool,uint256)", p0, p1, p2, p3));
    }

    function log(address p0, uint256 p1, bool p2, string memory p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(address,uint256,bool,string)", p0, p1, p2, p3));
    }

    function log(address p0, uint256 p1, bool p2, bool p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(address,uint256,bool,bool)", p0, p1, p2, p3));
    }

    function log(address p0, uint256 p1, bool p2, address p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(address,uint256,bool,address)", p0, p1, p2, p3));
    }

    function log(address p0, uint256 p1, address p2, uint256 p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(address,uint256,address,uint256)", p0, p1, p2, p3));
    }

    function log(address p0, uint256 p1, address p2, string memory p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(address,uint256,address,string)", p0, p1, p2, p3));
    }

    function log(address p0, uint256 p1, address p2, bool p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(address,uint256,address,bool)", p0, p1, p2, p3));
    }

    function log(address p0, uint256 p1, address p2, address p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(address,uint256,address,address)", p0, p1, p2, p3));
    }

    function log(address p0, string memory p1, uint256 p2, uint256 p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(address,string,uint256,uint256)", p0, p1, p2, p3));
    }

    function log(address p0, string memory p1, uint256 p2, string memory p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(address,string,uint256,string)", p0, p1, p2, p3));
    }

    function log(address p0, string memory p1, uint256 p2, bool p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(address,string,uint256,bool)", p0, p1, p2, p3));
    }

    function log(address p0, string memory p1, uint256 p2, address p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(address,string,uint256,address)", p0, p1, p2, p3));
    }

    function log(address p0, string memory p1, string memory p2, uint256 p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(address,string,string,uint256)", p0, p1, p2, p3));
    }

    function log(address p0, string memory p1, string memory p2, string memory p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(address,string,string,string)", p0, p1, p2, p3));
    }

    function log(address p0, string memory p1, string memory p2, bool p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(address,string,string,bool)", p0, p1, p2, p3));
    }

    function log(address p0, string memory p1, string memory p2, address p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(address,string,string,address)", p0, p1, p2, p3));
    }

    function log(address p0, string memory p1, bool p2, uint256 p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(address,string,bool,uint256)", p0, p1, p2, p3));
    }

    function log(address p0, string memory p1, bool p2, string memory p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(address,string,bool,string)", p0, p1, p2, p3));
    }

    function log(address p0, string memory p1, bool p2, bool p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(address,string,bool,bool)", p0, p1, p2, p3));
    }

    function log(address p0, string memory p1, bool p2, address p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(address,string,bool,address)", p0, p1, p2, p3));
    }

    function log(address p0, string memory p1, address p2, uint256 p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(address,string,address,uint256)", p0, p1, p2, p3));
    }

    function log(address p0, string memory p1, address p2, string memory p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(address,string,address,string)", p0, p1, p2, p3));
    }

    function log(address p0, string memory p1, address p2, bool p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(address,string,address,bool)", p0, p1, p2, p3));
    }

    function log(address p0, string memory p1, address p2, address p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(address,string,address,address)", p0, p1, p2, p3));
    }

    function log(address p0, bool p1, uint256 p2, uint256 p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(address,bool,uint256,uint256)", p0, p1, p2, p3));
    }

    function log(address p0, bool p1, uint256 p2, string memory p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(address,bool,uint256,string)", p0, p1, p2, p3));
    }

    function log(address p0, bool p1, uint256 p2, bool p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(address,bool,uint256,bool)", p0, p1, p2, p3));
    }

    function log(address p0, bool p1, uint256 p2, address p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(address,bool,uint256,address)", p0, p1, p2, p3));
    }

    function log(address p0, bool p1, string memory p2, uint256 p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(address,bool,string,uint256)", p0, p1, p2, p3));
    }

    function log(address p0, bool p1, string memory p2, string memory p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(address,bool,string,string)", p0, p1, p2, p3));
    }

    function log(address p0, bool p1, string memory p2, bool p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(address,bool,string,bool)", p0, p1, p2, p3));
    }

    function log(address p0, bool p1, string memory p2, address p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(address,bool,string,address)", p0, p1, p2, p3));
    }

    function log(address p0, bool p1, bool p2, uint256 p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(address,bool,bool,uint256)", p0, p1, p2, p3));
    }

    function log(address p0, bool p1, bool p2, string memory p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(address,bool,bool,string)", p0, p1, p2, p3));
    }

    function log(address p0, bool p1, bool p2, bool p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(address,bool,bool,bool)", p0, p1, p2, p3));
    }

    function log(address p0, bool p1, bool p2, address p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(address,bool,bool,address)", p0, p1, p2, p3));
    }

    function log(address p0, bool p1, address p2, uint256 p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(address,bool,address,uint256)", p0, p1, p2, p3));
    }

    function log(address p0, bool p1, address p2, string memory p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(address,bool,address,string)", p0, p1, p2, p3));
    }

    function log(address p0, bool p1, address p2, bool p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(address,bool,address,bool)", p0, p1, p2, p3));
    }

    function log(address p0, bool p1, address p2, address p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(address,bool,address,address)", p0, p1, p2, p3));
    }

    function log(address p0, address p1, uint256 p2, uint256 p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(address,address,uint256,uint256)", p0, p1, p2, p3));
    }

    function log(address p0, address p1, uint256 p2, string memory p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(address,address,uint256,string)", p0, p1, p2, p3));
    }

    function log(address p0, address p1, uint256 p2, bool p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(address,address,uint256,bool)", p0, p1, p2, p3));
    }

    function log(address p0, address p1, uint256 p2, address p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(address,address,uint256,address)", p0, p1, p2, p3));
    }

    function log(address p0, address p1, string memory p2, uint256 p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(address,address,string,uint256)", p0, p1, p2, p3));
    }

    function log(address p0, address p1, string memory p2, string memory p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(address,address,string,string)", p0, p1, p2, p3));
    }

    function log(address p0, address p1, string memory p2, bool p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(address,address,string,bool)", p0, p1, p2, p3));
    }

    function log(address p0, address p1, string memory p2, address p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(address,address,string,address)", p0, p1, p2, p3));
    }

    function log(address p0, address p1, bool p2, uint256 p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(address,address,bool,uint256)", p0, p1, p2, p3));
    }

    function log(address p0, address p1, bool p2, string memory p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(address,address,bool,string)", p0, p1, p2, p3));
    }

    function log(address p0, address p1, bool p2, bool p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(address,address,bool,bool)", p0, p1, p2, p3));
    }

    function log(address p0, address p1, bool p2, address p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(address,address,bool,address)", p0, p1, p2, p3));
    }

    function log(address p0, address p1, address p2, uint256 p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(address,address,address,uint256)", p0, p1, p2, p3));
    }

    function log(address p0, address p1, address p2, string memory p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(address,address,address,string)", p0, p1, p2, p3));
    }

    function log(address p0, address p1, address p2, bool p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(address,address,address,bool)", p0, p1, p2, p3));
    }

    function log(address p0, address p1, address p2, address p3) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(address,address,address,address)", p0, p1, p2, p3));
    }
}

// lib/openzeppelin-contracts/contracts/interfaces/draft-IERC1822.sol

// OpenZeppelin Contracts (last updated v5.4.0) (interfaces/draft-IERC1822.sol)

/**
 * @dev ERC-1822: Universal Upgradeable Proxy Standard (UUPS) documents a method for upgradeability through a simplified
 * proxy whose upgrades are fully controlled by the current implementation.
 */
interface IERC1822Proxiable {
    /**
     * @dev Returns the storage slot that the proxiable contract assumes is being used to store the implementation
     * address.
     *
     * IMPORTANT: A proxy pointing at a proxiable contract should not be considered proxiable itself, because this risks
     * bricking a proxy that upgrades to it, by delegating to itself until out of gas. Thus it is critical that this
     * function revert if invoked through a proxy.
     */
    function proxiableUUID() external view returns (bytes32);
}

// lib/openzeppelin-contracts/contracts/interfaces/draft-IERC6093.sol

// OpenZeppelin Contracts (last updated v5.4.0) (interfaces/draft-IERC6093.sol)

/**
 * @dev Standard ERC-20 Errors
 * Interface of the https://eips.ethereum.org/EIPS/eip-6093[ERC-6093] custom errors for ERC-20 tokens.
 */
interface IERC20Errors {
    /**
     * @dev Indicates an error related to the current `balance` of a `sender`. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     * @param balance Current balance for the interacting account.
     * @param needed Minimum amount required to perform a transfer.
     */
    error ERC20InsufficientBalance(address sender, uint256 balance, uint256 needed);

    /**
     * @dev Indicates a failure with the token `sender`. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     */
    error ERC20InvalidSender(address sender);

    /**
     * @dev Indicates a failure with the token `receiver`. Used in transfers.
     * @param receiver Address to which tokens are being transferred.
     */
    error ERC20InvalidReceiver(address receiver);

    /**
     * @dev Indicates a failure with the `spender`’s `allowance`. Used in transfers.
     * @param spender Address that may be allowed to operate on tokens without being their owner.
     * @param allowance Amount of tokens a `spender` is allowed to operate with.
     * @param needed Minimum amount required to perform a transfer.
     */
    error ERC20InsufficientAllowance(address spender, uint256 allowance, uint256 needed);

    /**
     * @dev Indicates a failure with the `approver` of a token to be approved. Used in approvals.
     * @param approver Address initiating an approval operation.
     */
    error ERC20InvalidApprover(address approver);

    /**
     * @dev Indicates a failure with the `spender` to be approved. Used in approvals.
     * @param spender Address that may be allowed to operate on tokens without being their owner.
     */
    error ERC20InvalidSpender(address spender);
}

/**
 * @dev Standard ERC-721 Errors
 * Interface of the https://eips.ethereum.org/EIPS/eip-6093[ERC-6093] custom errors for ERC-721 tokens.
 */
interface IERC721Errors {
    /**
     * @dev Indicates that an address can't be an owner. For example, `address(0)` is a forbidden owner in ERC-20.
     * Used in balance queries.
     * @param owner Address of the current owner of a token.
     */
    error ERC721InvalidOwner(address owner);

    /**
     * @dev Indicates a `tokenId` whose `owner` is the zero address.
     * @param tokenId Identifier number of a token.
     */
    error ERC721NonexistentToken(uint256 tokenId);

    /**
     * @dev Indicates an error related to the ownership over a particular token. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     * @param tokenId Identifier number of a token.
     * @param owner Address of the current owner of a token.
     */
    error ERC721IncorrectOwner(address sender, uint256 tokenId, address owner);

    /**
     * @dev Indicates a failure with the token `sender`. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     */
    error ERC721InvalidSender(address sender);

    /**
     * @dev Indicates a failure with the token `receiver`. Used in transfers.
     * @param receiver Address to which tokens are being transferred.
     */
    error ERC721InvalidReceiver(address receiver);

    /**
     * @dev Indicates a failure with the `operator`’s approval. Used in transfers.
     * @param operator Address that may be allowed to operate on tokens without being their owner.
     * @param tokenId Identifier number of a token.
     */
    error ERC721InsufficientApproval(address operator, uint256 tokenId);

    /**
     * @dev Indicates a failure with the `approver` of a token to be approved. Used in approvals.
     * @param approver Address initiating an approval operation.
     */
    error ERC721InvalidApprover(address approver);

    /**
     * @dev Indicates a failure with the `operator` to be approved. Used in approvals.
     * @param operator Address that may be allowed to operate on tokens without being their owner.
     */
    error ERC721InvalidOperator(address operator);
}

/**
 * @dev Standard ERC-1155 Errors
 * Interface of the https://eips.ethereum.org/EIPS/eip-6093[ERC-6093] custom errors for ERC-1155 tokens.
 */
interface IERC1155Errors {
    /**
     * @dev Indicates an error related to the current `balance` of a `sender`. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     * @param balance Current balance for the interacting account.
     * @param needed Minimum amount required to perform a transfer.
     * @param tokenId Identifier number of a token.
     */
    error ERC1155InsufficientBalance(address sender, uint256 balance, uint256 needed, uint256 tokenId);

    /**
     * @dev Indicates a failure with the token `sender`. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     */
    error ERC1155InvalidSender(address sender);

    /**
     * @dev Indicates a failure with the token `receiver`. Used in transfers.
     * @param receiver Address to which tokens are being transferred.
     */
    error ERC1155InvalidReceiver(address receiver);

    /**
     * @dev Indicates a failure with the `operator`’s approval. Used in transfers.
     * @param operator Address that may be allowed to operate on tokens without being their owner.
     * @param owner Address of the current owner of a token.
     */
    error ERC1155MissingApprovalForAll(address operator, address owner);

    /**
     * @dev Indicates a failure with the `approver` of a token to be approved. Used in approvals.
     * @param approver Address initiating an approval operation.
     */
    error ERC1155InvalidApprover(address approver);

    /**
     * @dev Indicates a failure with the `operator` to be approved. Used in approvals.
     * @param operator Address that may be allowed to operate on tokens without being their owner.
     */
    error ERC1155InvalidOperator(address operator);

    /**
     * @dev Indicates an array length mismatch between ids and values in a safeBatchTransferFrom operation.
     * Used in batch transfers.
     * @param idsLength Length of the array of token identifiers
     * @param valuesLength Length of the array of token amounts
     */
    error ERC1155InvalidArrayLength(uint256 idsLength, uint256 valuesLength);
}

// lib/openzeppelin-contracts/contracts/utils/Address.sol

// OpenZeppelin Contracts (last updated v5.4.0) (utils/Address.sol)

/**
 * @dev Collection of functions related to the address type
 */
library Address {
    /**
     * @dev There's no code at `target` (it is not a contract).
     */
    error AddressEmptyCode(address target);

    /**
     * @dev Replacement for Solidity's `transfer`: sends `amount` wei to
     * `recipient`, forwarding all available gas and reverting on errors.
     *
     * https://eips.ethereum.org/EIPS/eip-1884[EIP1884] increases the gas cost
     * of certain opcodes, possibly making contracts go over the 2300 gas limit
     * imposed by `transfer`, making them unable to receive funds via
     * `transfer`. {sendValue} removes this limitation.
     *
     * https://consensys.net/diligence/blog/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.8.20/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        if (address(this).balance < amount) {
            revert Errors.InsufficientBalance(address(this).balance, amount);
        }

        (bool success, bytes memory returndata) = recipient.call{value: amount}("");
        if (!success) {
            _revert(returndata);
        }
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain `call` is an unsafe replacement for a function call: use this
     * function instead.
     *
     * If `target` reverts with a revert reason or custom error, it is bubbled
     * up by this function (like regular Solidity function calls). However, if
     * the call reverted with no returned reason, this function reverts with a
     * {Errors.FailedCall} error.
     *
     * Returns the raw returned data. To convert to the expected return value,
     * use https://solidity.readthedocs.io/en/latest/units-and-global-variables.html?highlight=abi.decode#abi-encoding-and-decoding-functions[`abi.decode`].
     *
     * Requirements:
     *
     * - `target` must be a contract.
     * - calling `target` with `data` must not revert.
     */
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but also transferring `value` wei to `target`.
     *
     * Requirements:
     *
     * - the calling contract must have an ETH balance of at least `value`.
     * - the called Solidity function must be `payable`.
     */
    function functionCallWithValue(address target, bytes memory data, uint256 value) internal returns (bytes memory) {
        if (address(this).balance < value) {
            revert Errors.InsufficientBalance(address(this).balance, value);
        }
        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResultFromTarget(target, success, returndata);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a static call.
     */
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResultFromTarget(target, success, returndata);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a delegate call.
     */
    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResultFromTarget(target, success, returndata);
    }

    /**
     * @dev Tool to verify that a low level call to smart-contract was successful, and reverts if the target
     * was not a contract or bubbling up the revert reason (falling back to {Errors.FailedCall}) in case
     * of an unsuccessful call.
     */
    function verifyCallResultFromTarget(
        address target,
        bool success,
        bytes memory returndata
    ) internal view returns (bytes memory) {
        if (!success) {
            _revert(returndata);
        } else {
            // only check if target is a contract if the call was successful and the return data is empty
            // otherwise we already know that it was a contract
            if (returndata.length == 0 && target.code.length == 0) {
                revert AddressEmptyCode(target);
            }
            return returndata;
        }
    }

    /**
     * @dev Tool to verify that a low level call was successful, and reverts if it wasn't, either by bubbling the
     * revert reason or with a default {Errors.FailedCall} error.
     */
    function verifyCallResult(bool success, bytes memory returndata) internal pure returns (bytes memory) {
        if (!success) {
            _revert(returndata);
        } else {
            return returndata;
        }
    }

    /**
     * @dev Reverts with returndata if present. Otherwise reverts with {Errors.FailedCall}.
     */
    function _revert(bytes memory returndata) private pure {
        // Look for revert reason and bubble it up if present
        if (returndata.length > 0) {
            // The easiest way to bubble the revert reason is using memory via assembly
            assembly ("memory-safe") {
                revert(add(returndata, 0x20), mload(returndata))
            }
        } else {
            revert Errors.FailedCall();
        }
    }
}

// lib/openzeppelin-contracts-upgradeable/contracts/utils/ContextUpgradeable.sol

// OpenZeppelin Contracts (last updated v5.0.1) (utils/Context.sol)

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract ContextUpgradeable is Initializable {
    function __Context_init() internal onlyInitializing {
    }

    function __Context_init_unchained() internal onlyInitializing {
    }
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }

    function _contextSuffixLength() internal view virtual returns (uint256) {
        return 0;
    }
}

// lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol

// OpenZeppelin Contracts (last updated v5.4.0) (token/ERC20/extensions/IERC20Metadata.sol)

/**
 * @dev Interface for the optional metadata functions from the ERC-20 standard.
 */
interface IERC20Metadata is IERC20 {
    /**
     * @dev Returns the name of the token.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the symbol of the token.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the decimals places of the token.
     */
    function decimals() external view returns (uint8);
}

// lib/openzeppelin-contracts-upgradeable/contracts/utils/ReentrancyGuardUpgradeable.sol

// OpenZeppelin Contracts (last updated v5.1.0) (utils/ReentrancyGuard.sol)

/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 *
 * Inheriting from `ReentrancyGuard` will make the {nonReentrant} modifier
 * available, which can be applied to functions to make sure there are no nested
 * (reentrant) calls to them.
 *
 * Note that because there is a single `nonReentrant` guard, functions marked as
 * `nonReentrant` may not call one another. This can be worked around by making
 * those functions `private`, and then adding `external` `nonReentrant` entry
 * points to them.
 *
 * TIP: If EIP-1153 (transient storage) is available on the chain you're deploying at,
 * consider using {ReentrancyGuardTransient} instead.
 *
 * TIP: If you would like to learn more about reentrancy and alternative ways
 * to protect against it, check out our blog post
 * https://blog.openzeppelin.com/reentrancy-after-istanbul/[Reentrancy After Istanbul].
 */
abstract contract ReentrancyGuardUpgradeable is Initializable {
    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;

    /// @custom:storage-location erc7201:openzeppelin.storage.ReentrancyGuard
    struct ReentrancyGuardStorage {
        uint256 _status;
    }

    // keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.ReentrancyGuard")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant ReentrancyGuardStorageLocation = 0x9b779b17422d0df92223018b32b4d1fa46e071723d6817e2486d003becc55f00;

    function _getReentrancyGuardStorage() private pure returns (ReentrancyGuardStorage storage $) {
        assembly {
            $.slot := ReentrancyGuardStorageLocation
        }
    }

    /**
     * @dev Unauthorized reentrant call.
     */
    error ReentrancyGuardReentrantCall();

    function __ReentrancyGuard_init() internal onlyInitializing {
        __ReentrancyGuard_init_unchained();
    }

    function __ReentrancyGuard_init_unchained() internal onlyInitializing {
        ReentrancyGuardStorage storage $ = _getReentrancyGuardStorage();
        $._status = NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and making it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        _nonReentrantBefore();
        _;
        _nonReentrantAfter();
    }

    function _nonReentrantBefore() private {
        ReentrancyGuardStorage storage $ = _getReentrancyGuardStorage();
        // On the first call to nonReentrant, _status will be NOT_ENTERED
        if ($._status == ENTERED) {
            revert ReentrancyGuardReentrantCall();
        }

        // Any calls to nonReentrant after this point will fail
        $._status = ENTERED;
    }

    function _nonReentrantAfter() private {
        ReentrancyGuardStorage storage $ = _getReentrancyGuardStorage();
        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        $._status = NOT_ENTERED;
    }

    /**
     * @dev Returns true if the reentrancy guard is currently set to "entered", which indicates there is a
     * `nonReentrant` function in the call stack.
     */
    function _reentrancyGuardEntered() internal view returns (bool) {
        ReentrancyGuardStorage storage $ = _getReentrancyGuardStorage();
        return $._status == ENTERED;
    }
}

// src/libraries/TransferRestrictions.sol

/**
 * @title TransferRestrictions
 * @notice Library for transfer restriction validation logic
 * @dev Pure and view functions to reduce contract bytecode size and maintain 24KB limit.
 * Provides modular validation for lockup periods, concentration limits, minimum holding
 * periods, whitelist/blacklist, and emergency pause controls.
 *
 * Design Pattern:
 * - Pure functions for gas optimization and testability
 * - Aggregate validation function returns (bool, string) for detailed error messages
 * - Integration with _update hook for autonomous enforcement
 * - No state modifications (validation only)
 *
 * Usage:
 * - Called from YieldSharesToken._update() and CombinedPropertyYieldToken._beforeTokenTransfer()
 * - Validates restrictions before allowing transfer to proceed
 * - Returns reason string for frontend display and error messages
 */
library TransferRestrictions {
    using TransferRestrictionsStorage for TransferRestrictionsStorage.TransferRestrictionData;

    /**
     * @notice Validate lockup period has expired
     * @param lockupEndTimestamp Timestamp when lockup ends (0 = no lockup)
     * @return allowed True if lockup expired or not set
     */
    function validateLockupPeriod(uint256 lockupEndTimestamp) internal view returns (bool allowed) {
        if (lockupEndTimestamp == 0) {
            return true; // No lockup set
        }
        return block.timestamp >= lockupEndTimestamp;
    }

    /**
     * @notice Validate concentration limit not exceeded
     * @param recipientBalance Current balance of recipient
     * @param transferAmount Amount being transferred
     * @param totalSupply Total token supply
     * @param maxSharesPerInvestor Maximum shares per investor in basis points (e.g., 2000 = 20%)
     * @return allowed True if concentration limit not exceeded
     */
    function validateConcentrationLimit(
        uint256 recipientBalance,
        uint256 transferAmount,
        uint256 totalSupply,
        uint256 maxSharesPerInvestor
    ) internal pure returns (bool allowed) {
        if (maxSharesPerInvestor == 0 || totalSupply == 0) {
            return true; // No concentration limit set or supply is zero
        }
        
        // Calculate new balance percentage in basis points (10000 = 100%)
        uint256 newBalance = recipientBalance + transferAmount;
        uint256 newBalancePercentage = (newBalance * 10000) / totalSupply;
        
        return newBalancePercentage <= maxSharesPerInvestor;
    }

    /**
     * @notice Validate minimum holding period has elapsed
     * @param lastTransferTimestamp Timestamp of last transfer for sender
     * @param minHoldingPeriod Minimum holding period in seconds (0 = no requirement)
     * @return allowed True if holding period met or not set
     */
    function validateHoldingPeriod(
        uint256 lastTransferTimestamp,
        uint256 minHoldingPeriod
    ) internal view returns (bool allowed) {
        if (minHoldingPeriod == 0 || lastTransferTimestamp == 0) {
            return true; // No holding period set or first transfer
        }
        return block.timestamp >= lastTransferTimestamp + minHoldingPeriod;
    }

    /**
     * @notice Validate address is whitelisted (if whitelist enabled)
     * @param account Address to check
     * @param whitelist Mapping of whitelisted addresses
     * @param whitelistEnabled Whether whitelist is active
     * @return allowed True if address whitelisted or whitelist disabled
     */
    function validateWhitelist(
        address account,
        mapping(address => bool) storage whitelist,
        bool whitelistEnabled
    ) internal view returns (bool allowed) {
        if (!whitelistEnabled) {
            return true; // Whitelist disabled
        }
        return whitelist[account];
    }

    /**
     * @notice Validate address is not blacklisted (if blacklist enabled)
     * @param account Address to check
     * @param blacklist Mapping of blacklisted addresses
     * @param blacklistEnabled Whether blacklist is active
     * @return allowed True if address not blacklisted or blacklist disabled
     */
    function validateBlacklist(
        address account,
        mapping(address => bool) storage blacklist,
        bool blacklistEnabled
    ) internal view returns (bool allowed) {
        if (!blacklistEnabled) {
            return true; // Blacklist disabled
        }
        return !blacklist[account]; // Allow if NOT blacklisted
    }

    /**
     * @notice Validate transfers are not paused
     * @param isTransferPaused Pause flag from storage
     * @return allowed True if transfers not paused
     */
    function validateTransferNotPaused(bool isTransferPaused) internal pure returns (bool allowed) {
        return !isTransferPaused;
    }

    /**
     * @notice Aggregate validation of all transfer restrictions
     * @param from Sender address
     * @param to Recipient address
     * @param amount Transfer amount
     * @param recipientBalance Current balance of recipient
     * @param totalSupply Total token supply
     * @param restrictions Storage pointer to restriction data
     * @return allowed True if all restrictions pass
     * @return reason Human-readable reason for restriction violation (empty if allowed)
     */
    function validateAllRestrictions(
        address from,
        address to,
        uint256 amount,
        uint256 recipientBalance,
        uint256 totalSupply,
        TransferRestrictionsStorage.TransferRestrictionData storage restrictions
    ) internal view returns (bool allowed, string memory reason) {
        // Check 1: Transfer not paused
        if (!validateTransferNotPaused(restrictions.isTransferPaused)) {
            return (false, "Transfers paused by owner or governance");
        }

        // Check 2: Lockup period expired
        if (!validateLockupPeriod(restrictions.lockupEndTimestamp)) {
            return (false, string(abi.encodePacked(
                "Lockup period active until timestamp ",
                _uint2str(restrictions.lockupEndTimestamp)
            )));
        }

        // Check 3: Sender holding period met
        if (!validateHoldingPeriod(restrictions.lastTransferTimestamp[from], restrictions.minHoldingPeriod)) {
            uint256 requiredTime = restrictions.lastTransferTimestamp[from] + restrictions.minHoldingPeriod;
            return (false, string(abi.encodePacked(
                "Minimum holding period not met. Can transfer after timestamp ",
                _uint2str(requiredTime)
            )));
        }

        // Check 4: Recipient concentration limit
        if (!validateConcentrationLimit(recipientBalance, amount, totalSupply, restrictions.maxSharesPerInvestor)) {
            return (false, string(abi.encodePacked(
                "Concentration limit exceeded. Max allowed: ",
                _uint2str(restrictions.maxSharesPerInvestor / 100),
                "%"
            )));
        }

        // Check 5: Recipient whitelist (if enabled)
        if (!validateWhitelist(to, restrictions.whitelistedAddresses, restrictions.whitelistEnabled)) {
            return (false, "Recipient not whitelisted");
        }

        // Check 6: Recipient not blacklisted (if enabled)
        if (!validateBlacklist(to, restrictions.blacklistedAddresses, restrictions.blacklistEnabled)) {
            return (false, "Recipient is blacklisted");
        }

        // Check 7: Sender not blacklisted (if enabled)
        if (!validateBlacklist(from, restrictions.blacklistedAddresses, restrictions.blacklistEnabled)) {
            return (false, "Sender is blacklisted");
        }

        // All checks passed
        return (true, "");
    }

    /**
     * @notice Convert uint256 to string (helper for error messages)
     * @param _i Number to convert
     * @return _uintAsString String representation
     */
    function _uint2str(uint256 _i) internal pure returns (string memory _uintAsString) {
        if (_i == 0) {
            return "0";
        }
        uint256 j = _i;
        uint256 len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint256 k = len;
        while (_i != 0) {
            k = k - 1;
            uint8 temp = (48 + uint8(_i - _i / 10 * 10));
            bytes1 b1 = bytes1(temp);
            bstr[k] = b1;
            _i /= 10;
        }
        return string(bstr);
    }
}

// src/libraries/YieldCalculations.sol

/// @title Yield Calculations Library
/// @notice Pure mathematical functions for yield tokenization calculations
/// @dev Library functions are deployed once and linked at deployment time, reducing main contract bytecode size
/// All functions are pure (no state modifications) for gas efficiency and testability
library YieldCalculations {
    /// @notice Calculates the monthly repayment amount for a yield agreement
    /// @dev Uses compound interest formula: PMT = P * (r(1+r)^n) / ((1+r)^n - 1)
    /// Where: PMT = monthly payment, P = principal, r = monthly rate, n = number of payments
    /// @param upfrontCapital The initial capital amount (principal)
    /// @param termMonths The repayment term in months
    /// @param annualROIBasisPoints The annual ROI in basis points (e.g., 500 = 5%)
    /// @return The monthly repayment amount
    function calculateMonthlyRepayment(
        uint256 upfrontCapital,
        uint16 termMonths,
        uint16 annualROIBasisPoints
    ) internal pure returns (uint256) {
        // Simple calculation: principal / term + simple interest
        // This avoids complex compound interest calculations that can overflow
        uint256 principalPayment = upfrontCapital / termMonths;
        uint256 annualInterest = (upfrontCapital * annualROIBasisPoints) / 10000;
        uint256 monthlyInterest = annualInterest / 12;
        return principalPayment + monthlyInterest;
    }

    /// @notice Calculates the total repayment amount over the full term
    /// @param upfrontCapital The initial capital amount
    /// @param termMonths The repayment term in months
    /// @param annualROIBasisPoints The annual ROI in basis points
    /// @return The total amount to be repaid (principal + interest)
    function calculateTotalRepaymentAmount(
        uint256 upfrontCapital,
        uint16 termMonths,
        uint16 annualROIBasisPoints
    ) internal pure returns (uint256) {
        uint256 monthlyPayment = calculateMonthlyRepayment(upfrontCapital, termMonths, annualROIBasisPoints);
        return monthlyPayment * termMonths;
    }

    /// @notice Calculates pro-rata distribution for pooled investor repayments
    /// @dev Ensures proportional distribution when multiple investors contribute to the upfront capital
    /// @param totalAmount The total amount to distribute
    /// @param investorShares The investor's share of the total pool
    /// @param totalShares The total shares in the pool
    /// @return The amount allocated to this investor
    function calculateProRataDistribution(
        uint256 totalAmount,
        uint256 investorShares,
        uint256 totalShares
    ) internal pure returns (uint256) {
        require(totalShares > 0, "Total shares cannot be zero");
        return (totalAmount * investorShares) / totalShares;
    }

    /// @notice Checks if a repayment is overdue based on the last repayment timestamp
    /// @param lastRepaymentTimestamp The timestamp of the last repayment
    /// @param termMonths The total term in months (parameter kept for future extensibility)
    /// @return True if the last repayment was more than 30 days ago
    function isRepaymentOverdue(
        uint256 lastRepaymentTimestamp,
        uint16 termMonths
    ) internal view returns (bool) {
        // Use constant 30-day monthly interval for repayment checks
        uint256 monthlyInterval = 30 days;
        return block.timestamp > lastRepaymentTimestamp + monthlyInterval;
    }

    /// @dev Helper function to calculate (1 + r)^n with high precision
    /// @param monthlyRate The monthly interest rate (18 decimal places)
    /// @param termMonths The number of months
    /// @return The compound factor (1+r)^n (18 decimal places)
    function _calculateCompoundFactor(
        uint256 monthlyRate,
        uint16 termMonths
    ) private pure returns (uint256) {
        uint256 result = 1e18; // Start with 1.0 (18 decimal places)

        for (uint16 i = 0; i < termMonths; i++) {
            // result = result * (1 + monthlyRate)
            result = (result * (1e18 + monthlyRate)) / 1e18;
        }

        return result;
    }

    /// @notice Calculates cumulative penalty for missed payments
    /// @dev Uses penalty rate and missed payment count to calculate total penalty amount
    /// @param monthlyPayment The standard monthly payment amount
    /// @param penaltyRateBasisPoints The penalty rate in basis points (e.g., 200 = 2%)
    /// @param missedPaymentCount The number of consecutive missed payments
    /// @return The cumulative penalty amount
    function calculateDefaultPenalty(
        uint256 monthlyPayment,
        uint16 penaltyRateBasisPoints,
        uint8 missedPaymentCount
    ) internal pure returns (uint256) {
        if (missedPaymentCount == 0) return 0;

        uint256 penaltyPerMonth = (monthlyPayment * penaltyRateBasisPoints) / 10000;
        return penaltyPerMonth * missedPaymentCount;
    }

    /// @notice Calculates rebate for early lump-sum repayment
    /// @dev Provides incentive for prepayment by waiving portion of remaining interest
    /// @param remainingPrincipal The outstanding principal amount
    /// @param remainingInterest The remaining interest to be paid
    /// @param rebatePercentage The rebate percentage in basis points (e.g., 1000 = 10%)
    /// @return The rebate amount to deduct from remaining balance
    function calculateEarlyRepaymentRebate(
        uint256 remainingPrincipal,
        uint256 remainingInterest,
        uint16 rebatePercentage
    ) internal pure returns (uint256) {
        uint256 totalRemaining = remainingPrincipal + remainingInterest;
        return (totalRemaining * rebatePercentage) / 10000;
    }

    /// @notice Allocates partial payment between arrears and current obligation
    /// @dev Priority allocation: arrears first, then current payment
    /// @param paymentAmount The total payment amount received
    /// @param accumulatedArrears The current arrears balance
    /// @param currentMonthlyPayment The standard monthly payment amount
    /// @return arrearsPayment Amount allocated to arrears
    /// @return currentPayment Amount allocated to current payment
    function calculatePartialRepaymentAllocation(
        uint256 paymentAmount,
        uint256 accumulatedArrears,
        uint256 currentMonthlyPayment
    ) internal pure returns (uint256 arrearsPayment, uint256 currentPayment) {
        // First allocate to arrears
        arrearsPayment = paymentAmount >= accumulatedArrears ? accumulatedArrears : paymentAmount;

        // Remaining amount goes to current payment
        uint256 remainingAmount = paymentAmount - arrearsPayment;
        currentPayment = remainingAmount >= currentMonthlyPayment ? currentMonthlyPayment : remainingAmount;
    }

    /// @notice Determines if agreement is in default based on grace period and threshold
    /// @dev Uses predictable grace period calculation starting from threshold reach time
    /// @param lastRepaymentTimestamp Timestamp of last successful repayment
    /// @param lastMissedPaymentTimestamp Timestamp when last missed payment was recorded
    /// @param gracePeriodDays Grace period in days before penalties apply
    /// @param missedPaymentCount Current consecutive missed payment count
    /// @param defaultThreshold Number of missed payments that trigger default
    /// @return True if agreement is in default
    function isAgreementInDefault(
        uint256 lastRepaymentTimestamp,
        uint256 lastMissedPaymentTimestamp,
        uint16 gracePeriodDays,
        uint8 missedPaymentCount,
        uint8 defaultThreshold
    ) internal view returns (bool) {
        // Check if missed payment threshold reached
        if (missedPaymentCount < defaultThreshold) return false;

        // Use a more predictable grace period calculation
        // Start grace period from when threshold was reached, not from last missed payment
        uint256 thresholdReachedTime = lastMissedPaymentTimestamp - ((missedPaymentCount - defaultThreshold) * 30 days);
        uint256 gracePeriodExpiry = thresholdReachedTime + (gracePeriodDays * 1 days);

        return block.timestamp > gracePeriodExpiry;
    }

    /// @notice Calculates remaining balance including principal and interest
    /// @dev Simple calculation: total expected - repaid (for dissertation simplicity)
    /// @param upfrontCapital The original capital amount
    /// @param totalRepaid The cumulative amount repaid so far
    /// @param termMonths The total term in months
    /// @param annualROIBasisPoints The annual ROI in basis points
    /// @param elapsedMonths The number of months elapsed since agreement start
    /// @return The remaining balance (principal + interest)
    function calculateRemainingBalance(
        uint256 upfrontCapital,
        uint256 totalRepaid,
        uint16 termMonths,
        uint16 annualROIBasisPoints,
        uint256 elapsedMonths
    ) internal pure returns (uint256) {
        uint256 totalExpected = calculateTotalRepaymentAmount(upfrontCapital, termMonths, annualROIBasisPoints);
        return totalExpected > totalRepaid ? totalExpected - totalRepaid : 0;
    }

    /// @notice Calculates months elapsed since agreement start
    /// @dev Approximates months using 30-day periods for simplicity
    /// @param startTimestamp The agreement start timestamp
    /// @param currentTimestamp The current timestamp
    /// @return The number of months elapsed
    function calculateElapsedMonths(
        uint256 startTimestamp,
        uint256 currentTimestamp
    ) internal pure returns (uint256) {
        require(currentTimestamp >= startTimestamp, "Current timestamp before start");
        uint256 elapsedSeconds = currentTimestamp - startTimestamp;
        uint256 secondsPerMonth = 30 days; // Approximation
        return elapsedSeconds / secondsPerMonth;
    }

    /// @notice Calculates grace period expiry timestamp
    /// @dev Adds grace period days to last missed payment timestamp
    /// @param lastMissedPaymentTimestamp When the last missed payment was recorded
    /// @param gracePeriodDays Grace period in days
    /// @return The grace period expiry timestamp
    function calculateGracePeriodExpiry(
        uint256 lastMissedPaymentTimestamp,
        uint16 gracePeriodDays
    ) internal pure returns (uint256) {
        return lastMissedPaymentTimestamp + (gracePeriodDays * 1 days);
    }

    /// @notice Validates repayment amount based on configuration
    /// @dev Checks if payment amount is acceptable (full, partial, or zero)
    /// @param paymentAmount The payment amount received
    /// @param monthlyPayment The standard monthly payment amount
    /// @param allowPartial Whether partial payments are allowed
    /// @return True if payment amount is valid
    function validateRepaymentAmount(
        uint256 paymentAmount,
        uint256 monthlyPayment,
        bool allowPartial
    ) internal pure returns (bool) {
        if (paymentAmount == 0) return false; // Zero payments not allowed

        // Allow 1% tolerance (100 basis points) for overpayments and underpayments
        uint256 tolerance = (monthlyPayment * 100) / 10000; // 1% of monthly payment
        uint256 minAcceptable = monthlyPayment - tolerance;
        uint256 maxAcceptable = monthlyPayment + tolerance;

        if (allowPartial) {
            // For partial repayments, allow any amount up to the monthly payment
            return paymentAmount <= monthlyPayment && paymentAmount > 0;
        }
        return paymentAmount >= minAcceptable && paymentAmount <= maxAcceptable;
    }
}

// lib/openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol

// OpenZeppelin Contracts (last updated v5.0.0) (access/Ownable.sol)

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * The initial owner is set to the address provided by the deployer. This can
 * later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract OwnableUpgradeable is Initializable, ContextUpgradeable {
    /// @custom:storage-location erc7201:openzeppelin.storage.Ownable
    struct OwnableStorage {
        address _owner;
    }

    // keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.Ownable")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant OwnableStorageLocation = 0x9016d09d72d40fdae2fd8ceac6b6234c7706214fd39c1cd1e609a0528c199300;

    function _getOwnableStorage() private pure returns (OwnableStorage storage $) {
        assembly {
            $.slot := OwnableStorageLocation
        }
    }

    /**
     * @dev The caller account is not authorized to perform an operation.
     */
    error OwnableUnauthorizedAccount(address account);

    /**
     * @dev The owner is not a valid owner account. (eg. `address(0)`)
     */
    error OwnableInvalidOwner(address owner);

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the address provided by the deployer as the initial owner.
     */
    function __Ownable_init(address initialOwner) internal onlyInitializing {
        __Ownable_init_unchained(initialOwner);
    }

    function __Ownable_init_unchained(address initialOwner) internal onlyInitializing {
        if (initialOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(initialOwner);
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        OwnableStorage storage $ = _getOwnableStorage();
        return $._owner;
    }

    /**
     * @dev Throws if the sender is not the owner.
     */
    function _checkOwner() internal view virtual {
        if (owner() != _msgSender()) {
            revert OwnableUnauthorizedAccount(_msgSender());
        }
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby disabling any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        if (newOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        OwnableStorage storage $ = _getOwnableStorage();
        address oldOwner = $._owner;
        $._owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

// src/libraries/YieldDistribution.sol

/// @title Yield Distribution Library
/// @notice Pure functions for autonomous yield distribution to ERC-20 token holders
/// @dev Library functions are deployed once and linked at deployment time, reducing main contract bytecode size
/// This library handles the complex distribution logic to keep YieldSharesToken under 24KB limit
/// Uses YieldCalculations.calculateProRataDistribution for consistent mathematical operations
library YieldDistribution {
    /// @dev Struct to return distribution results for batch processing
    struct DistributionResult {
        address shareholder;
        uint256 amount;
    }

    /// @notice Distributes repayment amount to shareholders based on their token holdings
    /// @dev SINGLE AGREEMENT MODEL: Simplified to work with single agreement per token instance.
    ///     Iterates through shareholder array and calculates pro-rata distribution for each.
    ///     Uses YieldCalculations.calculateProRataDistribution for consistency with yield calculations.
    /// @param shareholders Array of shareholder addresses for the agreement
    /// @param shareholderShares Mapping of shares held by each address
    /// @param totalShares Total shares outstanding for this agreement
    /// @param repaymentAmount Total amount to distribute
    /// @return results Array of DistributionResult structs containing address and amount for each shareholder
    function distributeRepayment(
        address[] memory shareholders,
        mapping(address => uint256) storage shareholderShares,
        uint256 totalShares,
        uint256 repaymentAmount
    ) internal view returns (DistributionResult[] memory results) {
        // Division by zero guard
        require(repaymentAmount == 0 || totalShares > 0, "No shareholders for distribution");

        uint256 shareholderCount = shareholders.length;
        results = new DistributionResult[](shareholderCount);

        for (uint256 i = 0; i < shareholderCount; i++) {
            address shareholder = shareholders[i];
            uint256 shareholderBalance = shareholderShares[shareholder];

            uint256 distributionAmount = YieldCalculations.calculateProRataDistribution(
                repaymentAmount,
                shareholderBalance,
                totalShares
            );

            results[i] = DistributionResult({
                shareholder: shareholder,
                amount: distributionAmount
            });
        }

        return results;
    }

    /// @notice Calculates the token amount to mint for a given capital contribution
    /// @dev Uses 1:1 ratio (1 token = 1 wei of capital) with 18 decimals for fractional ownership
    /// @param capitalAmount The amount of capital contributed
    /// @return The number of tokens to mint (with 18 decimals)
    function calculateSharesForCapital(uint256 capitalAmount) internal pure returns (uint256) {
        return capitalAmount;
    }

    /// @notice Validates shareholder count limits to prevent excessive gas costs
    /// @dev Enforces reasonable limits on shareholder arrays to maintain gas efficiency
    /// @param currentCount Current number of shareholders
    /// @param maxShareholders Maximum allowed shareholders per agreement
    /// @return True if within limits, false if exceeded
    function validateShareholderLimit(uint256 currentCount, uint256 maxShareholders) internal pure returns (bool) {
        return currentCount <= maxShareholders;
    }

    /// @notice Aggregates total shares held by a list of shareholders
    /// @dev Used for reporting and validation purposes
    /// @param shareholders Array of shareholder addresses
    /// @param shares Storage mapping of shares held by each address
    /// @return total Total shares held by all provided shareholders
    function aggregateShareholderBalances(
        address[] memory shareholders,
        mapping(address => uint256) storage shares
    ) internal view returns (uint256 total) {
        uint256 shareholderCount = shareholders.length;
        for (uint256 i = 0; i < shareholderCount; i++) {
            total += shares[shareholders[i]];
        }
        return total;
    }

    /// @notice Distributes partial repayment amount to shareholders based on their token holdings
    /// @dev Calculates percentage of full payment and distributes proportionally to each shareholder
    /// @param shareholders Array of shareholder addresses for the agreement
    /// @param shareholderShares Mapping of shares held by each address
    /// @param totalShares Total shares outstanding for this agreement
    /// @param partialAmount The partial repayment amount received
    /// @param fullMonthlyPayment The standard full monthly payment amount
    /// @return results Array of DistributionResult structs with proportional partial amounts
    function distributePartialRepayment(
        address[] memory shareholders,
        mapping(address => uint256) storage shareholderShares,
        uint256 totalShares,
        uint256 partialAmount,
        uint256 fullMonthlyPayment
    ) internal view returns (DistributionResult[] memory results) {
        // Division by zero guard
        require(partialAmount == 0 || totalShares > 0, "No shareholders for distribution");

        uint256 shareholderCount = shareholders.length;
        results = new DistributionResult[](shareholderCount);

        // Calculate the percentage of full payment this partial represents
        uint256 paymentPercentage = fullMonthlyPayment > 0 ? (partialAmount * 1e18) / fullMonthlyPayment : 0;

        for (uint256 i = 0; i < shareholderCount; i++) {
            address shareholder = shareholders[i];
            uint256 shareholderBalance = shareholderShares[shareholder];

            // Calculate shareholder's portion of the partial amount
            uint256 distributionAmount = YieldCalculations.calculateProRataDistribution(
                partialAmount,
                shareholderBalance,
                totalShares
            );

            results[i] = DistributionResult({
                shareholder: shareholder,
                amount: distributionAmount
            });
        }

        return results;
    }

    /// @notice Validates that pooled contributions sum to required upfront capital
    /// @dev Checks contribution array lengths and validates total matches required amount
    /// @param contributors Array of contributor addresses
    /// @param amounts Array of capital amounts contributed by each address
    /// @param totalRequired The total upfront capital required for the agreement
    /// @return isValid True if contributions are valid, false otherwise
    /// @return totalAccumulated The total amount accumulated from all contributions
    function accumulatePooledContributions(
        address[] memory contributors,
        uint256[] memory amounts,
        uint256 totalRequired
    ) internal pure returns (bool isValid, uint256 totalAccumulated) {
        require(contributors.length == amounts.length, "Array length mismatch");

        uint256 contributorCount = contributors.length;
        for (uint256 i = 0; i < contributorCount; i++) {
            require(amounts[i] > 0, "Zero contribution not allowed");
            totalAccumulated += amounts[i];
        }

        isValid = (totalAccumulated >= totalRequired);
        return (isValid, totalAccumulated);
    }

    /// @notice Calculates token shares to mint for each contributor based on capital contribution
    /// @dev Pro-rata calculation: each contributor gets shares proportional to their contribution
    /// @param contributors Array of contributor addresses
    /// @param contributions Array of capital amounts contributed
    /// @param totalCapital The total capital pooled for the agreement
    /// @return shareAmounts Array of token amounts to mint for each contributor
    function calculateContributorShares(
        address[] memory contributors,
        uint256[] memory contributions,
        uint256 totalCapital
    ) internal pure returns (uint256[] memory shareAmounts) {
        require(contributors.length == contributions.length, "Array length mismatch");
        require(totalCapital > 0, "Total capital cannot be zero");

        uint256 contributorCount = contributors.length;
        shareAmounts = new uint256[](contributorCount);

        for (uint256 i = 0; i < contributorCount; i++) {
            // Calculate shares proportional to contribution
            shareAmounts[i] = YieldCalculations.calculateProRataDistribution(
                totalCapital, // Total tokens to mint (1:1 with capital)
                contributions[i],
                totalCapital
            );
        }

        return shareAmounts;
    }

    /// @notice Validates pooled contributions meet required capital within tolerance
    /// @dev Allows small rounding differences when pooling from multiple investors
    /// @param totalContributions The total amount contributed
    /// @param requiredCapital The required upfront capital amount
    /// @param tolerance The allowed tolerance in wei (e.g., 1e15 for 0.001 ETH)
    /// @return True if within acceptable range
    function validatePooledCapital(
        uint256 totalContributions,
        uint256 requiredCapital,
        uint256 tolerance
    ) internal pure returns (bool) {
        if (totalContributions >= requiredCapital) {
            return (totalContributions - requiredCapital) <= tolerance;
        } else {
            return (requiredCapital - totalContributions) <= tolerance;
        }
    }
}

// lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Utils.sol

// OpenZeppelin Contracts (last updated v5.4.0) (proxy/ERC1967/ERC1967Utils.sol)

/**
 * @dev This library provides getters and event emitting update functions for
 * https://eips.ethereum.org/EIPS/eip-1967[ERC-1967] slots.
 */
library ERC1967Utils {
    /**
     * @dev Storage slot with the address of the current implementation.
     * This is the keccak-256 hash of "eip1967.proxy.implementation" subtracted by 1.
     */
    // solhint-disable-next-line private-vars-leading-underscore
    bytes32 internal constant IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    /**
     * @dev The `implementation` of the proxy is invalid.
     */
    error ERC1967InvalidImplementation(address implementation);

    /**
     * @dev The `admin` of the proxy is invalid.
     */
    error ERC1967InvalidAdmin(address admin);

    /**
     * @dev The `beacon` of the proxy is invalid.
     */
    error ERC1967InvalidBeacon(address beacon);

    /**
     * @dev An upgrade function sees `msg.value > 0` that may be lost.
     */
    error ERC1967NonPayable();

    /**
     * @dev Returns the current implementation address.
     */
    function getImplementation() internal view returns (address) {
        return StorageSlot.getAddressSlot(IMPLEMENTATION_SLOT).value;
    }

    /**
     * @dev Stores a new address in the ERC-1967 implementation slot.
     */
    function _setImplementation(address newImplementation) private {
        if (newImplementation.code.length == 0) {
            revert ERC1967InvalidImplementation(newImplementation);
        }
        StorageSlot.getAddressSlot(IMPLEMENTATION_SLOT).value = newImplementation;
    }

    /**
     * @dev Performs implementation upgrade with additional setup call if data is nonempty.
     * This function is payable only if the setup call is performed, otherwise `msg.value` is rejected
     * to avoid stuck value in the contract.
     *
     * Emits an {IERC1967-Upgraded} event.
     */
    function upgradeToAndCall(address newImplementation, bytes memory data) internal {
        _setImplementation(newImplementation);
        emit IERC1967.Upgraded(newImplementation);

        if (data.length > 0) {
            Address.functionDelegateCall(newImplementation, data);
        } else {
            _checkNonPayable();
        }
    }

    /**
     * @dev Storage slot with the admin of the contract.
     * This is the keccak-256 hash of "eip1967.proxy.admin" subtracted by 1.
     */
    // solhint-disable-next-line private-vars-leading-underscore
    bytes32 internal constant ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

    /**
     * @dev Returns the current admin.
     *
     * TIP: To get this value clients can read directly from the storage slot shown below (specified by ERC-1967) using
     * the https://eth.wiki/json-rpc/API#eth_getstorageat[`eth_getStorageAt`] RPC call.
     * `0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103`
     */
    function getAdmin() internal view returns (address) {
        return StorageSlot.getAddressSlot(ADMIN_SLOT).value;
    }

    /**
     * @dev Stores a new address in the ERC-1967 admin slot.
     */
    function _setAdmin(address newAdmin) private {
        if (newAdmin == address(0)) {
            revert ERC1967InvalidAdmin(address(0));
        }
        StorageSlot.getAddressSlot(ADMIN_SLOT).value = newAdmin;
    }

    /**
     * @dev Changes the admin of the proxy.
     *
     * Emits an {IERC1967-AdminChanged} event.
     */
    function changeAdmin(address newAdmin) internal {
        emit IERC1967.AdminChanged(getAdmin(), newAdmin);
        _setAdmin(newAdmin);
    }

    /**
     * @dev The storage slot of the UpgradeableBeacon contract which defines the implementation for this proxy.
     * This is the keccak-256 hash of "eip1967.proxy.beacon" subtracted by 1.
     */
    // solhint-disable-next-line private-vars-leading-underscore
    bytes32 internal constant BEACON_SLOT = 0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50;

    /**
     * @dev Returns the current beacon.
     */
    function getBeacon() internal view returns (address) {
        return StorageSlot.getAddressSlot(BEACON_SLOT).value;
    }

    /**
     * @dev Stores a new beacon in the ERC-1967 beacon slot.
     */
    function _setBeacon(address newBeacon) private {
        if (newBeacon.code.length == 0) {
            revert ERC1967InvalidBeacon(newBeacon);
        }

        StorageSlot.getAddressSlot(BEACON_SLOT).value = newBeacon;

        address beaconImplementation = IBeacon(newBeacon).implementation();
        if (beaconImplementation.code.length == 0) {
            revert ERC1967InvalidImplementation(beaconImplementation);
        }
    }

    /**
     * @dev Change the beacon and trigger a setup call if data is nonempty.
     * This function is payable only if the setup call is performed, otherwise `msg.value` is rejected
     * to avoid stuck value in the contract.
     *
     * Emits an {IERC1967-BeaconUpgraded} event.
     *
     * CAUTION: Invoking this function has no effect on an instance of {BeaconProxy} since v5, since
     * it uses an immutable beacon without looking at the value of the ERC-1967 beacon slot for
     * efficiency.
     */
    function upgradeBeaconToAndCall(address newBeacon, bytes memory data) internal {
        _setBeacon(newBeacon);
        emit IERC1967.BeaconUpgraded(newBeacon);

        if (data.length > 0) {
            Address.functionDelegateCall(IBeacon(newBeacon).implementation(), data);
        } else {
            _checkNonPayable();
        }
    }

    /**
     * @dev Reverts if `msg.value` is not zero. It can be used to avoid `msg.value` stuck in the contract
     * if an upgrade doesn't perform an initialization call.
     */
    function _checkNonPayable() private {
        if (msg.value > 0) {
            revert ERC1967NonPayable();
        }
    }
}

// lib/openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol

// OpenZeppelin Contracts (last updated v5.4.0) (token/ERC20/ERC20.sol)

/**
 * @dev Implementation of the {IERC20} interface.
 *
 * This implementation is agnostic to the way tokens are created. This means
 * that a supply mechanism has to be added in a derived contract using {_mint}.
 *
 * TIP: For a detailed writeup see our guide
 * https://forum.openzeppelin.com/t/how-to-implement-erc20-supply-mechanisms/226[How
 * to implement supply mechanisms].
 *
 * The default value of {decimals} is 18. To change this, you should override
 * this function so it returns a different value.
 *
 * We have followed general OpenZeppelin Contracts guidelines: functions revert
 * instead returning `false` on failure. This behavior is nonetheless
 * conventional and does not conflict with the expectations of ERC-20
 * applications.
 */
abstract contract ERC20Upgradeable is Initializable, ContextUpgradeable, IERC20, IERC20Metadata, IERC20Errors {
    /// @custom:storage-location erc7201:openzeppelin.storage.ERC20
    struct ERC20Storage {
        mapping(address account => uint256) _balances;

        mapping(address account => mapping(address spender => uint256)) _allowances;

        uint256 _totalSupply;

        string _name;
        string _symbol;
    }

    // keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.ERC20")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant ERC20StorageLocation = 0x52c63247e1f47db19d5ce0460030c497f067ca4cebf71ba98eeadabe20bace00;

    function _getERC20Storage() private pure returns (ERC20Storage storage $) {
        assembly {
            $.slot := ERC20StorageLocation
        }
    }

    /**
     * @dev Sets the values for {name} and {symbol}.
     *
     * Both values are immutable: they can only be set once during construction.
     */
    function __ERC20_init(string memory name_, string memory symbol_) internal onlyInitializing {
        __ERC20_init_unchained(name_, symbol_);
    }

    function __ERC20_init_unchained(string memory name_, string memory symbol_) internal onlyInitializing {
        ERC20Storage storage $ = _getERC20Storage();
        $._name = name_;
        $._symbol = symbol_;
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view virtual returns (string memory) {
        ERC20Storage storage $ = _getERC20Storage();
        return $._name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view virtual returns (string memory) {
        ERC20Storage storage $ = _getERC20Storage();
        return $._symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5.05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the default value returned by this function, unless
     * it's overridden.
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public view virtual returns (uint8) {
        return 18;
    }

    /// @inheritdoc IERC20
    function totalSupply() public view virtual returns (uint256) {
        ERC20Storage storage $ = _getERC20Storage();
        return $._totalSupply;
    }

    /// @inheritdoc IERC20
    function balanceOf(address account) public view virtual returns (uint256) {
        ERC20Storage storage $ = _getERC20Storage();
        return $._balances[account];
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - the caller must have a balance of at least `value`.
     */
    function transfer(address to, uint256 value) public virtual returns (bool) {
        address owner = _msgSender();
        _transfer(owner, to, value);
        return true;
    }

    /// @inheritdoc IERC20
    function allowance(address owner, address spender) public view virtual returns (uint256) {
        ERC20Storage storage $ = _getERC20Storage();
        return $._allowances[owner][spender];
    }

    /**
     * @dev See {IERC20-approve}.
     *
     * NOTE: If `value` is the maximum `uint256`, the allowance is not updated on
     * `transferFrom`. This is semantically equivalent to an infinite approval.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 value) public virtual returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, value);
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Skips emitting an {Approval} event indicating an allowance update. This is not
     * required by the ERC. See {xref-ERC20-_approve-address-address-uint256-bool-}[_approve].
     *
     * NOTE: Does not update the allowance if the current allowance
     * is the maximum `uint256`.
     *
     * Requirements:
     *
     * - `from` and `to` cannot be the zero address.
     * - `from` must have a balance of at least `value`.
     * - the caller must have allowance for ``from``'s tokens of at least
     * `value`.
     */
    function transferFrom(address from, address to, uint256 value) public virtual returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, value);
        _transfer(from, to, value);
        return true;
    }

    /**
     * @dev Moves a `value` amount of tokens from `from` to `to`.
     *
     * This internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * NOTE: This function is not virtual, {_update} should be overridden instead.
     */
    function _transfer(address from, address to, uint256 value) internal {
        if (from == address(0)) {
            revert ERC20InvalidSender(address(0));
        }
        if (to == address(0)) {
            revert ERC20InvalidReceiver(address(0));
        }
        _update(from, to, value);
    }

    /**
     * @dev Transfers a `value` amount of tokens from `from` to `to`, or alternatively mints (or burns) if `from`
     * (or `to`) is the zero address. All customizations to transfers, mints, and burns should be done by overriding
     * this function.
     *
     * Emits a {Transfer} event.
     */
    function _update(address from, address to, uint256 value) internal virtual {
        ERC20Storage storage $ = _getERC20Storage();
        if (from == address(0)) {
            // Overflow check required: The rest of the code assumes that totalSupply never overflows
            $._totalSupply += value;
        } else {
            uint256 fromBalance = $._balances[from];
            if (fromBalance < value) {
                revert ERC20InsufficientBalance(from, fromBalance, value);
            }
            unchecked {
                // Overflow not possible: value <= fromBalance <= totalSupply.
                $._balances[from] = fromBalance - value;
            }
        }

        if (to == address(0)) {
            unchecked {
                // Overflow not possible: value <= totalSupply or value <= fromBalance <= totalSupply.
                $._totalSupply -= value;
            }
        } else {
            unchecked {
                // Overflow not possible: balance + value is at most totalSupply, which we know fits into a uint256.
                $._balances[to] += value;
            }
        }

        emit Transfer(from, to, value);
    }

    /**
     * @dev Creates a `value` amount of tokens and assigns them to `account`, by transferring it from address(0).
     * Relies on the `_update` mechanism
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * NOTE: This function is not virtual, {_update} should be overridden instead.
     */
    function _mint(address account, uint256 value) internal {
        if (account == address(0)) {
            revert ERC20InvalidReceiver(address(0));
        }
        _update(address(0), account, value);
    }

    /**
     * @dev Destroys a `value` amount of tokens from `account`, lowering the total supply.
     * Relies on the `_update` mechanism.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * NOTE: This function is not virtual, {_update} should be overridden instead
     */
    function _burn(address account, uint256 value) internal {
        if (account == address(0)) {
            revert ERC20InvalidSender(address(0));
        }
        _update(account, address(0), value);
    }

    /**
     * @dev Sets `value` as the allowance of `spender` over the `owner`'s tokens.
     *
     * This internal function is equivalent to `approve`, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     *
     * Overrides to this logic should be done to the variant with an additional `bool emitEvent` argument.
     */
    function _approve(address owner, address spender, uint256 value) internal {
        _approve(owner, spender, value, true);
    }

    /**
     * @dev Variant of {_approve} with an optional flag to enable or disable the {Approval} event.
     *
     * By default (when calling {_approve}) the flag is set to true. On the other hand, approval changes made by
     * `_spendAllowance` during the `transferFrom` operation set the flag to false. This saves gas by not emitting any
     * `Approval` event during `transferFrom` operations.
     *
     * Anyone who wishes to continue emitting `Approval` events on the`transferFrom` operation can force the flag to
     * true using the following override:
     *
     * ```solidity
     * function _approve(address owner, address spender, uint256 value, bool) internal virtual override {
     *     super._approve(owner, spender, value, true);
     * }
     * ```
     *
     * Requirements are the same as {_approve}.
     */
    function _approve(address owner, address spender, uint256 value, bool emitEvent) internal virtual {
        ERC20Storage storage $ = _getERC20Storage();
        if (owner == address(0)) {
            revert ERC20InvalidApprover(address(0));
        }
        if (spender == address(0)) {
            revert ERC20InvalidSpender(address(0));
        }
        $._allowances[owner][spender] = value;
        if (emitEvent) {
            emit Approval(owner, spender, value);
        }
    }

    /**
     * @dev Updates `owner`'s allowance for `spender` based on spent `value`.
     *
     * Does not update the allowance value in case of infinite allowance.
     * Revert if not enough allowance is available.
     *
     * Does not emit an {Approval} event.
     */
    function _spendAllowance(address owner, address spender, uint256 value) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance < type(uint256).max) {
            if (currentAllowance < value) {
                revert ERC20InsufficientAllowance(spender, currentAllowance, value);
            }
            unchecked {
                _approve(owner, spender, currentAllowance - value, false);
            }
        }
    }
}

// lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol

// OpenZeppelin Contracts (last updated v5.3.0) (proxy/utils/UUPSUpgradeable.sol)

/**
 * @dev An upgradeability mechanism designed for UUPS proxies. The functions included here can perform an upgrade of an
 * {ERC1967Proxy}, when this contract is set as the implementation behind such a proxy.
 *
 * A security mechanism ensures that an upgrade does not turn off upgradeability accidentally, although this risk is
 * reinstated if the upgrade retains upgradeability but removes the security mechanism, e.g. by replacing
 * `UUPSUpgradeable` with a custom implementation of upgrades.
 *
 * The {_authorizeUpgrade} function must be overridden to include access restriction to the upgrade mechanism.
 */
abstract contract UUPSUpgradeable is Initializable, IERC1822Proxiable {
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    address private immutable __self = address(this);

    /**
     * @dev The version of the upgrade interface of the contract. If this getter is missing, both `upgradeTo(address)`
     * and `upgradeToAndCall(address,bytes)` are present, and `upgradeTo` must be used if no function should be called,
     * while `upgradeToAndCall` will invoke the `receive` function if the second argument is the empty byte string.
     * If the getter returns `"5.0.0"`, only `upgradeToAndCall(address,bytes)` is present, and the second argument must
     * be the empty byte string if no function should be called, making it impossible to invoke the `receive` function
     * during an upgrade.
     */
    string public constant UPGRADE_INTERFACE_VERSION = "5.0.0";

    /**
     * @dev The call is from an unauthorized context.
     */
    error UUPSUnauthorizedCallContext();

    /**
     * @dev The storage `slot` is unsupported as a UUID.
     */
    error UUPSUnsupportedProxiableUUID(bytes32 slot);

    /**
     * @dev Check that the execution is being performed through a delegatecall call and that the execution context is
     * a proxy contract with an implementation (as defined in ERC-1967) pointing to self. This should only be the case
     * for UUPS and transparent proxies that are using the current contract as their implementation. Execution of a
     * function through ERC-1167 minimal proxies (clones) would not normally pass this test, but is not guaranteed to
     * fail.
     */
    modifier onlyProxy() {
        _checkProxy();
        _;
    }

    /**
     * @dev Check that the execution is not being performed through a delegate call. This allows a function to be
     * callable on the implementing contract but not through proxies.
     */
    modifier notDelegated() {
        _checkNotDelegated();
        _;
    }

    function __UUPSUpgradeable_init() internal onlyInitializing {
    }

    function __UUPSUpgradeable_init_unchained() internal onlyInitializing {
    }
    /**
     * @dev Implementation of the ERC-1822 {proxiableUUID} function. This returns the storage slot used by the
     * implementation. It is used to validate the implementation's compatibility when performing an upgrade.
     *
     * IMPORTANT: A proxy pointing at a proxiable contract should not be considered proxiable itself, because this risks
     * bricking a proxy that upgrades to it, by delegating to itself until out of gas. Thus it is critical that this
     * function revert if invoked through a proxy. This is guaranteed by the `notDelegated` modifier.
     */
    function proxiableUUID() external view virtual notDelegated returns (bytes32) {
        return ERC1967Utils.IMPLEMENTATION_SLOT;
    }

    /**
     * @dev Upgrade the implementation of the proxy to `newImplementation`, and subsequently execute the function call
     * encoded in `data`.
     *
     * Calls {_authorizeUpgrade}.
     *
     * Emits an {Upgraded} event.
     *
     * @custom:oz-upgrades-unsafe-allow-reachable delegatecall
     */
    function upgradeToAndCall(address newImplementation, bytes memory data) public payable virtual onlyProxy {
        _authorizeUpgrade(newImplementation);
        _upgradeToAndCallUUPS(newImplementation, data);
    }

    /**
     * @dev Reverts if the execution is not performed via delegatecall or the execution
     * context is not of a proxy with an ERC-1967 compliant implementation pointing to self.
     */
    function _checkProxy() internal view virtual {
        if (
            address(this) == __self || // Must be called through delegatecall
            ERC1967Utils.getImplementation() != __self // Must be called through an active proxy
        ) {
            revert UUPSUnauthorizedCallContext();
        }
    }

    /**
     * @dev Reverts if the execution is performed via delegatecall.
     * See {notDelegated}.
     */
    function _checkNotDelegated() internal view virtual {
        if (address(this) != __self) {
            // Must not be called through delegatecall
            revert UUPSUnauthorizedCallContext();
        }
    }

    /**
     * @dev Function that should revert when `msg.sender` is not authorized to upgrade the contract. Called by
     * {upgradeToAndCall}.
     *
     * Normally, this function will use an xref:access.adoc[access control] modifier such as {Ownable-onlyOwner}.
     *
     * ```solidity
     * function _authorizeUpgrade(address) internal onlyOwner {}
     * ```
     */
    function _authorizeUpgrade(address newImplementation) internal virtual;

    /**
     * @dev Performs an implementation upgrade with a security check for UUPS proxies, and additional setup call.
     *
     * As a security check, {proxiableUUID} is invoked in the new implementation, and the return value
     * is expected to be the implementation slot in ERC-1967.
     *
     * Emits an {IERC1967-Upgraded} event.
     */
    function _upgradeToAndCallUUPS(address newImplementation, bytes memory data) private {
        try IERC1822Proxiable(newImplementation).proxiableUUID() returns (bytes32 slot) {
            if (slot != ERC1967Utils.IMPLEMENTATION_SLOT) {
                revert UUPSUnsupportedProxiableUUID(slot);
            }
            ERC1967Utils.upgradeToAndCall(newImplementation, data);
        } catch {
            // The implementation is not UUPS
            revert ERC1967Utils.ERC1967InvalidImplementation(newImplementation);
        }
    }
}

// src/KYCRegistry.sol

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

// src/YieldSharesToken.sol

/// @title Yield Shares Token
/// @notice ERC-20 token contract for fungible ownership of rental yield streams
/// @dev Implements autonomous minting and distribution using UUPS proxy pattern with ERC-7201 storage isolation
/// Only YieldBase contract can mint/burn tokens, ensuring controlled token supply and distribution
/// Uses 1:1 token-to-capital ratio (1 token = 1 wei) with 18 decimals for fractional ownership
contract YieldSharesToken is Initializable, ERC20Upgradeable, UUPSUpgradeable, OwnableUpgradeable, ReentrancyGuardUpgradeable {
    using YieldDistribution for *;
    using YieldCalculations for uint256;

    /// @notice Maximum number of shareholders to prevent pathological gas usage
    uint256 public constant MAX_SHAREHOLDERS = 1000;

    /// @notice Transfer restrictions enabled flag (default false for backward compatibility)
    bool public transferRestrictionsEnabled;

    /// @notice Reference to KYCRegistry for KYC verification and compliance enforcement
    KYCRegistry public kycRegistry;

    /// @notice Emitted when shares are minted for a new yield agreement
    event SharesMinted(uint256 indexed agreementId, address indexed investor, uint256 shares, uint256 capitalAmount);

    /// @notice Emitted when repayment is distributed to shareholders
    event RepaymentDistributed(uint256 indexed agreementId, uint256 totalAmount, uint256 shareholderCount);

    /// @notice Emitted when shares are burned (agreement completion or default)
    event SharesBurned(uint256 indexed agreementId, address indexed investor, uint256 shares);

    /// @notice Emitted when partial repayment is distributed
    event PartialRepaymentDistributed(uint256 indexed agreementId, uint256 partialAmount, uint256 fullAmount, uint256 shareholderCount);

    /// @notice Emitted when shares are minted for multiple contributors
    event SharesMintedBatch(uint256 indexed agreementId, address[] contributors, uint256[] shares, uint256 totalCapital);

    /// @notice Emitted when transfer restrictions are updated
    event TransferRestrictionsUpdated(uint256 lockupEndTimestamp, uint256 maxSharesPerInvestor, uint256 minHoldingPeriod);

    /// @notice Emitted when transfers are paused
    event TransfersPaused();

    /// @notice Emitted when transfers are unpaused
    event TransfersUnpaused();

    /// @notice Emitted when a transfer is blocked by restrictions
    event TransferBlocked(address indexed from, address indexed to, uint256 amount, string reason);

    /// @notice Emitted when KYC Registry is set
    event KYCRegistrySet(address indexed kycRegistryAddress);

    /// @dev Disable constructor to prevent initialization outside proxy context
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes the upgradeable contract with owner and YieldBase reference
    /// @param initialOwner Address that will own the contract (can authorize upgrades)
    /// @param yieldBaseAddress Address of the YieldBase contract for access control
    /// @param name ERC-20 token name
    /// @param symbol ERC-20 token symbol
    function initialize(
        address initialOwner,
        address yieldBaseAddress,
        string memory name,
        string memory symbol
    ) public initializer {
        __ERC20_init(name, symbol);
        __Ownable_init(initialOwner);
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();

        YieldSharesStorage.YieldSharesData storage data = _getYieldSharesStorage();
        data.yieldBaseContract = yieldBaseAddress;
    }

    /// @notice Authorizes contract upgrades (only owner can upgrade)
    /// @param newImplementation Address of the new implementation contract
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    /// @notice Set the KYCRegistry contract reference
    /// @dev Must be called after deployment to enable KYC verification and regulatory compliance
    /// Only owner can set the KYC Registry reference for security
    /// @param kycRegistryAddress Address of the deployed KYCRegistry contract
    function setKYCRegistry(address kycRegistryAddress) external onlyOwner {
        require(kycRegistryAddress != address(0), "Invalid KYC Registry");
        kycRegistry = KYCRegistry(kycRegistryAddress);
        emit KYCRegistrySet(kycRegistryAddress);
    }

    /// @notice Modifier to ensure only YieldBase contract can call restricted functions
    modifier onlyYieldBase() {
        YieldSharesStorage.YieldSharesData storage data = _getYieldSharesStorage();
        require(msg.sender == data.yieldBaseContract, "Only YieldBase can perform this action");
        _;
    }

    /// @notice Mints shares for a yield agreement (only callable by YieldBase)
    /// @dev SINGLE AGREEMENT CONSTRAINT: This token supports only one agreement per instance.
    ///     Creates tokens at 1:1 ratio with capital amount and updates storage mappings.
    /// @param agreementId Unique identifier for the yield agreement
    /// @param investor Address receiving the minted shares
    /// @param capitalAmount Amount of capital contributed (determines share amount)
    function mintShares(uint256 agreementId, address investor, uint256 capitalAmount) external onlyYieldBase {
        // KYC verification for regulatory compliance
        require(address(kycRegistry) != address(0), "KYC Registry not set");
        require(kycRegistry.isWhitelisted(investor), "Investor not KYC verified");
        require(!kycRegistry.isBlacklisted(investor), "Investor is blacklisted");

        uint256 sharesToMint = YieldDistribution.calculateSharesForCapital(capitalAmount);

        YieldSharesStorage.YieldSharesData storage data = _getYieldSharesStorage();

        // Enforce single agreement constraint
        if (data.currentAgreementId == 0) {
            // First mint sets the agreement ID for this token instance
            data.currentAgreementId = agreementId;
        } else {
            // Subsequent mints must use the same agreement ID
            require(agreementId == data.currentAgreementId, "Token instance supports only one agreement");
        }

        // Validate shareholder limit before adding new shareholder
        require(validateShareholderLimit(data.shareholderCount + (data.isShareholder[investor] ? 0 : 1), MAX_SHAREHOLDERS), "Too many shareholders");

        // Update storage mappings (scoped to single agreement)
        data.totalShares += sharesToMint;
        data.shareholderShares[investor] += sharesToMint;

        // Add investor to shareholder array if not already present
        if (!data.isShareholder[investor]) {
            data.shareholderAddresses.push(investor);
            data.shareholderCount++;
            data.isShareholder[investor] = true;
        }

        // Mint the tokens
        _mint(investor, sharesToMint);

        emit SharesMinted(agreementId, investor, sharesToMint, capitalAmount);
    }

    /// @notice Distributes repayment to shareholders based on their token holdings (only callable by YieldBase)
    /// @dev SINGLE AGREEMENT CONSTRAINT: Uses the current agreement ID set during first mint.
    ///     Uses YieldDistribution library to calculate pro-rata amounts and transfers ETH to holders.
    ///     Replaces .transfer with .call for safety and adds reentrancy protection.
    /// @param agreementId Unique identifier for the yield agreement (must match current agreement)
    function distributeRepayment(uint256 agreementId) external payable onlyYieldBase nonReentrant {
        YieldSharesStorage.YieldSharesData storage data = _getYieldSharesStorage();

        // Enforce single agreement constraint
        require(agreementId == data.currentAgreementId, "Invalid agreement ID for this token instance");

        uint256 repaymentAmount = msg.value;
        require(repaymentAmount > 0, "No funds sent");

        address[] memory shareholders = data.shareholderAddresses;
        uint256 totalShares = data.totalShares;

        // Division by zero guard
        require(repaymentAmount == 0 || totalShares > 0, "No shareholders for distribution");

        // Shareholder limit validation
        require(shareholders.length <= MAX_SHAREHOLDERS, "Too many shareholders for distribution");

        // Calculate and distribute pro-rata amounts
        YieldDistribution.DistributionResult[] memory results = YieldDistribution.distributeRepayment(
            shareholders,
            data.shareholderShares,
            totalShares,
            repaymentAmount
        );

        uint256 distributedTotal = 0;

        // Transfer ETH to each shareholder using .call instead of .transfer
        for (uint256 i = 0; i < results.length; i++) {
            if (results[i].amount > 0) {
                (bool success, ) = payable(results[i].shareholder).call{value: results[i].amount}("");
                if (!success) {
                    // On failure, accumulate to unclaimed remainder
                    data.unclaimedRemainder[results[i].shareholder] += results[i].amount;
                } else {
                    distributedTotal += results[i].amount;
                }
            }
        }

        // Handle rounding dust/remainder
        uint256 remainder = repaymentAmount - distributedTotal;
        if (remainder > 0) {
            // Send remainder to the largest holder, or accumulate if no holders
            if (shareholders.length > 0) {
                // Find the shareholder with the most shares
                address largestHolder = shareholders[0];
                uint256 maxShares = data.shareholderShares[shareholders[0]];
                for (uint256 i = 1; i < shareholders.length; i++) {
                    if (data.shareholderShares[shareholders[i]] > maxShares) {
                        maxShares = data.shareholderShares[shareholders[i]];
                        largestHolder = shareholders[i];
                    }
                }
                (bool success, ) = payable(largestHolder).call{value: remainder}("");
                if (!success) {
                    data.unclaimedRemainder[largestHolder] += remainder;
                } else {
                    distributedTotal += remainder;
                }
            }
        }

        emit RepaymentDistributed(agreementId, repaymentAmount, shareholders.length);
    }

    /// @notice Burns shares when agreement completes or defaults (only callable by YieldBase)
    /// @dev SINGLE AGREEMENT MODEL: Works with the current agreement set during first mint.
    ///     Removes tokens from circulation and updates storage mappings.
    /// @param agreementId Unique identifier for the yield agreement (must match current agreement)
    /// @param investor Address whose shares are being burned
    /// @param shares Amount of shares to burn
    function burnShares(uint256 agreementId, address investor, uint256 shares) external onlyYieldBase {
        YieldSharesStorage.YieldSharesData storage data = _getYieldSharesStorage();

        // Enforce single agreement constraint
        require(agreementId == data.currentAgreementId, "Invalid agreement ID for this token instance");

        // Update storage mappings (scoped to single agreement)
        data.totalShares -= shares;
        data.shareholderShares[investor] -= shares;

        // Remove from shareholder array if balance becomes zero
        if (data.shareholderShares[investor] == 0 && data.isShareholder[investor]) {
            _removeShareholder(investor);
        }

        // Burn the tokens
        _burn(investor, shares);

        emit SharesBurned(agreementId, investor, shares);
    }

    /// @notice Burns all remaining shares when agreement completes (only callable by YieldBase)
    /// @dev SINGLE AGREEMENT MODEL: Burns all outstanding shares for the current agreement.
    ///     Iterates through all shareholders and burns their remaining shares.
    /// @param agreementId Unique identifier for the yield agreement (must match current agreement)
    function burnRemainingShares(uint256 agreementId) external onlyYieldBase {
        YieldSharesStorage.YieldSharesData storage data = _getYieldSharesStorage();

        // Enforce single agreement constraint
        require(agreementId == data.currentAgreementId, "Invalid agreement ID for this token instance");

        // Burn shares for all shareholders
        address[] memory shareholders = data.shareholderAddresses;
        for (uint256 i = 0; i < shareholders.length; i++) {
            address shareholder = shareholders[i];
            uint256 sharesToBurn = data.shareholderShares[shareholder];

            if (sharesToBurn > 0) {
                data.shareholderShares[shareholder] = 0;
                data.isShareholder[shareholder] = false;
                _burn(shareholder, sharesToBurn);
                emit SharesBurned(agreementId, shareholder, sharesToBurn);
            }
        }

        // Reset storage to clean state
        delete data.shareholderAddresses;
        data.shareholderCount = 0;
        data.totalShares = 0;

        // Note: isShareholder mappings are not cleared to save gas, but they're effectively invalidated
    }

    /// @notice Distributes partial repayment amount to shareholders (only callable by YieldBase)
    /// @dev Uses YieldDistribution.distributePartialRepayment to calculate proportional amounts based on partial payment percentage
    /// @param agreementId Unique identifier for the yield agreement (must match current agreement)
    /// @param partialAmount The partial repayment amount received
    /// @param fullMonthlyPayment The standard full monthly payment amount
    function distributePartialRepayment(uint256 agreementId, uint256 partialAmount, uint256 fullMonthlyPayment) external payable onlyYieldBase nonReentrant {
        YieldSharesStorage.YieldSharesData storage data = _getYieldSharesStorage();

        // Enforce single agreement constraint
        require(agreementId == data.currentAgreementId, "Invalid agreement ID for this token instance");

        require(partialAmount > 0 && msg.value == partialAmount, "Invalid partial amount");

        address[] memory shareholders = data.shareholderAddresses;
        uint256 totalShares = data.totalShares;

        // Division by zero guard
        require(partialAmount == 0 || totalShares > 0, "No shareholders for distribution");

        // Shareholder limit validation
        require(shareholders.length <= MAX_SHAREHOLDERS, "Too many shareholders for distribution");

        // Calculate and distribute proportional partial amounts
        YieldDistribution.DistributionResult[] memory results = YieldDistribution.distributePartialRepayment(
            shareholders,
            data.shareholderShares,
            totalShares,
            partialAmount,
            fullMonthlyPayment
        );

        uint256 distributedTotal = 0;

        // Transfer ETH to each shareholder using .call instead of .transfer
        for (uint256 i = 0; i < results.length; i++) {
            if (results[i].amount > 0) {
                (bool success, ) = payable(results[i].shareholder).call{value: results[i].amount}("");
                if (!success) {
                    // On failure, accumulate to unclaimed remainder
                    data.unclaimedRemainder[results[i].shareholder] += results[i].amount;
                } else {
                    distributedTotal += results[i].amount;
                }
            }
        }

        // Handle rounding dust/remainder (same as full distribution)
        uint256 remainder = partialAmount - distributedTotal;
        if (remainder > 0) {
            if (shareholders.length > 0) {
                address largestHolder = shareholders[0];
                uint256 maxShares = data.shareholderShares[shareholders[0]];
                for (uint256 i = 1; i < shareholders.length; i++) {
                    if (data.shareholderShares[shareholders[i]] > maxShares) {
                        maxShares = data.shareholderShares[shareholders[i]];
                        largestHolder = shareholders[i];
                    }
                }
                (bool success, ) = payable(largestHolder).call{value: remainder}("");
                if (!success) {
                    data.unclaimedRemainder[largestHolder] += remainder;
                } else {
                    distributedTotal += remainder;
                }
            }
        }

        emit PartialRepaymentDistributed(agreementId, partialAmount, fullMonthlyPayment, shareholders.length);
    }

    /// @notice Mints shares for multiple contributors during pooled capital creation (only callable by YieldBase)
    /// @dev Batch mints shares proportionally to each contributor's capital amount, updates pooled contribution tracking
    /// @param agreementId Unique identifier for the yield agreement (must match current agreement)
    /// @param contributors Array of addresses contributing to the pooled capital
    /// @param contributions Array of capital amounts contributed by each address
    function mintSharesForContributors(uint256 agreementId, address[] memory contributors, uint256[] memory contributions, uint256 requiredCapital) external onlyYieldBase {
        require(contributors.length == contributions.length, "Array length mismatch");

        YieldSharesStorage.YieldSharesData storage data = _getYieldSharesStorage();

        // Enforce single agreement constraint
        if (data.currentAgreementId == 0) {
            data.currentAgreementId = agreementId;
        } else {
            require(agreementId == data.currentAgreementId, "Token instance supports only one agreement");
        }

        uint256 contributorCount = contributors.length;
        uint256 totalCapital = 0;

        // Calculate total capital and validate contributions
        for (uint256 i = 0; i < contributorCount; i++) {
            require(contributions[i] > 0, "Zero contribution not allowed");
            totalCapital += contributions[i];
        }

        // Validate pooled capital accumulation
        (bool isValid, uint256 totalAccumulated) = YieldDistribution.accumulatePooledContributions(contributors, contributions, requiredCapital);
        require(isValid, "Pooled contributions do not meet capital requirement");

        // Calculate shares for each contributor
        uint256[] memory shareAmounts = YieldDistribution.calculateContributorShares(contributors, contributions, totalCapital);

        // Mint shares and update storage for each contributor
        for (uint256 i = 0; i < contributorCount; i++) {
            address contributor = contributors[i];
            uint256 sharesToMint = shareAmounts[i];
            uint256 capitalContribution = contributions[i];

            // Update pooled contribution tracking
            data.pooledContributions[contributor] += capitalContribution;
            data.totalPooledCapital += capitalContribution;

            if (!data.isContributor[contributor]) {
                data.isContributor[contributor] = true;
                data.contributorCount++;
            }

            // Check shareholder limits before adding
            bool wouldAddNewShareholder = !data.isShareholder[contributor];
            if (wouldAddNewShareholder) {
                require(validateShareholderLimit(data.shareholderCount + 1, MAX_SHAREHOLDERS), "Too many shareholders");
            }

            // Update shareholder tracking
            data.totalShares += sharesToMint;
            data.shareholderShares[contributor] += sharesToMint;

            if (!data.isShareholder[contributor]) {
                data.shareholderAddresses.push(contributor);
                data.shareholderCount++;
                data.isShareholder[contributor] = true;
            }

            // Mint the tokens
            _mint(contributor, sharesToMint);
        }

        emit SharesMintedBatch(agreementId, contributors, shareAmounts, totalCapital);
    }

    /// @notice Gets the list of shareholders for the current agreement
    /// @dev SINGLE AGREEMENT MODEL: Returns shareholders for the agreement set during first mint
    /// @return Array of shareholder addresses
    function getAgreementShareholders() external view returns (address[] memory) {
        YieldSharesStorage.YieldSharesData storage data = _getYieldSharesStorage();
        return data.shareholderAddresses;
    }

    /// @notice Gets the share balance of a specific shareholder for the current agreement
    /// @dev SINGLE AGREEMENT MODEL: Returns balance for the agreement set during first mint
    /// @param shareholder Address of the shareholder
    /// @return Number of shares held by the shareholder for this agreement
    function getShareholderBalance(address shareholder) external view returns (uint256) {
        YieldSharesStorage.YieldSharesData storage data = _getYieldSharesStorage();
        return data.shareholderShares[shareholder];
    }

    /// @notice Gets the total shares outstanding for the current agreement
    /// @dev SINGLE AGREEMENT MODEL: Returns total shares for the agreement set during first mint
    /// @return Total number of shares minted for this agreement
    function getTotalSharesForAgreement() external view returns (uint256) {
        YieldSharesStorage.YieldSharesData storage data = _getYieldSharesStorage();
        return data.totalShares;
    }

    /// @notice Gets the current agreement ID for this token instance
    /// @return The agreement ID set during the first mint operation
    function getCurrentAgreementId() external view returns (uint256) {
        YieldSharesStorage.YieldSharesData storage data = _getYieldSharesStorage();
        return data.currentAgreementId;
    }

    /// @notice Gets the capital contributed by a contributor during agreement creation
    /// @dev Returns the pooled contribution amount from pooledContributions mapping
    /// @param contributor Address of the contributor
    /// @return Capital amount contributed by the address
    function getContributorBalance(address contributor) external view returns (uint256) {
        YieldSharesStorage.YieldSharesData storage data = _getYieldSharesStorage();
        return data.pooledContributions[contributor];
    }

    /// @notice Gets the total pooled capital contributed by all contributors
    /// @dev Returns the sum of all pooled contributions
    /// @return Total capital amount pooled from all contributors
    function getTotalPooledCapital() external view returns (uint256) {
        YieldSharesStorage.YieldSharesData storage data = _getYieldSharesStorage();
        return data.totalPooledCapital;
    }

    /// @notice Allows users to claim unclaimed ETH due to failed transfers
    /// @dev Pull-payment pattern to handle failed .call transfers
    function claimUnclaimedRemainder() external {
        YieldSharesStorage.YieldSharesData storage data = _getYieldSharesStorage();
        uint256 amount = data.unclaimedRemainder[msg.sender];
        require(amount > 0, "No unclaimed remainder");

        data.unclaimedRemainder[msg.sender] = 0;
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Claim transfer failed");
    }

    /// @notice Gets the unclaimed remainder amount for an address
    /// @param account Address to check
    /// @return Amount of unclaimed ETH available
    function getUnclaimedRemainder(address account) external view returns (uint256) {
        YieldSharesStorage.YieldSharesData storage data = _getYieldSharesStorage();
        return data.unclaimedRemainder[account];
    }

    /// @notice Enables transfer restrictions and sets restriction parameters
    /// @dev Only owner or governance can call this function
    /// @param lockupEndTimestamp Timestamp when lockup period ends (0 = no lockup)
    /// @param maxSharesPerInvestor Maximum shares per investor in basis points (e.g., 2000 = 20%)
    /// @param minHoldingPeriod Minimum holding period in seconds (e.g., 7 days = 604800)
    function setTransferRestrictions(
        uint256 lockupEndTimestamp,
        uint256 maxSharesPerInvestor,
        uint256 minHoldingPeriod
    ) external onlyOwner {
        TransferRestrictionsStorage.TransferRestrictionData storage restrictions = 
            TransferRestrictionsStorage.getTransferRestrictionsStorage();
        
        restrictions.lockupEndTimestamp = lockupEndTimestamp;
        restrictions.maxSharesPerInvestor = maxSharesPerInvestor;
        restrictions.minHoldingPeriod = minHoldingPeriod;
        
        // Enable whitelist by default when KYC is set
        if (address(kycRegistry) != address(0)) {
            restrictions.whitelistEnabled = true;
        }
        
        // Enable restrictions when parameters are set
        transferRestrictionsEnabled = true;
        
        emit TransferRestrictionsUpdated(lockupEndTimestamp, maxSharesPerInvestor, minHoldingPeriod);
    }

    /// @notice Pauses all transfers (emergency control)
    /// @dev Only owner or governance can call this function
    function pauseTransfers() external onlyOwner {
        TransferRestrictionsStorage.TransferRestrictionData storage restrictions = 
            TransferRestrictionsStorage.getTransferRestrictionsStorage();
        
        restrictions.isTransferPaused = true;
        transferRestrictionsEnabled = true; // Ensure restrictions are enabled when pausing
        
        emit TransfersPaused();
    }

    /// @notice Unpauses transfers
    /// @dev Only owner or governance can call this function
    function unpauseTransfers() external onlyOwner {
        TransferRestrictionsStorage.TransferRestrictionData storage restrictions = 
            TransferRestrictionsStorage.getTransferRestrictionsStorage();
        
        restrictions.isTransferPaused = false;
        
        emit TransfersUnpaused();
    }

    /// @notice Sets lockup end timestamp (governance pathway)
    /// @dev Only owner or governance can call this function
    /// @param lockupEndTimestamp Timestamp when lockup period ends (0 = no lockup)
    function setLockupEndTimestamp(uint256 lockupEndTimestamp) external onlyOwner {
        TransferRestrictionsStorage.TransferRestrictionData storage restrictions = 
            TransferRestrictionsStorage.getTransferRestrictionsStorage();
        
        restrictions.lockupEndTimestamp = lockupEndTimestamp;
        
        // Emit update event with current values
        emit TransferRestrictionsUpdated(
            lockupEndTimestamp, 
            restrictions.maxSharesPerInvestor, 
            restrictions.minHoldingPeriod
        );
    }

    /// @notice Sets maximum shares per investor (governance pathway)
    /// @dev Only owner or governance can call this function
    /// @param maxSharesPerInvestor Maximum shares per investor in basis points (e.g., 2000 = 20%)
    function setMaxSharesPerInvestor(uint256 maxSharesPerInvestor) external onlyOwner {
        TransferRestrictionsStorage.TransferRestrictionData storage restrictions = 
            TransferRestrictionsStorage.getTransferRestrictionsStorage();
        
        restrictions.maxSharesPerInvestor = maxSharesPerInvestor;
        
        // Emit update event with current values
        emit TransferRestrictionsUpdated(
            restrictions.lockupEndTimestamp, 
            maxSharesPerInvestor, 
            restrictions.minHoldingPeriod
        );
    }

    /// @notice Sets minimum holding period (governance pathway)
    /// @dev Only owner or governance can call this function
    /// @param minHoldingPeriod Minimum holding period in seconds (e.g., 7 days = 604800)
    function setMinHoldingPeriod(uint256 minHoldingPeriod) external onlyOwner {
        TransferRestrictionsStorage.TransferRestrictionData storage restrictions = 
            TransferRestrictionsStorage.getTransferRestrictionsStorage();
        
        restrictions.minHoldingPeriod = minHoldingPeriod;
        
        // Emit update event with current values
        emit TransferRestrictionsUpdated(
            restrictions.lockupEndTimestamp, 
            restrictions.maxSharesPerInvestor, 
            minHoldingPeriod
        );
    }

    /// @notice Checks if a transfer would be allowed under current restrictions
    /// @dev View function for frontend validation before user initiates transfer
    /// @param from Sender address
    /// @param to Recipient address
    /// @param amount Transfer amount
    /// @return allowed True if transfer would be allowed
    /// @return reason Human-readable reason if transfer would be blocked (empty if allowed)
    function isTransferAllowed(
        address from,
        address to,
        uint256 amount
    ) external view returns (bool allowed, string memory reason) {
        // If restrictions disabled, all transfers allowed
        if (!transferRestrictionsEnabled) {
            return (true, "");
        }
        
        // Mint and burn operations bypass restrictions
        if (from == address(0) || to == address(0)) {
            return (true, "");
        }
        
        TransferRestrictionsStorage.TransferRestrictionData storage restrictions = 
            TransferRestrictionsStorage.getTransferRestrictionsStorage();
        
        uint256 recipientBalance = balanceOf(to);
        uint256 supply = totalSupply();
        
        return TransferRestrictions.validateAllRestrictions(
            from,
            to,
            amount,
            recipientBalance,
            supply,
            restrictions
        );
    }

    /// @notice Override ERC20 _update to enforce transfer restrictions and track shareholder changes
    /// @dev SINGLE AGREEMENT MODEL: Works with the current agreement set during first mint.
    ///     Called during mint, burn, and transfer operations to maintain accurate shareholder tracking.
    ///     Uses O(1) membership checks with isShareholder mapping.
    ///     TRANSFER RESTRICTIONS: Validates restrictions before allowing transfer when enabled.
    ///     Restrictions are optional (disabled by default) and can be enabled per agreement.
    function _update(address from, address to, uint256 value) internal override {
        // Validate transfer restrictions BEFORE calling super._update
        // Only check restrictions for actual transfers (not mint/burn)
        if (transferRestrictionsEnabled && from != address(0) && to != address(0)) {
            // KYC checks (highest priority - enforced before other restrictions)
            if (address(kycRegistry) != address(0)) {
                require(kycRegistry.isWhitelisted(to), "Recipient not KYC verified");
                require(!kycRegistry.isBlacklisted(to), "Recipient is blacklisted");
                require(!kycRegistry.isBlacklisted(from), "Sender is blacklisted");
            }

            TransferRestrictionsStorage.TransferRestrictionData storage restrictions = 
                TransferRestrictionsStorage.getTransferRestrictionsStorage();
            
            // Get recipient balance for concentration limit check
            uint256 recipientBalance = balanceOf(to);
            uint256 totalSupply = totalSupply();
            
            // Validate all restrictions
            (bool allowed, string memory reason) = TransferRestrictions.validateAllRestrictions(
                from,
                to,
                value,
                recipientBalance,
                totalSupply,
                restrictions
            );
            
            if (!allowed) {
                emit TransferBlocked(from, to, value, reason);
                revert(reason);
            }
        }
        
        // Execute transfer after restriction validation
        super._update(from, to, value);
        
        // Update lastTransferTimestamp AFTER successful transfer/mint (for holding period enforcement)
        if (transferRestrictionsEnabled) {
            TransferRestrictionsStorage.TransferRestrictionData storage restrictions = 
                TransferRestrictionsStorage.getTransferRestrictionsStorage();
            
            // Set timestamp on mint (from == address(0)) if holding period is configured
            if (from == address(0) && restrictions.minHoldingPeriod > 0) {
                restrictions.lastTransferTimestamp[to] = block.timestamp;
            }
            // Update timestamp on transfer (from != address(0) && to != address(0))
            else if (from != address(0) && to != address(0)) {
                restrictions.lastTransferTimestamp[to] = block.timestamp;
            }
        }

        // Skip storage updates for mint/burn operations (handled in mintShares/burnShares)
        if (from == address(0) || to == address(0)) {
            return;
        }

        YieldSharesStorage.YieldSharesData storage data = _getYieldSharesStorage();

        // Update balances for the sender
        if (from != address(0) && data.shareholderShares[from] >= value) {
            data.shareholderShares[from] -= value;

            // Remove from shareholders array if balance becomes zero
            if (data.shareholderShares[from] == 0) {
                _removeShareholder(from);
            }
        }

        // Update balances for the receiver
        if (to != address(0)) {
            // Check shareholder limit before adding new shareholder
            bool wouldAddNewShareholder = !data.isShareholder[to] && value > 0;
            if (wouldAddNewShareholder) {
                require(validateShareholderLimit(data.shareholderCount + 1, MAX_SHAREHOLDERS), "Too many shareholders");
            }

            data.shareholderShares[to] += value;

            // Add to shareholders array if not already present (O(1) check)
            if (!data.isShareholder[to]) {
                data.shareholderAddresses.push(to);
                data.shareholderCount++;
                data.isShareholder[to] = true;
            }
        }
    }

    /// @dev Helper function to remove a shareholder from the array (swap-and-pop for gas efficiency)
    function _removeShareholder(address shareholder) internal {
        YieldSharesStorage.YieldSharesData storage data = _getYieldSharesStorage();
        address[] storage shareholders = data.shareholderAddresses;

        for (uint256 i = 0; i < shareholders.length; i++) {
            if (shareholders[i] == shareholder) {
                // Move the last element to this position and pop
                shareholders[i] = shareholders[shareholders.length - 1];
                shareholders.pop();
                data.shareholderCount--;
                data.isShareholder[shareholder] = false;
                break;
            }
        }
    }

    /// @notice Validates shareholder count limits to prevent excessive gas usage
    /// @dev Enforces reasonable limits on shareholder arrays to maintain gas efficiency
    /// @param currentCount Current number of shareholders
    /// @param maxShareholders Maximum allowed shareholders
    /// @return True if within limits, false if exceeded
    function validateShareholderLimit(uint256 currentCount, uint256 maxShareholders) internal pure returns (bool) {
        return currentCount <= maxShareholders;
    }

    /// @dev Internal helper to get storage pointer
    function _getYieldSharesStorage() internal pure returns (YieldSharesStorage.YieldSharesData storage) {
        return YieldSharesStorage.getYieldSharesStorage();
    }
}

