// React Context for global token standard preference with explicit ERC-20 labeling

import React, { createContext, useContext, useState, useEffect } from 'react';

const TokenStandardContext = createContext();

/**
 * TokenStandardProvider component providing global token standard state
 * @param {Object} props - React props
 * @param {React.ReactNode} props.children - Child components
 * @returns {React.ReactElement} Provider component
 */
export function TokenStandardProvider({ children }) {
  const [tokenStandard, setTokenStandard] = useState(
    localStorage.getItem('tokenStandard') || 'ERC721'
  );

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









