// Web-compatible WalletContext stub (for KYC components)
// Note: This is a temporary stub to allow KYC components to load
// Full web3 wallet integration with MetaMask/WalletConnect Web will be implemented in a future iteration

import React, { createContext, useContext, useState } from 'react';

const WalletContext = createContext();

export const useWallet = () => {
  const context = useContext(WalletContext);
  if (!context) {
    throw new Error('useWallet must be used within a WalletProvider');
  }
  return context;
};

export const WalletProvider = ({ children }) => {
  const [connected, setConnected] = useState(false);
  const [account, setAccount] = useState('');
  const [chainId, setChainId] = useState(1);
  const [error, setError] = useState('');
  const [connecting, setConnecting] = useState(false);

  // Mock connect function
  const connect = async () => {
    setConnecting(true);
    setError('');
    
    try {
      // Check if MetaMask is installed
      if (typeof window.ethereum !== 'undefined') {
        const accounts = await window.ethereum.request({ 
          method: 'eth_requestAccounts' 
        });
        const chainIdHex = await window.ethereum.request({ 
          method: 'eth_chainId' 
        });
        
        setAccount(accounts[0]);
        setChainId(parseInt(chainIdHex, 16));
        setConnected(true);
        
        return { success: true };
      } else {
        throw new Error('MetaMask not installed. Please install MetaMask to use this feature.');
      }
    } catch (err) {
      const errorMessage = err.message || 'Failed to connect wallet';
      setError(errorMessage);
      return { success: false, error: errorMessage };
    } finally {
      setConnecting(false);
    }
  };

  // Disconnect function
  const disconnect = async () => {
    setConnected(false);
    setAccount('');
    setError('');
  };

  // Sign message function (for KYC signature)
  const signMessage = async (message) => {
    if (!connected || !account) {
      throw new Error('Wallet not connected');
    }

    try {
      if (typeof window.ethereum !== 'undefined') {
        const signature = await window.ethereum.request({
          method: 'personal_sign',
          params: [message, account],
        });
        
        return signature;
      } else {
        throw new Error('MetaMask not available');
      }
    } catch (err) {
      throw new Error(err.message || 'Failed to sign message');
    }
  };

  const value = {
    // Connection state
    connected,
    connecting,
    account,
    chainId,
    error,
    
    // Actions
    connect,
    disconnect,
    signMessage,
  };

  return (
    <WalletContext.Provider value={value}>
      {children}
    </WalletContext.Provider>
  );
};

export default WalletContext;

