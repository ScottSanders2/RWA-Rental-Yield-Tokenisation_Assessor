/**
 * Analytics Dashboard Page Component
 * Displays platform-wide analytics powered by The Graph Protocol
 * Features: ROI reporting, pooling analytics, token standard comparison
 */

import React, { useMemo } from 'react';
import {
  Container,
  Paper,
  Typography,
  Box,
  Grid,
  Card,
  CardContent,
  Alert,
  CircularProgress,
  Divider,
  Chip,
} from '@mui/material';
import {
  BarChart as BarChartIcon,
  PieChart as PieChartIcon,
  TrendingUp as TrendingUpIcon,
  People as PeopleIcon,
  AccountBalance as AccountBalanceIcon,
  Timeline as TimelineIcon,
} from '@mui/icons-material';
import { useQuery } from '@apollo/client';
import {
  GET_ANALYTICS_SUMMARY,
  GET_ALL_AGREEMENTS_ANALYTICS,
  GET_TOKEN_STANDARD_COMPARISON,
} from '../graphql/queries';
import {
  LineChart,
  Line,
  BarChart,
  Bar,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  Legend,
  ResponsiveContainer,
} from 'recharts';
import { useEthPrice } from '../context/PriceContext';
import { useTokenStandard } from '../context/TokenStandardContext';
import { useNavigate } from 'react-router-dom';
import { formatWeiToUsd, formatDualCurrency } from '../utils/formatters';

/**
 * Format basis points to percentage string
 */
const formatBasisPointsToPercent = (basisPoints) => {
  if (!basisPoints) return '0.00%';
  return (basisPoints / 100).toFixed(2) + '%';
};

/**
 * AnalyticsDashboard Component
 * Main analytics dashboard displaying platform-wide metrics and visualizations
 */
const AnalyticsDashboard = () => {
  const navigate = useNavigate();
  const { ethUsdPrice } = useEthPrice();
  const { tokenStandard, getLabel } = useTokenStandard();

  // GraphQL queries
  const { data: summaryData, loading: summaryLoading, error: summaryError } = useQuery(GET_ANALYTICS_SUMMARY);
  const { data: agreementsData, loading: agreementsLoading } = useQuery(GET_ALL_AGREEMENTS_ANALYTICS);
  const { data: comparisonData, loading: comparisonLoading, error: comparisonError } = useQuery(GET_TOKEN_STANDARD_COMPARISON, {
    fetchPolicy: 'network-only', // Force fresh data, bypass Apollo cache
  });
  
  // Log comparison query errors
  if (comparisonError) {
    console.error('[ERROR] Token Standard Comparison Query Failed:', comparisonError);
  }

  // Calculate derived metrics from summary data
  const platformMetrics = useMemo(() => {
    if (!summaryData?.analyticsSummary) return null;

    const summary = summaryData.analyticsSummary;
    // CRITICAL FIX: USD values are NOT scaled by 1e18 in subgraph, use raw value
    // The subgraph stores raw USD amounts (e.g., "10000" = $10,000)
    const totalCapitalUSD = summary.totalCapitalDeployedUsd 
      ? new Intl.NumberFormat('en-US', {
          style: 'currency',
          currency: 'USD',
          minimumFractionDigits: 2,
        }).format(parseFloat(summary.totalCapitalDeployedUsd))
      : '$0.00';
    const totalRepaymentsUSD = formatWeiToUsd(summary.totalRepaymentsDistributed, ethUsdPrice);
    
    // Calculate platform ROI
    const capitalDeployed = parseFloat(summary.totalCapitalDeployed);
    const repaymentsDistributed = parseFloat(summary.totalRepaymentsDistributed);
    const platformROI = capitalDeployed > 0
      ? ((repaymentsDistributed - capitalDeployed) / capitalDeployed * 100).toFixed(2)
      : '0.00';

    return {
      totalCapitalUSD,
      totalRepaymentsUSD,
      platformROI,
      totalAgreements: summary.totalAgreements,
      activeAgreements: summary.activeAgreements,
      completedAgreements: summary.completedAgreements,
      totalShareholders: summary.totalShareholders,
      averageROI: formatBasisPointsToPercent(summary.averageROIBasisPoints),
      erc721Count: summary.erc721AgreementCount,
      erc1155Count: summary.erc1155AgreementCount,
    };
  }, [summaryData, ethUsdPrice]);

  // Prepare repayment history chart data
  const repaymentHistoryData = useMemo(() => {
    if (!agreementsData?.yieldAgreements) return [];

    const allRepayments = [];
    agreementsData.yieldAgreements.forEach((agreement) => {
      agreement.repayments.forEach((repayment) => {
        allRepayments.push({
          timestamp: new Date(parseInt(repayment.timestamp) * 1000),
          amount: parseFloat(repayment.amount) / 1e18 * ethUsdPrice,
          agreementId: agreement.id.substring(0, 8),
        });
      });
    });

    // Sort by timestamp and aggregate by month
    allRepayments.sort((a, b) => a.timestamp - b.timestamp);
    
    return allRepayments.map(r => ({
      date: r.timestamp.toLocaleDateString(),
      amountUSD: r.amount.toFixed(2),
      agreement: r.agreementId,
    }));
  }, [agreementsData, ethUsdPrice]);

  // Prepare token standard comparison chart data
  const tokenStandardComparisonData = useMemo(() => {
    if (!comparisonData?.erc721 || !comparisonData?.erc1155) {
      return [];
    }

    const calculateTotals = (agreements) => {
      let totalCapital = 0;
      let totalRepaid = 0;
      let totalShareholders = 0;

      agreements.forEach((agreement) => {
        // CRITICAL FIX: USD values are NOT scaled by 1e18 in subgraph, use raw value
        totalCapital += parseFloat(agreement.upfrontCapitalUsd || 0);
        totalRepaid += parseFloat(agreement.totalRepaid) / 1e18 * ethUsdPrice;
        totalShareholders += agreement.shareholders.length;
      });

      return {
        count: agreements.length,
        capital: totalCapital,
        repaid: totalRepaid,
        avgShareholders: agreements.length > 0 ? totalShareholders / agreements.length : 0,
      };
    };

    const erc721Totals = calculateTotals(comparisonData.erc721);
    const erc1155Totals = calculateTotals(comparisonData.erc1155);

    const chartData = [
      {
        name: 'ERC-721 + ERC-20',
        agreements: erc721Totals.count,
        capitalUSD: erc721Totals.capital.toFixed(2),
        repaidUSD: erc721Totals.repaid.toFixed(2),
        avgShareholders: erc721Totals.avgShareholders.toFixed(1),
      },
      {
        name: 'ERC-1155',
        agreements: erc1155Totals.count,
        capitalUSD: erc1155Totals.capital.toFixed(2),
        repaidUSD: erc1155Totals.repaid.toFixed(2),
        avgShareholders: erc1155Totals.avgShareholders.toFixed(1),
      },
    ];
    
    return chartData;
  }, [comparisonData, ethUsdPrice]);

  // Loading state
  if (summaryLoading || agreementsLoading || comparisonLoading) {
    return (
      <Container maxWidth="xl" sx={{ mt: 4, mb: 4, display: 'flex', justifyContent: 'center' }}>
        <CircularProgress />
      </Container>
    );
  }

  // Error state
  if (summaryError) {
    return (
      <Container maxWidth="xl" sx={{ mt: 4, mb: 4 }}>
        <Alert severity="error">
          Failed to load analytics data: {summaryError.message}
        </Alert>
      </Container>
    );
  }

  return (
    <Container maxWidth="xl" sx={{ mt: 4, mb: 4 }}>
      {/* Header */}
      <Box sx={{ mb: 4 }}>
        <Typography variant="h3" component="h1" gutterBottom>
          Analytics Dashboard
        </Typography>
        <Typography variant="subtitle1" color="text.secondary" gutterBottom>
          Real-time on-chain analytics powered by The Graph Protocol
        </Typography>
        <Alert severity="info" sx={{ mt: 2 }}>
          <strong>Current Token Standard:</strong> {getLabel()}
        </Alert>
      </Box>

      {/* Summary Metrics Cards */}
      {platformMetrics && (
        <Grid container spacing={3} sx={{ mb: 4 }}>
          <Grid item xs={12} sm={6} md={3}>
            <Card>
              <CardContent>
                <Box sx={{ display: 'flex', alignItems: 'center', mb: 1 }}>
                  <AccountBalanceIcon color="primary" sx={{ mr: 1 }} />
                  <Typography variant="h6" component="div">
                    Total Capital
                  </Typography>
                </Box>
                <Typography variant="h4" color="primary">
                  {platformMetrics.totalCapitalUSD}
                </Typography>
                <Typography variant="caption" color="text.secondary">
                  Deployed across {platformMetrics.totalAgreements} agreements
                </Typography>
              </CardContent>
            </Card>
          </Grid>

          <Grid item xs={12} sm={6} md={3}>
            <Card>
              <CardContent>
                <Box sx={{ display: 'flex', alignItems: 'center', mb: 1 }}>
                  <BarChartIcon color="success" sx={{ mr: 1 }} />
                  <Typography variant="h6" component="div">
                    Active Agreements
                  </Typography>
                </Box>
                <Typography variant="h4" color="success.main">
                  {platformMetrics.activeAgreements}
                </Typography>
                <Typography variant="caption" color="text.secondary">
                  {platformMetrics.completedAgreements} completed
                </Typography>
              </CardContent>
            </Card>
          </Grid>

          <Grid item xs={12} sm={6} md={3}>
            <Card>
              <CardContent>
                <Box sx={{ display: 'flex', alignItems: 'center', mb: 1 }}>
                  <TrendingUpIcon color="secondary" sx={{ mr: 1 }} />
                  <Typography variant="h6" component="div">
                    Total Repayments
                  </Typography>
                </Box>
                <Typography variant="h4" color="secondary.main">
                  {platformMetrics.totalRepaymentsUSD}
                </Typography>
                <Typography variant="caption" color="text.secondary">
                  Platform ROI: {platformMetrics.platformROI}%
                </Typography>
              </CardContent>
            </Card>
          </Grid>

          <Grid item xs={12} sm={6} md={3}>
            <Card>
              <CardContent>
                <Box sx={{ display: 'flex', alignItems: 'center', mb: 1 }}>
                  <PeopleIcon color="info" sx={{ mr: 1 }} />
                  <Typography variant="h6" component="div">
                    Shareholders
                  </Typography>
                </Box>
                <Typography variant="h4" color="info.main">
                  {platformMetrics.totalShareholders}
                </Typography>
                <Typography variant="caption" color="text.secondary">
                  Average ROI: {platformMetrics.averageROI}
                </Typography>
              </CardContent>
            </Card>
          </Grid>
        </Grid>
      )}

      <Divider sx={{ my: 4 }} />

      {/* Repayment History Chart */}
      <Paper sx={{ p: 3, mb: 4 }}>
        <Typography variant="h5" gutterBottom sx={{ display: 'flex', alignItems: 'center' }}>
          <TimelineIcon sx={{ mr: 1 }} />
          Repayment History
        </Typography>
        <Typography variant="body2" color="text.secondary" gutterBottom>
          Historical repayments across all agreements (USD)
        </Typography>
        <ResponsiveContainer width="100%" height={400}>
          <LineChart data={repaymentHistoryData}>
            <CartesianGrid strokeDasharray="3 3" />
            <XAxis dataKey="date" />
            <YAxis label={{ value: 'Amount (USD)', angle: -90, position: 'insideLeft' }} />
            <Tooltip formatter={(value) => `$${parseFloat(value).toFixed(2)}`} />
            <Legend />
            <Line type="monotone" dataKey="amountUSD" stroke="#1976d2" name="Repayment Amount" />
          </LineChart>
        </ResponsiveContainer>
      </Paper>

      {/* Token Standard Comparison Chart */}
      <Paper sx={{ p: 3, mb: 4 }}>
        <Typography variant="h5" gutterBottom sx={{ display: 'flex', alignItems: 'center' }}>
          <BarChartIcon sx={{ mr: 1 }} />
          Token Standard Comparison
        </Typography>
        <Typography variant="body2" color="text.secondary" gutterBottom>
          ERC-721 + ERC-20 vs ERC-1155 performance metrics
        </Typography>
        <ResponsiveContainer width="100%" height={400}>
          <BarChart data={tokenStandardComparisonData}>
            <CartesianGrid strokeDasharray="3 3" />
            <XAxis dataKey="name" />
            <YAxis />
            <Tooltip />
            <Legend />
            <Bar dataKey="agreements" fill="#1976d2" name="Agreements" />
            <Bar dataKey="avgShareholders" fill="#dc004e" name="Avg Shareholders" />
          </BarChart>
        </ResponsiveContainer>
      </Paper>

      {/* Token Standard Distribution */}
      {platformMetrics && (
        <Paper sx={{ p: 3 }}>
          <Typography variant="h5" gutterBottom>
            Token Standard Distribution
          </Typography>
          <Box sx={{ display: 'flex', gap: 2, mt: 2 }}>
            <Chip
              label={`ERC-721 + ERC-20: ${platformMetrics.erc721Count} agreements`}
              color="primary"
              variant="outlined"
            />
            <Chip
              label={`ERC-1155: ${platformMetrics.erc1155Count} agreements`}
              color="secondary"
              variant="outlined"
            />
          </Box>
        </Paper>
      )}
    </Container>
  );
};

export default AnalyticsDashboard;

