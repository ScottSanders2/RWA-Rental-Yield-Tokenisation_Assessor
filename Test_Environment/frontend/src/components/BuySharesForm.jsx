/**
 * BuySharesForm Component
 * 
 * Form for purchasing fractional yield shares from secondary market.
 * 
 * Features:
 * - Fractional purchase support (slider 1-100%)
 * - USD-first display with live ETH conversion
 * - Slippage protection (max price validation)
 * - Live calculation of total cost
 * - Transfer restriction pre-validation display
 * 
 * Props:
 * - listingId: ID of the listing to purchase from (from URL params)
 * 
 * Research Contribution:
 * - Demonstrates fractional pooling accessibility
 * - Shows USD-first pricing for clarity
 * - Validates transfer restrictions before purchase
 */

import React, { useState, useEffect } from 'react';
import {
  Box,
  Card,
  CardContent,
  Typography,
  TextField,
  Button,
  Alert,
  CircularProgress,
  Slider,
  Grid,
  Divider
} from '@mui/material';
import { useNavigate, useParams } from 'react-router-dom';
import { useSnackbar } from 'notistack';
import { getListing, buyShares } from '../services/apiClient';
import { useEthPrice } from '../context/PriceContext';
import UserProfileSwitcher from './UserProfileSwitcher';

const BuySharesForm = () => {
  const { listingId } = useParams();
  const navigate = useNavigate();
  const { enqueueSnackbar } = useSnackbar();
  const { ethUsdPrice } = useEthPrice();

  // User profile state
  const [currentProfile, setCurrentProfile] = useState(null);

  const [listing, setListing] = useState(null);
  const [loading, setLoading] = useState(true);
  const [purchasing, setPurchasing] = useState(false);
  const [error, setError] = useState(null);

  const [formData, setFormData] = useState({
    shares_to_buy_fraction: 1.0, // Default to 100% of available shares
    buyer_address: '', // Will be set from currentProfile
    max_price_per_share_usd: null
  });

  // Profile change handler
  const handleProfileChange = (profile) => {
    console.log('👤 Buyer profile changed to:', profile.display_name);
    setCurrentProfile(profile);
    setFormData(prev => ({
      ...prev,
      buyer_address: profile.wallet_address
    }));
  };

  // Fetch listing details
  useEffect(() => {
    const fetchListing = async () => {
      try {
        setLoading(true);
        const { data } = await getListing(listingId);
        setListing(data);
        setFormData(prev => ({
          ...prev,
          max_price_per_share_usd: data.price_per_share_usd * 1.05 // 5% slippage tolerance
        }));
      } catch (err) {
        console.error('Error fetching listing:', err);
        setError('Failed to load listing details');
        enqueueSnackbar('Failed to load listing', { variant: 'error' });
      } finally {
        setLoading(false);
      }
    };

    if (listingId) {
      fetchListing();
    }
  }, [listingId, enqueueSnackbar]);

  // Calculate derived values
  const sharesToBuy = listing 
    ? Math.floor(listing.shares_for_sale * formData.shares_to_buy_fraction)
    : 0;
  
  const totalCostUsd = listing 
    ? (sharesToBuy / 1e18) * listing.price_per_share_usd
    : 0;
  
  const totalCostEth = ethUsdPrice ? totalCostUsd / ethUsdPrice : 0;

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError(null);
    setPurchasing(true);

    try {
      const purchaseData = {
        listing_id: parseInt(listingId),
        shares_to_buy_fraction: formData.shares_to_buy_fraction,
        buyer_address: formData.buyer_address,
        max_price_per_share_usd: formData.max_price_per_share_usd
      };

      const { data } = await buyShares(purchaseData);
      
      enqueueSnackbar('Shares purchased successfully!', { variant: 'success' });
      navigate('/marketplace');
    } catch (err) {
      console.error('Error purchasing shares:', err);
      let errorMessage = 'Failed to purchase shares';
      if (Array.isArray(err.message)) {
        errorMessage = err.message.map(e => e.msg || JSON.stringify(e)).join(', ');
      } else if (typeof err.message === 'string') {
        errorMessage = err.message;
      }
      setError(errorMessage);
      enqueueSnackbar(errorMessage, { variant: 'error' });
    } finally {
      setPurchasing(false);
    }
  };

  if (loading) {
    return (
      <Box display="flex" justifyContent="center" alignItems="center" minHeight="400px">
        <CircularProgress />
      </Box>
    );
  }

  if (!listing) {
    return (
      <Box maxWidth="800px" mx="auto" mt={4}>
        <Alert severity="error">Listing not found</Alert>
        <Button variant="contained" onClick={() => navigate('/marketplace')} sx={{ mt: 2 }}>
          Back to Marketplace
        </Button>
      </Box>
    );
  }

  return (
    <Box maxWidth={900} mx="auto" mt={4}>
      {/* User Profile Switcher */}
      <UserProfileSwitcher
        onProfileChange={handleProfileChange}
        currentProfile={currentProfile}
      />

      <Box>
        <Typography variant="h4" gutterBottom>
          Purchase Yield Shares
        </Typography>
        <Typography variant="body2" color="text.secondary" gutterBottom mb={3}>
          Buy fractional shares from the secondary market with slippage protection.
        </Typography>

        {error && (
        <Alert severity="error" sx={{ mb: 2 }} onClose={() => setError(null)}>
          {error}
        </Alert>
      )}

      <Card>
        <CardContent>
          <Typography variant="h6" gutterBottom>
            Listing Details
          </Typography>

          <Grid container spacing={2} mb={3}>
            <Grid item xs={6}>
              <Typography variant="body2" color="text.secondary">
                Agreement ID
              </Typography>
              <Typography variant="body1" fontWeight="medium">
                #{listing.agreement_id}
              </Typography>
            </Grid>
            <Grid item xs={6}>
              <Typography variant="body2" color="text.secondary">
                Price per Share
              </Typography>
              <Typography variant="body1" fontWeight="medium">
                ${listing.price_per_share_usd?.toFixed(2)} USD
              </Typography>
            </Grid>
            <Grid item xs={6}>
              <Typography variant="body2" color="text.secondary">
                Available Shares
              </Typography>
              <Typography variant="body1" fontWeight="medium">
                {(listing.shares_for_sale / 1e18).toLocaleString(undefined, {
                  minimumFractionDigits: 2,
                  maximumFractionDigits: 2
                })}
              </Typography>
            </Grid>
            <Grid item xs={6}>
              <Typography variant="body2" color="text.secondary">
                Token Standard
              </Typography>
              <Typography variant="body1" fontWeight="medium">
                {listing.token_standard}
              </Typography>
            </Grid>
          </Grid>

          <Divider sx={{ my: 2 }} />

          <form onSubmit={handleSubmit}>
            <Grid container spacing={3}>
              {/* Buyer Address */}
              <Grid item xs={12}>
                <TextField
                  fullWidth
                  label="Your Wallet Address"
                  value={formData.buyer_address}
                  onChange={(e) => setFormData({ ...formData, buyer_address: e.target.value })}
                  placeholder="0x..."
                  required
                  helperText="Your Ethereum wallet address"
                />
              </Grid>

              {/* Purchase Percentage Slider */}
              <Grid item xs={12}>
                <Typography gutterBottom>
                  Percentage to Purchase: {(formData.shares_to_buy_fraction * 100).toFixed(0)}%
                </Typography>
                <Slider
                  value={formData.shares_to_buy_fraction * 100}
                  onChange={(e, value) => setFormData({ ...formData, shares_to_buy_fraction: value / 100 })}
                  min={1}
                  max={100}
                  step={1}
                  marks={[
                    { value: 25, label: '25%' },
                    { value: 50, label: '50%' },
                    { value: 75, label: '75%' },
                    { value: 100, label: '100%' }
                  ]}
                  valueLabelDisplay="auto"
                  valueLabelFormat={(value) => `${value}%`}
                />
                <Typography variant="caption" color="text.secondary">
                  Shares to buy: {(sharesToBuy / 1e18).toLocaleString(undefined, {
                    minimumFractionDigits: 2,
                    maximumFractionDigits: 2
                  })}
                </Typography>
              </Grid>

              {/* Max Price (Slippage Protection) */}
              <Grid item xs={12}>
                <TextField
                  fullWidth
                  type="number"
                  label="Max Price per Share (USD)"
                  value={formData.max_price_per_share_usd || ''}
                  onChange={(e) => setFormData({ ...formData, max_price_per_share_usd: parseFloat(e.target.value) })}
                  inputProps={{ step: '0.01', min: '0' }}
                  helperText="Maximum price you're willing to pay (slippage protection)"
                />
              </Grid>

              {/* Total Cost Display */}
              <Grid item xs={12}>
                <Box bgcolor="primary.50" p={2} borderRadius={1}>
                  <Typography variant="h6" gutterBottom>
                    Total Purchase Cost
                  </Typography>
                  <Typography variant="h4" color="primary" gutterBottom>
                    ${totalCostUsd.toLocaleString(undefined, {
                      minimumFractionDigits: 2,
                      maximumFractionDigits: 2
                    })} USD
                  </Typography>
                  <Typography variant="body2" color="text.secondary">
                    ≈ {totalCostEth.toFixed(6)} ETH
                    {formData.max_price_per_share_usd && formData.max_price_per_share_usd < listing.price_per_share_usd && (
                      <span style={{ color: 'red', marginLeft: '8px' }}>
                        ⚠ Max price is below current listing price!
                      </span>
                    )}
                  </Typography>
                </Box>
              </Grid>

              {/* Action Buttons */}
              <Grid item xs={12}>
                <Box display="flex" gap={2} justifyContent="flex-end">
                  <Button
                    variant="outlined"
                    onClick={() => navigate('/marketplace')}
                    disabled={purchasing}
                  >
                    Cancel
                  </Button>
                  <Button
                    type="submit"
                    variant="contained"
                    disabled={purchasing || !formData.buyer_address}
                  >
                    {purchasing ? <CircularProgress size={24} /> : 'Purchase Shares'}
                  </Button>
                </Box>
              </Grid>
            </Grid>
          </form>
        </CardContent>
      </Card>
      </Box>
    </Box>
  );
};

export default BuySharesForm;

