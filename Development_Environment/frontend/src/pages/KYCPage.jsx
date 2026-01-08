import React, { useState, useEffect } from 'react';
import {
  Container,
  Box,
  Typography,
  Tabs,
  Tab,
  Paper,
  Grid,
  Card,
  CardContent,
  Chip,
  Alert,
  Button
} from '@mui/material';
import {
  CheckCircle,
  HourglassEmpty,
  Cancel,
  Info
} from '@mui/icons-material';
import { useWallet } from '../context/WalletContext';
import UserProfileSwitcher from '../components/UserProfileSwitcher';
import KYCSubmissionForm from '../components/KYCSubmissionForm';
import KYCStatusBadge from '../components/KYCStatusBadge';
import apiClient from '../services/apiClient';

/**
 * KYC Page Component
 * 
 * Dedicated page for KYC verification with:
 * - Submission form for new applications
 * - Status display with detailed information
 * - Tabbed interface for easy navigation
 * - Regulatory compliance information
 * 
 * Uses User Profile system for testing (not real wallet connection)
 */
const KYCPage = () => {
  const [currentProfile, setCurrentProfile] = useState(null);
  const account = currentProfile?.wallet_address;
  const [tabValue, setTabValue] = useState(0);
  const [kycStatus, setKycStatus] = useState(null);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    if (account) {
      fetchKYCStatus();
    }
  }, [account]);

  const fetchKYCStatus = async () => {
    if (!account) return;
    
    setLoading(true);
    try {
      const response = await apiClient.get(`/kyc/status/${account}`);
      setKycStatus(response.data);
      // If KYC exists, show status tab
      if (response.data) {
        setTabValue(1);
      }
    } catch (err) {
      if (err.response?.status !== 404) {
        console.error('Failed to fetch KYC status:', err);
      }
      setKycStatus(null);
    } finally {
      setLoading(false);
    }
  };

  const handleTabChange = (event, newValue) => {
    setTabValue(newValue);
  };

  const handleSubmissionSuccess = (data) => {
    setKycStatus(data);
    setTabValue(1); // Switch to status tab
  };

  const getStatusIcon = (status) => {
    switch (status) {
      case 'approved':
        return <CheckCircle color="success" sx={{ fontSize: 40 }} />;
      case 'pending':
        return <HourglassEmpty color="warning" sx={{ fontSize: 40 }} />;
      case 'rejected':
        return <Cancel color="error" sx={{ fontSize: 40 }} />;
      default:
        return <Info color="info" sx={{ fontSize: 40 }} />;
    }
  };

  return (
    <Container maxWidth="lg" sx={{ py: 4 }}>
      {/* Header */}
      <Box sx={{ mb: 4 }}>
        <Typography variant="h4" gutterBottom>
          KYC Verification
        </Typography>
        <Typography variant="body1" color="text.secondary">
          Complete Know Your Customer (KYC) verification to participate in real estate yield tokenization.
          KYC ensures regulatory compliance and protects all platform participants.
        </Typography>
      </Box>

      {/* User Profile Switcher */}
      <Box sx={{ mb: 3 }}>
        <UserProfileSwitcher
          currentProfile={currentProfile}
          onProfileChange={setCurrentProfile}
        />
      </Box>

      {!currentProfile || !account ? (
        <Alert severity="info">
          Please select a user profile above to access KYC verification.
        </Alert>
      ) : (
        <>
      {/* Info Cards */}
      <Grid container spacing={3} sx={{ mb: 4 }}>
        <Grid item xs={12} md={4}>
          <Card>
            <CardContent>
              <Typography variant="h6" gutterBottom>Why KYC?</Typography>
              <Typography variant="body2" color="text.secondary">
                KYC verification ensures compliance with securities regulations and protects
                against fraud and money laundering.
              </Typography>
            </CardContent>
          </Card>
        </Grid>
        <Grid item xs={12} md={4}>
          <Card>
            <CardContent>
              <Typography variant="h6" gutterBottom>What's Required?</Typography>
              <Typography variant="body2" color="text.secondary">
                - Valid government-issued ID
                - Proof of address (utility bill)
                - Email address for notifications
              </Typography>
            </CardContent>
          </Card>
        </Grid>
        <Grid item xs={12} md={4}>
          <Card>
            <CardContent>
              <Typography variant="h6" gutterBottom>Review Time</Typography>
              <Typography variant="body2" color="text.secondary">
                Most applications are reviewed within 24-48 hours.
                You'll receive an email notification when reviewed.
              </Typography>
            </CardContent>
          </Card>
        </Grid>
      </Grid>

      {/* Tabs */}
      <Paper sx={{ mb: 3 }}>
        <Tabs value={tabValue} onChange={handleTabChange}>
          <Tab label="Submit KYC" />
          <Tab label="My Status" disabled={!kycStatus && !loading} />
        </Tabs>
      </Paper>

      {/* Tab Content */}
      {tabValue === 0 && (
        <Box>
          {kycStatus?.status === 'approved' ? (
            <Alert severity="success" sx={{ mb: 2 }}>
              You are already KYC verified! Your verification is valid until{' '}
              {new Date(kycStatus.expiry_date).toLocaleDateString()}.
            </Alert>
          ) : kycStatus?.status === 'pending' ? (
            <Alert severity="info" sx={{ mb: 2 }}>
              Your KYC application is pending review. We'll notify you once it's reviewed.
            </Alert>
          ) : (
            <KYCSubmissionForm 
              currentProfile={currentProfile}
              onSuccess={handleSubmissionSuccess} 
            />
          )}
        </Box>
      )}

      {tabValue === 1 && kycStatus && (
        <Paper sx={{ p: 3 }}>
          {/* Status Header */}
          <Box sx={{ display: 'flex', alignItems: 'center', mb: 3 }}>
            <Box sx={{ mr: 2 }}>
              {getStatusIcon(kycStatus.status)}
            </Box>
            <Box>
              <Typography variant="h5">
                {kycStatus.status === 'approved' && 'Verified'}
                {kycStatus.status === 'pending' && 'Under Review'}
                {kycStatus.status === 'rejected' && 'Application Rejected'}
              </Typography>
              <Chip
                label={kycStatus.tier}
                size="small"
                sx={{ mt: 1, textTransform: 'capitalize' }}
              />
            </Box>
          </Box>

          {/* Status Details */}
          <Grid container spacing={2}>
            <Grid item xs={12} sm={6}>
              <Typography variant="body2" color="text.secondary">
                Wallet Address
              </Typography>
              <Typography variant="body1" sx={{ fontFamily: 'monospace' }}>
                {kycStatus.wallet_address}
              </Typography>
            </Grid>

            <Grid item xs={12} sm={6}>
              <Typography variant="body2" color="text.secondary">
                Submission Date
              </Typography>
              <Typography variant="body1">
                {new Date(kycStatus.submission_date).toLocaleString()}
              </Typography>
            </Grid>

            {kycStatus.review_date && (
              <Grid item xs={12} sm={6}>
                <Typography variant="body2" color="text.secondary">
                  Review Date
                </Typography>
                <Typography variant="body1">
                  {new Date(kycStatus.review_date).toLocaleString()}
                </Typography>
              </Grid>
            )}

            {kycStatus.expiry_date && (
              <Grid item xs={12} sm={6}>
                <Typography variant="body2" color="text.secondary">
                  Expiry Date
                </Typography>
                <Typography variant="body1">
                  {new Date(kycStatus.expiry_date).toLocaleDateString()}
                </Typography>
              </Grid>
            )}

            {kycStatus.whitelisted_on_chain && (
              <Grid item xs={12}>
                <Alert severity="success" icon={<CheckCircle />}>
                  ✓ Whitelisted on blockchain
                  {kycStatus.whitelist_tx_hash && (
                    <Typography variant="caption" display="block" sx={{ mt: 0.5 }}>
                      Transaction: {kycStatus.whitelist_tx_hash.substring(0, 20)}...
                    </Typography>
                  )}
                </Alert>
              </Grid>
            )}

            {kycStatus.status === 'rejected' && (
              <Grid item xs={12}>
                <Alert severity="error">
                  <Typography variant="body2">
                    Your application was not approved. You may submit a new application
                    after addressing any issues.
                  </Typography>
                  <Button
                    size="small"
                    onClick={() => setTabValue(0)}
                    sx={{ mt: 1 }}
                  >
                    Submit New Application
                  </Button>
                </Alert>
              </Grid>
            )}
          </Grid>
        </Paper>
      )}
        </>
      )}
    </Container>
  );
};

export default KYCPage;

