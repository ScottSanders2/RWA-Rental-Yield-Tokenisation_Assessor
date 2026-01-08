/**
 * MarketplaceListingCard Component
 * 
 * Displays individual marketplace listing for yield share trading.
 * 
 * Features:
 * - USD-first pricing with live ETH conversion
 * - Fractional availability percentage display
 * - Token standard labeling (ERC-721 + ERC-20 or ERC-1155)
 * - Status indicators (Active, Sold, Cancelled, Expired)
 * - Action buttons (Buy, View Agreement, Cancel)
 * 
 * Props:
 * - listing: Listing object from API
 * - currentUserAddress: Current user's wallet address (for cancel button visibility)
 * - onBuyClick: Handler for buy button click
 * - onCancelClick: Handler for cancel button click
 * 
 * Research Contribution:
 * - Demonstrates USD-first pricing for user comprehension
 * - Shows fractional availability for pooling accessibility
 * - Explicit token standard labeling for comparative analysis
 */

import React from 'react';
import {
  Card,
  CardContent,
  CardActions,
  Typography,
  Button,
  Chip,
  Box,
  Divider,
  Tooltip
} from '@mui/material';
import {
  ShoppingCart as ShoppingCartIcon,
  Cancel as CancelIcon,
  Visibility as VisibilityIcon
} from '@mui/icons-material';
import { useNavigate } from 'react-router-dom';
import { formatAddress, formatWeiToUsd, formatDualCurrency } from '../utils/formatters';

/**
 * Get status chip color based on listing status
 */
const getStatusColor = (status) => {
  switch (status?.toLowerCase()) {
    case 'active':
      return 'success';
    case 'sold':
      return 'default';
    case 'cancelled':
      return 'error';
    case 'expired':
      return 'warning';
    default:
      return 'default';
  }
};

/**
 * Get token standard display label
 */
const getTokenStandardLabel = (tokenStandard) => {
  if (tokenStandard === 'ERC721') {
    return 'ERC-721 + ERC-20';
  } else if (tokenStandard === 'ERC1155') {
    return 'ERC-1155';
  }
  return tokenStandard;
};

/**
 * MarketplaceListingCard component
 */
const MarketplaceListingCard = ({
  listing,
  currentUserAddress,
  onBuyClick,
  onCancelClick,
  ethUsdPrice = 2000
}) => {
  const navigate = useNavigate();

  // Calculate derived values
  const totalValueUsd = listing.total_listing_value_usd || 
    (listing.shares_for_sale * listing.price_per_share_usd / 1e18);
  
  // Calculate ETH value from USD (simpler and more accurate)
  const totalValueEth = totalValueUsd / ethUsdPrice;
  
  const fractionalPercentage = listing.fractional_availability 
    ? (listing.fractional_availability * 100).toFixed(1)
    : '100.0';
  
  // Calculate time remaining if expires_at is set
  const timeRemaining = listing.expires_at 
    ? (() => {
        const expiryDate = new Date(listing.expires_at);
        const now = new Date();
        const diffMs = expiryDate - now;
        const diffHours = Math.floor(diffMs / (1000 * 60 * 60));
        const diffDays = Math.floor(diffHours / 24);
        
        if (diffMs < 0) return 'Expired';
        if (diffDays > 0) return `${diffDays} days`;
        return `${diffHours} hours`;
      })()
    : null;

  // Check if current user is seller
  const isCurrentUserSeller = currentUserAddress && 
    currentUserAddress.toLowerCase() === listing.seller_address.toLowerCase();

  // Handle navigation to agreement details
  const handleViewAgreement = () => {
    navigate(`/yield-agreements/${listing.agreement_id}`);
  };

  // Handle buy button click
  const handleBuyClick = () => {
    if (onBuyClick) {
      onBuyClick(listing);
    } else {
      navigate(`/marketplace/listings/${listing.id}/buy`);
    }
  };

  // Handle cancel button click
  const handleCancelClick = () => {
    if (onCancelClick) {
      onCancelClick(listing);
    }
  };

  // Determine if this is a primary offering or secondary market
  const isPrimaryOffering = listing.seller_role === 'property_owner';
  const listingType = isPrimaryOffering ? 'Primary Offering' : 'Secondary Market';
  const listingTypeColor = isPrimaryOffering ? 'primary' : 'info';

  return (
    <Card elevation={2} sx={{ height: '100%', display: 'flex', flexDirection: 'column' }}>
      <CardContent sx={{ flexGrow: 1 }}>
        {/* Header with Agreement ID and Status */}
        <Box display="flex" justifyContent="space-between" alignItems="center" mb={1}>
          <Box display="flex" flexDirection="column" gap={0.5}>
            <Typography variant="h6" component="div">
              Agreement #{listing.agreement_id}
            </Typography>
            <Chip 
              label={listingType}
              color={listingTypeColor}
              size="small"
              variant="outlined"
              sx={{ width: 'fit-content' }}
            />
          </Box>
          <Chip 
            label={listing.listing_status?.toUpperCase() || 'ACTIVE'} 
            color={getStatusColor(listing.listing_status)}
            size="small"
          />
        </Box>

        {/* Seller Information */}
        <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, mb: 1 }}>
          <Typography variant="body2" color="text.secondary">
            Seller:
          </Typography>
          {listing.seller_display_name ? (
            <>
              <Typography variant="body2" fontWeight="medium">
                {listing.seller_display_name}
              </Typography>
              {listing.seller_role && (
                <Chip 
                  label={listing.seller_role === 'property_owner' ? 'Owner' : 
                         listing.seller_role === 'investor' ? 'Investor' : 
                         listing.seller_role === 'admin' ? 'Admin' : listing.seller_role}
                  size="small"
                  color={listing.seller_role === 'property_owner' ? 'primary' : 
                         listing.seller_role === 'investor' ? 'success' : 'error'}
                />
              )}
            </>
          ) : (
            <Typography variant="body2">
              {formatAddress(listing.seller_address)}
            </Typography>
          )}
        </Box>

        <Divider sx={{ my: 1.5 }} />

        {/* Shares for Sale */}
        <Box mb={1}>
          <Typography variant="body2" color="text.secondary">
            Shares for Sale:
          </Typography>
          <Typography variant="body1" fontWeight="medium">
            {formatWeiToUsd(listing.shares_for_sale, 1)} ({fractionalPercentage}% of total)
          </Typography>
        </Box>

        {/* Price per Share */}
        <Box mb={1}>
          <Typography variant="body2" color="text.secondary">
            Price per Share:
          </Typography>
          <Typography variant="body1" fontWeight="medium" color="primary">
            ${listing.price_per_share_usd?.toLocaleString(undefined, {
              minimumFractionDigits: 2,
              maximumFractionDigits: 2
            })} USD
          </Typography>
          <Typography variant="caption" color="text.secondary">
            ≈ {(listing.price_per_share_wei / 1e18).toFixed(6)} ETH
          </Typography>
        </Box>

        {/* Total Value */}
        <Box mb={1}>
          <Typography variant="body2" color="text.secondary">
            Total Value:
          </Typography>
          <Typography variant="body1" fontWeight="medium">
            ${totalValueUsd.toLocaleString(undefined, {
              minimumFractionDigits: 2,
              maximumFractionDigits: 2
            })} USD
          </Typography>
          <Typography variant="caption" color="text.secondary">
            ≈ {totalValueEth.toFixed(6)} ETH
          </Typography>
        </Box>

        {/* Token Standard */}
        <Box mb={1}>
          <Typography variant="body2" color="text.secondary">
            Token Standard:
          </Typography>
          <Typography variant="body2" fontWeight="medium">
            {getTokenStandardLabel(listing.token_standard)}
          </Typography>
        </Box>

        {/* Expiry Information */}
        {timeRemaining && (
          <Box mb={1}>
            <Typography variant="body2" color="text.secondary">
              Expires:
            </Typography>
            <Typography 
              variant="body2" 
              color={timeRemaining === 'Expired' ? 'error' : 'text.primary'}
            >
              {timeRemaining}
            </Typography>
          </Box>
        )}

        {/* Listing Age */}
        {listing.listing_age_hours !== undefined && (
          <Typography variant="caption" color="text.secondary" display="block" mt={1}>
            Listed {listing.listing_age_hours.toFixed(1)} hours ago
          </Typography>
        )}
      </CardContent>

      <Divider />

      {/* Action Buttons */}
      <CardActions sx={{ justifyContent: 'space-between', p: 2 }}>
        <Box display="flex" gap={1}>
          {listing.listing_status === 'active' && !isCurrentUserSeller && (
            <Button
              variant="contained"
              color="primary"
              size="small"
              startIcon={<ShoppingCartIcon />}
              onClick={handleBuyClick}
            >
              Buy Shares
            </Button>
          )}
          
          {isCurrentUserSeller && listing.listing_status === 'active' && (
            <Button
              variant="outlined"
              color="error"
              size="small"
              startIcon={<CancelIcon />}
              onClick={handleCancelClick}
            >
              Cancel Listing
            </Button>
          )}
        </Box>

        <Tooltip title="View Agreement Details">
          <Button
            variant="outlined"
            size="small"
            startIcon={<VisibilityIcon />}
            onClick={handleViewAgreement}
          >
            View Agreement
          </Button>
        </Tooltip>
      </CardActions>
    </Card>
  );
};

export default MarketplaceListingCard;

