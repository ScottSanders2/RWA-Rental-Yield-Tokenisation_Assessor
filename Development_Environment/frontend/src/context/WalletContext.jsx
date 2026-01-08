// Web WalletContext - MetaMask Integration via window.ethereum
// This is the proper web3 wallet integration for the React web frontend
// Mobile apps use WalletContext.native.jsx with WalletConnect

import React, { createContext, useContext, useState, useEffect } from 'react';
import { ethers } from 'ethers';

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
  const [chainId, setChainId] = useState(null);
  const [error, setError] = useState('');
  const [connecting, setConnecting] = useState(false);
  const [provider, setProvider] = useState(null);
  const [signer, setSigner] = useState(null);

  // Check if wallet is already connected on mount
  useEffect(() => {
    checkConnection();
    setupEventListeners();
  }, []);

  // Check if MetaMask is already connected
  const checkConnection = async () => {
    if (typeof window.ethereum !== 'undefined') {
      try {
        const accounts = await window.ethereum.request({ method: 'eth_accounts' });
        if (accounts.length > 0) {
          const chainIdHex = await window.ethereum.request({ method: 'eth_chainId' });
          const ethersProvider = new ethers.BrowserProvider(window.ethereum);
          const ethersSigner = await ethersProvider.getSigner();
          
          setProvider(ethersProvider);
          setSigner(ethersSigner);
          setAccount(accounts[0]);
          setChainId(parseInt(chainIdHex, 16));
          setConnected(true);
        }
      } catch (err) {
        console.error('Failed to check wallet connection:', err);
      }
    }
  };

  // Setup MetaMask event listeners
  const setupEventListeners = () => {
    if (typeof window.ethereum !== 'undefined') {
      // Account changed
      window.ethereum.on('accountsChanged', (accounts) => {
        if (accounts.length === 0) {
          // User disconnected
          disconnect();
        } else {
          setAccount(accounts[0]);
        }
      });

      // Chain changed
      window.ethereum.on('chainChanged', (chainIdHex) => {
        setChainId(parseInt(chainIdHex, 16));
        // Reload the page as recommended by MetaMask
        window.location.reload();
      });
    }
  };

  // Connect wallet
  const connect = async () => {
    setConnecting(true);
    setError('');
    
    try {
      // Check if MetaMask is installed
      if (typeof window.ethereum === 'undefined') {
        throw new Error('MetaMask not installed. Please install MetaMask browser extension to continue.');
      }

      // Request account access
      const accounts = await window.ethereum.request({ 
        method: 'eth_requestAccounts' 
      });
      
      const chainIdHex = await window.ethereum.request({ 
        method: 'eth_chainId' 
      });

      // Create ethers provider and signer
      const ethersProvider = new ethers.BrowserProvider(window.ethereum);
      const ethersSigner = await ethersProvider.getSigner();
      
      setProvider(ethersProvider);
      setSigner(ethersSigner);
      setAccount(accounts[0]);
      setChainId(parseInt(chainIdHex, 16));
      setConnected(true);
      
      return { success: true, account: accounts[0] };
    } catch (err) {
      const errorMessage = err.code === 4001 
        ? 'Connection rejected by user' 
        : err.message || 'Failed to connect wallet';
      setError(errorMessage);
      return { success: false, error: errorMessage };
    } finally {
      setConnecting(false);
    }
  };

  // Disconnect wallet
  const disconnect = async () => {
    setConnected(false);
    setAccount('');
    setProvider(null);
    setSigner(null);
    setError('');
  };

  // Sign message function (for KYC signature and other use cases)
  const signMessage = async (message) => {
    if (!connected || !signer) {
      throw new Error('Wallet not connected');
    }

    try {
      // Use ethers.js signer to sign message (EIP-191 standard)
      const signature = await signer.signMessage(message);
      return signature;
    } catch (err) {
      if (err.code === 4001) {
        throw new Error('Signature rejected by user');
      }
      throw new Error(err.message || 'Failed to sign message');
    }
  };

  // Switch network (useful for testing)
  const switchNetwork = async (targetChainId) => {
    try {
      await window.ethereum.request({
        method: 'wallet_switchEthereumChain',
        params: [{ chainId: ethers.toQuantity(targetChainId) }],
      });
      return { success: true };
    } catch (err) {
      // Chain not added to MetaMask
      if (err.code === 4902) {
        return { success: false, error: 'Network not added to MetaMask' };
      }
      return { success: false, error: err.message };
    }
  };

  const value = {
    // Connection state
    connected,
    connecting,
    account,
    chainId,
    error,
    provider,
    signer,
    
    // Actions
    connect,
    disconnect,
    signMessage,
    switchNetwork,
  };

  return (
    <WalletContext.Provider value={value}>
      {children}
    </WalletContext.Provider>
  );
};

export default WalletContext;

