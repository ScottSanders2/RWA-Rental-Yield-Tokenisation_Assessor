import React, { useState } from 'react';
import { Box, TextField, Button, MenuItem, Typography, Alert, CircularProgress, Paper } from '@mui/material';
import apiClient from '../services/apiClient';

const KYC_TIERS = [
  { value: 'basic', label: 'Basic (Individual Investor)' },
  { value: 'accredited', label: 'Accredited Investor' },
  { value: 'institutional', label: 'Institutional' }
];

/**
 * KYC Submission Form Component
 * 
 * Allows users to submit KYC applications using User Profile system for testing.
 * Receives currentProfile as prop (not real wallet connection).
 * 
 * Features:
 * - Form validation
 * - Mock signature for testing purposes
 * - Tier selection (basic/accredited/institutional)
 * - Real-time error feedback
 */
const KYCSubmissionForm = ({ onSuccess, currentProfile }) => {
  const account = currentProfile?.wallet_address;
  const [formData, setFormData] = useState({
    full_name: '',
    email: '',
    country: '',
    tier: 'basic'
  });
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState(false);

  const handleChange = (e) => {
    setFormData({ ...formData, [e.target.name]: e.target.value });
    // Clear errors on user input
    if (error) setError('');
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setLoading(true);
    setError('');
    setSuccess(false);

    try {
      if (!account) {
        throw new Error('No user profile selected');
      }

      // Validate form data
      if (!formData.full_name || !formData.email || !formData.country) {
        throw new Error('Please fill in all required fields');
      }

      // Generate mock signature for testing (in production, use real wallet signature)
      const message = `KYC submission for ${account}`;
      const signature = `0xMockSignature_${Date.now()}_${account.slice(-8)}`;

      // Submit KYC application
      const response = await apiClient.post('/kyc/submit', {
        wallet_address: account,
        full_name: formData.full_name,
        email: formData.email,
        country: formData.country,
        tier: formData.tier,
        signature: signature
      });

      setSuccess(true);
      if (onSuccess) {
        onSuccess(response.data);
      }
    } catch (err) {
      const errorMessage = err.response?.data?.detail || err.message || 'Failed to submit KYC application';
      setError(errorMessage);
    } finally {
      setLoading(false);
    }
  };

  if (!currentProfile || !account) {
    return (
      <Alert severity="info" sx={{ my: 2 }}>
        Please select a user profile above to submit KYC application.
      </Alert>
    );
  }

  return (
    <Paper elevation={2} sx={{ p: 3, maxWidth: 600, mx: 'auto' }}>
      <Box component="form" onSubmit={handleSubmit}>
        <Typography variant="h5" gutterBottom>
          KYC Verification Application
        </Typography>
        <Typography variant="body2" color="text.secondary" sx={{ mb: 3 }}>
          Complete KYC verification to participate in yield tokenization. Your information is encrypted and stored securely.
        </Typography>

        <TextField
          fullWidth
          label="Full Name"
          name="full_name"
          value={formData.full_name}
          onChange={handleChange}
          required
          margin="normal"
          helperText="Legal name as it appears on your ID"
        />

        <TextField
          fullWidth
          label="Email"
          name="email"
          type="email"
          value={formData.email}
          onChange={handleChange}
          required
          margin="normal"
          helperText="We'll notify you when your application is reviewed"
        />

        <TextField
          fullWidth
          label="Country"
          name="country"
          value={formData.country}
          onChange={handleChange}
          required
          margin="normal"
          helperText="Country of residence"
        />

        <TextField
          fullWidth
          select
          label="Investor Tier"
          name="tier"
          value={formData.tier}
          onChange={handleChange}
          margin="normal"
          helperText="Select your investor classification"
        >
          {KYC_TIERS.map((option) => (
            <MenuItem key={option.value} value={option.value}>
              {option.label}
            </MenuItem>
          ))}
        </TextField>

        <TextField
          fullWidth
          label="Wallet Address"
          value={account}
          disabled
          margin="normal"
          helperText="Connected wallet address (automatically verified)"
          sx={{ mb: 2 }}
        />

        {error && (
          <Alert severity="error" sx={{ mt: 2 }}>
            {error}
          </Alert>
        )}

        {success && (
          <Alert severity="success" sx={{ mt: 2 }}>
            KYC application submitted successfully! You will be notified by email once reviewed.
          </Alert>
        )}

        <Button
          type="submit"
          variant="contained"
          fullWidth
          disabled={loading || success}
          sx={{ mt: 3 }}
        >
          {loading ? <CircularProgress size={24} /> : 'Submit KYC Application'}
        </Button>

        <Typography variant="caption" color="text.secondary" sx={{ mt: 2, display: 'block' }}>
          By submitting, you agree to our privacy policy and consent to KYC verification.
        </Typography>
      </Box>
    </Paper>
  );
};

export default KYCSubmissionForm;

