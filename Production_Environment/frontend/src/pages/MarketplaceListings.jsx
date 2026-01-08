/**
 * MarketplaceListings Page
 * 
 * Browse and purchase fractional yield shares from secondary market.
 * 
 * Features:
 * - Browse active marketplace listings
 * - Filter by agreement ID, token standard, price range, status
 * - USD-first pricing display with ETH conversion
 * - Fractional purchase support (buy partial listings)
 * - Navigate to create listing or purchase shares
 * 
 * Research Contribution:
 * - Demonstrates secondary market liquidity (Research Question 7)
 * - Shows comparative token standards (ERC-721+ERC-20 vs ERC-1155)
 * - USD-first pricing for user comprehension
 * - Fractional pooling for accessibility
 */

import React, { useState, useEffect } from 'react';
import {
  Container,
  Paper,
  Typography,
  Box,
  Grid,
  TextField,
  Select,
  MenuItem,
  FormControl,
  InputLabel,
  Button,
  Alert,
  CircularProgress,
  Divider,
  InputAdornment
} from '@mui/material';
import {
  Add as AddIcon,
  FilterList as FilterListIcon,
  Refresh as RefreshIcon,
  AttachMoney as AttachMoneyIcon
} from '@mui/icons-material';
import { useNavigate } from 'react-router-dom';
import { getListings, cancelListing } from '../services/apiClient';
import MarketplaceListingCard from '../components/MarketplaceListingCard';
import { useSnackbar } from 'notistack';

/**
 * MarketplaceListings page component
 */
const MarketplaceListings = () => {
  const navigate = useNavigate();
  const { enqueueSnackbar } = useSnackbar();

  // State
  const [listings, setListings] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [filters, setFilters] = useState({
    agreement_id: '',
    token_standard: '',
    min_price_usd: '',
    max_price_usd: '',
    status: 'active' // Default to active listings
  });

  // Placeholder current user address (would come from wallet context in production)
  const [currentUserAddress] = useState('0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb');

  // Fetch listings on mount and when filters change
  useEffect(() => {
    fetchListings();
  }, []); // eslint-disable-line react-hooks/exhaustive-deps

  /**
   * Fetch marketplace listings with current filters
   */
  const fetchListings = async () => {
    setLoading(true);
    setError(null);

    try {
      // Build filter object (only include non-empty values)
      const filterParams = {};
      if (filters.agreement_id) filterParams.agreement_id = parseInt(filters.agreement_id);
      if (filters.token_standard) filterParams.token_standard = filters.token_standard;
      if (filters.min_price_usd) filterParams.min_price_usd = parseFloat(filters.min_price_usd);
      if (filters.max_price_usd) filterParams.max_price_usd = parseFloat(filters.max_price_usd);
      if (filters.status) filterParams.status = filters.status;

      const { data, duration } = await getListings(filterParams);

      console.log(`Fetched ${data.length} listings in ${duration}ms`);
      setListings(data);
    } catch (err) {
      console.error('Error fetching listings:', err);
      const errorMessage = err.message || 'Failed to fetch listings';
      setError(errorMessage);
      enqueueSnackbar(errorMessage, { variant: 'error' });
    } finally {
      setLoading(false);
    }
  };

  /**
   * Handle filter change
   */
  const handleFilterChange = (e) => {
    const { name, value } = e.target;
    setFilters(prev => ({
      ...prev,
      [name]: value
    }));
  };

  /**
   * Handle apply filters button click
   */
  const handleApplyFilters = () => {
    fetchListings();
  };

  /**
   * Handle reset filters button click
   */
  const handleResetFilters = () => {
    setFilters({
      agreement_id: '',
      token_standard: '',
      min_price_usd: '',
      max_price_usd: '',
      status: 'active'
    });
    // Trigger refetch with reset filters
    setTimeout(() => fetchListings(), 0);
  };

  /**
   * Handle create listing button click
   */
  const handleCreateListing = () => {
    navigate('/marketplace/create');
  };

  /**
   * Handle buy button click on listing card
   */
  const handleBuyClick = (listing) => {
    navigate(`/marketplace/listings/${listing.id}/buy`);
  };

  /**
   * Handle cancel listing button click
   */
  const handleCancelClick = async (listing) => {
    if (!window.confirm(`Are you sure you want to cancel listing #${listing.id}?`)) {
      return;
    }

    try {
      const { data, duration } = await cancelListing(listing.id, currentUserAddress);

      console.log(`Cancelled listing in ${duration}ms:`, data);
      enqueueSnackbar('Listing cancelled successfully', { variant: 'success' });

      // Refresh listings
      fetchListings();
    } catch (err) {
      console.error('Error cancelling listing:', err);
      const errorMessage = err.message || 'Failed to cancel listing';
      enqueueSnackbar(errorMessage, { variant: 'error' });
    }
  };

  return (
    <Container maxWidth="lg" sx={{ mt: 4, mb: 4 }}>
      <Paper sx={{ p: 3 }}>
        {/* Header */}
        <Box display="flex" justifyContent="space-between" alignItems="center" mb={2}>
          <Box>
            <Typography variant="h4" gutterBottom>
              Secondary Market - Yield Share Listings
            </Typography>
            <Typography variant="body2" color="text.secondary">
              Browse and purchase fractional yield shares from other investors
            </Typography>
          </Box>
          <Button
            variant="contained"
            color="primary"
            startIcon={<AddIcon />}
            onClick={handleCreateListing}
          >
            Create Listing
          </Button>
        </Box>

        <Divider sx={{ my: 2 }} />

        {/* Filters Section */}
        <Box mb={3}>
          <Typography variant="h6" gutterBottom>
            <FilterListIcon sx={{ verticalAlign: 'middle', mr: 1 }} />
            Filters
          </Typography>
          <Grid container spacing={2}>
            {/* Agreement ID Filter */}
            <Grid item xs={12} sm={6} md={3}>
              <TextField
                fullWidth
                label="Agreement ID"
                name="agreement_id"
                type="number"
                value={filters.agreement_id}
                onChange={handleFilterChange}
                size="small"
                InputProps={{
                  inputProps: { min: 1 }
                }}
              />
            </Grid>

            {/* Token Standard Filter */}
            <Grid item xs={12} sm={6} md={3}>
              <FormControl fullWidth size="small">
                <InputLabel>Token Standard</InputLabel>
                <Select
                  name="token_standard"
                  value={filters.token_standard}
                  onChange={handleFilterChange}
                  label="Token Standard"
                >
                  <MenuItem value="">All</MenuItem>
                  <MenuItem value="ERC721">ERC-721 + ERC-20</MenuItem>
                  <MenuItem value="ERC1155">ERC-1155</MenuItem>
                </Select>
              </FormControl>
            </Grid>

            {/* Min Price Filter */}
            <Grid item xs={12} sm={6} md={2}>
              <TextField
                fullWidth
                label="Min Price (USD)"
                name="min_price_usd"
                type="number"
                value={filters.min_price_usd}
                onChange={handleFilterChange}
                size="small"
                InputProps={{
                  startAdornment: (
                    <InputAdornment position="start">
                      <AttachMoneyIcon fontSize="small" />
                    </InputAdornment>
                  ),
                  inputProps: { min: 0, step: 100 }
                }}
              />
            </Grid>

            {/* Max Price Filter */}
            <Grid item xs={12} sm={6} md={2}>
              <TextField
                fullWidth
                label="Max Price (USD)"
                name="max_price_usd"
                type="number"
                value={filters.max_price_usd}
                onChange={handleFilterChange}
                size="small"
                InputProps={{
                  startAdornment: (
                    <InputAdornment position="start">
                      <AttachMoneyIcon fontSize="small" />
                    </InputAdornment>
                  ),
                  inputProps: { min: 0, step: 100 }
                }}
              />
            </Grid>

            {/* Status Filter */}
            <Grid item xs={12} sm={6} md={2}>
              <FormControl fullWidth size="small">
                <InputLabel>Status</InputLabel>
                <Select
                  name="status"
                  value={filters.status}
                  onChange={handleFilterChange}
                  label="Status"
                >
                  <MenuItem value="">All</MenuItem>
                  <MenuItem value="active">Active</MenuItem>
                  <MenuItem value="sold">Sold</MenuItem>
                  <MenuItem value="cancelled">Cancelled</MenuItem>
                  <MenuItem value="expired">Expired</MenuItem>
                </Select>
              </FormControl>
            </Grid>

            {/* Filter Action Buttons */}
            <Grid item xs={12}>
              <Box display="flex" gap={1}>
                <Button
                  variant="contained"
                  size="small"
                  onClick={handleApplyFilters}
                  disabled={loading}
                >
                  Apply Filters
                </Button>
                <Button
                  variant="outlined"
                  size="small"
                  onClick={handleResetFilters}
                  disabled={loading}
                >
                  Reset
                </Button>
                <Button
                  variant="outlined"
                  size="small"
                  startIcon={<RefreshIcon />}
                  onClick={fetchListings}
                  disabled={loading}
                >
                  Refresh
                </Button>
              </Box>
            </Grid>
          </Grid>
        </Box>

        <Divider sx={{ my: 2 }} />

        {/* Loading State */}
        {loading && (
          <Box display="flex" justifyContent="center" alignItems="center" py={4}>
            <CircularProgress />
            <Typography variant="body1" ml={2}>
              Loading marketplace listings...
            </Typography>
          </Box>
        )}

        {/* Error State */}
        {error && !loading && (
          <Alert severity="error" sx={{ mb: 2 }}>
            {error}
          </Alert>
        )}

        {/* No Listings State */}
        {!loading && !error && listings.length === 0 && (
          <Alert severity="info">
            No active listings found. Try adjusting your filters or create a new listing to sell your yield shares.
          </Alert>
        )}

        {/* Listings Grid */}
        {!loading && !error && listings.length > 0 && (
          <Box>
            <Typography variant="body2" color="text.secondary" mb={2}>
              Found {listings.length} listing{listings.length !== 1 ? 's' : ''}
            </Typography>
            <Grid container spacing={3}>
              {listings.map((listing) => (
                <Grid item xs={12} sm={6} md={4} key={listing.id}>
                  <MarketplaceListingCard
                    listing={listing}
                    currentUserAddress={currentUserAddress}
                    onBuyClick={handleBuyClick}
                    onCancelClick={handleCancelClick}
                  />
                </Grid>
              ))}
            </Grid>
          </Box>
        )}
      </Paper>
    </Container>
  );
};

export default MarketplaceListings;

