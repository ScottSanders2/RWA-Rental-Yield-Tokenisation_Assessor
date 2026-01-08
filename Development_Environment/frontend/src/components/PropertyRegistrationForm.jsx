// Property registration form component with USD/ETH dual display

import React, { useState, useEffect } from 'react';
import {
  TextField,
  Button,
  Box,
  Typography,
  Alert,
  CircularProgress,
  Grid,
  Paper,
  Divider,
  MenuItem,
  Checkbox,
  FormControlLabel,
} from '@mui/material';
import { useTokenStandard } from '../context/TokenStandardContext';
import { useEthPrice } from '../context/PriceContext';
import { registerProperty } from '../services/apiClient';
import {
  validateDeedHash,
  validateEthereumAddress,
  formatTxHash,
} from '../utils/formatters';
import { useNavigate } from 'react-router-dom';
import { useSnackbar } from 'notistack';
import UserProfileSwitcher from './UserProfileSwitcher';

/**
 * PropertyRegistrationForm component for registering new properties
 * @returns {React.ReactElement} Form component
 */
function PropertyRegistrationForm() {
  const { tokenStandard, getLabel, getDescription } = useTokenStandard();
  const { ethUsdPrice } = useEthPrice();
  const navigate = useNavigate();
  const { enqueueSnackbar } = useSnackbar();
  const [currentProfile, setCurrentProfile] = useState(null);

  const [formData, setFormData] = useState({
    property_address: '',
    deed_hash: '',
    rental_agreement_uri: '',
    metadata: '',
    property_type: '',
    square_footage: '',
    bedrooms: '',
    year_built: '',
  });
  const [createYieldAgreementAfterRegistration, setCreateYieldAgreementAfterRegistration] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const [success, setSuccess] = useState(null);
  const [validationErrors, setValidationErrors] = useState({});


  const handleChange = (field) => (event) => {
    const value = event.target.value;
    setFormData(prev => ({ ...prev, [field]: value }));

    // Clear validation error for this field by removing the key
    if (validationErrors[field]) {
      setValidationErrors(prev => {
        const newErrors = { ...prev };
        delete newErrors[field];
        return newErrors;
      });
    }
  };

          const handleFileUpload = async (event, type) => {
            const file = event.target.files[0];
            if (!file) return;

            // Simulate file processing and hash generation
            // In a real implementation, this would upload to IPFS or cloud storage
            const mockHash = '0x' + Array.from({length: 64}, () => Math.floor(Math.random() * 16).toString(16)).join('');
            const mockURI = `https://ipfs.io/ipfs/${Math.random().toString(36).substr(2, 9)}`;

            // Update form data - use functional update to ensure state consistency
            setFormData(prev => {
              const newData = { ...prev };
              if (type === 'deed') {
                newData.deed_hash = mockHash;
              } else if (type === 'rental') {
                newData.rental_agreement_uri = mockURI;
              }
              return newData;
            });

            // Clear validation error by removing the key entirely
            setValidationErrors(prev => {
              const newErrors = { ...prev };
              delete newErrors[type === 'deed' ? 'deed_hash' : 'rental_agreement_uri'];
              return newErrors;
            });
  };

  const updateMetadataFromFields = (data) => {
    // Build metadata JSON from form fields
    const metadata = {};
    if (data.property_type) metadata.property_type = data.property_type;
    if (data.square_footage) metadata.square_footage = parseInt(data.square_footage);
    if (data.bedrooms) metadata.bedrooms = parseInt(data.bedrooms);
    if (data.year_built) metadata.year_built = parseInt(data.year_built);

    // Only update if there are actual values
    if (Object.keys(metadata).length > 0) {
      setFormData(prev => ({ ...prev, metadata: JSON.stringify(metadata, null, 2) }));
    } else {
      setFormData(prev => ({ ...prev, metadata: '' }));
    }
  };

  const validateForm = () => {
    const errors = {};

    // Property address validation
    if (!formData.property_address.trim()) {
      errors.property_address = 'Property address is required';
    }

    // Deed hash validation
    if (!formData.deed_hash) {
      errors.deed_hash = 'Deed hash is required';
    } else if (!validateDeedHash(formData.deed_hash)) {
      errors.deed_hash = 'Deed hash must be a 0x-prefixed 66-character hexadecimal string';
    }

    // Rental agreement URI validation
    if (!formData.rental_agreement_uri) {
      errors.rental_agreement_uri = 'Rental agreement URI is required';
    } else {
      try {
        new URL(formData.rental_agreement_uri);
        const url = new URL(formData.rental_agreement_uri);
        if (!['http:', 'https:', 'ipfs:'].includes(url.protocol)) {
          errors.rental_agreement_uri = 'URI must be HTTP, HTTPS, or IPFS protocol';
        }
      } catch {
        errors.rental_agreement_uri = 'Invalid URI format';
      }
    }

    // Metadata JSON validation (optional)
    if (formData.metadata.trim()) {
      try {
        JSON.parse(formData.metadata);
      } catch {
        errors.metadata = 'Metadata must be valid JSON';
      }
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

    try {
      const metadata = formData.metadata.trim()
        ? JSON.parse(formData.metadata)
        : {};

      const payload = {
        property_address: formData.property_address,
        deed_hash: formData.deed_hash,
        rental_agreement_uri: formData.rental_agreement_uri,
        metadata,
        token_standard: tokenStandard,
        owner_address: currentProfile?.wallet_address || null,
      };

      const result = await registerProperty(payload);

      const { property_id, blockchain_token_id, tx_hash } = result.data;

      setSuccess({
        property_id,
        blockchain_token_id,
        tx_hash,
      });

      enqueueSnackbar('Property registered successfully!', { variant: 'success' });

      // Navigate to yield agreement creation after 2 seconds if checkbox is checked
      // Users can also view all properties via the navigation menu to create agreements later
      if (createYieldAgreementAfterRegistration) {
        setTimeout(() => {
          navigate(`/yield-agreements/create/${blockchain_token_id}`);
        }, 2000);
      }

    } catch (err) {
      const errorMessage = err.message || err.data?.message || 'Failed to register property';
      setError(errorMessage);
      enqueueSnackbar(errorMessage, { variant: 'error' });
      console.error('Property registration error:', errorMessage);
    } finally {
      setLoading(false);
    }
  };

  const handleProfileChange = (profile) => {
    setCurrentProfile(profile);
    console.log('👤 Profile changed in PropertyRegistrationForm:', profile);
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
        Register Property
      </Typography>

      <Alert severity="info" sx={{ mb: 3 }}>
        <Typography variant="body2" sx={{ fontWeight: 'medium', mb: 1 }}>
          Document Preparation Required
        </Typography>
        <Typography variant="body2" sx={{ mb: 1 }}>
          Before registering your property, please prepare:
        </Typography>
        <Typography variant="body2" component="div" sx={{ fontSize: '0.875rem' }}>
          1. <strong>Property Deed:</strong> Upload your property deed to IPFS or cloud storage, then copy the hash/URL<br/>
          2. <strong>Rental Agreement:</strong> Upload your rental agreement document and get a shareable link<br/>
          3. <strong>Property Details:</strong> Optional metadata about your property (type, size, features)
        </Typography>
        <Typography variant="body2" sx={{ mt: 1, fontSize: '0.875rem', opacity: 0.8 }}>
          💡 Tip: Use IPFS for permanent, decentralized storage of your documents
        </Typography>
      </Alert>

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

      <Grid container spacing={2}>
        <Grid item xs={12}>
          <TextField
            fullWidth
            required
            label="Property Address"
            name="property_address"
            value={formData.property_address}
            onChange={handleChange('property_address')}
            error={!!validationErrors.property_address}
            helperText={
              validationErrors.property_address ||
              'Full property address (e.g., 123 Main Street, London, UK)'
            }
            disabled={loading}
          />
        </Grid>

        {/* File Upload Section */}
        <Grid item xs={12}>
          <Typography variant="h6" gutterBottom sx={{ mt: 2 }}>
            Document Upload
          </Typography>
          <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
            Upload your property documents. We'll automatically generate the required hash and URI.
          </Typography>
        </Grid>

                {/* Property Deed Upload */}
                <Grid item xs={12} md={6}>
                  <Box sx={{ border: '2px dashed', borderColor: 'divider', borderRadius: 2, p: 3, textAlign: 'center' }}>
                    <Typography variant="subtitle2" gutterBottom>
                      📄 Property Deed
                    </Typography>
                    <Button
                      variant="outlined"
                      component="label"
                      disabled={loading}
                      sx={{ mb: 1 }}
                    >
                      Choose File
                      <input
                        type="file"
                        accept=".pdf,.doc,.docx,.txt"
                        onChange={(e) => handleFileUpload(e, 'deed')}
                        hidden
                      />
                    </Button>
                    <Typography variant="caption" color="text.secondary" sx={{ display: 'block', mb: 1 }}>
                      PDF, DOC, DOCX, TXT files accepted
                    </Typography>
                    {formData.deed_hash && typeof formData.deed_hash === 'string' && formData.deed_hash.length > 0 && (
                      <Typography variant="caption" color="success.main" sx={{ display: 'block' }}>
                        ✓ Hash generated: {formData.deed_hash.substring(0, 10)}...
                      </Typography>
                    )}
                  </Box>
                </Grid>

                {/* Rental Agreement Upload */}
                <Grid item xs={12} md={6}>
                  <Box sx={{ border: '2px dashed', borderColor: 'divider', borderRadius: 2, p: 3, textAlign: 'center' }}>
                    <Typography variant="subtitle2" gutterBottom>
                      📋 Rental Agreement
                    </Typography>
                    <Button
                      variant="outlined"
                      component="label"
                      disabled={loading}
                      sx={{ mb: 1 }}
                    >
                      Choose File
                      <input
                        type="file"
                        accept=".pdf,.doc,.docx,.txt"
                        onChange={(e) => handleFileUpload(e, 'rental')}
                        hidden
                      />
                    </Button>
                    <Typography variant="caption" color="text.secondary" sx={{ display: 'block', mb: 1 }}>
                      PDF, DOC, DOCX, TXT files accepted
                    </Typography>
                    {formData.rental_agreement_uri && typeof formData.rental_agreement_uri === 'string' && formData.rental_agreement_uri.length > 0 && (
                      <Typography variant="caption" color="success.main" sx={{ display: 'block' }}>
                        ✓ URI generated: {formData.rental_agreement_uri.substring(0, 25)}...
                      </Typography>
                    )}
                  </Box>
                </Grid>

        {/* Manual Override Section */}
        <Grid item xs={12}>
          <Typography variant="body2" color="text.secondary" sx={{ mt: 2, mb: 1 }}>
            Or enter manually if you already have the hash and URI:
          </Typography>
        </Grid>

        <Grid item xs={12}>
          <TextField
            fullWidth
            label="Property Deed Hash (Manual Entry)"
            name="deed_hash"
            value={formData.deed_hash}
            onChange={handleChange('deed_hash')}
            error={!!validationErrors.deed_hash}
            helperText={
              validationErrors.deed_hash ||
              'Cryptographic hash (auto-filled by upload above, or enter manually)'
            }
            disabled={loading}
            inputProps={{
              pattern: '^0x[a-fA-F0-9]{64}$',
            }}
            placeholder="0x..."
          />
        </Grid>

        <Grid item xs={12}>
          <TextField
            fullWidth
            label="Rental Agreement URI (Manual Entry)"
            name="rental_agreement_uri"
            value={formData.rental_agreement_uri}
            onChange={handleChange('rental_agreement_uri')}
            error={!!validationErrors.rental_agreement_uri}
            helperText={
              validationErrors.rental_agreement_uri ||
              'Web link (auto-filled by upload above, or enter manually)'
            }
            disabled={loading}
            placeholder="https://drive.google.com/... or https://ipfs.io/ipfs/..."
          />
        </Grid>

        {/* Property Metadata Section */}
        <Grid item xs={12}>
          <Typography variant="h6" gutterBottom sx={{ mt: 2 }}>
            Property Details
          </Typography>
          <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
            Optional details about your property. This information helps investors understand your property better.
          </Typography>
        </Grid>

        <Grid item xs={12} md={6}>
          <TextField
            select
            fullWidth
            label="Property Type"
            value={formData.property_type || ''}
            onChange={(e) => {
              setFormData(prev => ({ ...prev, property_type: e.target.value }));
              // Update metadata JSON
              updateMetadataFromFields({ ...formData, property_type: e.target.value });
            }}
            disabled={loading}
          >
            <MenuItem value="residential">Residential</MenuItem>
            <MenuItem value="commercial">Commercial</MenuItem>
            <MenuItem value="industrial">Industrial</MenuItem>
            <MenuItem value="mixed-use">Mixed Use</MenuItem>
            <MenuItem value="vacant-land">Vacant Land</MenuItem>
          </TextField>
        </Grid>

        <Grid item xs={12} md={6}>
          <TextField
            fullWidth
            type="number"
            label="Square Footage"
            value={formData.square_footage || ''}
            onChange={(e) => {
              setFormData(prev => ({ ...prev, square_footage: e.target.value }));
              updateMetadataFromFields({ ...formData, square_footage: e.target.value });
            }}
            disabled={loading}
            placeholder="1200"
          />
        </Grid>

        <Grid item xs={12} md={6}>
          <TextField
            fullWidth
            type="number"
            label="Bedrooms"
            value={formData.bedrooms || ''}
            onChange={(e) => {
              setFormData(prev => ({ ...prev, bedrooms: e.target.value }));
              updateMetadataFromFields({ ...formData, bedrooms: e.target.value });
            }}
            disabled={loading}
            placeholder="3"
          />
        </Grid>

        <Grid item xs={12} md={6}>
          <TextField
            fullWidth
            type="number"
            label="Year Built"
            value={formData.year_built || ''}
            onChange={(e) => {
              setFormData(prev => ({ ...prev, year_built: e.target.value }));
              updateMetadataFromFields({ ...formData, year_built: e.target.value });
            }}
            disabled={loading}
            placeholder="1995"
          />
        </Grid>

        {/* Advanced JSON Editor */}
        <Grid item xs={12}>
          <Typography variant="body2" color="text.secondary" sx={{ mt: 2, mb: 1 }}>
            Or edit the raw JSON directly:
          </Typography>
          <TextField
            fullWidth
            multiline
            rows={3}
            label="Raw Metadata (JSON)"
            name="metadata"
            value={formData.metadata}
            onChange={handleChange('metadata')}
            error={!!validationErrors.metadata}
            helperText={
              validationErrors.metadata ||
              'Advanced: Edit the JSON directly or use the fields above'
            }
            disabled={loading}
            placeholder='{"property_type": "residential", "square_footage": 1200}'
          />
        </Grid>
      </Grid>

      <Divider sx={{ my: 3 }} />

      {/* Yield Agreement Creation Option */}
      <Box sx={{ mb: 3 }}>
        <FormControlLabel
          control={
            <Checkbox
              checked={createYieldAgreementAfterRegistration}
              onChange={(e) => setCreateYieldAgreementAfterRegistration(e.target.checked)}
              color="primary"
            />
          }
          label={
            <Box>
              <Typography variant="body1" sx={{ fontWeight: 'medium' }}>
                Create yield agreement immediately after registration
              </Typography>
              <Typography variant="body2" color="text.secondary">
                Automatically navigate to yield agreement creation form after successful property registration.
                You can also create agreements later from the View Properties page.
              </Typography>
            </Box>
          }
        />
      </Box>

      <Box sx={{ display: 'flex', justifyContent: 'flex-end', gap: 2 }}>
        <Button
          type="submit"
          variant="contained"
          color="primary"
          disabled={loading || Object.keys(validationErrors).length > 0}
          sx={{ minWidth: 200 }}
        >
          {loading ? (
            <CircularProgress size={20} color="inherit" sx={{ mr: 1 }} />
          ) : null}
          Register Property
        </Button>
      </Box>

      {success && (
        <Alert severity="success" sx={{ mt: 3 }}>
          <Typography variant="body2" sx={{ fontWeight: 'medium' }}>
            Property registered successfully!
          </Typography>
          <Typography variant="body2" sx={{ mt: 0.5 }}>
            Property ID: {success.property_id}
          </Typography>
          <Typography variant="body2">
            Blockchain Token ID: {success.blockchain_token_id}
          </Typography>
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

export default PropertyRegistrationForm;
