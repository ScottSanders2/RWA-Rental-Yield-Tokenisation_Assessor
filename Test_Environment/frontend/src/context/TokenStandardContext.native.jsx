import React, {createContext, useContext, useState, useEffect} from 'react';
import AsyncStorage from '@react-native-async-storage/async-storage';

const TokenStandardContext = createContext();

export const TokenStandardProvider = ({children}) => {
  const [tokenStandard, setTokenStandard] = useState('ERC1155');

  useEffect(() => {
    const loadTokenStandard = async () => {
      try {
        const stored = await AsyncStorage.getItem('tokenStandard');
        if (stored) {
          setTokenStandard(stored);
        }
      } catch (error) {
        console.error('Error loading token standard:', error);
      }
    };

    loadTokenStandard();
  }, []);

  useEffect(() => {
    const saveTokenStandard = async () => {
      try {
        await AsyncStorage.setItem('tokenStandard', tokenStandard);
      } catch (error) {
        console.error('Error saving token standard:', error);
      }
    };

    saveTokenStandard();
  }, [tokenStandard]);

  const isERC1155 = tokenStandard === 'ERC1155';

  const getLabel = () => {
    switch (tokenStandard) {
      case 'ERC721':
        return 'ERC-721 Only';
      case 'HYBRID':
        return 'ERC-721 + ERC-20 (Separate Contracts)';
      case 'ERC1155':
        return 'ERC-1155 (Combined Contract)';
      default:
        return 'ERC-721 + ERC-20 (Separate Contracts)';
    }
  };

  const getDescription = () => {
    switch (tokenStandard) {
      case 'ERC721':
        return 'Single ERC-721 contract for property NFTs only. Simple ownership tokenisation without fungible yield shares.';
      case 'HYBRID':
        return 'Separate ERC-721 contract for property NFTs and ERC-20 contract for yield shares. Better composability with existing DeFi protocols.';
      case 'ERC1155':
        return 'Single ERC-1155 contract manages both property ownership (NFT) and yield shares (fungible tokens). More gas-efficient for complex transactions.';
      default:
        return 'Separate ERC-721 contract for property NFTs and ERC-20 contract for yield shares. Better composability with existing DeFi protocols.';
    }
  };

  const value = {
    tokenStandard,
    setTokenStandard,
    isERC1155,
    getLabel,
    getDescription,
  };

  return (
    <TokenStandardContext.Provider value={value}>
      {children}
    </TokenStandardContext.Provider>
  );
};

export const useTokenStandard = () => {
  const context = useContext(TokenStandardContext);
  if (!context) {
    throw new Error('useTokenStandard must be used within a TokenStandardProvider');
  }
  return context;
};
// This is the React Native version using AsyncStorage for persistence, maintaining explicit ERC-20 labeling from web version for consistency across platforms.


