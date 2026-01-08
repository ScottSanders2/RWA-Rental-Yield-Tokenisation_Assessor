// ETH/USD price feed service using CoinGecko API

const COINGECKO_API_URL = 'https://api.coingecko.com/api/v3/simple/price?ids=ethereum&vs_currencies=usd';
const FALLBACK_ETH_USD_RATE = 2000; // Fallback rate when API is unavailable
const REQUEST_TIMEOUT = 10000; // 10 second timeout

/**
 * Fetch current ETH/USD price from CoinGecko API with timeout and better error handling
 * @returns {Promise<number>} Current ETH/USD price
 */
export async function fetchEthUsdPrice() {
  try {
    // Create AbortController for timeout
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), REQUEST_TIMEOUT);

    const response = await fetch(COINGECKO_API_URL, {
      signal: controller.signal,
      headers: {
        'Accept': 'application/json',
        'User-Agent': 'RWA-Tokenisation-Platform/1.0'
      }
    });

    clearTimeout(timeoutId);

    if (!response.ok) {
      // Handle specific HTTP status codes
      if (response.status === 429) {
        throw new Error('CoinGecko API rate limit exceeded');
      } else if (response.status >= 500) {
        throw new Error('CoinGecko API server error');
      } else {
        throw new Error(`CoinGecko API error: ${response.status}`);
      }
    }

    const data = await response.json();
    const price = data.ethereum?.usd;

    if (!price || price <= 0 || price > 100000) {
      throw new Error(`Invalid price data received: ${price}`);
    }

    return price;
  } catch (error) {
    // Handle different types of errors
    if (error.name === 'AbortError') {
      console.warn('ETH/USD price fetch timed out, using fallback');
    } else if (error.message.includes('CORS') || error.message.includes('NetworkError')) {
      console.warn('CORS or network error fetching ETH/USD price, using fallback:', error.message);
    } else if (error.message.includes('rate limit')) {
      console.warn('CoinGecko rate limit hit, using fallback price');
    } else {
      console.warn('Failed to fetch ETH/USD price from CoinGecko, using fallback:', error.message);
    }

    return FALLBACK_ETH_USD_RATE;
  }
}

/**
 * Start polling for ETH/USD price updates with exponential backoff on rate limit
 * @param {Function} callback - Function to call with new price
 * @param {number} intervalMs - Polling interval in milliseconds (default: 300000 = 5 minutes)
 * @returns {Function} Cleanup function to stop polling
 */
export function startPricePolling(callback, intervalMs = 300000) {
  let currentInterval = intervalMs;
  let rateLimitCount = 0;
  let intervalId = null;

  const poll = async () => {
    try {
      const price = await fetchEthUsdPrice();
      
      // If successful, reset rate limit counter and interval
      if (price !== FALLBACK_ETH_USD_RATE) {
        rateLimitCount = 0;
        if (currentInterval !== intervalMs) {
          // Reset to normal interval
          currentInterval = intervalMs;
          clearInterval(intervalId);
          intervalId = setInterval(poll, currentInterval);
        }
      } else {
        // Likely rate limited, increase backoff
        rateLimitCount++;
        if (rateLimitCount > 2) {
          // After 3 failed attempts, back off to 10 minutes
          currentInterval = 600000; // 10 minutes
          clearInterval(intervalId);
          intervalId = setInterval(poll, currentInterval);
          console.warn('Increased polling interval to 10 minutes due to repeated rate limits');
        }
      }
      
      callback(price);
    } catch (error) {
      console.error('Price polling error:', error);
    }
  };

  // Fetch initial price
  poll();

  // Set up interval polling
  intervalId = setInterval(poll, currentInterval);

  // Return cleanup function
  return () => clearInterval(intervalId);
}

export { FALLBACK_ETH_USD_RATE };

