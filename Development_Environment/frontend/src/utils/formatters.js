// Utility functions for data formatting and conversion with USD-first approach
// Stub implementations without Web3 dependencies for basic app functionality

// Static ETH/USD exchange rate for consistent financial calculations
// This prevents fluctuations in displayed capital values due to live market prices
export const STATIC_ETH_USD_RATE = 2000;

/**
 * Convert wei value to ETH
 * @param {string|number} weiValue - Wei value to convert
 * @returns {string} ETH value formatted to 4 decimal places
 */
export function formatWeiToEth(weiValue) {
  if (!weiValue) return '0.0000';
  // Stub implementation: convert wei to ETH (1 ETH = 10^18 wei)
  const ethValue = Number(weiValue) / 1000000000000000000;
  return ethValue.toLocaleString('en-US', { minimumFractionDigits: 4, maximumFractionDigits: 4 });
}

/**
 * Convert ETH value to wei
 * @param {string|number} ethValue - ETH value to convert
 * @returns {string} Wei value as string
 */
export function formatEthToWei(ethValue) {
  if (!ethValue) return '0';
  // Stub implementation: convert ETH to wei (1 ETH = 10^18 wei)
  const weiValue = Number(ethValue) * 1000000000000000000;
  return weiValue.toString();
}

/**
 * Convert wei value to USD using STATIC ETH/USD price
 * @param {string|number} weiValue - Wei value to convert
 * @param {number} ethUsdPrice - DEPRECATED: Not used, kept for backward compatibility
 * @returns {string} USD value formatted with thousand separators and 2 decimal places
 */
export function formatWeiToUsd(weiValue, ethUsdPrice) {
  if (!weiValue) return '$0.00';

  // Convert wei to ETH then to USD using STATIC rate
  const ethValue = Number(weiValue) / 1000000000000000000;
  const usdValue = ethValue * STATIC_ETH_USD_RATE;

  return new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency: 'USD',
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  }).format(usdValue);
}

/**
 * Convert USD value to wei using STATIC ETH/USD price
 * @param {string|number} usdValue - USD value to convert
 * @param {number} ethUsdPrice - DEPRECATED: Not used, kept for backward compatibility
 * @returns {string} Wei value as string
 */
export function formatUsdToWei(usdValue, ethUsdPrice) {
  if (!usdValue) return '0';

  const ethValue = parseFloat(usdValue) / STATIC_ETH_USD_RATE;
  return formatEthToWei(ethValue);
}

/**
 * Format dual currency display showing USD primary and ETH secondary
 * @param {string|number} weiValue - Wei value to display
 * @param {number} ethUsdPrice - Current ETH/USD price
 * @returns {string} Formatted string like '$50,000.00 USD ≈ 25.0000 ETH at $2,000/ETH'
 */
export function formatDualCurrency(weiValue, ethUsdPrice) {
  if (!weiValue || !ethUsdPrice) return '$0.00 USD ≈ 0.0000 ETH';

  const usdFormatted = formatWeiToUsd(weiValue, ethUsdPrice);
  // Stub implementation: convert wei to ETH
  const ethValue = Number(weiValue) / 1000000000000000000;
  const ethFormatted = ethValue.toLocaleString('en-US', { minimumFractionDigits: 4, maximumFractionDigits: 4 });

  return `${usdFormatted} USD ≈ ${ethFormatted} ETH at $${ethUsdPrice.toLocaleString()}/ETH`;
}

/**
 * Convert basis points to percentage
 * @param {number} basisPoints - Value in basis points
 * @returns {string} Percentage formatted to 2 decimal places
 */
export function formatBasisPointsToPercent(basisPoints) {
  if (!basisPoints) return '0.00%';
  return `${(basisPoints / 100).toFixed(2)}%`;
}

/**
 * Convert percentage to basis points
 * @param {string|number} percent - Percentage value
 * @returns {number} Value in basis points
 */
export function formatPercentToBasisPoints(percent) {
  if (!percent) return 0;
  return Math.round(parseFloat(percent) * 100);
}

/**
 * Truncate Ethereum address for display
 * @param {string} address - Full Ethereum address
 * @returns {string} Truncated address like '0x1234...5678'
 */
export function formatAddress(address) {
  if (!address || address.length < 10) return address;
  return `${address.slice(0, 6)}...${address.slice(-4)}`;
}

/**
 * Truncate transaction hash for display
 * @param {string} hash - Full transaction hash
 * @returns {string} Truncated hash like '0x1234...5678'
 */
export function formatTxHash(hash) {
  if (!hash || hash.length < 10) return hash;
  return `${hash.slice(0, 6)}...${hash.slice(-4)}`;
}

/**
 * Format ISO timestamp to readable date
 * @param {string} timestamp - ISO timestamp
 * @returns {string} Formatted date string
 */
export function formatDate(timestamp) {
  if (!timestamp) return '';
  return new Date(timestamp).toLocaleDateString('en-US', {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  });
}

/**
 * Validate deed hash format (0x-prefixed 66-character hex)
 * @param {string} hash - Hash to validate
 * @returns {boolean} True if valid format
 */
export function validateDeedHash(hash) {
  return /^0x[a-fA-F0-9]{64}$/.test(hash);
}

/**
 * Validate Ethereum address format
 * @param {string} address - Address to validate
 * @returns {boolean} True if valid Ethereum address
 */
export function validateEthereumAddress(address) {
  // Stub implementation: basic Ethereum address validation
  return /^0x[a-fA-F0-9]{40}$/.test(address);
}

