/**
 * Governance Proposal Creation Form Component
 * 
 * Allows users to create governance proposals for:
 * - ROI adjustments (within ±5% bounds)
 * - Reserve allocation (≤20% of capital)
 * - Reserve withdrawal
 * - Parameter updates
 * 
 * Features USD-first display for reserve amounts with live ETH conversion.
 */

import React, { useState, useEffect } from 'react';
import {
  TextField,
  Button,
  Box,
  Typography,
  Alert,
  CircularProgress,
  Select,
  MenuItem,
  FormControl,
  InputLabel,
  FormHelperText,
  Grid,
  Paper,
  Divider,
  InputAdornment
} from '@mui/material';
import { useNavigate } from 'react-router-dom';

// Placeholder imports - implement as needed
// import { useTokenStandard } from '../context/TokenStandardContext';
// import { useEthPrice } from '../context/PriceContext';
import { getYieldAgreements, createGovernanceProposal } from '../services/apiClient';

const GovernanceProposalForm = () => {
  const navigate = useNavigate();

  // State
  const [formData, setFormData] = useState({
    agreement_id: '',
    proposal_type: '',
    target_roi_percent: '',
    target_value_usd: '',
    parameter_type: '', // For parameter updates: GOVERNANCE or AGREEMENT
    parameter_name: '', // For PARAMETER_UPDATE
    parameter_value: '', // For PARAMETER_UPDATE
    description: ''
  });

  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const [success, setSuccess] = useState(null);
  const [validationErrors, setValidationErrors] = useState({});
  const [ethEquivalent, setEthEquivalent] = useState(null);
  const [agreements, setAgreements] = useState([]);
  const [loadingAgreements, setLoadingAgreements] = useState(true);

  // Placeholder - replace with actual context
  const tokenStandard = 'ERC721';
  const ethPrice = 2000; // USD per ETH

  // Fetch all active yield agreements on component mount
  useEffect(() => {
    const fetchAgreements = async () => {
      try {
        setLoadingAgreements(true);
        // Use apiClient to route through NGINX proxy in production
        const response = await getYieldAgreements();
        const data = response.data;
        // Filter only active agreements
        const activeAgreements = data.filter(agreement => agreement.is_active);
        setAgreements(activeAgreements);
      } catch (err) {
        console.error('Error fetching agreements:', err);
      } finally {
        setLoadingAgreements(false);
      }
    };

    fetchAgreements();
  }, []);

  // Calculate ETH equivalent when USD value changes
  useEffect(() => {
    if (formData.target_value_usd && formData.proposal_type.includes('RESERVE')) {
      const ethValue = parseFloat(formData.target_value_usd) / ethPrice;
      setEthEquivalent(ethValue.toFixed(4));
    } else {
      setEthEquivalent(null);
    }
  }, [formData.target_value_usd, formData.proposal_type, ethPrice]);

  const handleChange = (e) => {
    const { name, value } = e.target;
    console.log(`🔄 handleChange called: ${name} = ${value}`);
    setFormData(prev => ({ ...prev, [name]: value }));
    
    // Clear validation error for this field by removing the key entirely
    if (validationErrors[name]) {
      setValidationErrors(prev => {
        const newErrors = { ...prev };
        delete newErrors[name];
        return newErrors;
      });
    }
  };

  const handleProposalTypeChange = (e) => {
    const proposalType = e.target.value;
    setFormData(prev => ({
      ...prev,
      proposal_type: proposalType,
      target_roi_percent: '',
      target_value_usd: '',
      parameter_name: '',
      parameter_value: ''
    }));
  };

  const validateForm = () => {
    const errors = {};

    // Validate agreement ID
    if (!formData.agreement_id || formData.agreement_id <= 0) {
      errors.agreement_id = 'Agreement ID must be greater than 0';
    }

    // Validate proposal type selected
    if (!formData.proposal_type) {
      errors.proposal_type = 'Please select a proposal type';
    }

    // Validate based on proposal type
    if (formData.proposal_type === 'ROI_ADJUSTMENT') {
      if (!formData.target_roi_percent || formData.target_roi_percent < 1 || formData.target_roi_percent > 50) {
        errors.target_roi_percent = 'ROI must be between 1% and 50%';
      }
      // Note: ±5% bounds validation should be done against original ROI
    }

    if (formData.proposal_type.includes('RESERVE')) {
      if (!formData.target_value_usd || formData.target_value_usd <= 0) {
        errors.target_value_usd = 'Reserve amount must be greater than 0';
      }
      // Note: 20% limit validation should be done against upfront capital
    }

    if (formData.proposal_type === 'PARAMETER_UPDATE') {
      if (!formData.parameter_name) {
        errors.parameter_name = 'Please select a parameter to update';
      }
      if (!formData.parameter_value || formData.parameter_value <= 0) {
        errors.parameter_value = 'Parameter value must be greater than 0';
      }
    }

    // Validate description
    if (!formData.description || formData.description.length < 10 || formData.description.length > 500) {
      errors.description = 'Description must be between 10 and 500 characters';
    }

    setValidationErrors(errors);
    return Object.keys(errors).length === 0;
  };

  const handleSubmit = async (e) => {
    e.preventDefault();

    // Validate form
    if (!validateForm()) {
      return;
    }

    setLoading(true);
    setError(null);
    setSuccess(null);

    try {
      // Convert inputs to contract format
      let targetValue;
      let parameterType = null;
      let paramId = null;

      if (formData.proposal_type === 'ROI_ADJUSTMENT') {
        // Convert percent to basis points (12.5% = 1250 bp)
        targetValue = Math.floor(parseFloat(formData.target_roi_percent) * 100);
      } else if (formData.proposal_type.includes('RESERVE')) {
        // Convert USD to wei
        const ethValue = parseFloat(formData.target_value_usd) / ethPrice;
        targetValue = Math.floor(ethValue * 1e18); // Convert to wei
      } else if (formData.proposal_type === 'GOVERNANCE_PARAMETER_UPDATE') {
        // Map governance parameter names to IDs
        const govParamMap = {
          'voting_delay': 0,
          'voting_period': 1,
          'quorum_percentage': 2,
          'proposal_threshold': 3
        };
        parameterType = 'GOVERNANCE';
        paramId = govParamMap[formData.parameter_name];
        targetValue = parseInt(formData.parameter_value);
      } else if (formData.proposal_type === 'AGREEMENT_PARAMETER_UPDATE') {
        // Map agreement parameter names to IDs
        const agreementParamMap = {
          'grace_period': 0,
          'penalty_rate': 1,
          'default_threshold': 2,
          'allow_partial_repayment': 3,
          'allow_early_repayment': 4
        };
        parameterType = 'AGREEMENT';
        paramId = agreementParamMap[formData.parameter_name];
        targetValue = parseInt(formData.parameter_value);
      }

      const proposalData = {
        agreement_id: parseInt(formData.agreement_id),
        proposal_type: formData.proposal_type,
        target_value: targetValue,
        target_value_usd: formData.target_value_usd ? parseFloat(formData.target_value_usd) : null,
        parameter_type: parameterType,
        param_id: paramId,
        description: formData.description,
        token_standard: tokenStandard
      };

      // Call API to create proposal using apiClient (routes through NGINX proxy in production)
      console.log('Creating proposal:', proposalData);
      
      const apiResponse = await createGovernanceProposal(proposalData);
      const response = apiResponse.data;

      setSuccess({
        ...response,
        message: `Proposal created successfully! Proposal ID: ${response.blockchain_proposal_id}`
      });

      // Navigate back to governance dashboard after 2 seconds
      setTimeout(() => {
        navigate('/governance');
      }, 2000);

    } catch (err) {
      console.error('Error creating proposal:', err);
      setError(err.detail || err.message || 'Failed to create proposal');
    } finally {
      setLoading(false);
    }
  };

  return (
    <Paper elevation={3} sx={{ p: 4, maxWidth: 800, mx: 'auto', mt: 4 }}>
      <Typography variant="h5" gutterBottom>
        Create Governance Proposal
      </Typography>

      <Alert severity="info" sx={{ mb: 3 }}>
        Token Standard: <strong>{tokenStandard}</strong> - Voting power = token balance (1 token = 1 vote)
      </Alert>

      <Box component="form" onSubmit={handleSubmit} noValidate>
        <Grid container spacing={3}>
          <Grid item xs={12}>
            <FormControl fullWidth required error={!!validationErrors.agreement_id}>
              <InputLabel>Select Yield Agreement</InputLabel>
              <Select
                name="agreement_id"
                value={formData.agreement_id}
                onChange={handleChange}
                label="Select Yield Agreement"
                disabled={loadingAgreements}
              >
                {loadingAgreements ? (
                  <MenuItem disabled>
                    <CircularProgress size={20} sx={{ mr: 1 }} />
                    Loading agreements...
                  </MenuItem>
                ) : agreements.length === 0 ? (
                  <MenuItem disabled>No active agreements found</MenuItem>
                ) : (
                  agreements.map((agreement) => (
                    <MenuItem key={agreement.id} value={agreement.id}>
                      Agreement #{agreement.id} - Property #{agreement.property_id} 
                      {' '}(${(agreement.upfront_capital_usd || 0).toLocaleString()} capital, {((agreement.annual_roi_basis_points || 0) / 100).toFixed(2)}% ROI)
                    </MenuItem>
                  ))
                )}
              </Select>
              {validationErrors.agreement_id ? (
                <Typography variant="caption" color="error" sx={{ mt: 0.5, ml: 1.5 }}>
                  {validationErrors.agreement_id}
                </Typography>
              ) : (
                <Typography variant="caption" color="textSecondary" sx={{ mt: 0.5, ml: 1.5 }}>
                  Select the yield agreement to govern
                </Typography>
              )}
            </FormControl>
          </Grid>

          <Grid item xs={12}>
            <FormControl fullWidth required error={!!validationErrors.proposal_type}>
              <InputLabel>Proposal Type</InputLabel>
              <Select
                name="proposal_type"
                value={formData.proposal_type}
                onChange={handleProposalTypeChange}
                label="Proposal Type"
              >
                <MenuItem value="ROI_ADJUSTMENT">ROI Adjustment (±5% bounds)</MenuItem>
                <MenuItem value="RESERVE_ALLOCATION">Reserve Allocation (≤20% capital)</MenuItem>
                <MenuItem value="RESERVE_WITHDRAWAL">Reserve Withdrawal</MenuItem>
                <MenuItem value="GOVERNANCE_PARAMETER_UPDATE">Governance Parameter Update</MenuItem>
                <MenuItem value="AGREEMENT_PARAMETER_UPDATE">Agreement Parameter Update</MenuItem>
              </Select>
            </FormControl>
          </Grid>

          {/* Conditional fields based on proposal type */}
          {formData.proposal_type === 'ROI_ADJUSTMENT' && (
            <Grid item xs={12}>
              <TextField
                required
                fullWidth
                type="number"
                name="target_roi_percent"
                label="New Annual ROI (%)"
                value={formData.target_roi_percent}
                onChange={handleChange}
                inputProps={{ step: '0.1', min: '1', max: '50' }}
                error={!!validationErrors.target_roi_percent}
                helperText={validationErrors.target_roi_percent || 'Must be within ±5% of original ROI'}
              />
            </Grid>
          )}

          {(formData.proposal_type === 'RESERVE_ALLOCATION' || formData.proposal_type === 'RESERVE_WITHDRAWAL') && (
            <>
              <Grid item xs={12}>
                <TextField
                  required
                  fullWidth
                  type="number"
                  name="target_value_usd"
                  label={formData.proposal_type === 'RESERVE_ALLOCATION' ? 'Reserve Amount (USD)' : 'Withdrawal Amount (USD)'}
                  value={formData.target_value_usd}
                  onChange={handleChange}
                  InputProps={{
                    startAdornment: <InputAdornment position="start">$</InputAdornment>,
                  }}
                  error={!!validationErrors.target_value_usd}
                  helperText={validationErrors.target_value_usd || (formData.proposal_type === 'RESERVE_ALLOCATION' ? 'Maximum 20% of upfront capital' : 'Amount to return to investors')}
                />
              </Grid>
              {ethEquivalent && (
                <Grid item xs={12}>
                  <Typography variant="caption" color="textSecondary">
                    ≈ {ethEquivalent} ETH (at ${ethPrice}/ETH)
                  </Typography>
                </Grid>
              )}
            </>
          )}

          {formData.proposal_type === 'GOVERNANCE_PARAMETER_UPDATE' && (
            <Grid item xs={12}>
              <FormControl fullWidth required error={!!validationErrors.parameter_name}>
                <InputLabel>Parameter to Update</InputLabel>
                <Select
                  name="parameter_name"
                  value={formData.parameter_name}
                  onChange={handleChange}
                  label="Parameter to Update"
                >
                  <MenuItem value="voting_delay">Voting Delay (seconds)</MenuItem>
                  <MenuItem value="voting_period">Voting Period (seconds)</MenuItem>
                  <MenuItem value="quorum_percentage">Quorum Percentage (basis points)</MenuItem>
                  <MenuItem value="proposal_threshold">Proposal Threshold (basis points)</MenuItem>
                </Select>
                {validationErrors.parameter_name ? (
                  <Typography variant="caption" color="error" sx={{ mt: 0.5, ml: 1.5 }}>
                    {validationErrors.parameter_name}
                  </Typography>
                ) : (
                  <Typography variant="caption" color="textSecondary" sx={{ mt: 0.5, ml: 1.5 }}>
                    Select which governance parameter to modify
                  </Typography>
                )}
              </FormControl>
            </Grid>
          )}

          {formData.proposal_type === 'AGREEMENT_PARAMETER_UPDATE' && (
            <Grid item xs={12}>
              <FormControl fullWidth required error={!!validationErrors.parameter_name}>
                <InputLabel>Parameter to Update</InputLabel>
                <Select
                  name="parameter_name"
                  value={formData.parameter_name}
                  onChange={handleChange}
                  label="Parameter to Update"
                >
                  <MenuItem value="grace_period">Grace Period (days)</MenuItem>
                  <MenuItem value="penalty_rate">Penalty Rate (basis points)</MenuItem>
                  <MenuItem value="default_threshold">Default Threshold (missed payments)</MenuItem>
                  <MenuItem value="allow_partial_repayment">Allow Partial Repayment (0/1)</MenuItem>
                  <MenuItem value="allow_early_repayment">Allow Early Repayment (0/1)</MenuItem>
                </Select>
                {validationErrors.parameter_name ? (
                  <Typography variant="caption" color="error" sx={{ mt: 0.5, ml: 1.5 }}>
                    {validationErrors.parameter_name}
                  </Typography>
                ) : (
                  <Typography variant="caption" color="textSecondary" sx={{ mt: 0.5, ml: 1.5 }}>
                    Select which agreement parameter to modify
                  </Typography>
                )}
              </FormControl>
            </Grid>
          )}

          {(formData.proposal_type === 'GOVERNANCE_PARAMETER_UPDATE' || formData.proposal_type === 'AGREEMENT_PARAMETER_UPDATE') && (
            <>
              <Grid item xs={12}>
                <TextField
                  required
                  fullWidth
                  type="number"
                  name="parameter_value"
                  label="New Parameter Value"
                  value={formData.parameter_value}
                  onChange={handleChange}
                  inputProps={{ step: '1', min: '0' }}
                  error={!!validationErrors.parameter_value}
                  helperText={validationErrors.parameter_value || 'Enter new value for the selected parameter'}
                />
              </Grid>

              <Grid item xs={12}>
                <Alert severity="info" sx={{ fontSize: '0.875rem' }}>
                  <strong>Parameter Guidelines:</strong>
                  {formData.proposal_type === 'GOVERNANCE_PARAMETER_UPDATE' ? (
                    <ul style={{ marginTop: 4, marginBottom: 0 }}>
                      <li><strong>Voting Delay:</strong> 1 hour to 7 days (3600-604800 seconds)</li>
                      <li><strong>Voting Period:</strong> 1 day to 30 days (86400-2592000 seconds)</li>
                      <li><strong>Quorum Percentage:</strong> 5% to 50% (500-5000 basis points)</li>
                      <li><strong>Proposal Threshold:</strong> 0.1% to 10% (10-1000 basis points)</li>
                    </ul>
                  ) : (
                    <ul style={{ marginTop: 4, marginBottom: 0 }}>
                      <li><strong>Grace Period:</strong> Days before penalties apply (1-90)</li>
                      <li><strong>Penalty Rate:</strong> 1% to 20% (100-2000 basis points)</li>
                      <li><strong>Default Threshold:</strong> Missed payments before default (1-12)</li>
                      <li><strong>Boolean Parameters:</strong> 1 = true, 0 = false</li>
                    </ul>
                  )}
                </Alert>
              </Grid>
            </>
          )}

          <Grid item xs={12}>
            <TextField
              required
              fullWidth
              multiline
              rows={4}
              name="description"
              label="Proposal Description"
              value={formData.description}
              onChange={handleChange}
              error={!!validationErrors.description}
              helperText={`${formData.description.length}/500 characters - Explain rationale for this governance action`}
            />
          </Grid>

          <Grid item xs={12}>
            <Divider />
          </Grid>

          <Grid item xs={12}>
            <Button
              type="submit"
              variant="contained"
              color="primary"
              fullWidth
              disabled={loading || Object.keys(validationErrors).length > 0}
            >
              {loading ? <CircularProgress size={24} /> : 'Create Proposal'}
            </Button>
          </Grid>
        </Grid>

        {success && (
          <Alert severity="success" sx={{ mt: 3 }}>
            {success.message}
            <Typography variant="body2" sx={{ mt: 1 }}>
              Voting starts: {new Date(success.voting_start).toLocaleString()}
            </Typography>
            <Typography variant="body2">
              Voting ends: {new Date(success.voting_end).toLocaleString()}
            </Typography>
            <Typography variant="body2">
              Quorum required: {success.quorum_required} votes (10% of supply)
            </Typography>
          </Alert>
        )}

        {error && (
          <Alert severity="error" sx={{ mt: 3 }}>
            {error}
          </Alert>
        )}
      </Box>
    </Paper>
  );
};

export default GovernanceProposalForm;

