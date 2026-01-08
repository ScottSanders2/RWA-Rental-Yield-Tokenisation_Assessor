// Vitest test suite for formatter utility functions

import { describe, it, expect } from 'vitest';
import {
  formatWeiToEth,
  formatEthToWei,
  formatWeiToUsd,
  formatUsdToWei,
  formatDualCurrency,
  formatBasisPointsToPercent,
  formatPercentToBasisPoints,
  formatAddress,
  validateDeedHash,
  validateEthereumAddress,
} from '../utils/formatters';

describe('Formatter Utilities', () => {
  describe('formatWeiToEth', () => {
    it('converts wei to ETH correctly', () => {
      expect(formatWeiToEth('1000000000000000000')).toBe('1.0000'); // 1 ETH
      expect(formatWeiToEth('500000000000000000')).toBe('0.5000'); // 0.5 ETH
      expect(formatWeiToEth(10000000000000000000n)).toBe('10.0000'); // 10 ETH
    });

    it('handles zero and small values', () => {
      expect(formatWeiToEth('0')).toBe('0.0000');
      expect(formatWeiToEth('1000000000000000')).toBe('0.0010'); // 0.001 ETH
    });

    it('handles invalid inputs', () => {
      expect(formatWeiToEth(null)).toBe('0.0000');
      expect(formatWeiToEth(undefined)).toBe('0.0000');
      expect(formatWeiToEth('')).toBe('0.0000');
    });
  });

  describe('formatEthToWei', () => {
    it('converts ETH to wei correctly', () => {
      expect(formatEthToWei('1')).toBe('1000000000000000000');
      expect(formatEthToWei('0.5')).toBe('500000000000000000');
      expect(formatEthToWei('10.1234')).toBe('10123400000000000000');
    });

    it('handles zero values', () => {
      expect(formatEthToWei('0')).toBe('0');
    });

    it('handles invalid inputs', () => {
      expect(formatEthToWei(null)).toBe('0');
      expect(formatEthToWei(undefined)).toBe('0');
      expect(formatEthToWei('')).toBe('0');
    });
  });

  describe('formatWeiToUsd', () => {
    it('converts wei to USD correctly with live price', () => {
      // 1 ETH = $2000, so 1 ETH in wei = $2000
      expect(formatWeiToUsd('1000000000000000000', 2000)).toBe('$2,000.00');
      // 0.5 ETH in wei = $1000
      expect(formatWeiToUsd('500000000000000000', 2000)).toBe('$1,000.00');
      // 25,000 ETH in wei = $50,000,000
      expect(formatWeiToUsd('25000000000000000000000', 2000)).toBe('$50,000,000.00');
    });

    it('handles different price points', () => {
      // Same amount, different price
      expect(formatWeiToUsd('1000000000000000000', 2500)).toBe('$2,500.00');
      expect(formatWeiToUsd('1000000000000000000', 1500)).toBe('$1,500.00');
    });

    it('handles invalid inputs', () => {
      expect(formatWeiToUsd(null, 2000)).toBe('$0.00');
      expect(formatWeiToUsd('1000000000000000000', null)).toBe('$0.00');
    });
  });

  describe('formatUsdToWei', () => {
    it('converts USD to wei correctly with live price', () => {
      // $2000 at $2000/ETH = 1 ETH in wei
      expect(formatUsdToWei('2000', 2000)).toBe('1000000000000000000');
      // $1000 at $2000/ETH = 0.5 ETH in wei
      expect(formatUsdToWei('1000', 2000)).toBe('500000000000000000');
      // $50,000 at $2000/ETH = 25 ETH in wei
      expect(formatUsdToWei('50000', 2000)).toBe('25000000000000000000');
    });

    it('handles different price points', () => {
      // Same USD amount, different ETH price
      expect(formatUsdToWei('2000', 2500)).toBe('800000000000000000'); // 0.8 ETH
      expect(formatUsdToWei('2000', 1500)).toBe('1333333333333333300'); // ~1.333 ETH
    });

    it('handles invalid inputs', () => {
      expect(formatUsdToWei(null, 2000)).toBe('0');
      expect(formatUsdToWei('1000', null)).toBe('0');
    });
  });

  describe('formatDualCurrency', () => {
    it('formats dual currency display correctly', () => {
      // 1 ETH in wei at $2000/ETH
      expect(formatDualCurrency('1000000000000000000', 2000))
        .toBe('$2,000.00 USD ≈ 1.0000 ETH at $2,000/ETH');

      // 25,000 ETH in wei at $2000/ETH
      expect(formatDualCurrency('25000000000000000000000', 2000))
        .toBe('$50,000,000.00 USD ≈ 25,000.0000 ETH at $2,000/ETH');
    });

    it('handles invalid inputs', () => {
      expect(formatDualCurrency(null, 2000)).toBe('$0.00 USD ≈ 0.0000 ETH');
      expect(formatDualCurrency('1000000000000000000', null)).toBe('$0.00 USD ≈ 0.0000 ETH');
    });
  });

  describe('formatBasisPointsToPercent', () => {
    it('converts basis points to percentage correctly', () => {
      expect(formatBasisPointsToPercent(1200)).toBe('12.00%');
      expect(formatBasisPointsToPercent(500)).toBe('5.00%');
      expect(formatBasisPointsToPercent(1)).toBe('0.01%');
      expect(formatBasisPointsToPercent(10000)).toBe('100.00%');
    });

    it('handles zero and invalid inputs', () => {
      expect(formatBasisPointsToPercent(0)).toBe('0.00%');
      expect(formatBasisPointsToPercent(null)).toBe('0.00%');
      expect(formatBasisPointsToPercent(undefined)).toBe('0.00%');
    });
  });

  describe('formatPercentToBasisPoints', () => {
    it('converts percentage to basis points correctly', () => {
      expect(formatPercentToBasisPoints('12')).toBe(1200);
      expect(formatPercentToBasisPoints('5.5')).toBe(550);
      expect(formatPercentToBasisPoints('0.01')).toBe(1);
      expect(formatPercentToBasisPoints('100')).toBe(10000);
    });

    it('handles zero and invalid inputs', () => {
      expect(formatPercentToBasisPoints('0')).toBe(0);
      expect(formatPercentToBasisPoints(null)).toBe(0);
      expect(formatPercentToBasisPoints(undefined)).toBe(0);
      expect(formatPercentToBasisPoints('')).toBe(0);
    });
  });

  describe('formatAddress', () => {
    it('truncates Ethereum addresses correctly', () => {
      expect(formatAddress('0x1234567890123456789012345678901234567890'))
        .toBe('0x1234...7890');
      expect(formatAddress('0xabcdefabcdefabcdefabcdefabcdefabcdefabcd'))
        .toBe('0xabcd...abcd');
    });

    it('handles short addresses', () => {
      expect(formatAddress('0x1234')).toBe('0x1234');
      expect(formatAddress('')).toBe('');
      expect(formatAddress(null)).toBe(null);
    });
  });

  describe('validateDeedHash', () => {
    it('validates correct deed hash format', () => {
      expect(validateDeedHash('0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef')).toBe(true);
      expect(validateDeedHash('0xabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcd')).toBe(true);
    });

    it('rejects invalid deed hash formats', () => {
      expect(validateDeedHash('1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef')).toBe(false); // missing 0x
      expect(validateDeedHash('0x1234')).toBe(false); // too short
      expect(validateDeedHash('0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcde')).toBe(false); // too short
      expect(validateDeedHash('0xgggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg')).toBe(false); // invalid hex
      expect(validateDeedHash('')).toBe(false); // empty
      expect(validateDeedHash(null)).toBe(false); // null
    });
  });

  describe('validateEthereumAddress', () => {
    it('validates correct Ethereum addresses', () => {
      expect(validateEthereumAddress('0x1234567890123456789012345678901234567890')).toBe(true);
      expect(validateEthereumAddress('0xabcdefabcdefabcdefabcdefabcdefabcdefabcd')).toBe(true);
      expect(validateEthereumAddress('0x0000000000000000000000000000000000000000')).toBe(true);
    });

    it('rejects invalid Ethereum addresses', () => {
      expect(validateEthereumAddress('0x123456789012345678901234567890123456789')).toBe(false); // too short
      expect(validateEthereumAddress('0x12345678901234567890123456789012345678901')).toBe(false); // too long
      expect(validateEthereumAddress('1234567890123456789012345678901234567890')).toBe(true); // ethers accepts without 0x prefix
      expect(validateEthereumAddress('0xgggggggggggggggggggggggggggggggggggggggg')).toBe(false); // invalid hex
      expect(validateEthereumAddress('')).toBe(false); // empty
      expect(validateEthereumAddress(null)).toBe(false); // null
    });
  });

  describe('USD/ETH conversion round-trip accuracy', () => {
    it('maintains precision within acceptable tolerance', () => {
      const testCases = [
        { usd: '50000', ethPrice: 2000 }, // $50,000 at $2000/ETH
        { usd: '100000', ethPrice: 2500 }, // $100,000 at $2500/ETH
        { usd: '25000', ethPrice: 1500 }, // $25,000 at $1500/ETH
      ];

      testCases.forEach(({ usd, ethPrice }) => {
        // USD -> wei
        const wei = formatUsdToWei(usd, ethPrice);
        // wei -> USD
        const usdBack = formatWeiToUsd(wei, ethPrice);

        // Remove dollar sign and commas for comparison
        const usdBackClean = usdBack.replace(/[$,]/g, '');
        const originalUsd = parseFloat(usd);

        // Should be within $0.01 tolerance
        expect(Math.abs(parseFloat(usdBackClean) - originalUsd)).toBeLessThan(0.01);
      });
    });
  });
});

