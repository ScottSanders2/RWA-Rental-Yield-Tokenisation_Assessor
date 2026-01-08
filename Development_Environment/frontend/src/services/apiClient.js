import axios from 'axios';

const instance = axios.create({
  baseURL: import.meta.env.VITE_API_BASE_URL || 'http://localhost:8000',
  timeout: 30000,
  headers: { 'Content-Type': 'application/json', Accept: 'application/json' }
});

instance.interceptors.request.use((config) => {
  if (import.meta.env.DEV) console.debug('[API]', config.method?.toUpperCase(), config.url, config.data);
  return config;
});

instance.interceptors.response.use(
  (response) => response,
  (error) => {
    const status = error.response?.status ?? 500;
    const message = error.response?.data?.detail || error.response?.statusText || error.message || 'Network error';
    return Promise.reject({ message, status, originalError: error });
  }
);

async function get(url, config = {}) {
  const start = Date.now();
  const res = await instance.get(url, config);
  return { data: res.data, duration: Date.now() - start, status: res.status };
}

async function post(url, body, config = {}) {
  const start = Date.now();
  const res = await instance.post(url, body, config);
  return { data: res.data, duration: Date.now() - start, status: res.status };
}

// API methods

export const verifyProperty = async (propertyId) => {
  return post(`/properties/${propertyId}/verify`);
};

export const getProperty = async (propertyId) => {
  return get(`/properties/${propertyId}`);
};

export const createYieldAgreement = async (agreementData) => {
  return post('/yield-agreements/create', agreementData);
};

export const getYieldAgreement = async (agreementId) => {
  return get(`/yield-agreements/${agreementId}`);
};

export const getContracts = async () => {
  return get('/contracts');
};

export const registerProperty = async (propertyData) => {
  return post('/properties/register', propertyData);
};

export const getProperties = async (ownerAddress = null) => {
  const url = ownerAddress ? `/properties?owner_address=${ownerAddress}` : '/properties';
  return get(url);
};

export const getYieldAgreements = async () => {
  return get('/yield-agreements');
};

// ============ Governance API Methods ============

/**
 * Create a new governance proposal
 * @param {Object} proposalData - Proposal data
 * @param {number} proposalData.agreement_id - Target yield agreement ID
 * @param {string} proposalData.proposal_type - ROI_ADJUSTMENT|RESERVE_ALLOCATION|RESERVE_WITHDRAWAL|PARAMETER_UPDATE
 * @param {number} proposalData.target_value - New ROI (basis points) or reserve amount (wei)
 * @param {number} [proposalData.target_value_usd] - Reserve amount in USD for display
 * @param {string} proposalData.description - Rationale for proposal (10-500 chars)
 * @param {string} [proposalData.token_standard='ERC721'] - Token standard
 * @returns {Promise<{data, duration, status}>} Proposal creation response with proposal ID, tx hash, voting period
 */
export const createGovernanceProposal = async (proposalData) => {
  return post('/governance/proposals', proposalData);
};

/**
 * Cast a vote on a governance proposal
 * @param {Object} voteData - Vote data
 * @param {number} voteData.proposal_id - Proposal ID to vote on
 * @param {number} voteData.support - Vote direction (0=Against, 1=For, 2=Abstain)
 * @param {string} voteData.voter_address - Voter wallet address
 * @param {string} [voteData.token_standard='ERC721'] - Token standard
 * @returns {Promise<{data, duration, status}>} Vote cast response with voter, support, voting power, tx hash
 */
export const castVote = async (voteData) => {
  // Extract voter_address for query parameter
  const { voter_address, ...bodyData } = voteData;
  const queryParam = voter_address ? `?voter_address=${encodeURIComponent(voter_address)}` : '';
  return post(`/governance/proposals/${voteData.proposal_id}/vote${queryParam}`, bodyData);
};

/**
 * Execute a governance proposal after voting period ends
 * @param {number} proposalId - Proposal ID to execute
 * @returns {Promise<{data, duration, status}>} Execution response with executed status and tx hash
 */
export const executeProposal = async (proposalId) => {
  return post(`/governance/proposals/${proposalId}/execute`, {});
};

/**
 * Get all governance proposals
 * @returns {Promise<{data, duration, status}>} Array of all proposals with details
 */
export const getProposals = async () => {
  return get('/governance/proposals');
};

/**
 * Get governance proposal details
 * @param {number} proposalId - Proposal ID to query
 * @returns {Promise<{data, duration, status}>} Proposal details including vote counts, status, execution state
 */
export const getProposal = async (proposalId) => {
  return get(`/governance/proposals/${proposalId}`);
};

/**
 * Get voting power for a voter on a specific agreement
 * @param {string} voterAddress - Wallet address of voter
 * @param {number} agreementId - Agreement ID to check voting power for
 * @param {string} [tokenStandard='ERC721'] - Token standard
 * @returns {Promise<{data, duration, status}>} Voting power response with token balance
 */
export const getVotingPower = async (voterAddress, agreementId, tokenStandard = 'ERC721') => {
  return get(`/governance/voting-power/${voterAddress}/${agreementId}?token_standard=${tokenStandard}`);
};

// ============ User Profile API Methods (for testing) ============

/**
 * Get all user profiles for testing mode
 * @returns {Promise<{data, duration, status}>} Array of user profiles with wallet addresses and roles
 */
export const getUserProfiles = async () => {
  return get('/users/profiles');
};

// Note: isTokenIdUsed would need to be implemented on the backend
// For now, we'll assume token IDs are managed server-side

// ============ Marketplace API Methods (Secondary Market Trading) ============

/**
 * Create marketplace listing for yield shares
 * @param {Object} listingData - Listing details
 * @param {number} listingData.agreement_id - Yield agreement ID
 * @param {number} [listingData.shares_for_sale_fraction] - Fractional amount to sell (0.01-1.0)
 * @param {number} listingData.price_per_share_usd - Price per share in USD
 * @param {number} [listingData.expires_in_days] - Listing expiry in days
 * @param {string} listingData.seller_address - Seller Ethereum address
 * @param {string} [listingData.token_standard='ERC721'] - Token standard
 * @returns {Promise<{data, duration, status}>} Created listing response with listing_id and details
 */
export const createListing = async (listingData) => {
  return post('/marketplace/listings', listingData);
};

/**
 * Get marketplace listings with optional filters
 * @param {Object} [filters={}] - Filter criteria
 * @param {number} [filters.agreement_id] - Filter by agreement ID
 * @param {string} [filters.token_standard] - Filter by token standard ('ERC721' or 'ERC1155')
 * @param {number} [filters.min_price_usd] - Filter by minimum price per share
 * @param {number} [filters.max_price_usd] - Filter by maximum price per share
 * @param {string} [filters.status] - Filter by status ('active', 'sold', 'cancelled', 'expired')
 * @returns {Promise<{data, duration, status}>} Array of marketplace listings
 */
export const getListings = async (filters = {}) => {
  const params = new URLSearchParams();
  if (filters.agreement_id) params.append('agreement_id', filters.agreement_id);
  if (filters.token_standard) params.append('token_standard', filters.token_standard);
  if (filters.min_price_usd) params.append('min_price_usd', filters.min_price_usd);
  if (filters.max_price_usd) params.append('max_price_usd', filters.max_price_usd);
  if (filters.status) params.append('listing_status', filters.status);
  const queryString = params.toString();
  return get(`/marketplace/listings${queryString ? '?' + queryString : ''}`);
};

/**
 * Get single marketplace listing by ID
 * @param {number} listingId - Listing ID to fetch
 * @returns {Promise<{data, duration, status}>} Listing details
 */
export const getListing = async (listingId) => {
  return get(`/marketplace/listings/${listingId}`);
};

/**
 * Purchase yield shares from marketplace listing
 * @param {Object} buyData - Purchase details
 * @param {number} buyData.listing_id - Listing ID to purchase from
 * @param {number} [buyData.shares_to_buy_fraction] - Fractional amount to buy (0.01-1.0)
 * @param {string} buyData.buyer_address - Buyer Ethereum address
 * @param {number} [buyData.max_price_per_share_usd] - Slippage protection price limit
 * @returns {Promise<{data, duration, status}>} Trade execution response with tx_hash and gas_used
 */
export const buyShares = async (buyData) => {
  return post(`/marketplace/listings/${buyData.listing_id}/buy`, buyData);
};

/**
 * Cancel marketplace listing
 * @param {number} listingId - Listing ID to cancel
 * @param {string} sellerAddress - Seller Ethereum address (must match listing seller)
 * @returns {Promise<{data, duration, status}>} Cancellation confirmation
 */
export const cancelListing = async (listingId, sellerAddress) => {
  const params = new URLSearchParams({ seller_address: sellerAddress });
  const start = Date.now();
  const res = await instance.delete(`/marketplace/listings/${listingId}?${params.toString()}`);
  return { data: res.data, duration: Date.now() - start, status: res.status };
};

// ===================
//  PORTFOLIO API
// ===================

/**
 * Get user's complete portfolio of share holdings.
 * 
 * @param {string} userAddress - User's Ethereum wallet address
 * @returns {Promise<Object>} Portfolio summary with holdings array
 * 
 * Response structure:
 * {
 *   user_address: string,
 *   total_agreements: number,
 *   total_shares_value_usd: number | null,
 *   holdings: Array<{
 *     agreement_id: number,
 *     balance_shares: number,
 *     ownership_percentage: number,
 *     ...
 *   }>
 * }
 */
export const getPortfolio = async (userAddress) => {
  const response = await instance.get(`/portfolio/${userAddress}`);
  return response.data;
};

/**
 * Get user's share balance for a specific yield agreement.
 * 
 * @param {string} userAddress - User's wallet address
 * @param {number} agreementId - Yield agreement ID
 * @returns {Promise<Object>} Balance details
 */
export const getUserBalance = async (userAddress, agreementId) => {
  const response = await instance.get(`/portfolio/${userAddress}/balance/${agreementId}`);
  return response.data;
};

/**
 * Get list of yield agreements where user has shares (balance > 0).
 * 
 * @param {string} userAddress - User's wallet address
 * @returns {Promise<Object>} { user_address, agreements: [...], total_agreements }
 */
export const getUserAgreements = async (userAddress) => {
  const response = await instance.get(`/portfolio/${userAddress}/agreements`);
  return response.data;
};

/**
 * Get user's available balance for listing (total - already listed shares).
 * 
 * @param {string} userAddress - User's wallet address
 * @param {number} agreementId - Yield agreement ID
 * @returns {Promise<Object>} Available balance details
 */
export const getUserAvailableBalance = async (userAddress, agreementId) => {
  const response = await instance.get(`/portfolio/${userAddress}/available-balance/${agreementId}`);
  return response.data;
};

/**
 * Get user's balance change history (marketplace trades).
 * 
 * @param {string} userAddress - User's wallet address
 * @param {number|null} agreementId - Optional filter by agreement ID
 * @returns {Promise<Object>} Trade history with events array
 */
export const getUserHistory = async (userAddress, agreementId = null) => {
  const params = agreementId ? new URLSearchParams({ agreement_id: agreementId }) : new URLSearchParams();
  const response = await instance.get(`/portfolio/${userAddress}/history?${params.toString()}`);
  return response.data;
};

// Export axios instance as default for components that need direct access
export default instance;