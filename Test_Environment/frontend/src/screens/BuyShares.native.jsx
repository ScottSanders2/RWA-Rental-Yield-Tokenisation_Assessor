import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  ScrollView,
  StyleSheet,
  ActivityIndicator,
  Alert,
} from 'react-native';
import {
  Card,
  TextInput,
  Button,
  HelperText,
  Chip,
} from 'react-native-paper';
import Slider from '@react-native-community/slider';
import { useNavigation, useRoute } from '@react-navigation/native';
import { getListing, buyShares } from '../services/apiClient.native';
import { useEthPrice } from '../context/PriceContext.native';
import UserProfilePicker from '../components/UserProfilePicker.native';

const BuySharesScreen = () => {
  const navigation = useNavigation();
  const route = useRoute();
  const { listingId } = route.params || {};
  const { ethUsdPrice } = useEthPrice();

  const [currentProfile, setCurrentProfile] = useState(null);
  const [listing, setListing] = useState(null);
  const [loading, setLoading] = useState(true);
  const [submitting, setSubmitting] = useState(false);

  const [formData, setFormData] = useState({
    purchase_fraction: 0.25, // Default to 25%
    max_price_per_share_usd: '',
  });

  const [validationErrors, setValidationErrors] = useState({});

  useEffect(() => {
    if (listingId) {
      loadListing();
    }
  }, [listingId]);

  const loadListing = async () => {
    setLoading(true);
    try {
      const data = await getListing(listingId);
      setListing(data);
      
      // Set default max price to listing price + 5% slippage
      const defaultMaxPrice = (data.price_per_share_usd * 1.05).toFixed(2);
      setFormData((prev) => ({ ...prev, max_price_per_share_usd: defaultMaxPrice }));
    } catch (error) {
      console.error('Failed to load listing:', error);
      Alert.alert('Error', 'Failed to load listing details');
    } finally {
      setLoading(false);
    }
  };

  const handleProfileChange = (profile) => {
    setCurrentProfile(profile);
  };

  const calculateValues = () => {
    if (!listing) {
      return { sharesToBuyWei: 0, sharesToBuyHuman: 0, totalCostUsd: 0, totalCostEth: 0 };
    }

    const availableShares = parseFloat(listing.shares_for_sale);
    const sharesToBuyWei = Math.floor(availableShares * formData.purchase_fraction);
    const sharesToBuyHuman = sharesToBuyWei / 1e18;
    const totalCostUsd = sharesToBuyHuman * listing.price_per_share_usd;
    const totalCostEth = ethUsdPrice ? totalCostUsd / ethUsdPrice : 0;

    return { sharesToBuyWei, sharesToBuyHuman, totalCostUsd, totalCostEth };
  };

  const { sharesToBuyWei, sharesToBuyHuman, totalCostUsd, totalCostEth } = calculateValues();

  const validateForm = () => {
    const errors = {};

    if (!currentProfile) {
      errors.profile = 'Please select a buyer profile';
    }

    if (sharesToBuyWei <= 0) {
      errors.purchase_fraction = 'Must purchase at least some shares';
    }

    if (!formData.max_price_per_share_usd || parseFloat(formData.max_price_per_share_usd) <= 0) {
      errors.max_price_per_share_usd = 'Max price must be greater than 0';
    }

    if (
      formData.max_price_per_share_usd &&
      parseFloat(formData.max_price_per_share_usd) < listing?.price_per_share_usd
    ) {
      errors.max_price_per_share_usd = 'Max price must be at least the listing price';
    }

    if (currentProfile && listing && currentProfile.wallet_address.toLowerCase() === listing.seller_address?.toLowerCase()) {
      errors.profile = 'Cannot buy from your own listing';
    }

    setValidationErrors(errors);
    return Object.keys(errors).length === 0;
  };

  const handleSubmit = async () => {
    if (!validateForm()) {
      Alert.alert('Validation Error', 'Please fix the errors before submitting');
      return;
    }

    setSubmitting(true);

    try {
      const purchaseData = {
        listing_id: listingId,
        buyer_address: currentProfile.wallet_address.toLowerCase(),
        shares_to_buy_fraction: formData.purchase_fraction, // Send fraction to avoid JavaScript precision loss with large integers
        max_price_per_share_usd: parseFloat(formData.max_price_per_share_usd),
      };

      const result = await buyShares(purchaseData);

      Alert.alert(
        'Success!',
        `Purchase successful!\n\nShares purchased: ${sharesToBuyHuman.toFixed(2)}\nTotal cost: $${totalCostUsd.toFixed(2)} USD`,
        [
          {
            text: 'View Portfolio',
            onPress: () => navigation.navigate('Portfolio'),
          },
          {
            text: 'OK',
            onPress: () => navigation.navigate('Marketplace'),
          },
        ]
      );
    } catch (error) {
      console.error('Failed to purchase shares:', error);
      Alert.alert('Error', error.message || 'Failed to complete purchase');
    } finally {
      setSubmitting(false);
    }
  };

  if (loading) {
    return (
      <View style={styles.centerContainer}>
        <ActivityIndicator size="large" color="#6200ee" />
        <Text style={styles.loadingText}>Loading listing...</Text>
      </View>
    );
  }

  if (!listing) {
    return (
      <View style={styles.centerContainer}>
        <Text style={styles.errorText}>Listing not found</Text>
        <Button mode="contained" onPress={() => navigation.goBack()} style={styles.backButton}>
          Go Back
        </Button>
      </View>
    );
  }

  const availableSharesHuman = parseFloat(listing.shares_for_sale) / 1e18;
  const slippagePercent = formData.max_price_per_share_usd
    ? (((parseFloat(formData.max_price_per_share_usd) - listing.price_per_share_usd) /
        listing.price_per_share_usd) *
        100).toFixed(1)
    : 0;

  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.content}>
      {/* User Profile Switcher */}
      <Card style={styles.card} mode="elevated">
        <Card.Title title="Select Buyer Profile" />
        <Card.Content>
        <UserProfilePicker
          onProfileChange={handleProfileChange}
          currentProfile={currentProfile}
        />
          {validationErrors.profile && (
            <HelperText type="error" visible={true}>
              {validationErrors.profile}
            </HelperText>
          )}
        </Card.Content>
      </Card>

      {/* Listing Details */}
      <Card style={styles.card} mode="elevated">
        <Card.Title title="Listing Details" />
        <Card.Content>
          <View style={styles.detailRow}>
            <Text style={styles.detailLabel}>Agreement ID:</Text>
            <Chip mode="outlined">#{listing.agreement_id}</Chip>
          </View>
          <View style={styles.detailRow}>
            <Text style={styles.detailLabel}>Seller:</Text>
            <Text style={styles.detailValue}>
              {listing.seller_display_name || 'Unknown'}
              {listing.seller_role && ` (${listing.seller_role})`}
            </Text>
          </View>
          <View style={styles.detailRow}>
            <Text style={styles.detailLabel}>Available Shares:</Text>
            <Text style={styles.detailValue}>{availableSharesHuman.toFixed(2)} shares</Text>
          </View>
          <View style={styles.detailRow}>
            <Text style={styles.detailLabel}>Price per Share:</Text>
            <View>
              <Text style={styles.detailValue}>${listing.price_per_share_usd.toFixed(2)} USD</Text>
              <Text style={styles.detailSubValue}>
                ≈ {ethUsdPrice ? (listing.price_per_share_usd / ethUsdPrice).toFixed(6) : 'N/A'} ETH
              </Text>
            </View>
          </View>
          <View style={styles.detailRow}>
            <Text style={styles.detailLabel}>Token Standard:</Text>
            <Text style={styles.detailValue}>{listing.token_standard || 'N/A'}</Text>
          </View>
        </Card.Content>
      </Card>

      {/* Purchase Details */}
      <Card style={styles.card} mode="elevated">
        <Card.Title title="Purchase Details" />
        <Card.Content>
          {/* Purchase Fraction Slider */}
          <Text style={styles.label}>
            Percentage to Purchase: {(formData.purchase_fraction * 100).toFixed(0)}%
          </Text>
          <Slider
            style={styles.slider}
            value={formData.purchase_fraction}
            onValueChange={(value) =>
              setFormData((prev) => ({ ...prev, purchase_fraction: value }))
            }
            minimumValue={0.01}
            maximumValue={1.0}
            step={0.01}
            minimumTrackTintColor="#6200ee"
            maximumTrackTintColor="#d3d3d3"
            thumbTintColor="#6200ee"
          />
          <Text style={styles.helperText}>
            Shares to buy: {sharesToBuyHuman.toFixed(2)} of {availableSharesHuman.toFixed(2)} available
          </Text>
          {validationErrors.purchase_fraction && (
            <HelperText type="error" visible={true}>
              {validationErrors.purchase_fraction}
            </HelperText>
          )}

          {/* Max Price (Slippage Protection) */}
          <TextInput
            label="Max Price per Share (USD)"
            value={formData.max_price_per_share_usd}
            onChangeText={(value) =>
              setFormData((prev) => ({ ...prev, max_price_per_share_usd: value }))
            }
            keyboardType="decimal-pad"
            mode="outlined"
            style={styles.input}
            left={<TextInput.Icon icon="shield-check" />}
            error={!!validationErrors.max_price_per_share_usd}
          />
          {validationErrors.max_price_per_share_usd && (
            <HelperText type="error" visible={true}>
              {validationErrors.max_price_per_share_usd}
            </HelperText>
          )}
          <HelperText type="info">
            Slippage protection: {slippagePercent}% above listing price
          </HelperText>
        </Card.Content>
      </Card>

      {/* Cost Summary */}
      <Card style={styles.card} mode="elevated">
        <Card.Title title="Total Purchase Cost" />
        <Card.Content>
          <View style={styles.summaryRow}>
            <Text style={styles.summaryLabel}>Shares to Buy:</Text>
            <Text style={styles.summaryValue}>{sharesToBuyHuman.toFixed(2)} shares</Text>
          </View>
          <View style={styles.summaryRow}>
            <Text style={styles.summaryLabel}>Price per Share:</Text>
            <Text style={styles.summaryValue}>${listing.price_per_share_usd.toFixed(2)} USD</Text>
          </View>
          <View style={styles.summaryDivider} />
          <View style={styles.summaryRow}>
            <Text style={[styles.summaryLabel, styles.summaryTotal]}>Total Cost:</Text>
            <View>
              <Text style={[styles.summaryValue, styles.summaryTotalValue]}>
                ${totalCostUsd.toFixed(2)} USD
              </Text>
              <Text style={styles.summarySubValue}>≈ {totalCostEth.toFixed(6)} ETH</Text>
            </View>
          </View>
        </Card.Content>
      </Card>

      {/* Submit Button */}
      <Button
        mode="contained"
        onPress={handleSubmit}
        loading={submitting}
        disabled={submitting || listing.listing_status?.toUpperCase() !== 'ACTIVE'}
        style={styles.submitButton}
        icon="cart-check"
      >
        Purchase Shares
      </Button>
    </ScrollView>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#f5f5f5',
  },
  content: {
    padding: 16,
    paddingBottom: 32,
  },
  centerContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    padding: 32,
  },
  loadingText: {
    marginTop: 16,
    fontSize: 16,
    color: '#757575',
  },
  errorText: {
    fontSize: 18,
    color: '#F44336',
    marginBottom: 16,
    textAlign: 'center',
  },
  backButton: {
    marginTop: 8,
  },
  card: {
    marginBottom: 16,
  },
  detailRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 12,
  },
  detailLabel: {
    fontSize: 14,
    color: '#757575',
  },
  detailValue: {
    fontSize: 14,
    fontWeight: '600',
    color: '#212121',
    textAlign: 'right',
  },
  detailSubValue: {
    fontSize: 12,
    color: '#757575',
    textAlign: 'right',
  },
  label: {
    fontSize: 14,
    fontWeight: '600',
    marginBottom: 8,
    color: '#212121',
  },
  slider: {
    width: '100%',
    height: 40,
  },
  helperText: {
    fontSize: 12,
    color: '#757575',
    marginTop: 4,
  },
  input: {
    marginTop: 12,
  },
  summaryRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'flex-start',
    marginBottom: 12,
  },
  summaryLabel: {
    fontSize: 14,
    color: '#757575',
  },
  summaryValue: {
    fontSize: 14,
    fontWeight: '600',
    color: '#212121',
    textAlign: 'right',
  },
  summarySubValue: {
    fontSize: 12,
    color: '#757575',
    textAlign: 'right',
  },
  summaryDivider: {
    height: 1,
    backgroundColor: '#e0e0e0',
    marginVertical: 12,
  },
  summaryTotal: {
    fontSize: 16,
    fontWeight: 'bold',
  },
  summaryTotalValue: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#6200ee',
  },
  submitButton: {
    marginTop: 8,
  },
});

export default BuySharesScreen;

