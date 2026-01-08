/**
 * GraphQL Query Definitions for Analytics Data Fetching
 * Queries The Graph subgraph for on-chain analytics, ROI reporting, pooling metrics
 */

import { gql } from '@apollo/client';

/**
 * Query AnalyticsSummary singleton for platform-wide aggregate metrics
 * Returns: total agreements, capital deployed, repayments, shareholders, ROI, token standard counts
 * Used by: AnalyticsDashboard for overview metrics
 * Note: ID is stored as Bytes (hex), not String. "GLOBAL" in hex is 0x474c4f42414c
 */
export const GET_ANALYTICS_SUMMARY = gql`
  query AnalyticsSummary {
    analyticsSummary(id: "0x474c4f42414c") {
      id
      totalAgreements
      totalCapitalDeployed
      totalCapitalDeployedUsd
      totalRepaymentsDistributed
      activeAgreements
      completedAgreements
      totalShareholders
      averageROIBasisPoints
      erc721AgreementCount
      erc1155AgreementCount
      totalGovernanceProposals
      totalVotesCast
      lastUpdated
    }
  }
`;

/**
 * Query detailed analytics for a specific YieldAgreement
 * Parameters: $agreementId (Bytes!)
 * Returns: agreement details, property info, repayment history, shareholders, governance proposals
 * Used by: AgreementAnalytics page for per-agreement detailed view
 */
export const GET_YIELD_AGREEMENT_ANALYTICS = gql`
  query YieldAgreementAnalytics($agreementId: Bytes!) {
    yieldAgreement(id: $agreementId) {
      id
      upfrontCapital
      upfrontCapitalUsd
      termMonths
      annualROIBasisPoints
      totalRepaid
      isActive
      isCompleted
      tokenStandard
      monthlyPaymentExpected
      totalExpectedRepayment
      actualROIBasisPoints
      createdAt
      completedAt
      lastRepaymentAt
      property {
        id
        propertyAddressHash
        metadataURI
        isVerified
        verifier
        verificationTimestamp
      }
      repayments(orderBy: timestamp, orderDirection: desc) {
        id
        amount
        timestamp
        isPartial
        isEarly
        arrearsPayment
        currentPayment
        rebateAmount
        transactionHash
      }
      shareholders(orderBy: shares, orderDirection: desc) {
        id
        investor
        shares
        capitalContributed
        distributionsReceived
        isActive
        lastUpdated
      }
      governanceProposals {
        id
        proposalType
        targetValue
        executed
        defeated
        forVotes
        againstVotes
        abstainVotes
      }
    }
  }
`;

/**
 * Query all agreements with optional filters
 * Parameters: $tokenStandard (String), $isActive (Boolean)
 * Returns: array of agreements with basic metrics
 * Used by: ROIReportingChart, TokenStandardComparisonChart for comparative analytics
 */
export const GET_ALL_AGREEMENTS_ANALYTICS = gql`
  query AllAgreementsAnalytics($tokenStandard: String, $isActive: Boolean) {
    yieldAgreements(
      where: { tokenStandard: $tokenStandard, isActive: $isActive }
      orderBy: createdAt
      orderDirection: desc
    ) {
      id
      upfrontCapital
      upfrontCapitalUsd
      termMonths
      annualROIBasisPoints
      totalRepaid
      isActive
      tokenStandard
      actualROIBasisPoints
      createdAt
      completedAt
      shareholders {
        investor
        shares
        capitalContributed
      }
      repayments {
        amount
        timestamp
      }
    }
  }
`;

/**
 * Query pooling analytics for shareholder distribution analysis
 * Returns: all agreements with shareholder details for concentration metrics
 * Used by: PoolingAnalyticsChart for shareholder distribution, concentration, pooling rates
 */
export const GET_POOLING_ANALYTICS = gql`
  query PoolingAnalytics {
    yieldAgreements {
      id
      tokenStandard
      upfrontCapital
      upfrontCapitalUsd
      createdAt
      shareholders(where: { isActive: true }) {
        investor
        shares
        capitalContributed
      }
    }
  }
`;

/**
 * Query governance analytics for voting participation metrics
 * Returns: all proposals with votes for participation analysis
 * Used by: GovernanceAnalytics (future component) for voting metrics
 */
export const GET_GOVERNANCE_ANALYTICS = gql`
  query GovernanceAnalytics {
    governanceProposals(orderBy: createdAt, orderDirection: desc) {
      id
      proposer
      proposalType
      targetValue
      description
      votingStart
      votingEnd
      forVotes
      againstVotes
      abstainVotes
      executed
      defeated
      quorumReached
      createdAt
      executedAt
      agreement {
        id
        tokenStandard
      }
      votes {
        voter
        support
        votingPower
        timestamp
      }
    }
  }
`;

/**
 * Query token standard comparison metrics
 * Returns: separate arrays for ERC-721+ERC-20 and ERC-1155 agreements
 * Used by: TokenStandardComparisonChart for variant comparison
 */
export const GET_TOKEN_STANDARD_COMPARISON = gql`
  query TokenStandardComparison {
    erc721: yieldAgreements(where: { tokenStandard: "ERC721" }) {
      id
      upfrontCapital
      upfrontCapitalUsd
      totalRepaid
      termMonths
      annualROIBasisPoints
      actualROIBasisPoints
      createdAt
      shareholders {
        id
        investor
        shares
      }
      repayments {
        id
        amount
      }
    }
    erc1155: yieldAgreements(where: { tokenStandard: "ERC1155" }) {
      id
      upfrontCapital
      upfrontCapitalUsd
      totalRepaid
      termMonths
      annualROIBasisPoints
      actualROIBasisPoints
      createdAt
      shareholders {
        id
        investor
        shares
      }
      repayments {
        id
        amount
      }
    }
  }
`;

/**
 * Query repayment history for time-series visualization
 * Parameters: $agreementId (Bytes) - optional filter for specific agreement
 * Returns: repayments ordered by timestamp for chart rendering
 * Used by: ROIReportingChart for repayment history line chart
 */
export const GET_REPAYMENT_HISTORY = gql`
  query RepaymentHistory($agreementId: Bytes) {
    repayments(
      where: { agreement: $agreementId }
      orderBy: timestamp
      orderDirection: asc
    ) {
      id
      amount
      timestamp
      isPartial
      isEarly
      agreement {
        id
        tokenStandard
        upfrontCapital
        upfrontCapitalUsd
        annualROIBasisPoints
      }
    }
  }
`;

/**
 * Query shareholder distribution for specific agreement
 * Parameters: $agreementId (Bytes!)
 * Returns: shareholders ordered by shares for pie chart visualization
 * Used by: PoolingAnalyticsChart for shareholder distribution pie chart
 */
export const GET_SHAREHOLDER_DISTRIBUTION = gql`
  query ShareholderDistribution($agreementId: Bytes!) {
    shareholders(
      where: { agreement: $agreementId, isActive: true }
      orderBy: shares
      orderDirection: desc
    ) {
      id
      investor
      shares
      capitalContributed
      distributionsReceived
      lastUpdated
    }
  }
`;

