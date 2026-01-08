/**
 * Token Standard Comparison Chart Component
 * Compares ERC-721 + ERC-20 (separate contracts) vs ERC-1155 (combined contract)
 * Displays metrics: agreement count, capital deployed, shareholders, pooling rate
 * Supports Research Question 1 (token standard impacts)
 */

import React, { useMemo } from 'react';
import {
  Box,
  Typography,
  Paper,
  Grid,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  Alert,
  CircularProgress,
} from '@mui/material';
import { useQuery } from '@apollo/client';
import { GET_TOKEN_STANDARD_COMPARISON } from '../graphql/queries';
import {
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

/**
 * TokenStandardComparisonChart Component
 * Displays comprehensive comparison between token standard variants
 */
const TokenStandardComparisonChart = () => {
  const { ethUsdPrice } = useEthPrice();

  // Query token standard comparison data
  const { data, loading, error } = useQuery(GET_TOKEN_STANDARD_COMPARISON);

  // Calculate comparison metrics
  const comparisonMetrics = useMemo(() => {
    if (!data?.erc721 || !data?.erc1155) return null;

    const calculateMetrics = (agreements) => {
      if (agreements.length === 0) {
        return {
          agreementCount: 0,
          totalCapitalUSD: 0,
          averageCapitalUSD: 0,
          totalRepaidUSD: 0,
          averageRepaidUSD: 0,
          totalShareholders: 0,
          averageShareholders: 0,
          poolingRate: 0,
        };
      }

      let totalCapital = 0;
      let totalRepaid = 0;
      let totalShareholders = 0;
      let pooledAgreements = 0;

      agreements.forEach((agreement) => {
        totalCapital += parseFloat(agreement.upfrontCapital);
        totalRepaid += parseFloat(agreement.totalRepaid);
        const shareholderCount = agreement.shareholders.length;
        totalShareholders += shareholderCount;
        
        if (shareholderCount > 1) {
          pooledAgreements++;
        }
      });

      const totalCapitalUSD = (totalCapital / 1e18 * ethUsdPrice).toFixed(2);
      const averageCapitalUSD = (totalCapital / agreements.length / 1e18 * ethUsdPrice).toFixed(2);
      const totalRepaidUSD = (totalRepaid / 1e18 * ethUsdPrice).toFixed(2);
      const averageRepaidUSD = (totalRepaid / agreements.length / 1e18 * ethUsdPrice).toFixed(2);
      const averageShareholders = (totalShareholders / agreements.length).toFixed(1);
      const poolingRate = ((pooledAgreements / agreements.length) * 100).toFixed(1);

      return {
        agreementCount: agreements.length,
        totalCapitalUSD,
        averageCapitalUSD,
        totalRepaidUSD,
        averageRepaidUSD,
        totalShareholders,
        averageShareholders,
        poolingRate,
      };
    };

    const erc721Metrics = calculateMetrics(data.erc721);
    const erc1155Metrics = calculateMetrics(data.erc1155);

    return {
      erc721: erc721Metrics,
      erc1155: erc1155Metrics,
    };
  }, [data, ethUsdPrice]);

  // Prepare chart data
  const chartData = useMemo(() => {
    if (!comparisonMetrics) return [];

    return [
      {
        metric: 'Agreements',
        'ERC-721 + ERC-20': comparisonMetrics.erc721.agreementCount,
        'ERC-1155': comparisonMetrics.erc1155.agreementCount,
      },
      {
        metric: 'Avg Capital (k USD)',
        'ERC-721 + ERC-20': (parseFloat(comparisonMetrics.erc721.averageCapitalUSD) / 1000).toFixed(1),
        'ERC-1155': (parseFloat(comparisonMetrics.erc1155.averageCapitalUSD) / 1000).toFixed(1),
      },
      {
        metric: 'Avg Shareholders',
        'ERC-721 + ERC-20': parseFloat(comparisonMetrics.erc721.averageShareholders),
        'ERC-1155': parseFloat(comparisonMetrics.erc1155.averageShareholders),
      },
      {
        metric: 'Pooling Rate %',
        'ERC-721 + ERC-20': parseFloat(comparisonMetrics.erc721.poolingRate),
        'ERC-1155': parseFloat(comparisonMetrics.erc1155.poolingRate),
      },
    ];
  }, [comparisonMetrics]);

  // Loading state
  if (loading) {
    return (
      <Paper sx={{ p: 3 }}>
        <Box sx={{ display: 'flex', justifyContent: 'center', alignItems: 'center', height: 400 }}>
          <CircularProgress />
        </Box>
      </Paper>
    );
  }

  // Error state
  if (error) {
    return (
      <Paper sx={{ p: 3 }}>
        <Alert severity="error">Failed to load comparison data: {error.message}</Alert>
      </Paper>
    );
  }

  // No data state
  if (!comparisonMetrics) {
    return (
      <Paper sx={{ p: 3 }}>
        <Alert severity="info">No comparison data available.</Alert>
      </Paper>
    );
  }

  return (
    <Paper sx={{ p: 3 }}>
      <Box sx={{ mb: 2 }}>
        <Typography variant="h6" gutterBottom>
          Token Standard Comparison: ERC-721 + ERC-20 vs ERC-1155
        </Typography>
        <Typography variant="caption" color="text.secondary">
          Comparative analysis of separate contracts (ERC-721 PropertyNFT + ERC-20 YieldSharesToken) vs combined
          contract (ERC-1155 CombinedPropertyYieldToken)
        </Typography>
      </Box>

      {/* Bar Chart Comparison */}
      <Grid container spacing={2}>
        <Grid item xs={12}>
          <ResponsiveContainer width="100%" height={400}>
            <BarChart data={chartData}>
              <CartesianGrid strokeDasharray="3 3" />
              <XAxis dataKey="metric" />
              <YAxis />
              <Tooltip />
              <Legend />
              <Bar dataKey="ERC-721 + ERC-20" fill="#1976d2" name="ERC-721 + ERC-20 (Separate)" />
              <Bar dataKey="ERC-1155" fill="#dc004e" name="ERC-1155 (Combined)" />
            </BarChart>
          </ResponsiveContainer>
        </Grid>

        {/* Detailed Comparison Table */}
        <Grid item xs={12}>
          <TableContainer>
            <Table size="small">
              <TableHead>
                <TableRow>
                  <TableCell>
                    <strong>Metric</strong>
                  </TableCell>
                  <TableCell align="right">
                    <strong>ERC-721 + ERC-20</strong>
                  </TableCell>
                  <TableCell align="right">
                    <strong>ERC-1155</strong>
                  </TableCell>
                </TableRow>
              </TableHead>
              <TableBody>
                <TableRow>
                  <TableCell>Agreement Count</TableCell>
                  <TableCell align="right">{comparisonMetrics.erc721.agreementCount}</TableCell>
                  <TableCell align="right">{comparisonMetrics.erc1155.agreementCount}</TableCell>
                </TableRow>
                <TableRow>
                  <TableCell>Total Capital (USD)</TableCell>
                  <TableCell align="right">${comparisonMetrics.erc721.totalCapitalUSD}</TableCell>
                  <TableCell align="right">${comparisonMetrics.erc1155.totalCapitalUSD}</TableCell>
                </TableRow>
                <TableRow>
                  <TableCell>Average Capital (USD)</TableCell>
                  <TableCell align="right">${comparisonMetrics.erc721.averageCapitalUSD}</TableCell>
                  <TableCell align="right">${comparisonMetrics.erc1155.averageCapitalUSD}</TableCell>
                </TableRow>
                <TableRow>
                  <TableCell>Total Repayments (USD)</TableCell>
                  <TableCell align="right">${comparisonMetrics.erc721.totalRepaidUSD}</TableCell>
                  <TableCell align="right">${comparisonMetrics.erc1155.totalRepaidUSD}</TableCell>
                </TableRow>
                <TableRow>
                  <TableCell>Average Repayments (USD)</TableCell>
                  <TableCell align="right">${comparisonMetrics.erc721.averageRepaidUSD}</TableCell>
                  <TableCell align="right">${comparisonMetrics.erc1155.averageRepaidUSD}</TableCell>
                </TableRow>
                <TableRow>
                  <TableCell>Total Shareholders</TableCell>
                  <TableCell align="right">{comparisonMetrics.erc721.totalShareholders}</TableCell>
                  <TableCell align="right">{comparisonMetrics.erc1155.totalShareholders}</TableCell>
                </TableRow>
                <TableRow>
                  <TableCell>Average Shareholders</TableCell>
                  <TableCell align="right">{comparisonMetrics.erc721.averageShareholders}</TableCell>
                  <TableCell align="right">{comparisonMetrics.erc1155.averageShareholders}</TableCell>
                </TableRow>
                <TableRow>
                  <TableCell>Pooling Rate (%)</TableCell>
                  <TableCell align="right">{comparisonMetrics.erc721.poolingRate}%</TableCell>
                  <TableCell align="right">{comparisonMetrics.erc1155.poolingRate}%</TableCell>
                </TableRow>
              </TableBody>
            </Table>
          </TableContainer>
        </Grid>
      </Grid>

      {/* Key Findings Alert */}
      {comparisonMetrics && (
        <Alert severity="info" sx={{ mt: 2 }}>
          <strong>Key Findings:</strong>{' '}
          {comparisonMetrics.erc721.agreementCount > comparisonMetrics.erc1155.agreementCount
            ? 'ERC-721 + ERC-20 has more agreements deployed. '
            : comparisonMetrics.erc1155.agreementCount > comparisonMetrics.erc721.agreementCount
            ? 'ERC-1155 has more agreements deployed. '
            : 'Both token standards have equal agreement counts. '}
          {parseFloat(comparisonMetrics.erc721.poolingRate) > parseFloat(comparisonMetrics.erc1155.poolingRate)
            ? 'ERC-721 + ERC-20 shows higher pooling participation rate.'
            : parseFloat(comparisonMetrics.erc1155.poolingRate) > parseFloat(comparisonMetrics.erc721.poolingRate)
            ? 'ERC-1155 shows higher pooling participation rate.'
            : 'Both token standards have similar pooling rates.'}
        </Alert>
      )}
    </Paper>
  );
};

export default TokenStandardComparisonChart;

