/**
 * User Portfolio Page
 * 
 * Displays user's share holdings across all yield agreements.
 * Shows real balance data from UserShareBalance table.
 * 
 * Features:
 * - User profile switcher for testing
 * - Holdings table with agreement details
 * - Ownership percentages
 * - Real-time balance updates
 */

import React, { useState, useEffect } from 'react';
import { useNavigate, useLocation } from 'react-router-dom';
import {
  Container,
  Typography,
  Card,
  CardContent,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  Paper,
  Box,
  Chip,
  CircularProgress,
  Alert,
  Button,
  Tooltip,
  IconButton
} from '@mui/material';
import AddShoppingCartIcon from '@mui/icons-material/AddShoppingCart';
import RefreshIcon from '@mui/icons-material/Refresh';
import UserProfileSwitcher from '../components/UserProfileSwitcher';
import { getPortfolio } from '../services/apiClient';

export default function Portfolio() {
  const navigate = useNavigate();
  const location = useLocation();
  const [currentProfile, setCurrentProfile] = useState(null);
  const [portfolio, setPortfolio] = useState(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);

  // Load portfolio when profile changes or when navigating back to this page
  useEffect(() => {
    if (currentProfile) {
      loadPortfolio(currentProfile.wallet_address);
    }
  }, [currentProfile, location.key]); // location.key changes on navigation

  // Auto-refresh when page becomes visible (user returns to tab)
  useEffect(() => {
    const handleVisibilityChange = () => {
      if (!document.hidden && currentProfile) {
        loadPortfolio(currentProfile.wallet_address);
      }
    };

    document.addEventListener('visibilitychange', handleVisibilityChange);
    return () => document.removeEventListener('visibilitychange', handleVisibilityChange);
  }, [currentProfile]);

  const loadPortfolio = async (walletAddress) => {
    setLoading(true);
    setError(null);
    
    try {
      const data = await getPortfolio(walletAddress);
      setPortfolio(data);
    } catch (err) {
      console.error('Error loading portfolio:', err);
      setError(err.message || 'Failed to load portfolio');
    } finally {
      setLoading(false);
    }
  };

  const handleCreateListing = (agreementId) => {
    navigate(`/marketplace/create/${agreementId}`);
  };

  const formatAddress = (address) => {
    if (!address) return '';
    return `${address.substring(0, 6)}...${address.substring(address.length - 4)}`;
  };

  return (
    <Container maxWidth="lg" sx={{ mt: 4, mb: 4 }}>
      <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 2 }}>
        <Typography variant="h4">
          👤 User Portfolio
        </Typography>
        <Tooltip title="Refresh portfolio data">
          <IconButton 
            onClick={() => currentProfile && loadPortfolio(currentProfile.wallet_address)}
            disabled={loading || !currentProfile}
            color="primary"
          >
            <RefreshIcon />
          </IconButton>
        </Tooltip>
      </Box>

      <Card sx={{ mb: 3 }}>
        <CardContent>
          <UserProfileSwitcher
            currentProfile={currentProfile}
            onProfileChange={setCurrentProfile}
          />
        </CardContent>
      </Card>

      {loading && (
        <Box display="flex" justifyContent="center" my={4}>
          <CircularProgress />
        </Box>
      )}

      {error && (
        <Alert severity="error" sx={{ mb: 2 }}>
          {error}
        </Alert>
      )}

      {!loading && !error && portfolio && (
        <>
          <Card sx={{ mb: 3 }}>
            <CardContent>
              <Typography variant="h6" gutterBottom>
                Portfolio Summary
              </Typography>
              <Box sx={{ display: 'flex', gap: 4, mt: 2 }}>
                <Box>
                  <Typography variant="body2" color="text.secondary">
                    Wallet Address
                  </Typography>
                  <Typography variant="body1" fontWeight="medium">
                    {formatAddress(portfolio.user_address)}
                  </Typography>
                </Box>
                <Box>
                  <Typography variant="body2" color="text.secondary">
                    Total Holdings
                  </Typography>
                  <Typography variant="body1" fontWeight="medium">
                    {portfolio.total_agreements} Agreement{portfolio.total_agreements !== 1 ? 's' : ''}
                  </Typography>
                </Box>
                {portfolio.total_shares_value_usd && (
                  <Box>
                    <Typography variant="body2" color="text.secondary">
                      Estimated Value
                    </Typography>
                    <Typography variant="body1" fontWeight="medium">
                      ${portfolio.total_shares_value_usd.toLocaleString()}
                    </Typography>
                  </Box>
                )}
              </Box>
            </CardContent>
          </Card>

          <Card>
            <CardContent>
              <Typography variant="h6" gutterBottom>
                Holdings
              </Typography>
              
              {portfolio.holdings.length === 0 ? (
                <Alert severity="info">
                  No holdings found for this user.
                </Alert>
              ) : (
                <TableContainer component={Paper} sx={{ mt: 2 }}>
                  <Table>
                    <TableHead>
                      <TableRow>
                        <TableCell>Agreement ID</TableCell>
                        <TableCell>Property ID</TableCell>
                        <TableCell align="right">Share Balance</TableCell>
                        <TableCell align="right">Total Supply</TableCell>
                        <TableCell align="right">Ownership %</TableCell>
                        <TableCell>Token Standard</TableCell>
                        <TableCell>Last Updated</TableCell>
                        <TableCell align="center">Actions</TableCell>
                      </TableRow>
                    </TableHead>
                    <TableBody>
                      {portfolio.holdings.map((holding) => (
                        <TableRow key={`${holding.agreement_id}`}>
                          <TableCell>
                            <Chip 
                              label={`#${holding.agreement_id}`} 
                              size="small" 
                              color="primary" 
                            />
                          </TableCell>
                          <TableCell>
                            {holding.property_id ? (
                              <Chip 
                                label={`Property #${holding.property_id}`} 
                                size="small" 
                                variant="outlined"
                              />
                            ) : (
                              <Typography variant="body2" color="text.secondary">
                                N/A
                              </Typography>
                            )}
                          </TableCell>
                          <TableCell align="right">
                            <Typography variant="body2" fontWeight="medium">
                              {holding.balance_shares.toLocaleString(undefined, {
                                maximumFractionDigits: 2
                              })}
                            </Typography>
                            <Typography variant="caption" color="text.secondary">
                              shares
                            </Typography>
                          </TableCell>
                          <TableCell align="right">
                            <Typography variant="body2">
                              {holding.agreement_total_supply?.toLocaleString()}
                            </Typography>
                            <Typography variant="caption" color="text.secondary">
                              shares
                            </Typography>
                          </TableCell>
                          <TableCell align="right">
                            <Chip 
                              label={`${holding.ownership_percentage?.toFixed(2)}%`}
                              size="small"
                              color={
                                holding.ownership_percentage >= 50 ? 'success' : 
                                holding.ownership_percentage >= 25 ? 'warning' : 'default'
                              }
                            />
                          </TableCell>
                          <TableCell>
                            <Chip 
                              label={holding.agreement_token_standard || 'Unknown'} 
                              size="small"
                              variant="outlined"
                            />
                          </TableCell>
                          <TableCell>
                            <Typography variant="body2" color="text.secondary">
                              {holding.last_updated ? 
                                new Date(holding.last_updated + (holding.last_updated.endsWith('Z') ? '' : 'Z')).toLocaleString(undefined, {
                                  year: 'numeric',
                                  month: '2-digit',
                                  day: '2-digit',
                                  hour: '2-digit',
                                  minute: '2-digit',
                                  second: '2-digit',
                                  hour12: false
                                }) : 
                                'N/A'
                              }
                            </Typography>
                          </TableCell>
                          <TableCell align="center">
                            <Tooltip title="Create marketplace listing for these shares">
                              <Button
                                variant="outlined"
                                size="small"
                                startIcon={<AddShoppingCartIcon />}
                                onClick={() => handleCreateListing(holding.agreement_id)}
                                sx={{ minWidth: 'auto' }}
                              >
                                List
                              </Button>
                            </Tooltip>
                          </TableCell>
                        </TableRow>
                      ))}
                    </TableBody>
                  </Table>
                </TableContainer>
              )}
            </CardContent>
          </Card>
        </>
      )}

      {!loading && !error && !portfolio && (
        <Alert severity="info">
          Select a user profile above to view their portfolio.
        </Alert>
      )}
    </Container>
  );
}

