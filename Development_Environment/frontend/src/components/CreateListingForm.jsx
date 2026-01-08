/**
 * CreateListingForm Component
 * 
 * Form for creating marketplace listings with USD pricing and fractional share slider.
 * 
 * Features:
 * - Fractional share slider (sell 1%-100% of holdings)
 * - USD-first pricing with live ETH conversion
 * - Total value calculation (shares * price_per_share)
 * - Expiry date configuration (1-365 days)
 * - Token standard selection (ERC-721+ERC-20 or ERC-1155)
 * - Real-time validation and error display
 * 
 * Props:
 * - agreementId: Pre-filled agreement ID (optional)
 * - userShareBalance: User's current share balance in wei
 * - onSuccess: Callback after successful listing creation
 * - onCancel: Callback for cancel button
 * 
 * Research Contribution:
 * - Demonstrates fractional pooling for accessibility
 * - USD-first pricing for user comprehension
 * - Transfer restriction validation before listing
 */

import React, { useState, useEffect } from 'react';
import {
  TextField,
  Button,
  Box,
  Typography,
  Alert,
  CircularProgress,
  Slider,
  Grid,
  Paper,
  Divider,
  InputAdornment,
  FormControl,
  InputLabel,
  Select,
  MenuItem
} from '@mui/material';
import {
  AttachMoney as AttachMoneyIcon,
  Percent as PercentIcon
} from '@mui/icons-material';
import { useNavigate } from 'react-router-dom';
import { useSnackbar } from 'notistack';
import { createListing, getUserAgreements, getUserAvailableBalance } from '../services/apiClient';
import { useEthPrice } from '../context/PriceContext';
import UserProfileSwitcher from './UserProfileSwitcher';

/**
 * CreateListingForm component
 */
const CreateListingForm = ({
  agreementId: propAgreementId,
  userShareBalance: propUserShareBalance,
  onSuccess,
  onCancel
}) => {
  const navigate = useNavigate();
  const { enqueueSnackbar } = useSnackbar();
  const { ethUsdPrice } = useEthPrice();

  // User profile state
  const [currentProfile, setCurrentProfile] = useState(null);

  // Form state
  const [formData, setFormData] = useState({
    agreement_id: propAgreementId || '',
    shares_for_sale_fraction: 1.0, // Default to 100% of holdings
    price_per_share_usd: '',
    expires_in_days: 30,
    token_standard: 'ERC721',
    seller_address: '' // Will be set from currentProfile
  });

  // Agreement data
  const [userAgreements, setUserAgreements] = useState([]);
  const [fetchingAgreements, setFetchingAgreements] = useState(false);
  const [agreementData, setAgreementData] = useState(null);
  const [fetchingAgreement, setFetchingAgreement] = useState(false);
  const [userShareBalance, setUserShareBalance] = useState(propUserShareBalance || null);
  const [availableBalance, setAvailableBalance] = useState(null); // Available = Total - Listed
  const [fetchingAvailableBalance, setFetchingAvailableBalance] = useState(false);

  // Calculated values
  const [calculatedValues, setCalculatedValues] = useState({
    shares_for_sale_wei: 0,
    total_listing_value_usd: 0,
    total_listing_value_eth: 0,
    price_per_share_eth: 0
  });

  // UI state
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const [success, setSuccess] = useState(false);
  const [validationErrors, setValidationErrors] = useState({});

  // Profile change handler
  const handleProfileChange = (profile) => {
    console.log('👤 Seller profile changed to:', profile.display_name);
    setCurrentProfile(profile);
    setFormData(prev => ({
      ...prev,
      seller_address: profile.wallet_address
    }));
  };

  // Fetch user's agreements when profile changes
  useEffect(() => {
    const fetchUserAgreements = async () => {
      if (!currentProfile || !currentProfile.wallet_address) {
        setUserAgreements([]);
        return;
      }

      setFetchingAgreements(true);
      try {
        const response = await getUserAgreements(currentProfile.wallet_address);
        console.log('📋 User agreements:', response);
        setUserAgreements(response.agreements || []);
      } catch (err) {
        console.error('Error fetching user agreements:', err);
        enqueueSnackbar('Failed to fetch your agreements', { variant: 'error' });
        setUserAgreements([]);
      } finally {
        setFetchingAgreements(false);
      }
    };

    fetchUserAgreements();
  }, [currentProfile, enqueueSnackbar]);

  // Fetch agreement details and available balance when agreement_id changes
  useEffect(() => {
    const fetchAgreementData = async () => {
      if (!formData.agreement_id || formData.agreement_id <= 0) {
        setAgreementData(null);
        setUserShareBalance(null);
        setAvailableBalance(null);
        return;
      }

      if (!currentProfile || !currentProfile.wallet_address) {
        enqueueSnackbar('Please select a user profile first', { variant: 'warning' });
        return;
      }

      setFetchingAgreement(true);
      setFetchingAvailableBalance(true);
      try {
        // Find agreement from user's agreements list
        const agreement = userAgreements.find(a => a.id === parseInt(formData.agreement_id));
        
        if (agreement) {
          setAgreementData(agreement);
          
          // Fetch available balance (total - listed)
          const balanceData = await getUserAvailableBalance(
            currentProfile.wallet_address,
            formData.agreement_id
          );
          
          console.log('💰 Available balance:', balanceData);
          
          setUserShareBalance(balanceData.total_balance_wei);
          setAvailableBalance(balanceData);
          
          // Set token standard based on agreement (read-only)
          setFormData(prev => ({
            ...prev,
            token_standard: agreement.token_standard || 'ERC721'
          }));
        } else {
          setAgreementData(null);
          setUserShareBalance(null);
          setAvailableBalance(null);
          enqueueSnackbar('Agreement not found in your holdings', { variant: 'warning' });
        }
      } catch (err) {
        console.error('Error fetching agreement data:', err);
        enqueueSnackbar('Failed to fetch agreement details', { variant: 'error' });
      } finally {
        setFetchingAgreement(false);
        setFetchingAvailableBalance(false);
      }
    };

    fetchAgreementData();
  }, [formData.agreement_id, currentProfile, userAgreements, enqueueSnackbar]);

  // Calculate shares_for_sale_wei when fraction changes
  // NOTE: USD values should NOT fluctuate with ETH price - only recalculate on USD input changes
  // NOW USES AVAILABLE BALANCE (total - already listed)
  useEffect(() => {
    if (availableBalance && formData.shares_for_sale_fraction) {
      // Calculate based on AVAILABLE balance, not total balance
      const shares_for_sale_wei = Math.floor(availableBalance.available_balance_wei * formData.shares_for_sale_fraction);
      const total_listing_value_usd = (shares_for_sale_wei / 1e18) * parseFloat(formData.price_per_share_usd || 0);
      
      // ETH conversion is for reference only - calculated from USD at display time
      const price_per_share_eth = formData.price_per_share_usd / ethUsdPrice;
      const total_listing_value_eth = total_listing_value_usd / ethUsdPrice;

      setCalculatedValues({
        shares_for_sale_wei,
        total_listing_value_usd,
        total_listing_value_eth,
        price_per_share_eth
      });
    }
  }, [formData.shares_for_sale_fraction, formData.price_per_share_usd, availableBalance, ethUsdPrice]);

  // Handle input changes
  const handleChange = (e) => {
    const { name, value } = e.target;
    setFormData(prev => ({
      ...prev,
      [name]: value
    }));
    
    // Clear error for this field
    if (validationErrors[name]) {
      setValidationErrors(prev => {
        const newErrors = { ...prev };
        delete newErrors[name];
        return newErrors;
      });
    }
  };

  // Handle slider change
  const handleSliderChange = (event, newValue) => {
    setFormData(prev => ({
      ...prev,
      shares_for_sale_fraction: newValue
    }));
  };

  // Validate form
  const validateForm = () => {
    const errors = {};

    if (!formData.agreement_id || formData.agreement_id <= 0) {
      errors.agreement_id = 'Agreement ID is required and must be positive';
    }

    if (!formData.shares_for_sale_fraction || formData.shares_for_sale_fraction < 0.01 || formData.shares_for_sale_fraction > 1.0) {
      errors.shares_for_sale_fraction = 'Fraction must be between 0.01 and 1.0';
    }

    if (!formData.price_per_share_usd || formData.price_per_share_usd <= 0) {
      errors.price_per_share_usd = 'Price per share must be positive';
    }

    if (formData.expires_in_days && (formData.expires_in_days < 1 || formData.expires_in_days > 365)) {
      errors.expires_in_days = 'Expiry must be between 1 and 365 days';
    }

    // Check against AVAILABLE balance (not total balance)
    if (!availableBalance) {
      errors.shares_for_sale_fraction = 'Unable to determine available balance';
    } else if (availableBalance.available_balance_wei <= 0) {
      errors.shares_for_sale_fraction = 'No shares available to list (all shares may already be listed)';
    } else if (calculatedValues.shares_for_sale_wei > availableBalance.available_balance_wei) {
      errors.shares_for_sale_fraction = `Insufficient available balance. You have ${availableBalance.available_balance_shares.toFixed(2)} shares available (${availableBalance.listed_balance_shares.toFixed(2)} already listed)`;
    }

    if (!formData.seller_address) {
      errors.seller_address = 'Please select a user profile';
    }

    setValidationErrors(errors);
    return Object.keys(errors).length === 0;
  };

  // Handle form submission
  const handleSubmit = async (e) => {
    e.preventDefault();

    if (!validateForm()) {
      enqueueSnackbar('Please fix validation errors', { variant: 'error' });
      return;
    }

    setLoading(true);
    setError(null);

    try {
      const listingData = {
        agreement_id: parseInt(formData.agreement_id),
        shares_for_sale_fraction: formData.shares_for_sale_fraction,
        price_per_share_usd: parseFloat(formData.price_per_share_usd),
        expires_in_days: parseInt(formData.expires_in_days),
        token_standard: formData.token_standard,
        seller_address: formData.seller_address
      };

      const { data, duration } = await createListing(listingData);

      console.log(`Listing created in ${duration}ms:`, data);

      setSuccess(true);
      enqueueSnackbar(
        `Listing created successfully! Listing ID: ${data.listing_id}`,
        { variant: 'success' }
      );

      // Call success callback or navigate
      if (onSuccess) {
        onSuccess(data);
      } else {
        // Navigate to marketplace after short delay
        setTimeout(() => {
          navigate('/marketplace');
        }, 2000);
      }
    } catch (err) {
      console.error('Error creating listing:', err);
      // Handle Pydantic validation errors (array of error objects)
      let errorMessage = 'Failed to create listing';
      if (Array.isArray(err.message)) {
        // Extract error messages from Pydantic validation errors
        errorMessage = err.message.map(e => e.msg || JSON.stringify(e)).join(', ');
      } else if (typeof err.message === 'string') {
        errorMessage = err.message;
      }
      setError(errorMessage);
      enqueueSnackbar(errorMessage, { variant: 'error' });
    } finally {
      setLoading(false);
    }
  };

  // Handle cancel
  const handleCancelClick = () => {
    if (onCancel) {
      onCancel();
    } else {
      navigate('/marketplace');
    }
  };

  // Slider marks
  const sliderMarks = [
    { value: 0.25, label: '25%' },
    { value: 0.5, label: '50%' },
    { value: 0.75, label: '75%' },
    { value: 1.0, label: '100%' }
  ];

  return (
    <Box maxWidth={900} mx="auto">
      {/* User Profile Switcher */}
      <UserProfileSwitcher
        onProfileChange={handleProfileChange}
        currentProfile={currentProfile}
      />

      <Paper elevation={3} sx={{ p: 3 }}>
        <Typography variant="h5" gutterBottom>
          Create Marketplace Listing
        </Typography>
        <Typography variant="body2" color="text.secondary" paragraph>
          List your yield shares for sale on the secondary market with fractional pooling support.
        </Typography>

        {success && (
        <Alert severity="success" sx={{ mb: 2 }}>
          Listing created successfully! Redirecting to marketplace...
        </Alert>
      )}

      {error && (
        <Alert severity="error" sx={{ mb: 2 }} onClose={() => setError(null)}>
          {error}
        </Alert>
      )}

      <form onSubmit={handleSubmit}>
        <Grid container spacing={3}>
          {/* Agreement ID - Dropdown of user's agreements */}
          <Grid item xs={12} sm={6}>
            <FormControl fullWidth required error={!!validationErrors.agreement_id}>
              <InputLabel>Yield Agreement</InputLabel>
              <Select
                name="agreement_id"
                value={formData.agreement_id}
                onChange={handleChange}
                disabled={!!propAgreementId || loading || fetchingAgreement || fetchingAgreements || userAgreements.length === 0}
                label="Yield Agreement"
              >
                {fetchingAgreements ? (
                  <MenuItem disabled>
                    <CircularProgress size={20} sx={{ mr: 1 }} /> Loading your agreements...
                  </MenuItem>
                ) : userAgreements.length === 0 ? (
                  <MenuItem disabled>No agreements found with shares</MenuItem>
                ) : (
                  userAgreements.map(agreement => (
                    <MenuItem key={agreement.id} value={agreement.id}>
                      Agreement #{agreement.id} - {agreement.agreement_name || 'Unnamed'} ({agreement.user_balance_shares.toFixed(2)} shares, {agreement.ownership_percentage.toFixed(1)}%)
                    </MenuItem>
                  ))
                )}
              </Select>
              {validationErrors.agreement_id && (
                <Typography variant="caption" color="error" sx={{ mt: 0.5 }}>
                  {validationErrors.agreement_id}
                </Typography>
              )}
              {fetchingAgreement && (
                <Typography variant="caption" color="text.secondary" sx={{ mt: 0.5 }}>
                  Fetching agreement details...
                </Typography>
              )}
            </FormControl>
          </Grid>

          {/* Token Standard - Read-only (determined by agreement) */}
          <Grid item xs={12} sm={6}>
            <TextField
              fullWidth
              label="Token Standard"
              value={formData.token_standard === 'ERC721' ? 'ERC-721 + ERC-20' : formData.token_standard === 'ERC1155' ? 'ERC-1155' : formData.token_standard}
              disabled
              helperText="Determined by yield agreement"
              InputProps={{
                readOnly: true
              }}
            />
          </Grid>

          {/* Available Balance Display (Total - Already Listed) */}
          {formData.agreement_id && (
            <Grid item xs={12}>
              {(fetchingAgreement || fetchingAvailableBalance) ? (
                <Alert severity="info" icon={<CircularProgress size={20} />}>
                  Fetching agreement details and available balance...
                </Alert>
              ) : availableBalance ? (
                <Box>
                  <Alert 
                    severity={availableBalance.available_balance_wei > 0 ? "success" : "warning"}
                    sx={{ mb: 1 }}
                  >
                    <Typography variant="body2" fontWeight="medium">
                      Available to List: {availableBalance.available_balance_shares.toLocaleString(undefined, {
                        minimumFractionDigits: 2,
                        maximumFractionDigits: 2
                      })} shares
                    </Typography>
                    <Typography variant="caption" display="block" sx={{ mt: 0.5 }}>
                      • Total Balance: {availableBalance.total_balance_shares.toFixed(2)} shares<br/>
                      • Already Listed: {availableBalance.listed_balance_shares.toFixed(2)} shares<br/>
                      • Available: {availableBalance.available_balance_shares.toFixed(2)} shares
                      {availableBalance.available_balance_wei === 0 && ' ⚠️ All shares are already listed!'}
                    </Typography>
                  </Alert>
                  {agreementData && (
                    <Typography variant="caption" color="text.secondary" display="block">
                      Agreement: #{agreementData.id} • 
                      Total Supply: {agreementData.total_token_supply?.toLocaleString() || 'N/A'} shares • 
                      Token Standard: {agreementData.token_standard === 'ERC721' ? 'ERC-721 + ERC-20' : agreementData.token_standard}
                    </Typography>
                  )}
                </Box>
              ) : (
                <Alert severity="warning">
                  Unable to fetch available balance. Please select an agreement.
                </Alert>
              )}
            </Grid>
          )}

          {/* Fractional Share Slider */}
          <Grid item xs={12}>
            <Typography variant="body2" gutterBottom>
              Percentage of Available Shares to Sell: {(formData.shares_for_sale_fraction * 100).toFixed(0)}%
              {availableBalance && availableBalance.total_balance_shares > 0 && (
                <Typography component="span" variant="body2" color="text.secondary" sx={{ ml: 1 }}>
                  ({((calculatedValues.shares_for_sale_wei / 1e18) / availableBalance.total_balance_shares * 100).toFixed(1)}% of total balance)
                </Typography>
              )}
            </Typography>
            <Slider
              value={formData.shares_for_sale_fraction}
              onChange={handleSliderChange}
              min={0.01}
              max={1.0}
              step={0.01}
              marks={sliderMarks}
              valueLabelDisplay="auto"
              valueLabelFormat={(value) => `${(value * 100).toFixed(0)}%`}
              disabled={loading || !availableBalance || availableBalance.available_balance_wei <= 0}
            />
            <Typography variant="caption" color="text.secondary">
              Shares for Sale: {(calculatedValues.shares_for_sale_wei / 1e18).toLocaleString(undefined, {
                minimumFractionDigits: 2,
                maximumFractionDigits: 2
              })} shares of {availableBalance ? availableBalance.available_balance_shares.toFixed(2) : '0'} available
              {validationErrors.shares_for_sale_fraction && (
                <Typography variant="caption" color="error" display="block">
                  {validationErrors.shares_for_sale_fraction}
                </Typography>
              )}
            </Typography>
          </Grid>

          {/* Price per Share (USD) */}
          <Grid item xs={12} sm={6}>
            <TextField
              fullWidth
              label="Price per Share (USD)"
              name="price_per_share_usd"
              type="number"
              value={formData.price_per_share_usd}
              onChange={handleChange}
              required
              disabled={loading}
              error={!!validationErrors.price_per_share_usd}
              helperText={validationErrors.price_per_share_usd || `≈ ${calculatedValues.price_per_share_eth.toFixed(6)} ETH`}
              InputProps={{
                startAdornment: (
                  <InputAdornment position="start">
                    <AttachMoneyIcon />
                  </InputAdornment>
                ),
                inputProps: { min: 0, step: 0.01 }
              }}
            />
          </Grid>

          {/* Expiry Days */}
          <Grid item xs={12} sm={6}>
            <TextField
              fullWidth
              label="Listing Expiry (Days)"
              name="expires_in_days"
              type="number"
              value={formData.expires_in_days}
              onChange={handleChange}
              disabled={loading}
              error={!!validationErrors.expires_in_days}
              helperText={validationErrors.expires_in_days || 'Listing will expire after this many days'}
              InputProps={{
                inputProps: { min: 1, max: 365 }
              }}
            />
          </Grid>

          {/* Total Listing Value Display */}
          <Grid item xs={12}>
            <Divider sx={{ my: 1 }} />
            <Box sx={{ bgcolor: 'background.default', p: 2, borderRadius: 1 }}>
              <Typography variant="h6" gutterBottom>
                Total Listing Value
              </Typography>
              <Typography variant="h5" color="primary">
                ${calculatedValues.total_listing_value_usd.toLocaleString(undefined, {
                  minimumFractionDigits: 2,
                  maximumFractionDigits: 2
                })} USD
              </Typography>
              <Typography variant="body2" color="text.secondary">
                ≈ {calculatedValues.total_listing_value_eth.toFixed(6)} ETH
              </Typography>
            </Box>
          </Grid>

          {/* Action Buttons */}
          <Grid item xs={12}>
            <Box display="flex" gap={2} justifyContent="flex-end">
              <Button
                variant="outlined"
                onClick={handleCancelClick}
                disabled={loading}
              >
                Cancel
              </Button>
              <Button
                type="submit"
                variant="contained"
                color="primary"
                disabled={loading || fetchingAgreement || Object.keys(validationErrors).length > 0 || !userShareBalance}
                startIcon={loading ? <CircularProgress size={20} /> : null}
              >
                {loading ? 'Creating Listing...' : fetchingAgreement ? 'Fetching Data...' : 'Create Listing'}
              </Button>
            </Box>
          </Grid>
        </Grid>
      </form>
    </Paper>
    </Box>
  );
};

export default CreateListingForm;

