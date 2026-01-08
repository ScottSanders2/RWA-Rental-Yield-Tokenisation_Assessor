// Yield agreement creation form component with USD-first display and live ETH conversion

import React, { useState, useEffect } from 'react';
import {
  TextField,
  Button,
  Box,
  Typography,
  Alert,
  CircularProgress,
  Slider,
  FormControlLabel,
  Switch,
  Grid,
  Paper,
  Divider,
  InputAdornment,
  Select,
  MenuItem,
  FormControl,
  InputLabel,
} from '@mui/material';
// import AttachMoneyIcon from '@mui/icons-material/AttachMoney';
import { useTokenStandard } from '../context/TokenStandardContext';
import { useEthPrice } from '../context/PriceContext';
import { createYieldAgreement, getProperties } from '../services/apiClient';
import UserProfileSwitcher from './UserProfileSwitcher';
import {
  formatWeiToUsd,
  formatUsdToWei,
  formatWeiToEth,
  formatDualCurrency,
  formatBasisPointsToPercent,
  formatPercentToBasisPoints,
  validateEthereumAddress,
  formatAddress,
  formatTxHash,
} from '../utils/formatters';
import { useNavigate } from 'react-router-dom';
import { useSnackbar } from 'notistack';

/**
 * YieldAgreementForm component for creating yield agreements
 * @param {Object} props - React props
 * @param {number} props.propertyTokenId - Pre-filled property token ID
 * @returns {React.ReactElement} Form component
 */
function YieldAgreementForm({ propertyTokenId }) {
  const { tokenStandard, getLabel, getDescription } = useTokenStandard();
  const [currentProfile, setCurrentProfile] = useState(null);
  const { ethUsdPrice } = useEthPrice();
  const navigate = useNavigate();
  const { enqueueSnackbar } = useSnackbar();

  const [formData, setFormData] = useState({
    property_token_id: propertyTokenId || '',
    upfront_capital_usd: '',
    term_months: 24,
    annual_roi_percent: 12.0,
    property_payer: '',
    grace_period_days: 30,
    default_penalty_rate: 2,
    default_threshold: 3,
    allow_partial_repayments: true,
    allow_early_repayment: true,
  });

  const [calculatedPayments, setCalculatedPayments] = useState(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const [success, setSuccess] = useState(null);
  const [validationErrors, setValidationErrors] = useState({});
  const [properties, setProperties] = useState([]);
  const [loadingProperties, setLoadingProperties] = useState(false);

  // Calculate live ETH equivalent when USD input changes
  const [ethEquivalent, setEthEquivalent] = useState('0.0000');

  // Set property token ID from props or auto-generate if not provided
  useEffect(() => {
    if (propertyTokenId) {
      // If propertyTokenId is provided via props (from URL), use it
      setFormData(prev => ({ ...prev, property_token_id: propertyTokenId }));
    } else {
      // If no propertyTokenId provided, auto-generate a yield agreement ID
      const tokenId = parseInt(formData.property_token_id);
      if (!formData.property_token_id || isNaN(tokenId) || tokenId <= 0 || tokenId > 9999) {
        // Generate a unique yield agreement ID that hasn't been used before
        let newId;
        const usedIds = JSON.parse(localStorage.getItem('usedYieldAgreementIds') || '[]');

        do {
          newId = Math.floor(Math.random() * 9000) + 1000; // 1000-9999 range
        } while (usedIds.includes(newId));

        // Mark this ID as used
        usedIds.push(newId);
        localStorage.setItem('usedYieldAgreementIds', JSON.stringify(usedIds));

        setFormData(prev => ({ ...prev, property_token_id: newId }));
      }
    }
  }, [propertyTokenId]); // Run when propertyTokenId changes

  useEffect(() => {
    if (formData.upfront_capital_usd && ethUsdPrice) {
      const usdValue = parseFloat(formData.upfront_capital_usd);
      if (!isNaN(usdValue) && usdValue > 0) {
        const ethValue = usdValue / ethUsdPrice;
        setEthEquivalent(ethValue.toFixed(4));
      } else {
        setEthEquivalent('0.0000');
      }
    } else {
      setEthEquivalent('0.0000');
    }
  }, [formData.upfront_capital_usd, ethUsdPrice]);

  // Fetch properties owned by current profile
  useEffect(() => {
    const fetchProperties = async () => {
      if (!currentProfile || !currentProfile.wallet_address) {
        setProperties([]);
        return;
      }
      
      setLoadingProperties(true);
      try {
        const response = await getProperties(currentProfile.wallet_address);
        // Filter to only show properties without active yield agreements
        const availableProps = response.data.filter(prop => !prop.has_active_yield_agreement);
        setProperties(availableProps);
      } catch (err) {
        console.error('Error fetching properties:', err);
        enqueueSnackbar('Failed to fetch your properties', { variant: 'error' });
        setProperties([]);
      } finally {
        setLoadingProperties(false);
      }
    };
    
    fetchProperties();
  }, [currentProfile, enqueueSnackbar]);

  const handleChange = (field) => (event) => {
    const value = event.target.type === 'checkbox'
      ? event.target.checked
      : event.target.value;

    setFormData(prev => ({ ...prev, [field]: value }));

    // Clear validation error for this field
    if (validationErrors[field]) {
      setValidationErrors(prev => ({ ...prev, [field]: null }));
    }
  };

  const handleSliderChange = (field) => (event, newValue) => {
    setFormData(prev => ({ ...prev, [field]: newValue }));

    // Clear validation error for this field
    if (validationErrors[field]) {
      setValidationErrors(prev => ({ ...prev, [field]: null }));
    }
  };

  const validateForm = () => {
    const errors = {};

    // Property token ID validation (references property, can be any positive integer)
    const tokenId = parseInt(formData.property_token_id);
    if (!formData.property_token_id || isNaN(tokenId) || tokenId <= 0) {
      errors.property_token_id = 'Property token ID must be a positive integer';
    }

    // Upfront capital validation
    const capital = parseFloat(formData.upfront_capital_usd);
    if (!formData.upfront_capital_usd || isNaN(capital) || capital <= 0) {
      errors.upfront_capital_usd = 'Upfront capital must be a positive number';
    }

    // Term months validation
    if (formData.term_months < 1 || formData.term_months > 360) {
      errors.term_months = 'Term must be between 1 and 360 months';
    }

    // ROI validation
    if (formData.annual_roi_percent < 0.01 || formData.annual_roi_percent > 50) {
      errors.annual_roi_percent = 'ROI must be between 0.01% and 50%';
    }

    // Property payer validation (optional)
    if (formData.property_payer.trim() && !validateEthereumAddress(formData.property_payer)) {
      errors.property_payer = 'Property payer must be a valid Ethereum address';
    }

    setValidationErrors(errors);
    return Object.keys(errors).length === 0;
  };

  const handleSubmit = async (event) => {
    event.preventDefault();

    if (!validateForm()) {
      return;
    }

    setLoading(true);
    setError(null);
    setCalculatedPayments(null);

    try {
      // Convert USD to wei
      const upfrontCapitalWei = formatUsdToWei(formData.upfront_capital_usd, ethUsdPrice);

      // Convert percent to basis points
      const roiBasisPoints = formatPercentToBasisPoints(formData.annual_roi_percent);

      const result = await createYieldAgreement({
        property_token_id: parseInt(formData.property_token_id),
        upfront_capital: upfrontCapitalWei,
        upfront_capital_usd: formData.upfront_capital_usd,
        term_months: formData.term_months,
        annual_roi_basis_points: roiBasisPoints,
        property_payer: formData.property_payer.trim() || undefined,
        grace_period_days: formData.grace_period_days,
        default_penalty_rate: formData.default_penalty_rate,
        default_threshold: formData.default_threshold,
        allow_partial_repayments: formData.allow_partial_repayments,
        allow_early_repayment: formData.allow_early_repayment,
        token_standard: tokenStandard,
      });

      const {
        agreement_id,
        monthly_payment,
        total_expected_repayment,
        blockchain_agreement_id,
        token_contract_address,
        tx_hash
      } = result.data;

      // Convert wei values to USD and ETH for display
      const monthlyPaymentUsd = formatWeiToUsd(monthly_payment, ethUsdPrice);
      const monthlyPaymentEth = formatWeiToEth(monthly_payment);
      const totalExpectedUsd = formatWeiToUsd(total_expected_repayment, ethUsdPrice);
      const totalExpectedEth = formatWeiToEth(total_expected_repayment);

      setCalculatedPayments({
        monthly_payment_wei: monthly_payment,
        monthly_payment_usd: monthlyPaymentUsd,
        monthly_payment_eth: monthlyPaymentEth,
        total_expected_wei: total_expected_repayment,
        total_expected_usd: totalExpectedUsd,
        total_expected_eth: totalExpectedEth,
      });

      setSuccess({
        agreement_id,
        blockchain_agreement_id,
        token_contract_address,
        tx_hash,
      });

      enqueueSnackbar('Yield agreement created successfully!', { variant: 'success' });

      // Navigate to agreement detail page
      setTimeout(() => {
        navigate(`/yield-agreements/${agreement_id}`);
      }, 3000);

    } catch (err) {
      const errorMessage = err.message || err.data?.message || 'Failed to create yield agreement';
      setError(errorMessage);
      enqueueSnackbar(errorMessage, { variant: 'error' });
      console.error('Yield agreement creation error:', errorMessage);
    } finally {
      setLoading(false);
    }
  };

  const handleProfileChange = (profile) => {
    setCurrentProfile(profile);
    console.log('👤 Profile changed in YieldAgreementForm:', profile);
  };

  return (
    <Box component="form" onSubmit={handleSubmit} sx={{ width: '100%' }}>
      {/* User Profile Switcher */}
      <Box sx={{ mb: 3 }}>
        <UserProfileSwitcher 
          onProfileChange={handleProfileChange}
          currentProfile={currentProfile}
        />
      </Box>

      <Typography variant="h5" gutterBottom>
        Create Yield Agreement
      </Typography>

      <Alert
        severity="info"
        sx={{ mb: 3 }}
        icon={false}
      >
        <Typography variant="body2" sx={{ fontWeight: 'medium' }}>
          Current Token Standard: {getLabel()}
        </Typography>
        <Typography variant="body2" sx={{ mt: 0.5, opacity: 0.9 }}>
          {getDescription()}
        </Typography>
      </Alert>

      <Grid container spacing={3}>
        {/* Property Selection Dropdown */}
        <Grid item xs={12}>
          <FormControl fullWidth required error={!!validationErrors.property_token_id}>
            <InputLabel>Select Property</InputLabel>
            <Select
              name="property_token_id"
              value={formData.property_token_id}
              onChange={handleChange('property_token_id')}
              label="Select Property"
              disabled={loading || loadingProperties || properties.length === 0}
            >
              {loadingProperties ? (
                <MenuItem disabled>
                  <CircularProgress size={20} sx={{ mr: 1 }} /> Loading your properties...
                </MenuItem>
              ) : properties.length === 0 ? (
                <MenuItem disabled>
                  No properties available (register a property first)
                </MenuItem>
              ) : (
                properties.map((property) => (
                  <MenuItem key={property.id} value={property.blockchain_token_id}>
                    Property #{property.id} - Token ID: {property.blockchain_token_id} 
                    {property.metadata_json && (() => {
                      try {
                        const metadata = JSON.parse(property.metadata_json);
                        return metadata.property_type ? ` (${metadata.property_type})` : '';
                      } catch {
                        return '';
                      }
                    })()}
                  </MenuItem>
                ))
              )}
            </Select>
            {validationErrors.property_token_id ? (
              <Typography variant="caption" color="error" sx={{ mt: 0.5 }}>
                {validationErrors.property_token_id}
              </Typography>
            ) : (
              <Typography variant="caption" color="textSecondary" sx={{ mt: 0.5 }}>
                Select a property you own to create a yield agreement
              </Typography>
            )}
          </FormControl>
        </Grid>

        {/* Token Standard - Read-only */}
        <Grid item xs={12} md={6}>
          <TextField
            fullWidth
            label="Token Standard"
            value={tokenStandard === 'ERC721' ? 'ERC-721 + ERC-20' : tokenStandard === 'ERC1155' ? 'ERC-1155' : tokenStandard}
            disabled
            helperText="Token standard determined by property type (read-only)"
            InputProps={{
              readOnly: true
            }}
          />
        </Grid>

        {/* Total Token Supply - Read-only, calculated */}
        <Grid item xs={12} md={6}>
          <TextField
            fullWidth
            label="Total Token Supply"
            value={formData.upfront_capital_usd ? 
              `${parseFloat(formData.upfront_capital_usd).toLocaleString()} shares` : 
              'Enter capital amount first'}
            disabled
            helperText="Total shares = Upfront capital (USD) amount (read-only)"
            InputProps={{
              readOnly: true
            }}
          />
        </Grid>

        <Grid item xs={12} md={6}>
          <TextField
            fullWidth
            required
            type="number"
            label="Upfront Capital (USD)"
            name="upfront_capital_usd"
            value={formData.upfront_capital_usd}
            onChange={handleChange('upfront_capital_usd')}
            error={!!validationErrors.upfront_capital_usd}
            helperText={
              validationErrors.upfront_capital_usd ||
              `Amount the property owner wants to borrow from investors. Should be less than total rental income to ensure profitable investment (e.g., if rental agreement provides $12,000/year, maximum capital might be $10,800 at 10% ROI).`
            }
            disabled={loading}
            InputProps={{
              startAdornment: (
                <InputAdornment position="start">
                  $
                </InputAdornment>
              ),
            }}
          />
          {formData.upfront_capital_usd && ethUsdPrice && (
            <Typography variant="caption" sx={{ mt: 0.5, color: 'text.secondary' }}>
              ≈ {ethEquivalent} ETH at ${ethUsdPrice.toLocaleString()}/ETH
            </Typography>
          )}
        </Grid>

        {/* Sliders */}
        <Grid item xs={12} md={6}>
          <Typography variant="body2" gutterBottom sx={{ fontWeight: 'medium' }}>
            Agreement Term: {formData.term_months} months ({Math.round(formData.term_months / 12 * 10) / 10} years)
          </Typography>
          <Slider
            value={formData.term_months}
            onChange={handleSliderChange('term_months')}
            aria-label="Agreement Term"
            min={1}
            max={360}
            step={1}
            marks={[
              { value: 12, label: '1' },
              { value: 60, label: '5' },
              { value: 120, label: '10' },
              { value: 180, label: '15' },
            ]}
            valueLabelDisplay="auto"
            valueLabelFormat={(value) => `${value} months`}
            disabled={loading}
            sx={{
              mt: 2,
              '& .MuiSlider-markLabel': {
                fontSize: '0.5rem',
                fontWeight: 400,
              }
            }}
          />
          {validationErrors.term_months && (
            <Typography variant="caption" color="error" sx={{ mt: 0.5 }}>
              {validationErrors.term_months}
            </Typography>
          )}
          <Typography variant="caption" color="text.secondary" sx={{ mt: 0.5 }}>
            Duration should match or be shorter than the rental agreement term (e.g., if rental agreement provides $12,000/year for 5 years, max term should be 60 months).
          </Typography>
        </Grid>

        <Grid item xs={12} md={6}>
          <Typography variant="body2" gutterBottom sx={{ fontWeight: 'medium' }}>
            Annual ROI: {formData.annual_roi_percent}%
          </Typography>
          <Slider
            value={parseFloat(formData.annual_roi_percent)}
            onChange={(event, newValue) => {
              // Round to 2 decimal places to avoid floating point precision issues
              const roundedValue = Math.round(newValue * 100) / 100;
              setFormData(prev => ({ ...prev, annual_roi_percent: roundedValue }));
              if (validationErrors.annual_roi_percent) {
                setValidationErrors(prev => ({ ...prev, annual_roi_percent: null }));
              }
            }}
            aria-label="Annual ROI"
            min={0.01}
            max={50}
            step={0.01}
            marks={[
              { value: 5, label: '5%' },
              { value: 10, label: '10%' },
              { value: 15, label: '15%' },
              { value: 20, label: '20%' },
            ]}
            valueLabelDisplay="auto"
            valueLabelFormat={(value) => `${value.toFixed(2)}%`}
            disabled={loading}
            sx={{ mt: 2 }}
          />
          {validationErrors.annual_roi_percent && (
            <Typography variant="caption" color="error" sx={{ mt: 0.5 }}>
              {validationErrors.annual_roi_percent}
            </Typography>
          )}
        </Grid>

        <Grid item xs={12}>
          <Divider sx={{ my: 2 }}>
            <Typography variant="body2" color="text.secondary">
              Advanced Parameters
            </Typography>
          </Divider>
        </Grid>

        {/* Advanced Parameters */}
        <Grid item xs={12} md={6}>
          <Box sx={{ display: 'flex', gap: 1, alignItems: 'flex-start' }}>
            <TextField
              fullWidth
              label="Property Payer Address"
              name="property_payer"
              value={formData.property_payer}
              onChange={handleChange('property_payer')}
              error={!!validationErrors.property_payer}
              helperText={
                validationErrors.property_payer ||
                'Ethereum wallet address of the designated property payer'
              }
              disabled={loading}
              placeholder="0x..."
              inputProps={{
                pattern: '^0x[a-fA-F0-9]{40}$',
              }}
            />
            <Button
              variant="outlined"
              onClick={() => setFormData(prev => ({
                ...prev,
                property_payer: '0x1234567890123456789012345678901234567890'
              }))}
              disabled={loading}
              sx={{ minWidth: 'auto', px: 2, py: 1.875 }}
              title="Use mock wallet address for development testing"
            >
              🏦 Mock Wallet
            </Button>
          </Box>
          <Typography variant="caption" color="text.secondary" sx={{ mt: 0.5, display: 'block' }}>
            Click the bank icon to use a mock wallet address for development testing
          </Typography>
        </Grid>

        <Grid item xs={12} md={6}>
          <TextField
            fullWidth
            type="number"
            label="Grace Period (Days)"
            name="grace_period_days"
            value={formData.grace_period_days}
            onChange={handleChange('grace_period_days')}
            disabled={loading}
            helperText="Days before late payment penalties apply"
          />
        </Grid>

        <Grid item xs={12} md={6}>
          <TextField
            fullWidth
            type="number"
            label="Default Penalty Rate (%)"
            name="default_penalty_rate"
            value={formData.default_penalty_rate}
            onChange={handleChange('default_penalty_rate')}
            disabled={loading}
            helperText="Late payment penalty percentage"
          />
        </Grid>

        <Grid item xs={12} md={6}>
          <TextField
            fullWidth
            type="number"
            label="Default Threshold (Months)"
            name="default_threshold"
            value={formData.default_threshold}
            onChange={handleChange('default_threshold')}
            disabled={loading}
            helperText="Missed payments before default declaration"
          />
        </Grid>

        <Grid item xs={12} md={6}>
          <FormControlLabel
            control={
              <Switch
                checked={formData.allow_partial_repayments}
                onChange={handleChange('allow_partial_repayments')}
                disabled={loading}
              />
            }
            label="Allow Partial Repayments"
          />
        </Grid>

        <Grid item xs={12} md={6}>
          <FormControlLabel
            control={
              <Switch
                checked={formData.allow_early_repayment}
                onChange={handleChange('allow_early_repayment')}
                disabled={loading}
              />
            }
            label="Allow Early Repayment"
          />
        </Grid>

        {/* Financial Projections */}
        {calculatedPayments && (
          <>
            <Grid item xs={12}>
              <Divider sx={{ my: 2 }}>
                <Typography variant="body2" color="text.secondary">
                  Financial Projections
                </Typography>
              </Divider>
            </Grid>

            <Grid item xs={12}>
              <Alert severity="success">
                <Typography variant="body2" sx={{ fontWeight: 'medium', mb: 1 }}>
                  Monthly Payment: {formatDualCurrency(calculatedPayments.monthly_payment_wei, ethUsdPrice)}
                </Typography>
                <Typography variant="body2">
                  Total Expected Repayment: {formatDualCurrency(calculatedPayments.total_expected_wei, ethUsdPrice)}
                </Typography>
              </Alert>
            </Grid>
          </>
        )}

        {/* Submit Button */}
        <Grid item xs={12}>
          <Box sx={{ display: 'flex', justifyContent: 'flex-end' }}>
            <Button
              type="submit"
              variant="contained"
              color="primary"
              disabled={loading || Object.keys(validationErrors).length > 0}
              sx={{ minWidth: 250 }}
            >
              {loading ? (
                <CircularProgress size={20} color="inherit" sx={{ mr: 1 }} />
              ) : null}
              Create Yield Agreement
            </Button>
          </Box>
        </Grid>
      </Grid>

      {success && (
        <Alert severity="success" sx={{ mt: 3 }}>
          <Typography variant="body2" sx={{ fontWeight: 'medium' }}>
            Yield agreement created successfully!
          </Typography>
          <Typography variant="body2" sx={{ mt: 0.5 }}>
            Agreement ID: {success.agreement_id}
          </Typography>
          {success.blockchain_agreement_id && (
            <Typography variant="body2">
              Blockchain Agreement ID: {success.blockchain_agreement_id}
            </Typography>
          )}
          {success.token_contract_address && (
            <Typography variant="body2" sx={{ fontFamily: 'monospace', fontSize: '0.75rem' }}>
              Token Contract: {formatAddress(success.token_contract_address)}
            </Typography>
          )}
          {success.tx_hash && (
            <Typography variant="body2" sx={{ fontFamily: 'monospace', fontSize: '0.75rem' }}>
              Transaction: {formatTxHash(success.tx_hash)}
            </Typography>
          )}
        </Alert>
      )}

      {error && (
        <Alert severity="error" sx={{ mt: 3 }}>
          <Typography variant="body2">
            {error}
          </Typography>
        </Alert>
      )}
    </Box>
  );
}

export default YieldAgreementForm;
