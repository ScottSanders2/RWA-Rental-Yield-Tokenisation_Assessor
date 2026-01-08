import React, {createContext, useContext, useState, useEffect} from 'react';
import AsyncStorage from '@react-native-async-storage/async-storage';
import {fetchEthUsdPrice, startPricePolling, FALLBACK_ETH_USD_RATE} from '../services/priceService';

const PriceContext = createContext();

export const PriceProvider = ({children}) => {
  const [ethUsdPrice, setEthUsdPrice] = useState(FALLBACK_ETH_USD_RATE);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    const loadPrice = async () => {
      try {
        // Load cached price from AsyncStorage and use it immediately
        const cachedPrice = await AsyncStorage.getItem('ethUsdPrice');
        if (cachedPrice) {
          setEthUsdPrice(parseFloat(cachedPrice));
        }
        
        // Set loading to false IMMEDIATELY so UI renders without waiting for fetch
        setLoading(false);

        // Fetch fresh price in background (won't block UI)
        const price = await fetchEthUsdPrice();
        setEthUsdPrice(price);
        await AsyncStorage.setItem('ethUsdPrice', price.toString());
      } catch (err) {
        setError(err.message);
        setEthUsdPrice(FALLBACK_ETH_USD_RATE);
        setLoading(false);
      }
    };

    loadPrice();

    // Start polling for price updates
    const stopPolling = startPricePolling(async (price) => {
      setEthUsdPrice(price);
      await AsyncStorage.setItem('ethUsdPrice', price.toString());
    });

    return stopPolling;
  }, []);

  const isUsingFallback = ethUsdPrice === FALLBACK_ETH_USD_RATE;

  const value = {
    ethUsdPrice,
    loading,
    error,
    isUsingFallback,
  };

  return (
    <PriceContext.Provider value={value}>
      {children}
    </PriceContext.Provider>
  );
};

export const useEthPrice = () => {
  const context = useContext(PriceContext);
  if (!context) {
    throw new Error('useEthPrice must be used within a PriceProvider');
  }
  return context;
};
// This is the React Native version of PriceContext using AsyncStorage for persistence (replaces localStorage from web version), maintaining identical API for seamless code sharing between web and mobile platforms.



