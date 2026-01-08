// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

import "./storage/YieldSharesStorage.sol";
import "./storage/TransferRestrictionsStorage.sol";
import "./libraries/YieldDistribution.sol";
import "./libraries/YieldCalculations.sol";
import "./libraries/TransferRestrictions.sol";

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
