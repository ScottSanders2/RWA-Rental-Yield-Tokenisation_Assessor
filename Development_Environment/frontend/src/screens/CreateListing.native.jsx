import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  ScrollView,
  StyleSheet,
  ActivityIndicator,
  Alert,
  Modal,
  TouchableOpacity,
} from 'react-native';
import {
  Card,
  TextInput,
  Button,
  Chip,
  HelperText,
} from 'react-native-paper';
import Slider from '@react-native-community/slider';
import { Picker } from '@react-native-picker/picker';
import { useNavigation, useRoute } from '@react-navigation/native';
import {
  createListing,
  getUserAgreements,
  getUserAvailableBalance,
} from '../services/apiClient.native';
import { useEthPrice } from '../context/PriceContext.native';
import UserProfilePicker from '../components/UserProfilePicker.native';

const CreateListingScreen = () => {
  const navigation = useNavigation();
  const route = useRoute();
  const { ethUsdPrice } = useEthPrice();
  const { agreementId: preselectedAgreement } = route.params || {};

  const [currentProfile, setCurrentProfile] = useState(null);
  const [userAgreements, setUserAgreements] = useState([]);
  const [availableBalance, setAvailableBalance] = useState(null);
  const [loading, setLoading] = useState(false);
  const [fetchingAgreements, setFetchingAgreements] = useState(false);
  const [fetchingBalance, setFetchingBalance] = useState(false);
  const [showAgreementPicker, setShowAgreementPicker] = useState(false);
  const [tempAgreementId, setTempAgreementId] = useState('');

  const [formData, setFormData] = useState({
    agreement_id: preselectedAgreement || '',
    shares_for_sale_fraction: 0.5, // Default to 50%
    price_per_share_usd: '',
    expires_in_days: 30,
  });

  const [validationErrors, setValidationErrors] = useState({});

  // Fetch user agreements when profile changes
  useEffect(() => {
    if (currentProfile) {
      fetchUserAgreements(currentProfile.wallet_address);
    }
  }, [currentProfile]);

  // Fetch available balance when agreement changes
  useEffect(() => {
    if (currentProfile && formData.agreement_id) {
      fetchAvailableBalance(currentProfile.wallet_address, formData.agreement_id);
    }
  }, [currentProfile, formData.agreement_id]);

  const fetchUserAgreements = async (walletAddress) => {
    setFetchingAgreements(true);
    try {
      const data = await getUserAgreements(walletAddress);
      setUserAgreements(data.agreements || []);
      
      // If pre-selected agreement, set it
      if (preselectedAgreement && data.agreements.some((a) => a.id === preselectedAgreement)) {
        setFormData((prev) => ({ ...prev, agreement_id: preselectedAgreement }));
      }
    } catch (error) {
      console.error('Failed to fetch agreements:', error);
      Alert.alert('Error', 'Failed to fetch your agreements');
    } finally {
      setFetchingAgreements(false);
    }
  };

  const fetchAvailableBalance = async (walletAddress, agreementId) => {
    setFetchingBalance(true);
    try {
      const data = await getUserAvailableBalance(walletAddress, agreementId);
      setAvailableBalance(data);
    } catch (error) {
      console.error('Failed to fetch available balance:', error);
      setAvailableBalance(null);
    } finally {
      setFetchingBalance(false);
    }
  };

  const handleProfileChange = (profile) => {
    setCurrentProfile(profile);
  };

  const calculateValues = () => {
    if (!availableBalance || !availableBalance.available_balance_wei) {
      return { sharesForSaleWei: 0, sharesForSaleHuman: 0, totalValueUsd: 0 };
    }

    const sharesForSaleWei = Math.floor(
      parseFloat(availableBalance.available_balance_wei) * formData.shares_for_sale_fraction
    );
    const sharesForSaleHuman = sharesForSaleWei / 1e18;
    const pricePerShare = parseFloat(formData.price_per_share_usd) || 0;
    const totalValueUsd = sharesForSaleHuman * pricePerShare;

    return { sharesForSaleWei, sharesForSaleHuman, totalValueUsd };
  };

  const { sharesForSaleWei, sharesForSaleHuman, totalValueUsd } = calculateValues();

  const validateForm = () => {
    const errors = {};

    if (!currentProfile) {
      errors.profile = 'Please select a user profile';
    }

    if (!formData.agreement_id) {
      errors.agreement_id = 'Please select a yield agreement';
    }

    if (!availableBalance || availableBalance.available_balance_wei <= 0) {
      errors.shares = 'No shares available to list';
    }

    if (sharesForSaleWei <= 0) {
      errors.shares_for_sale_fraction = 'Must list at least some shares';
    }

    if (sharesForSaleWei > availableBalance?.available_balance_wei) {
      errors.shares_for_sale_fraction = `Cannot list more than available balance (${(availableBalance.available_balance_shares || 0).toFixed(2)} shares)`;
    }

    if (!formData.price_per_share_usd || parseFloat(formData.price_per_share_usd) <= 0) {
      errors.price_per_share_usd = 'Price per share must be greater than 0';
    }

    setValidationErrors(errors);
    return Object.keys(errors).length === 0;
  };

  const handleSubmit = async () => {
    console.log('🔵 ========================================');
    console.log('🔵 CREATE LISTING - FORM SUBMISSION STARTED');
    console.log('🔵 ========================================');
    
    if (!validateForm()) {
      console.log('❌ Validation failed - form has errors');
      Alert.alert('Validation Error', 'Please fix the errors before submitting');
      return;
    }
    console.log('✅ Form validation passed');

    setLoading(true);

    try {
      const listingData = {
        agreement_id: parseInt(formData.agreement_id),
        seller_address: currentProfile.wallet_address.toLowerCase(),
        shares_for_sale_fraction: formData.shares_for_sale_fraction, // Already a fraction (0.01-1.0)
        price_per_share_usd: parseFloat(formData.price_per_share_usd),
        expires_in_days: parseInt(formData.expires_in_days),
      };

      console.log('📦 Prepared listing data:', JSON.stringify(listingData, null, 2));
      console.log('📡 Calling createListing API...');
      console.log('🕐 Timestamp:', new Date().toISOString());
      
      const result = await createListing(listingData);
      
      console.log('✅ ========================================');
      console.log('✅ API CALL SUCCESSFUL!');
      console.log('✅ ========================================');
      console.log('📊 API Response:', JSON.stringify(result, null, 2));
      console.log('🆔 Listing ID:', result.listing_id);
      console.log('✅ Listing created in Development backend (port 8000)');
      
      Alert.alert(
        'Success!',
        `Listing created successfully!\n\nListing ID: ${result.listing_id}\nShares listed: ${sharesForSaleHuman.toFixed(2)}`,
        [
          {
            text: 'View Marketplace',
            onPress: () => navigation.navigate('Marketplace'),
          },
          {
            text: 'OK',
            onPress: () => navigation.goBack(),
          },
        ]
      );
    } catch (error) {
      console.error('❌ ========================================');
      console.error('❌ API CALL FAILED!');
      console.error('❌ ========================================');
      console.error('❌ Error type:', typeof error);
      console.error('❌ Error object:', error);
      console.error('❌ Error message:', error.message);
      console.error('❌ Error stack:', error.stack);
      
      if (error.response) {
        console.error('📡 HTTP Response received:');
        console.error('   Status:', error.response.status);
        console.error('   Status Text:', error.response.statusText);
        console.error('   Data:', JSON.stringify(error.response.data, null, 2));
        console.error('   Headers:', JSON.stringify(error.response.headers, null, 2));
      } else if (error.request) {
        console.error('📡 No response received from server');
        console.error('   Request:', error.request);
      } else {
        console.error('📡 Error occurred before request was sent');
      }
      
      console.error('🔍 Network Info:');
      console.error('   Expected backend: http://localhost:8000 (Development)');
      console.error('   Timestamp:', new Date().toISOString());
      
      const errorMessage = error.response?.data?.detail 
        || error.message 
        || 'Failed to create listing - check console for details';
      
      Alert.alert(
        'Error Creating Listing', 
        errorMessage + '\n\nCheck console logs for detailed error information.',
        [{ text: 'OK' }]
      );
    } finally {
      setLoading(false);
      console.log('🏁 Form submission completed');
    }
  };

  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.content}>
      {/* User Profile Switcher */}
      <Card style={styles.card} mode="elevated">
        <Card.Title title="Select Seller Profile" />
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

      {/* Agreement Selection */}
      <Card style={styles.card} mode="elevated">
        <Card.Title title="Select Yield Agreement" />
        <Card.Content>
          {fetchingAgreements ? (
            <ActivityIndicator size="small" />
          ) : userAgreements.length > 0 ? (
            <>
              <TouchableOpacity
                style={styles.agreementPickerButton}
                onPress={() => {
                  setTempAgreementId(formData.agreement_id);
                  setShowAgreementPicker(true);
                }}
              >
                <Text style={styles.agreementPickerText}>
                  {formData.agreement_id
                    ? userAgreements.find((a) => a.id === formData.agreement_id)?.agreement_name || 'Select an agreement...'
                    : 'Select an agreement...'}
                </Text>
                <Text style={styles.pickerArrow}>▼</Text>
              </TouchableOpacity>
              {validationErrors.agreement_id && (
                <HelperText type="error" visible={true}>
                  {validationErrors.agreement_id}
                </HelperText>
              )}
            </>
          ) : (
            <Text style={styles.noAgreementsText}>
              You don't have any agreements with shares to list
            </Text>
          )}
        </Card.Content>
      </Card>

      {/* Agreement Picker Modal */}
      <Modal
        visible={showAgreementPicker}
        transparent={true}
        animationType="slide"
        onRequestClose={() => setShowAgreementPicker(false)}
      >
        <View style={styles.modalOverlay}>
          <TouchableOpacity
            style={styles.modalOverlayTouchable}
            activeOpacity={1}
            onPress={() => setShowAgreementPicker(false)}
          />
          <View style={styles.modalContent}>
            <View style={styles.modalHeader}>
              <TouchableOpacity onPress={() => setShowAgreementPicker(false)} style={styles.modalButton}>
                <Text style={styles.modalButtonCancel}>Cancel</Text>
              </TouchableOpacity>
              <Text style={styles.modalTitle}>Select Yield Agreement</Text>
              <TouchableOpacity
                onPress={() => {
                  setFormData((prev) => ({ ...prev, agreement_id: tempAgreementId }));
                  setShowAgreementPicker(false);
                }}
                style={styles.modalButton}
              >
                <Text style={styles.modalButtonDone}>Done</Text>
              </TouchableOpacity>
            </View>
            
            <Picker
              selectedValue={tempAgreementId}
              onValueChange={(value) => setTempAgreementId(value)}
              style={styles.modalPicker}
            >
              <Picker.Item label="Select an agreement..." value="" />
              {userAgreements.map((agreement) => (
                <Picker.Item
                  key={agreement.id}
                  label={agreement.agreement_name}
                  value={agreement.id}
                />
              ))}
            </Picker>
          </View>
        </View>
      </Modal>

      {/* Available Balance Info */}
      {formData.agreement_id && (
        <Card style={styles.card} mode="elevated">
          <Card.Title title="Available Shares" />
          <Card.Content>
            {fetchingBalance ? (
              <ActivityIndicator size="small" />
            ) : availableBalance ? (
              <View style={styles.balanceInfo}>
                <View style={styles.balanceRow}>
                  <Text style={styles.balanceLabel}>Available to List:</Text>
                  <Text style={styles.balanceValue}>
                    {(availableBalance.available_balance_shares || 0).toFixed(2)} shares
                  </Text>
                </View>
                <View style={styles.balanceRow}>
                  <Text style={styles.balanceLabel}>Total Balance:</Text>
                  <Text style={styles.balanceValue}>
                    {(availableBalance.total_balance_shares || 0).toFixed(2)} shares
                  </Text>
                </View>
                <View style={styles.balanceRow}>
                  <Text style={styles.balanceLabel}>Already Listed:</Text>
                  <Text style={styles.balanceValue}>
                    {(availableBalance.listed_shares || 0).toFixed(2)} shares
                  </Text>
                </View>
              </View>
            ) : (
              <Text style={styles.errorText}>Unable to fetch balance</Text>
            )}
          </Card.Content>
        </Card>
      )}

      {/* Listing Details */}
      {availableBalance && availableBalance.available_balance_wei > 0 && (
        <>
          <Card style={styles.card} mode="elevated">
            <Card.Title title="Listing Details" />
            <Card.Content>
              {/* Shares for Sale Slider */}
              <Text style={styles.label}>
                Percentage of Available Shares to Sell: {(formData.shares_for_sale_fraction * 100).toFixed(0)}%
              </Text>
              <Slider
                style={styles.slider}
                value={formData.shares_for_sale_fraction}
                onValueChange={(value) =>
                  setFormData((prev) => ({ ...prev, shares_for_sale_fraction: value }))
                }
                minimumValue={0.01}
                maximumValue={1.0}
                step={0.01}
                minimumTrackTintColor="#6200ee"
                maximumTrackTintColor="#d3d3d3"
                thumbTintColor="#6200ee"
              />
              <Text style={styles.helperText}>
                Shares for Sale: {sharesForSaleHuman.toFixed(2)} of {(availableBalance.available_balance_shares || 0).toFixed(2)} available
              </Text>
              {validationErrors.shares_for_sale_fraction && (
                <HelperText type="error" visible={true}>
                  {validationErrors.shares_for_sale_fraction}
                </HelperText>
              )}

              {/* Price per Share */}
              <TextInput
                label="Price per Share (USD)"
                value={formData.price_per_share_usd}
                onChangeText={(value) =>
                  setFormData((prev) => ({ ...prev, price_per_share_usd: value }))
                }
                keyboardType="decimal-pad"
                mode="outlined"
                style={styles.input}
                left={<TextInput.Icon icon="currency-usd" />}
                error={!!validationErrors.price_per_share_usd}
              />
              {validationErrors.price_per_share_usd && (
                <HelperText type="error" visible={true}>
                  {validationErrors.price_per_share_usd}
                </HelperText>
              )}
              {formData.price_per_share_usd && ethUsdPrice && (
                <HelperText type="info">
                  ≈ {(parseFloat(formData.price_per_share_usd) / ethUsdPrice).toFixed(6)} ETH
                </HelperText>
              )}

              {/* Expiry */}
              <TextInput
                label="Listing Duration (Days)"
                value={formData.expires_in_days.toString()}
                onChangeText={(value) =>
                  setFormData((prev) => ({ ...prev, expires_in_days: value }))
                }
                keyboardType="number-pad"
                mode="outlined"
                style={styles.input}
                left={<TextInput.Icon icon="calendar-clock" />}
              />
            </Card.Content>
          </Card>

          {/* Summary */}
          <Card style={styles.card} mode="elevated">
            <Card.Title title="Listing Summary" />
            <Card.Content>
              <View style={styles.summaryRow}>
                <Text style={styles.summaryLabel}>Shares for Sale:</Text>
                <Text style={styles.summaryValue}>{sharesForSaleHuman.toFixed(2)} shares</Text>
              </View>
              <View style={styles.summaryRow}>
                <Text style={styles.summaryLabel}>Price per Share:</Text>
                <Text style={styles.summaryValue}>${parseFloat(formData.price_per_share_usd || 0).toFixed(2)} USD</Text>
              </View>
              <View style={styles.summaryRow}>
                <Text style={styles.summaryLabel}>Total Value:</Text>
                <Text style={[styles.summaryValue, styles.summaryHighlight]}>
                  ${totalValueUsd.toFixed(2)} USD
                </Text>
              </View>
              {ethUsdPrice && (
                <View style={styles.summaryRow}>
                  <Text style={styles.summaryLabel}>≈</Text>
                  <Text style={styles.summaryValue}>{(totalValueUsd / ethUsdPrice).toFixed(6)} ETH</Text>
                </View>
              )}
            </Card.Content>
          </Card>

          {/* Submit Button */}
          <Button
            mode="contained"
            onPress={handleSubmit}
            loading={loading}
            disabled={loading || fetchingBalance}
            style={styles.submitButton}
            icon="check"
          >
            Create Listing
          </Button>
        </>
      )}
    </ScrollView>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#f5f5f5',
  },
  centerContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    padding: 32,
    backgroundColor: '#f5f5f5',
  },
  loadingText: {
    marginTop: 16,
    fontSize: 16,
    color: '#757575',
  },
  content: {
    padding: 16,
    paddingBottom: 32,
  },
  card: {
    marginBottom: 16,
  },
  pickerContainer: {
    borderWidth: 1,
    borderColor: '#ccc',
    borderRadius: 4,
    overflow: 'hidden',
  },
  picker: {
    height: 50,
  },
  noAgreementsText: {
    fontSize: 14,
    color: '#757575',
    textAlign: 'center',
    padding: 16,
  },
  balanceInfo: {
    backgroundColor: '#E8F5E9',
    padding: 12,
    borderRadius: 8,
  },
  balanceRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginBottom: 8,
  },
  balanceLabel: {
    fontSize: 14,
    color: '#424242',
  },
  balanceValue: {
    fontSize: 14,
    fontWeight: '600',
    color: '#2E7D32',
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
    alignItems: 'center',
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
  },
  summaryHighlight: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#6200ee',
  },
  submitButton: {
    marginTop: 8,
  },
  errorText: {
    fontSize: 14,
    color: '#F44336',
    textAlign: 'center',
  },
  agreementPickerButton: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    backgroundColor: '#FFF',
    padding: 12,
    borderRadius: 8,
    borderWidth: 1,
    borderColor: '#ccc',
  },
  agreementPickerText: {
    fontSize: 16,
    color: '#333',
    flex: 1,
  },
  pickerArrow: {
    fontSize: 12,
    color: '#666',
    marginLeft: 8,
  },
  modalOverlay: {
    flex: 1,
    backgroundColor: 'rgba(0, 0, 0, 0.5)',
    justifyContent: 'flex-end',
  },
  modalOverlayTouchable: {
    flex: 1,
  },
  modalContent: {
    backgroundColor: '#FFF',
    borderTopLeftRadius: 20,
    borderTopRightRadius: 20,
    paddingBottom: 34,
  },
  modalHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    padding: 16,
    borderBottomWidth: 1,
    borderBottomColor: '#E0E0E0',
  },
  modalTitle: {
    fontSize: 17,
    fontWeight: '600',
    color: '#333',
  },
  modalButton: {
    padding: 8,
  },
  modalButtonCancel: {
    fontSize: 17,
    color: '#666',
  },
  modalButtonDone: {
    fontSize: 17,
    color: '#2196F3',
    fontWeight: '600',
  },
  modalPicker: {
    height: 200,
  },
});

export default CreateListingScreen;

