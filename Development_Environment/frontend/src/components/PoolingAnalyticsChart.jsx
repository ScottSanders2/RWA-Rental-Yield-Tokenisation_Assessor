/**
 * Pooling Analytics Chart Component
 * Visualizes shareholder distribution, concentration metrics, and pooling participation
 * Supports Research Question 6 (financial inclusion) and Research Question 7 (liquidity)
 */

import React, { useMemo } from 'react';
import { Box, Typography, Paper, Grid, Chip, CircularProgress, Alert } from '@mui/material';
import { useQuery } from '@apollo/client';
import { GET_POOLING_ANALYTICS } from '../graphql/queries';
import {
  PieChart,
  Pie,
  Cell,
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

// Colors for pie chart
const COLORS = ['#1976d2', '#dc004e', '#4caf50', '#ff9800', '#9c27b0', '#00bcd4', '#ffeb3b', '#795548'];

/**
 * Calculate Gini coefficient for shareholder concentration
 */
const calculateGiniCoefficient = (shares) => {
  if (shares.length === 0) return 0;
  
  const sorted = [...shares].sort((a, b) => a - b);
  const n = sorted.length;
  let sum = 0;
  
  for (let i = 0; i < n; i++) {
    sum += (2 * (i + 1) - n - 1) * sorted[i];
  }
  
  const mean = sorted.reduce((a, b) => a + b, 0) / n;
  return sum / (n * n * mean);
};

/**
 * PoolingAnalyticsChart Component
 * Displays shareholder distribution and pooling metrics
 */
const PoolingAnalyticsChart = () => {
  const { ethUsdPrice } = useEthPrice();
  const { tokenStandard, getLabel } = useTokenStandard();

  // Query pooling analytics data
  const { data, loading, error } = useQuery(GET_POOLING_ANALYTICS);

  // Calculate pooling metrics
  const poolingMetrics = useMemo(() => {
    if (!data?.yieldAgreements) return null;

    const agreements = data.yieldAgreements
      .filter((a) => tokenStandard === 'both' || a.tokenStandard === tokenStandard);

    // Aggregate metrics
    let totalPooledAgreements = 0;
    let totalShareholderCount = 0;
    const shareholderCounts = [];
    const allContributions = [];
    const concentrationMetrics = [];

    agreements.forEach((agreement) => {
      const shareholderCount = agreement.shareholders.length;
      shareholderCounts.push(shareholderCount);
      
      if (shareholderCount > 1) {
        totalPooledAgreements++;
      }
      
      totalShareholderCount += shareholderCount;

      // Collect contributions for median calculation
      agreement.shareholders.forEach((shareholder) => {
        const contributionUSD = parseFloat(shareholder.capitalContributed) / 1e18 * ethUsdPrice;
        allContributions.push(contributionUSD);
      });

      // Calculate concentration (top-3 holder percentage)
      if (shareholderCount > 0) {
        const sortedShares = agreement.shareholders
          .map((s) => parseFloat(s.shares))
          .sort((a, b) => b - a);
        const totalShares = sortedShares.reduce((sum, s) => sum + s, 0);
        const top3Shares = sortedShares.slice(0, 3).reduce((sum, s) => sum + s, 0);
        const concentration = totalShares > 0 ? (top3Shares / totalShares * 100) : 0;
        
        concentrationMetrics.push({
          agreementId: agreement.id.substring(0, 8),
          shareholderCount,
          concentration,
        });
      }
    });

    // Calculate aggregate metrics
    const poolingRate = agreements.length > 0
      ? (totalPooledAgreements / agreements.length * 100).toFixed(1)
      : '0.0';

    const avgShareholdersPerAgreement = agreements.length > 0
      ? (totalShareholderCount / agreements.length).toFixed(1)
      : '0.0';

    // Calculate median contribution
    allContributions.sort((a, b) => a - b);
    const medianContribution = allContributions.length > 0
      ? allContributions[Math.floor(allContributions.length / 2)].toFixed(2)
      : '0.00';

    return {
      poolingRate,
      avgShareholdersPerAgreement,
      medianContribution,
      totalPooledAgreements,
      totalAgreements: agreements.length,
      concentrationMetrics,
    };
  }, [data, tokenStandard, ethUsdPrice]);

  // Prepare shareholder distribution pie chart data (top 10 contributors)
  const shareholderDistributionData = useMemo(() => {
    if (!data?.yieldAgreements) return [];

    const contributorMap = {};

    data.yieldAgreements
      .filter((a) => tokenStandard === 'both' || a.tokenStandard === tokenStandard)
      .forEach((agreement) => {
        agreement.shareholders.forEach((shareholder) => {
          const investor = shareholder.investor;
          const contribution = parseFloat(shareholder.capitalContributed) / 1e18 * ethUsdPrice;

          if (contributorMap[investor]) {
            contributorMap[investor] += contribution;
          } else {
            contributorMap[investor] = contribution;
          }
        });
      });

    // Convert to array and sort by contribution
    const contributors = Object.entries(contributorMap)
      .map(([investor, contribution]) => ({
        investor: `${investor.substring(0, 6)}...${investor.substring(38)}`,
        contribution: contribution.toFixed(2),
      }))
      .sort((a, b) => parseFloat(b.contribution) - parseFloat(a.contribution))
      .slice(0, 10); // Top 10 contributors

    return contributors;
  }, [data, tokenStandard, ethUsdPrice]);

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
        <Alert severity="error">Failed to load pooling data: {error.message}</Alert>
      </Paper>
    );
  }

  // No data state
  if (!poolingMetrics) {
    return (
      <Paper sx={{ p: 3 }}>
        <Alert severity="info">No pooling data available.</Alert>
      </Paper>
    );
  }

  return (
    <Paper sx={{ p: 3 }}>
      <Box sx={{ mb: 2 }}>
        <Typography variant="h6" gutterBottom>
          Pooling Analytics
        </Typography>
        <Typography variant="caption" color="text.secondary">
          Token Standard: {getLabel()}
        </Typography>
      </Box>

      {/* Pooling Metrics Summary */}
      <Grid container spacing={2} sx={{ mb: 3 }}>
        <Grid item xs={12} sm={4}>
          <Chip
            label={`Pooling Rate: ${poolingMetrics.poolingRate}%`}
            color="primary"
            sx={{ width: '100%', fontSize: '0.9rem' }}
          />
        </Grid>
        <Grid item xs={12} sm={4}>
          <Chip
            label={`Avg Shareholders: ${poolingMetrics.avgShareholdersPerAgreement}`}
            color="secondary"
            sx={{ width: '100%', fontSize: '0.9rem' }}
          />
        </Grid>
        <Grid item xs={12} sm={4}>
          <Chip
            label={`Median Contribution: $${poolingMetrics.medianContribution}`}
            color="success"
            sx={{ width: '100%', fontSize: '0.9rem' }}
          />
        </Grid>
      </Grid>

      {/* Charts Grid */}
      <Grid container spacing={2}>
        {/* Shareholder Count per Agreement */}
        <Grid item xs={12} md={6}>
          <Typography variant="subtitle2" gutterBottom>
            Shareholder Distribution by Agreement
          </Typography>
          <ResponsiveContainer width="100%" height={300}>
            <BarChart data={poolingMetrics.concentrationMetrics}>
              <CartesianGrid strokeDasharray="3 3" />
              <XAxis dataKey="agreementId" />
              <YAxis label={{ value: 'Shareholders', angle: -90, position: 'insideLeft' }} />
              <Tooltip />
              <Legend />
              <Bar dataKey="shareholderCount" fill="#1976d2" name="Shareholder Count" />
            </BarChart>
          </ResponsiveContainer>
        </Grid>

        {/* Top Contributors Pie Chart */}
        <Grid item xs={12} md={6}>
          <Typography variant="subtitle2" gutterBottom>
            Top 10 Contributors (USD)
          </Typography>
          <ResponsiveContainer width="100%" height={300}>
            <PieChart>
              <Pie
                data={shareholderDistributionData}
                dataKey="contribution"
                nameKey="investor"
                cx="50%"
                cy="50%"
                outerRadius={80}
                label={(entry) => `${entry.investor}: $${entry.contribution}`}
              >
                {shareholderDistributionData.map((entry, index) => (
                  <Cell key={`cell-${index}`} fill={COLORS[index % COLORS.length]} />
                ))}
              </Pie>
              <Tooltip formatter={(value) => `$${parseFloat(value).toFixed(2)}`} />
            </PieChart>
          </ResponsiveContainer>
        </Grid>

        {/* Concentration Metrics */}
        <Grid item xs={12}>
          <Typography variant="subtitle2" gutterBottom>
            Shareholder Concentration (Top-3 Holder %)
          </Typography>
          <ResponsiveContainer width="100%" height={300}>
            <BarChart data={poolingMetrics.concentrationMetrics}>
              <CartesianGrid strokeDasharray="3 3" />
              <XAxis dataKey="agreementId" />
              <YAxis label={{ value: 'Concentration %', angle: -90, position: 'insideLeft' }} />
              <Tooltip formatter={(value) => `${parseFloat(value).toFixed(2)}%`} />
              <Legend />
              <Bar
                dataKey="concentration"
                fill={(entry) => {
                  if (entry.concentration > 50) return '#dc004e'; // Red for high concentration
                  if (entry.concentration > 20) return '#ff9800'; // Orange for medium
                  return '#4caf50'; // Green for distributed
                }}
                name="Top-3 Holder %"
              />
            </BarChart>
          </ResponsiveContainer>
        </Grid>
      </Grid>

      {/* Pooling Insights */}
      <Box sx={{ mt: 2 }}>
        <Typography variant="caption" color="text.secondary">
          <strong>Pooling Rate:</strong> {poolingMetrics.totalPooledAgreements} out of{' '}
          {poolingMetrics.totalAgreements} agreements have multiple shareholders (
          {poolingMetrics.poolingRate}%)
        </Typography>
      </Box>
    </Paper>
  );
};

export default PoolingAnalyticsChart;

