// React Context for global ETH/USD price state

import React, { createContext, useContext, useState, useEffect } from 'react';
import { fetchEthUsdPrice, startPricePolling, FALLBACK_ETH_USD_RATE } from '../services/priceService';

const PriceContext = createContext();

/**
 * PriceProvider component providing global ETH/USD price state
 * @param {Object} props - React props
 * @param {React.ReactNode} props.children - Child components
 * @returns {React.ReactElement} Provider component
 */
export function PriceProvider({ children }) {
  const [ethUsdPrice, setEthUsdPrice] = useState(FALLBACK_ETH_USD_RATE);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    let cleanup;

    // Fetch initial price
    fetchEthUsdPrice()
      .then((price) => {
        setEthUsdPrice(price);
        setLoading(false);
        setError(null);
      })
      .catch((err) => {
        console.warn('Using fallback ETH/USD price:', err.message);
        setEthUsdPrice(FALLBACK_ETH_USD_RATE);
        setLoading(false);
        setError(err);
      })
      .then(() => {
        // Start polling after initial fetch (whether successful or failed)
        cleanup = startPricePolling((newPrice) => {
          setEthUsdPrice(newPrice);
          setError(null); // Clear error when polling succeeds
        }, 60000);
      });

    // Cleanup polling on unmount
    return () => {
      if (cleanup) cleanup();
    };
  }, []);

  const value = {
    ethUsdPrice,
    loading,
    error,
    isUsingFallback: error !== null,
  };

  return (
    <PriceContext.Provider value={value}>
      {children}
    </PriceContext.Provider>
  );
}

/**
 * Custom hook to access ETH/USD price context
 * @returns {Object} Price context value
 * @throws {Error} When used outside PriceProvider
 */
export function useEthPrice() {
  const context = useContext(PriceContext);
  if (!context) {
    throw new Error('useEthPrice must be used within a PriceProvider');
  }
  return context;
}

export { PriceContext };









