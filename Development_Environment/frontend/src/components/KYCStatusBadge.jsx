import React, { useState, useEffect } from 'react';
import { Chip, Tooltip, CircularProgress, Box } from '@mui/material';
import { CheckCircle, Cancel, HourglassEmpty, Error } from '@mui/icons-material';
import { useWallet } from '../context/WalletContext';
import apiClient from '../services/apiClient';

const STATUS_CONFIG = {
  approved: {
    label: 'KYC Verified',
    color: 'success',
    icon: <CheckCircle fontSize="small" />
  },
  pending: {
    label: 'KYC Pending',
    color: 'warning',
    icon: <HourglassEmpty fontSize="small" />
  },
  rejected: {
    label: 'KYC Rejected',
    color: 'error',
    icon: <Cancel fontSize="small" />
  },
  expired: {
    label: 'KYC Expired',
    color: 'default',
    icon: <Error fontSize="small" />
  },
  not_submitted: {
    label: 'KYC Required',
    color: 'default',
    icon: null
  }
};

/**
 * KYC Status Badge Component
 * 
 * Displays current KYC verification status with color-coded badge.
 * Auto-refreshes status and provides detailed tooltip information.
 * Clickable to navigate to KYC page.
 * 
 * Status indicators:
 * - Green (Approved): User is KYC verified and whitelisted
 * - Yellow (Pending): Application under review
 * - Red (Rejected): Application rejected
 * - Gray (Required): No application submitted
 */
const KYCStatusBadge = ({ onClick, autoRefresh = false }) => {
  const { account } = useWallet();
  const [status, setStatus] = useState('not_submitted');
  const [loading, setLoading] = useState(false);
  const [kycData, setKycData] = useState(null);

  useEffect(() => {
    if (account) {
      fetchKYCStatus();
      
      // Auto-refresh every 30 seconds if enabled
      if (autoRefresh) {
        const interval = setInterval(fetchKYCStatus, 30000);
        return () => clearInterval(interval);
      }
    }
  }, [account, autoRefresh]);

  const fetchKYCStatus = async () => {
    if (!account) return;
    
    setLoading(true);
    try {
      const response = await apiClient.get(`/kyc/status/${account}/public`);
      setKycData(response.data);
      setStatus(response.data.status);
    } catch (err) {
      if (err.response?.status === 404) {
        setStatus('not_submitted');
        setKycData(null);
      } else {
        console.error('Failed to fetch KYC status:', err);
      }
    } finally {
      setLoading(false);
    }
  };

  if (!account) return null;
  if (loading && !kycData) {
    return (
      <Box sx={{ display: 'inline-block', ml: 1 }}>
        <CircularProgress size={20} />
      </Box>
    );
  }

  const config = STATUS_CONFIG[status] || STATUS_CONFIG.not_submitted;

  const tooltipContent = kycData ? (
    <Box sx={{ p: 1 }}>
      <Box sx={{ fontWeight: 'bold', mb: 0.5 }}>KYC Status: {config.label}</Box>
      <Box>Tier: {kycData.tier}</Box>
      {kycData.submission_date && (
        <Box>Submitted: {new Date(kycData.submission_date).toLocaleDateString()}</Box>
      )}
      {kycData.whitelisted_on_chain && (
        <Box sx={{ color: 'success.light', mt: 0.5 }}>✓ Whitelisted on blockchain</Box>
      )}
      {status === 'pending' && (
        <Box sx={{ mt: 0.5, fontStyle: 'italic' }}>Under review...</Box>
      )}
      {status === 'rejected' && (
        <Box sx={{ mt: 0.5, color: 'error.light' }}>Application rejected</Box>
      )}
    </Box>
  ) : (
    <Box sx={{ p: 1 }}>
      Click to submit KYC application
    </Box>
  );

  return (
    <Tooltip title={tooltipContent} arrow placement="bottom">
      <Chip
        label={config.label}
        color={config.color}
        icon={config.icon}
        onClick={onClick}
        size="small"
        sx={{
          cursor: 'pointer',
          '&:hover': {
            opacity: 0.8
          }
        }}
      />
    </Tooltip>
  );
};

export default KYCStatusBadge;

