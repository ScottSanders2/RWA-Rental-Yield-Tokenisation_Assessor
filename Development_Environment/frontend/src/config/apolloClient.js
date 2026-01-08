/**
 * Apollo Client Configuration for GraphQL Queries to The Graph Subgraph
 * Connects to local Graph Node (Dev) or Graph Studio (Test/Prod)
 * Provides GraphQL query interface for real-time on-chain analytics
 */

import { ApolloClient, InMemoryCache, HttpLink, from } from '@apollo/client';

/**
 * Graph Node GraphQL endpoint URL
 * Dev: http://localhost:8200/subgraphs/name/rwa-tokenization (local Graph Node)
 * Test/Prod: Graph Studio endpoint or hosted service URL
 */
const GRAPH_NODE_URL = import.meta.env.VITE_GRAPH_NODE_URL || 'http://localhost:8200/subgraphs/name/rwa-tokenization';

/**
 * Create HTTP link to Graph Node GraphQL endpoint
 */
const httpLink = new HttpLink({
  uri: GRAPH_NODE_URL,
});

/**
 * Configure Apollo Client cache with type policies
 * Defines caching strategy for subgraph entities
 */
const cache = new InMemoryCache({
  typePolicies: {
    // YieldAgreement entity caching by id field
    YieldAgreement: {
      keyFields: ['id'],
    },
    // Property entity caching by id field
    Property: {
      keyFields: ['id'],
    },
    // Shareholder entity caching by composite id (agreementId-address)
    Shareholder: {
      keyFields: ['id'],
    },
    // GovernanceProposal entity caching by id field
    GovernanceProposal: {
      keyFields: ['id'],
    },
    // Repayment entity caching by id field
    Repayment: {
      keyFields: ['id'],
    },
    // Vote entity caching by composite id (proposalId-voter)
    Vote: {
      keyFields: ['id'],
    },
    // AnalyticsSummary singleton (always 'GLOBAL')
    AnalyticsSummary: {
      keyFields: ['id'],
    },
  },
});

/**
 * Create Apollo Client instance
 * Configured for real-time analytics with cache-and-network fetch policy
 * Enables GraphQL queries from React components via useQuery hook
 */
const apolloClient = new ApolloClient({
  link: from([httpLink]),
  cache,
  defaultOptions: {
    watchQuery: {
      fetchPolicy: 'cache-and-network', // Fetch from cache first, then network for updates
      errorPolicy: 'all', // Return partial data even if errors occur
    },
    query: {
      fetchPolicy: 'network-only', // Always fetch fresh data for queries
      errorPolicy: 'all',
    },
  },
});

export default apolloClient;

