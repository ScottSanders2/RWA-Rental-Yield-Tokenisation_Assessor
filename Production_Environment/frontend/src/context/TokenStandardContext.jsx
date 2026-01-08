// React Context for global token standard preference with explicit ERC-20 labeling
// 
// Configuration Priority (highest to lowest):
// 1. URL query parameter: ?tokenStandard=ERC721 or ?tokenStandard=ERC1155
// 2. localStorage (persisted from previous session)
// 3. Config file: /token_standard_config.json (set by demo_variant_switch.sh)
// 4. Default: ERC721

import React, { createContext, useContext, useState, useEffect } from 'react';

const TokenStandardContext = createContext();

/**
 * Get initial token standard from various sources
 * @returns {string} Initial token standard (ERC721 or ERC1155)
 */
function getInitialTokenStandard() {
  // 1. Check URL query parameter first (highest priority)
  const urlParams = new URLSearchParams(window.location.search);
  const urlStandard = urlParams.get('tokenStandard');
  if (urlStandard === 'ERC721' || urlStandard === 'ERC1155') {
    return urlStandard;
  }
  
  // 2. Check localStorage (persisted from previous session)
  const storedStandard = localStorage.getItem('tokenStandard');
  if (storedStandard === 'ERC721' || storedStandard === 'ERC1155') {
    return storedStandard;
  }
  
  // 3. Default to ERC721 (config file will be checked async)
  return 'ERC721';
}

/**
 * TokenStandardProvider component providing global token standard state
 * @param {Object} props - React props
 * @param {React.ReactNode} props.children - Child components
 * @returns {React.ReactElement} Provider component
 */
export function TokenStandardProvider({ children }) {
  const [tokenStandard, setTokenStandard] = useState(getInitialTokenStandard);
  const [configLoaded, setConfigLoaded] = useState(false);

  // Load config file on mount (only if no localStorage or URL param)
  useEffect(() => {
    const loadConfigFile = async () => {
      // Skip if URL param or localStorage already set the value
      const urlParams = new URLSearchParams(window.location.search);
      const urlStandard = urlParams.get('tokenStandard');
      const storedStandard = localStorage.getItem('tokenStandard');
      
      if (urlStandard || storedStandard) {
        setConfigLoaded(true);
        return;
      }
      
      // Try to load config file (set by demo_variant_switch.sh)
      try {
        const response = await fetch('/token_standard_config.json');
        if (response.ok) {
          const config = await response.json();
          if (config.tokenStandard === 'ERC721' || config.tokenStandard === 'ERC1155') {
            console.log(`[TokenStandardContext] Loaded standard from config file: ${config.tokenStandard}`);
            setTokenStandard(config.tokenStandard);
          }
        }
      } catch (error) {
        // Config file not found or invalid - use default
        console.log('[TokenStandardContext] No config file found, using default ERC721');
      }
      setConfigLoaded(true);
    };
    
    loadConfigFile();
  }, []);

  // Persist to localStorage when tokenStandard changes
  useEffect(() => {
    localStorage.setItem('tokenStandard', tokenStandard);
  }, [tokenStandard]);

  const value = {
    tokenStandard,
    setTokenStandard,
    isERC1155: tokenStandard === 'ERC1155',
    getLabel: () => tokenStandard === 'ERC721'
      ? 'ERC-721 + ERC-20 (Separate Contracts)'
      : 'ERC-1155 (Combined Contract)',
    getDescription: () => tokenStandard === 'ERC721'
      ? 'Uses separate ERC-721 contract for property NFTs and ERC-20 contract for yield tokens. Clear separation of concerns and independent upgradeability.'
      : 'Uses single ERC-1155 contract for both property and yield tokens. Batch operation efficiency and unified interface.',
  };

  return (
    <TokenStandardContext.Provider value={value}>
      {children}
    </TokenStandardContext.Provider>
  );
}

/**
 * Custom hook to access token standard context
 * @returns {Object} Token standard context value
 * @throws {Error} When used outside TokenStandardProvider
 */
export function useTokenStandard() {
  const context = useContext(TokenStandardContext);
  if (!context) {
    throw new Error('useTokenStandard must be used within a TokenStandardProvider');
  }
  return context;
}

export { TokenStandardContext };

