import React, { useState, useEffect } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import {
  Container,
  Paper,
  Typography,
  Box,
  Grid,
  Card,
  CardContent,
  Button,
  Alert,
  Divider,
  Chip,
} from '@mui/material';
import { getYieldAgreement } from '../services/apiClient';
import { formatWeiToUsd, formatWeiToEth } from '../utils/formatters';
import { useEthPrice } from '../context/PriceContext';

/**
 * YieldAgreementDetail page component for displaying yield agreement details
 * @returns {React.ReactElement} Page component
 */
function YieldAgreementDetail() {
  const { id } = useParams();
  const navigate = useNavigate();
  const { ethUsdPrice } = useEthPrice();
  const [agreement, setAgreement] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    const fetchAgreement = async () => {
      try {
        setLoading(true);
        setError(null);
        const result = await getYieldAgreement(id);
        setAgreement(result.data);
      } catch (err) {
        setError(err.message || 'Failed to load yield agreement');
        console.error('Error fetching yield agreement:', err);
      } finally {
        setLoading(false);
      }
    };

    if (id) {
      fetchAgreement();
    }
  }, [id]);

  if (loading) {
    return (
      <Container maxWidth="md" sx={{ mt: 4, mb: 4 }}>
        <Paper elevation={3} sx={{ p: 4 }}>
          <Typography variant="h5" gutterBottom>
            Loading Yield Agreement...
          </Typography>
        </Paper>
      </Container>
    );
  }

  if (error) {
    return (
      <Container maxWidth="md" sx={{ mt: 4, mb: 4 }}>
        <Paper elevation={3} sx={{ p: 4 }}>
          <Alert severity="error" sx={{ mb: 3 }}>
            {error}
          </Alert>
          <Button variant="outlined" onClick={() => navigate('/')}>
            Back to Dashboard
          </Button>
        </Paper>
      </Container>
    );
  }

  if (!agreement) {
    return (
      <Container maxWidth="md" sx={{ mt: 4, mb: 4 }}>
        <Paper elevation={3} sx={{ p: 4 }}>
          <Alert severity="warning" sx={{ mb: 3 }}>
            Yield agreement not found.
          </Alert>
          <Button variant="outlined" onClick={() => navigate('/')}>
            Back to Dashboard
          </Button>
        </Paper>
      </Container>
    );
  }

  return (
    <Container maxWidth="lg" sx={{ mt: 4, mb: 4 }}>
      <Paper elevation={3} sx={{ p: { xs: 2, md: 4 } }}>
        {/* Header */}
        <Box sx={{ mb: 4 }}>
          <Typography variant="h4" component="h1" gutterBottom>
            Yield Agreement Details
          </Typography>
          <Typography variant="subtitle1" color="text.secondary">
            Agreement ID: {agreement.id}
          </Typography>
          <Chip
            label={agreement.is_active ? 'Active' : 'Inactive'}
            color={agreement.is_active ? 'success' : 'default'}
            sx={{ mt: 1 }}
          />
        </Box>

        <Divider sx={{ mb: 4 }} />

        <Grid container spacing={3}>
          {/* Financial Summary */}
          <Grid item xs={12} md={6}>
            <Card>
              <CardContent>
                <Typography variant="h6" gutterBottom>
                  📊 Financial Summary
                </Typography>
                <Box sx={{ mt: 2 }}>
                      <Typography variant="body1" sx={{ mb: 1 }}>
                        <strong>Upfront Capital:</strong> {agreement.upfront_capital_usd ? `$${agreement.upfront_capital_usd.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}` : '0.00 USD'}
                      </Typography>
                      <Typography variant="body1" sx={{ mb: 1 }}>
                        <strong>Monthly Payment:</strong> {agreement.upfront_capital_usd && agreement.repayment_term_months && agreement.annual_roi_basis_points ?
                          (() => {
                            // Total repayment = principal * (1 + rate * time)
                            const totalRepayment = agreement.upfront_capital_usd * (1 + (agreement.annual_roi_basis_points / 10000) * (agreement.repayment_term_months / 12));
                            const monthlyPayment = totalRepayment / agreement.repayment_term_months;
                            return new Intl.NumberFormat('en-US', {
                              style: 'currency',
                              currency: 'USD',
                              minimumFractionDigits: 2,
                              maximumFractionDigits: 2,
                            }).format(monthlyPayment);
                          })() : '$0.00'}
                      </Typography>
                      <Typography variant="body1" sx={{ mb: 1 }}>
                        <strong>Total Expected Repayment:</strong> {agreement.upfront_capital_usd && agreement.repayment_term_months && agreement.annual_roi_basis_points ?
                          (() => {
                            // Total repayment = principal * (1 + rate * time)
                            const totalRepayment = agreement.upfront_capital_usd * (1 + (agreement.annual_roi_basis_points / 10000) * (agreement.repayment_term_months / 12));
                            return new Intl.NumberFormat('en-US', {
                              style: 'currency',
                              currency: 'USD',
                              minimumFractionDigits: 2,
                              maximumFractionDigits: 2,
                            }).format(totalRepayment);
                          })() : '$0.00'}
                      </Typography>
                  <Typography variant="body1" sx={{ mb: 1 }}>
                    <strong>Term:</strong> {agreement.repayment_term_months || 0} months
                  </Typography>
                  <Typography variant="body1">
                    <strong>Annual ROI:</strong> {agreement.annual_roi_basis_points ? `${agreement.annual_roi_basis_points / 100}%` : '0%'}
                  </Typography>
                </Box>
              </CardContent>
            </Card>
          </Grid>

          {/* Agreement Details */}
          <Grid item xs={12} md={6}>
            <Card>
              <CardContent>
                <Typography variant="h6" gutterBottom>
                  📋 Agreement Details
                </Typography>
                <Box sx={{ mt: 2 }}>
                  <Typography variant="body1" sx={{ mb: 1 }}>
                    <strong>Property ID:</strong> {agreement.property_id || 'N/A'}
                  </Typography>
                  <Typography variant="body1" sx={{ mb: 1 }}>
                    <strong>Blockchain Agreement ID:</strong> {agreement.blockchain_agreement_id || 'N/A'}
                  </Typography>
                  <Typography variant="body1" sx={{ mb: 1 }}>
                    <strong>Token Contract Address:</strong>
                    <Box component="span" sx={{ fontFamily: 'monospace', fontSize: '0.875rem', wordBreak: 'break-all' }}>
                      {agreement.token_contract_address || 'N/A'}
                    </Box>
                  </Typography>
                  <Typography variant="body1" sx={{ mb: 1 }}>
                    <strong>Token Standard:</strong> {agreement.token_standard || 'N/A'}
                  </Typography>
                  <Typography variant="body1" sx={{ mb: 1 }}>
                    <strong>Created:</strong> {agreement.created_at ? new Date(agreement.created_at).toLocaleDateString() : 'N/A'}
                  </Typography>
                </Box>
              </CardContent>
            </Card>
          </Grid>

          {/* Advanced Parameters */}
          <Grid item xs={12}>
            <Card>
              <CardContent>
                <Typography variant="h6" gutterBottom>
                  ⚙️ Advanced Parameters
                </Typography>
                <Box sx={{ mt: 2 }}>
                  <Typography variant="body1" sx={{ mb: 1 }}>
                    <strong>Grace Period:</strong> {agreement.grace_period_days || 0} days
                  </Typography>
                  <Typography variant="body1" sx={{ mb: 1 }}>
                    <strong>Default Penalty Rate:</strong> {agreement.default_penalty_rate ? `${agreement.default_penalty_rate / 100}%` : '0%'}
                  </Typography>
                  <Typography variant="body1" sx={{ mb: 1 }}>
                    <strong>Allow Partial Repayments:</strong> {agreement.allow_partial_repayments ? 'Yes' : 'No'}
                  </Typography>
                  <Typography variant="body1">
                    <strong>Allow Early Repayment:</strong> {agreement.allow_early_repayment ? 'Yes' : 'No'}
                  </Typography>
                </Box>
              </CardContent>
            </Card>
          </Grid>
        </Grid>

        {/* Actions */}
        <Box sx={{ mt: 4, display: 'flex', gap: 2, justifyContent: 'center' }}>
          <Button variant="outlined" onClick={() => navigate('/')}>
            Back to Dashboard
          </Button>
          <Button variant="contained" onClick={() => navigate('/yield-agreements/create')}>
            Create Another Agreement
          </Button>
        </Box>
      </Paper>
    </Container>
  );
}

export default YieldAgreementDetail;
