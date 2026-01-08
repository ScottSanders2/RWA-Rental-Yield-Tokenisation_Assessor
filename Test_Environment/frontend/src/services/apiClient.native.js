import axios from 'axios';
import { Platform } from 'react-native';
import { API_BASE_URL, ENVIRONMENT as ENV } from '@env';

// Export environment for display in UI
export const ENVIRONMENT = ENV;

// Determine base URL based on platform
// iOS Simulator: Use localhost (runs natively on macOS)
// Android Emulator: Use 10.0.2.2 (special alias for host machine)
// Physical devices: Use network IP from .env
// TEST ENVIRONMENT: Port 8001
const getBaseURL = () => {
  // If running in iOS simulator, always use localhost
  if (Platform.OS === 'ios') {
    return 'http://localhost:8001';  // Test backend port
  }
  // Android emulator uses special IP
  if (Platform.OS === 'android') {
    return 'http://10.0.2.2:8001';  // Test backend port
  }
  // Fallback to env variable or network IP
  return API_BASE_URL || 'http://192.168.1.144:8001';  // Test backend port
};

// Create axios instance with platform-aware base URL
const apiClient = axios.create({
  baseURL: getBaseURL(),
  timeout: 30000,
  headers: {
    'Content-Type': 'application/json',
  },
});

console.log('📡 API Client initialized with baseURL:', getBaseURL());

// Request interceptor for logging and tracking
apiClient.interceptors.request.use(
  (config) => {
    const startTime = Date.now();
    config.metadata = {startTime};

    console.log(`API Request: ${config.method?.toUpperCase()} ${config.url}`);
    return config;
  },
  (error) => {
    console.error('API Request Error:', error);
    return Promise.reject(error);
  }
);

// Response interceptor for logging and tracking
apiClient.interceptors.response.use(
  (response) => {
    const duration = Date.now() - response.config.metadata.startTime;
    console.log(`API Response: ${response.status} ${response.config.url} (${duration}ms)`);

    return {
      data: response.data,
      duration,
      status: response.status,
    };
  },
  (error) => {
    const duration = Date.now() - (error.config?.metadata?.startTime || Date.now());
    console.error(`API Error: ${error.response?.status || 'Network'} ${error.config?.url || 'unknown'} (${duration}ms)`, error.message);

    // Extract error message from response
    let errorMessage = 'Network error';
    if (error.response?.data) {
      const apiError = error.response.data;
      if (apiError.detail) {
        if (Array.isArray(apiError.detail)) {
          // FastAPI validation errors - format as readable string
          errorMessage = apiError.detail.map(e => {
            const field = e.loc ? e.loc.slice(1).join('.') : 'unknown';
            return `${field}: ${e.msg}`;
          }).join('; ');
        } else if (typeof apiError.detail === 'string') {
          errorMessage = apiError.detail;
        } else {
          errorMessage = JSON.stringify(apiError.detail);
        }
      } else if (apiError.message) {
        errorMessage = apiError.message;
      }
    } else if (error.message) {
      errorMessage = error.message;
    }

    return Promise.reject({
      message: errorMessage,
      response: error.response,
      duration,
      status: error.response?.status || 0,
    });
  }
);

// API methods (identical to web version)
export const registerProperty = async (propertyData) => {
  return apiClient.post('/properties/register', propertyData);
};

export const verifyProperty = async (propertyId) => {
  return apiClient.post(`/properties/${propertyId}/verify`);
};

export const getProperty = async (propertyId) => {
  return apiClient.get(`/properties/${propertyId}`);
};

export const createYieldAgreement = async (agreementData) => {
  return apiClient.post('/yield-agreements/create', agreementData);
};

export const getYieldAgreement = async (agreementId) => {
  return apiClient.get(`/yield-agreements/${agreementId}`);
};

export const getContracts = async () => {
  return apiClient.get('/contracts');
};

export const getProperties = async () => {
  return apiClient.get('/properties');
};

export const getYieldAgreements = async () => {
  return apiClient.get('/yield-agreements');
};

// ============ Governance API Methods ============

export const createGovernanceProposal = async (proposalData) => {
  return apiClient.post('/governance/proposals', proposalData);
};

export const castVote = async (voteData, voterAddress = null) => {
  const url = voterAddress 
    ? `/governance/proposals/${voteData.proposal_id}/vote?voter_address=${voterAddress}`
    : `/governance/proposals/${voteData.proposal_id}/vote`;
  console.log(`🗳️ Casting vote for proposal ${voteData.proposal_id}, voter: ${voterAddress ? voterAddress.slice(0, 10) + '...' : 'default'}`);
  return apiClient.post(url, voteData);
};

export const executeProposal = async (proposalId) => {
  return apiClient.post(`/governance/proposals/${proposalId}/execute`, {});
};

export const getProposals = async () => {
  return apiClient.get('/governance/proposals');
};

export const getProposal = async (proposalId) => {
  return apiClient.get(`/governance/proposals/${proposalId}`);
};

export const getVotingPower = async (voterAddress, agreementId, tokenStandard = 'ERC721') => {
  return apiClient.get(`/governance/voting-power/${voterAddress}/${agreementId}?token_standard=${tokenStandard}`);
};

export const checkVoteStatus = async (proposalId, voterAddress = '0x0000000000000000000000000000000000000000') => {
  console.log(`🔍 Checking vote status for proposal ${proposalId}, voter: ${voterAddress.slice(0, 10)}...`);
  return apiClient.get(`/governance/proposals/${proposalId}/my-vote?voter_address=${voterAddress}`);
};

// ===================
//  MARKETPLACE API (Iteration 12)
// ===================

export const createListing = async (listingData) => {
  const response = await apiClient.post('/marketplace/listings', listingData);
  return response.data;
};

export const getListings = async (options = {}) => {
  const { status, agreementId, sellerAddress } = options;
  const params = new URLSearchParams();
  if (status) params.append('listing_status', status);
  if (agreementId) params.append('agreement_id', agreementId);
  if (sellerAddress) params.append('seller_address', sellerAddress);
  
  const url = `/marketplace/listings${params.toString() ? `?${params.toString()}` : ''}`;
  const response = await apiClient.get(url);
  return response.data;
};

export const getListing = async (listingId) => {
  const response = await apiClient.get(`/marketplace/listings/${listingId}`);
  return response.data;
};

export const buyShares = async (buyData) => {
  const response = await apiClient.post(`/marketplace/listings/${buyData.listing_id}/buy`, buyData);
  return response.data;
};

export const cancelListing = async (listingId, sellerAddress) => {
  const params = new URLSearchParams({ seller_address: sellerAddress });
  const response = await apiClient.delete(`/marketplace/listings/${listingId}?${params.toString()}`);
  return response.data;
};

// ===================
//  PORTFOLIO API (Iteration 12)
// ===================

export const getPortfolio = async (userAddress) => {
  const response = await apiClient.get(`/portfolio/${userAddress}`);
  return response.data;
};

export const getUserBalance = async (userAddress, agreementId) => {
  const response = await apiClient.get(`/portfolio/${userAddress}/balance/${agreementId}`);
  return response.data;
};

export const getUserAgreements = async (userAddress) => {
  const response = await apiClient.get(`/portfolio/${userAddress}/agreements`);
  return response.data;
};

export const getUserAvailableBalance = async (userAddress, agreementId) => {
  const response = await apiClient.get(`/portfolio/${userAddress}/available-balance/${agreementId}`);
  return response.data;
};

export const getUserHistory = async (userAddress, agreementId = null) => {
  const params = agreementId ? new URLSearchParams({ agreement_id: agreementId }) : new URLSearchParams();
  const response = await apiClient.get(`/portfolio/${userAddress}/history?${params.toString()}`);
  return response.data;
};

// This is the React Native version of apiClient using react-native-config for environment variables (replaces Vite's import.meta.env), maintaining identical API interface for seamless code sharing between web and mobile platforms.


