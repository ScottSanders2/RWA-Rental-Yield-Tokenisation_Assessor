// Production WalletConnect v2 implementation using SignClient (works in Expo Go)
import React, {createContext, useContext, useState, useEffect} from 'react';
import SignClient from '@walletconnect/sign-client';
import {getSdkError} from '@walletconnect/utils';
import AsyncStorage from '@react-native-async-storage/async-storage';
import {Linking} from 'react-native';
import {WALLETCONNECT_PROJECT_ID} from '@env';

const WalletContext = createContext();

const STORAGE_KEY = '@walletconnect_session';

// WalletConnect metadata
const metadata = {
  name: 'RWA Tokenization Platform',
  description: 'Real Estate Rental Yield Tokenization for Financial Inclusion',
  url: 'https://rwa-tokenization.com',
  icons: ['https://rwa-tokenization.com/icon.png'],
};

export const WalletProvider = ({children}) => {
  const [signClient, setSignClient] = useState(null);
  const [session, setSession] = useState(null);
  const [connected, setConnected] = useState(false);
  const [account, setAccount] = useState('');
  const [chainId, setChainId] = useState(1);
  const [error, setError] = useState('');
  const [connecting, setConnecting] = useState(false);
  const [mockMode, setMockMode] = useState(false);

  // Initialize SignClient on mount
  useEffect(() => {
    initializeSignClient();
  }, []);

  const initializeSignClient = async () => {
    try {
      const projectId = WALLETCONNECT_PROJECT_ID || 'c0eadd099105a31f3e91753a3fcf4997';
      
      if (!projectId) {
        console.warn('WalletConnect Project ID not configured');
        setError('WalletConnect not configured');
        return;
      }

      console.log('Initializing WalletConnect SignClient with Project ID:', projectId);

      const client = await SignClient.init({
        projectId,
        metadata,
        relayUrl: 'wss://relay.walletconnect.com',
      });

      setSignClient(client);
      console.log('SignClient initialized successfully');

      // Set up event handlers
      client.on('session_event', handleSessionEvent);
      client.on('session_update', handleSessionUpdate);
      client.on('session_delete', handleSessionDelete);

      // Restore previous session if exists
      await restoreSession(client);
    } catch (err) {
      console.error('Failed to initialize SignClient:', err);
      setError('Failed to initialize WalletConnect: ' + err.message);
    }
  };

  const handleSessionEvent = (event) => {
    console.log('Session event:', event);
  };

  const handleSessionUpdate = ({topic, params}) => {
    console.log('Session updated:', topic, params);
    const {namespaces} = params;
    const currentSession = signClient.session.get(topic);
    const updatedSession = {...currentSession, namespaces};
    setSession(updatedSession);
    onSessionConnected(updatedSession);
  };

  const handleSessionDelete = () => {
    console.log('Session deleted');
    reset();
  };

  const reset = async () => {
    setSession(null);
    setConnected(false);
    setAccount('');
    setChainId(1);
    await AsyncStorage.removeItem(STORAGE_KEY);
  };

  const onSessionConnected = (sessionData) => {
    try {
      const allNamespaceAccounts = Object.values(sessionData.namespaces)
        .map((namespace) => namespace.accounts)
        .flat();
      
      if (allNamespaceAccounts.length > 0) {
        const address = allNamespaceAccounts[0].split(':')[2];
        const chain = parseInt(allNamespaceAccounts[0].split(':')[1]);
        
        setSession(sessionData);
        setConnected(true);
        setAccount(address);
        setChainId(chain);
        
        // Persist session
        AsyncStorage.setItem(STORAGE_KEY, JSON.stringify(sessionData));
        
        console.log('Wallet connected:', address, 'Chain:', chain);
      }
    } catch (err) {
      console.error('Failed to process session:', err);
      setError('Failed to connect: ' + err.message);
    }
  };

  const restoreSession = async (client) => {
    try {
      const sessionData = await AsyncStorage.getItem(STORAGE_KEY);
      if (sessionData) {
        const parsedSession = JSON.parse(sessionData);
        
        // Check if session is still active
        const activeSessions = client.session.getAll();
        const activeSession = activeSessions.find(s => s.topic === parsedSession.topic);
        
        if (activeSession) {
          onSessionConnected(activeSession);
          console.log('Session restored successfully');
        } else {
          // Session expired, clear storage
          await AsyncStorage.removeItem(STORAGE_KEY);
        }
      }
    } catch (err) {
      console.error('Failed to restore session:', err);
      await AsyncStorage.removeItem(STORAGE_KEY);
    }
  };

  const connectWallet = async () => {
    // Mock mode for simulator testing
    if (mockMode) {
      setConnecting(true);
      setError('');
      
        try {
          await new Promise(resolve => setTimeout(resolve, 1000));

          const mockAddress = '0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb0';
          setConnected(true);
          setAccount(mockAddress);
          setChainId(1);

          console.log('Mock wallet connected:', mockAddress);
      } catch (err) {
        setError('Mock connection failed: ' + err.message);
      } finally {
        setConnecting(false);
      }
      return;
    }

    if (!signClient) {
      setError('WalletConnect not initialized');
      return;
    }

    if (connected) {
      console.log('Already connected');
      return;
    }

    setConnecting(true);
    setError('');

    try {
      console.log('Creating WalletConnect pairing...');

      // Create connection
      const {uri, approval} = await signClient.connect({
        optionalNamespaces: {
          eip155: {
            methods: [
              'eth_sendTransaction',
              'eth_signTransaction',
              'eth_sign',
              'personal_sign',
              'eth_signTypedData',
            ],
            chains: ['eip155:1'], // Ethereum mainnet
            events: ['chainChanged', 'accountsChanged'],
          },
        },
      });

      // Display URI to user (for now, just log it and open wallet)
      if (uri) {
        console.log('WalletConnect URI:', uri);
        console.log('To connect: Copy this URI and paste into your mobile wallet app');
        console.log('Or scan QR code generated from this URI on a real device');
        
        // Try to open MetaMask or any wallet app with the URI
        // This will fail in iOS Simulator (expected) but work on real device
        const metamaskUrl = `metamask://wc?uri=${encodeURIComponent(uri)}`;
        
        try {
          const canOpen = await Linking.canOpenURL(metamaskUrl);
          if (canOpen) {
            await Linking.openURL(metamaskUrl);
          } else {
            console.log('No wallet app found. This is expected in iOS Simulator.');
            console.log('On a real device, this would open your wallet app automatically.');
          }
        } catch (e) {
          console.log('Wallet app not available in simulator - this is normal');
        }
      }

      // Wait for session approval with timeout
      // In simulator, this will timeout since no wallet app can approve
      console.log('Waiting for wallet approval...');
      console.log('SIMULATOR MODE: Approval will timeout in 10 seconds');
      
      const approvalPromise = approval();
      const timeoutPromise = new Promise((_, reject) => 
        setTimeout(() => reject(new Error('Connection timeout - no wallet responded')), 10000)
      );
      
      const sessionData = await Promise.race([approvalPromise, timeoutPromise]);
      console.log('Session approved:', sessionData);
      
      onSessionConnected(sessionData);
    } catch (err) {
      console.error('Failed to connect wallet:', err);
      if (err.message.includes('timeout')) {
        setError('Connection timeout: No wallet app responded. Use a real device with MetaMask/Trust Wallet installed, or enable mock mode.');
      } else {
        setError('Failed to connect wallet: ' + err.message);
      }
    } finally {
      setConnecting(false);
    }
  };

  const disconnectWallet = async () => {
    if (!signClient || !session) {
      await reset();
      return;
    }

    try {
      await signClient.disconnect({
        topic: session.topic,
        reason: getSdkError('USER_DISCONNECTED'),
      });
      await reset();
      console.log('Wallet disconnected');
    } catch (err) {
      console.error('Failed to disconnect wallet:', err);
      setError('Failed to disconnect: ' + err.message);
      await reset(); // Force reset even if disconnect fails
    }
  };

  const sendTransaction = async (transaction) => {
    if (!signClient || !session || !connected) {
      throw new Error('Wallet not connected');
    }

    try {
      const result = await signClient.request({
        topic: session.topic,
        chainId: `eip155:${chainId}`,
        request: {
          method: 'eth_sendTransaction',
          params: [transaction],
        },
      });
      return result;
    } catch (err) {
      console.error('Failed to send transaction:', err);
      throw err;
    }
  };

  const signMessage = async (message) => {
    if (!signClient || !session || !connected) {
      throw new Error('Wallet not connected');
    }

    try {
      const result = await signClient.request({
        topic: session.topic,
        chainId: `eip155:${chainId}`,
        request: {
          method: 'personal_sign',
          params: [message, account],
        },
      });
      return result;
    } catch (err) {
      console.error('Failed to sign message:', err);
      throw err;
    }
  };

  const enableMockMode = () => {
    console.log('Mock mode enabled - wallet will connect without real wallet app');
    setMockMode(true);
  };

  const disableMockMode = () => {
    console.log('Mock mode disabled - will use real WalletConnect');
    setMockMode(false);
  };

  const value = {
    signClient,
    session,
    connected,
    account,
    chainId,
    signer: null, // SignClient doesn't provide direct signer, use sendTransaction/signMessage
    error,
    connecting,
    mockMode,
    connectWallet,
    disconnectWallet,
    sendTransaction,
    signMessage,
    enableMockMode,
    disableMockMode,
  };

  return (
    <WalletContext.Provider value={value}>{children}</WalletContext.Provider>
  );
};

export const useWallet = () => {
  const context = useContext(WalletContext);
  if (!context) {
    throw new Error('useWallet must be used within WalletProvider');
  }
  return context;
};

export default WalletContext;
