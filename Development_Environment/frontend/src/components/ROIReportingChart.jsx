/**
 * ROI Reporting Chart Component
 * Visualizes actual vs expected ROI performance across yield agreements
 * Supports filtering by token standard (ERC-721+ERC-20 vs ERC-1155)
 */

import React, { useMemo } from 'react';
import { Box, Typography, Paper, Alert, CircularProgress, Chip } from '@mui/material';
import { useQuery } from '@apollo/client';
import { GET_ALL_AGREEMENTS_ANALYTICS } from '../graphql/queries';
import {
  LineChart,
  Line,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  Legend,
  ResponsiveContainer,
} from 'recharts';
import { useTokenStandard } from '../context/TokenStandardContext';

/**
 * Format basis points to percentage with 2 decimals
 */
const formatBasisPointsToPercent = (basisPoints) => {
  if (!basisPoints && basisPoints !== 0) return '0.00';
  return (basisPoints / 100).toFixed(2);
};

/**
 * ROIReportingChart Component
 * Props:
 *   agreementId (optional): Filter to single agreement, if null shows all agreements
 */
const ROIReportingChart = ({ agreementId = null }) => {
  const { tokenStandard, getLabel } = useTokenStandard();

  // Query agreements with optional token standard filter
  const { data, loading, error } = useQuery(GET_ALL_AGREEMENTS_ANALYTICS, {
    variables: {
      tokenStandard: tokenStandard !== 'both' ? tokenStandard : null,
    },
  });

  // Prepare ROI comparison data
  const roiData = useMemo(() => {
    if (!data?.yieldAgreements) return [];

    return data.yieldAgreements
      .filter((agreement) => !agreementId || agreement.id === agreementId)
      .map((agreement) => {
        const expectedROI = formatBasisPointsToPercent(agreement.annualROIBasisPoints);
        const actualROI = formatBasisPointsToPercent(agreement.actualROIBasisPoints);
        const variance = (parseFloat(actualROI) - parseFloat(expectedROI)).toFixed(2);

        return {
          agreementId: agreement.id.substring(0, 8), // Shortened ID for display
          expectedROI: parseFloat(expectedROI),
          actualROI: parseFloat(actualROI),
          variance: parseFloat(variance),
          createdAt: new Date(parseInt(agreement.createdAt) * 1000).toLocaleDateString(),
        };
      })
      .sort((a, b) => new Date(a.createdAt) - new Date(b.createdAt));
  }, [data, agreementId]);

  // Check for significant variance (>5% difference)
  const significantVariance = useMemo(() => {
    return roiData.find((item) => Math.abs(item.variance) > 5);
  }, [roiData]);

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
        <Alert severity="error">Failed to load ROI data: {error.message}</Alert>
      </Paper>
    );
  }

  // No data state
  if (roiData.length === 0) {
    return (
      <Paper sx={{ p: 3 }}>
        <Alert severity="info">No ROI data available for the selected filter.</Alert>
      </Paper>
    );
  }

  return (
    <Paper sx={{ p: 3 }}>
      <Box sx={{ mb: 2 }}>
        <Typography variant="h6" gutterBottom>
          ROI Performance Analysis
        </Typography>
        <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, mb: 1 }}>
          <Typography variant="caption" color="text.secondary">
            Token Standard Filter:
          </Typography>
          <Chip label={getLabel()} size="small" color="primary" variant="outlined" />
        </Box>
        <Typography variant="caption" color="text.secondary">
          Comparing actual ROI (from repayments) vs expected ROI (configured rate)
        </Typography>
      </Box>

      {/* Variance Alert */}
      {significantVariance && (
        <Alert severity="warning" sx={{ mb: 2 }}>
          <strong>ROI Variance Detected:</strong> Agreement {significantVariance.agreementId} has{' '}
          {significantVariance.variance > 0 ? '+' : ''}
          {significantVariance.variance}% variance from expected ROI.
        </Alert>
      )}

      {/* ROI Chart */}
      <ResponsiveContainer width="100%" height={400}>
        <LineChart data={roiData}>
          <CartesianGrid strokeDasharray="3 3" />
          <XAxis 
            dataKey={agreementId ? "createdAt" : "agreementId"} 
            label={{ 
              value: agreementId ? 'Date' : 'Agreement ID', 
              position: 'insideBottom', 
              offset: -5 
            }} 
          />
          <YAxis
            label={{
              value: 'ROI %',
              angle: -90,
              position: 'insideLeft',
            }}
          />
          <Tooltip
            formatter={(value) => `${parseFloat(value).toFixed(2)}%`}
            labelFormatter={(label) => `Agreement: ${label}`}
          />
          <Legend />
          <Line
            type="monotone"
            dataKey="actualROI"
            stroke="#1976d2"
            strokeWidth={2}
            name="Actual ROI"
            dot={{ r: 4 }}
          />
          <Line
            type="monotone"
            dataKey="expectedROI"
            stroke="#dc004e"
            strokeWidth={2}
            strokeDasharray="5 5"
            name="Expected ROI"
            dot={{ r: 4 }}
          />
          <Line
            type="monotone"
            dataKey="variance"
            stroke="#4caf50"
            strokeWidth={2}
            name="Variance"
            dot={{ r: 3 }}
          />
        </LineChart>
      </ResponsiveContainer>

      {/* ROI Summary */}
      <Box sx={{ mt: 2, display: 'flex', justifyContent: 'space-around', flexWrap: 'wrap' }}>
        <Box sx={{ textAlign: 'center', minWidth: 120 }}>
          <Typography variant="caption" color="text.secondary">
            Avg Expected ROI
          </Typography>
          <Typography variant="h6" color="error">
            {(roiData.reduce((sum, item) => sum + item.expectedROI, 0) / roiData.length).toFixed(2)}%
          </Typography>
        </Box>
        <Box sx={{ textAlign: 'center', minWidth: 120 }}>
          <Typography variant="caption" color="text.secondary">
            Avg Actual ROI
          </Typography>
          <Typography variant="h6" color="primary">
            {(roiData.reduce((sum, item) => sum + item.actualROI, 0) / roiData.length).toFixed(2)}%
          </Typography>
        </Box>
        <Box sx={{ textAlign: 'center', minWidth: 120 }}>
          <Typography variant="caption" color="text.secondary">
            Avg Variance
          </Typography>
          <Typography variant="h6" color="success">
            {(roiData.reduce((sum, item) => sum + item.variance, 0) / roiData.length).toFixed(2)}%
          </Typography>
        </Box>
      </Box>
    </Paper>
  );
};

export default ROIReportingChart;

