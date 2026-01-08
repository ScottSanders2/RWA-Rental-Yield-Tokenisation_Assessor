import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
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
  Chip,
  List,
  ListItem,
  ListItemText,
  Divider,
} from '@mui/material';
import { getYieldAgreements } from '../services/apiClient';
import { formatWeiToUsd } from '../utils/formatters';
import { useEthPrice } from '../context/PriceContext';

/**
 * YieldAgreementsList page component for displaying all yield agreements
 * @returns {React.ReactElement} Page component
 */
function YieldAgreementsList() {
  const navigate = useNavigate();
  const { ethUsdPrice } = useEthPrice();
  const [agreements, setAgreements] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    const fetchAgreements = async () => {
      try {
        setLoading(true);
        setError(null);

        // Get all agreements from API
        const result = await getYieldAgreements();
        setAgreements(result.data);
      } catch (err) {
        setError(err.message || 'Failed to load yield agreements');
        console.error('Error fetching yield agreements:', err);
      } finally {
        setLoading(false);
      }
    };

    fetchAgreements();
  }, []);

  const handleViewAgreement = (agreementId) => {
    navigate(`/yield-agreements/${agreementId}`);
  };

  if (loading) {
    return (
      <Container maxWidth="lg" sx={{ mt: 4, mb: 4 }}>
        <Paper elevation={3} sx={{ p: 4 }}>
          <Typography variant="h5" gutterBottom>
            Loading Yield Agreements...
          </Typography>
        </Paper>
      </Container>
    );
  }

  if (error) {
    return (
      <Container maxWidth="lg" sx={{ mt: 4, mb: 4 }}>
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

  return (
    <Container maxWidth="lg" sx={{ mt: 4, mb: 4 }}>
      <Paper elevation={3} sx={{ p: { xs: 2, md: 4 } }}>
        {/* Header */}
        <Box sx={{ mb: 4, display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <Box>
            <Typography variant="h4" component="h1" gutterBottom>
              Yield Agreements
            </Typography>
            <Typography variant="subtitle1" color="text.secondary">
              Monitor your tokenized rental yield agreements
            </Typography>
          </Box>
          <Button variant="contained" onClick={() => navigate('/yield-agreements/create')}>
            Create New Agreement
          </Button>
        </Box>

        <Divider sx={{ mb: 4 }} />

        {agreements.length === 0 ? (
          <Alert severity="info" sx={{ mb: 3 }}>
            No yield agreements found. Create your first agreement to get started.
          </Alert>
        ) : (
          <Grid container spacing={3}>
            {agreements.map((agreement) => (
              <Grid item xs={12} md={6} key={agreement.id}>
                <Card>
                  <CardContent>
                    <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', mb: 2 }}>
                      <Typography variant="h6" component="h2">
                        Agreement #{agreement.id}
                      </Typography>
                      <Chip
                        label={agreement.status || 'Active'}
                        color={agreement.status === 'active' ? 'success' : 'default'}
                        size="small"
                      />
                    </Box>

                    <Box sx={{ mb: 2 }}>
                      <Typography variant="body2" color="text.secondary" sx={{ mb: 1 }}>
                        <strong>Property ID:</strong> {agreement.property_id}
                      </Typography>
                      <Typography variant="body2" color="text.secondary" sx={{ mb: 1 }}>
                        <strong>Upfront Capital:</strong> {agreement.upfront_capital_usd ? `$${agreement.upfront_capital_usd.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}` : '$0.00'}
                      </Typography>
                      <Typography variant="body2" color="text.secondary" sx={{ mb: 1 }}>
                        <strong>Monthly Payment:</strong> {agreement.monthly_payment_usd ? `$${agreement.monthly_payment_usd.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}` : '$0.00'}
                      </Typography>
                      <Typography variant="body2" color="text.secondary" sx={{ mb: 1 }}>
                        <strong>Term:</strong> {agreement.repayment_term_months} months
                      </Typography>
                      <Typography variant="body2" color="text.secondary">
                        <strong>ROI:</strong> {agreement.annual_roi_basis_points / 100}%
                      </Typography>
                    </Box>

                    <Button
                      variant="outlined"
                      size="small"
                      onClick={() => handleViewAgreement(agreement.id)}
                      fullWidth
                    >
                      View Details
                    </Button>
                  </CardContent>
                </Card>
              </Grid>
            ))}
          </Grid>
        )}

        {/* Actions */}
        <Box sx={{ mt: 4, display: 'flex', gap: 2, justifyContent: 'center' }}>
          <Button variant="outlined" onClick={() => navigate('/')}>
            Back to Dashboard
          </Button>
        </Box>
      </Paper>
    </Container>
  );
}

export default YieldAgreementsList;
