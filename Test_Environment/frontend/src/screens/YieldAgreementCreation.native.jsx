import React, {useState, useEffect} from 'react';
import {
  View,
  ScrollView,
  KeyboardAvoidingView,
  Platform,
  StyleSheet,
} from 'react-native';
import Slider from '@react-native-community/slider';
import {
  Text,
  TextInput,
  Button,
  HelperText,
  ActivityIndicator,
  Banner,
  Switch,
} from 'react-native-paper';
import AsyncStorage from '@react-native-async-storage/async-storage';
import {useNavigation, useRoute} from '@react-navigation/native';
import {useTokenStandard} from '../context/TokenStandardContext.native';
import {useEthPrice} from '../context/PriceContext.native';
import {useWallet} from '../context/WalletContext';
import {createYieldAgreement, getProperties} from '../services/apiClient.native';
import {
  formatWeiToUsd,
  formatUsdToWei,
  formatWeiToEth,
  formatDualCurrency,
  formatPercentToBasisPoints,
  validateEthereumAddress,
} from '../utils/formatters';
import UserProfilePicker from '../components/UserProfilePicker.native';
import {Card} from 'react-native-paper';

export default function YieldAgreementCreation() {
  const navigation = useNavigation();
  const route = useRoute();
  const {tokenStandard, getLabel, getDescription} = useTokenStandard();
  const {ethUsdPrice} = useEthPrice();
  const {account: connectedWallet} = useWallet();

  // User profile state for owner tracking
  const [currentProfile, setCurrentProfile] = useState(null);
  const [properties, setProperties] = useState([]);
  const [loadingProperties, setLoadingProperties] = useState(false);

  const [formData, setFormData] = useState({
    property_token_id: '',
    upfront_capital_usd: '',
    term_months: 24,
    annual_roi_percent: 12.0, // Changed from 12 to 12.0 for float precision
    property_payer: '',
    grace_period_days: 30,
    default_penalty_rate: 2,
    default_threshold: 3,
    allow_partial_repayments: true,
    allow_early_repayment: true,
  });

  const [calculatedPayments, setCalculatedPayments] = useState(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState(false);
  const [validationErrors, setValidationErrors] = useState({});
  const [ethEquivalent, setEthEquivalent] = useState('');

  // Auto-generate or set property token ID from route params
  useEffect(() => {
    const initializePropertyTokenId = async () => {
      // If coming from property registration, use the provided ID
      if (route.params?.propertyTokenId) {
        setFormData(prev => ({...prev, property_token_id: route.params.propertyTokenId.toString()}));
      } else {
        // Otherwise, auto-generate a new ID
        try {
          const lastId = await AsyncStorage.getItem('lastPropertyTokenId');
          const nextId = lastId ? parseInt(lastId) + 1 : 1;
          setFormData(prev => ({...prev, property_token_id: nextId.toString()}));
          await AsyncStorage.setItem('lastPropertyTokenId', nextId.toString());
        } catch (error) {
          console.error('Error generating property token ID:', error);
        }
      }
    };

    initializePropertyTokenId();
  }, [route.params?.propertyTokenId]);

  // Calculate ETH equivalent
  useEffect(() => {
    if (formData.upfront_capital_usd && ethUsdPrice) {
      const usdAmount = parseFloat(formData.upfront_capital_usd);
      if (!isNaN(usdAmount)) {
        const ethAmount = usdAmount / ethUsdPrice;
        setEthEquivalent(`≈ ${ethAmount.toFixed(6)} ETH`);
      } else {
        setEthEquivalent('');
      }
    } else {
      setEthEquivalent('');
    }
  }, [formData.upfront_capital_usd, ethUsdPrice]);

  // Fetch properties owned by current profile
  useEffect(() => {
    if (currentProfile) {
      fetchProperties(currentProfile.wallet_address);
    } else {
      setProperties([]);
    }
  }, [currentProfile]);

  const fetchProperties = async (ownerAddress) => {
    setLoadingProperties(true);
    try {
      const data = await getProperties(ownerAddress);
      // Filter out properties that already have active yield agreements
      // (This filtering should ideally be done by backend, but we can do it here too)
      setProperties(data || []);
    } catch (error) {
      console.error('Failed to fetch properties:', error);
      setProperties([]);
    } finally {
      setLoadingProperties(false);
    }
  };

  const handleProfileChange = (profile) => {
    setCurrentProfile(profile);
  };

  const handleChange = (field, value) => {
    setFormData(prev => ({...prev, [field]: value}));
    if (validationErrors[field]) {
      setValidationErrors(prev => ({...prev, [field]: false}));
    }
  };

  // Format currency with thousand separators
  const formatCurrency = (value) => {
    if (!value) return '';
    // Remove non-digits
    const digits = value.replace(/\D/g, '');
    // Add thousand separators
    return digits.replace(/\B(?=(\d{3})+(?!\d))/g, ',');
  };

  // Handle currency input with formatting
  const handleCurrencyChange = (value) => {
    // Remove commas for storage
    const rawValue = value.replace(/,/g, '');
    handleChange('upfront_capital_usd', rawValue);
  };

  const handleMockWallet = () => {
    // Use connected wallet address if available, otherwise generate random
    let mockAddress;
    
    if (connectedWallet) {
      // Use the connected wallet address from Dashboard
      // Ensure it's lowercase for consistent validation
      mockAddress = connectedWallet.toLowerCase();
      console.log('Using connected wallet address:', mockAddress);
    } else {
      // Generate a valid mock Ethereum address for development
      // Use lowercase for consistency
      mockAddress = '0x' + Array(40).fill(0).map(() => 
        Math.floor(Math.random() * 16).toString(16)
      ).join('').toLowerCase();
      console.log('No wallet connected, generated random address:', mockAddress);
    }
    
    handleChange('property_payer', mockAddress);
    // Clear validation error if it exists
    if (validationErrors.property_payer) {
      setValidationErrors(prev => ({...prev, property_payer: false}));
    }
  };

  const validateForm = () => {
    const errors = {};

    if (!formData.property_token_id.trim()) {
      errors.property_token_id = true;
    }

    if (!formData.upfront_capital_usd.trim()) {
      errors.upfront_capital_usd = true;
    } else {
      const usdAmount = parseFloat(formData.upfront_capital_usd);
      if (isNaN(usdAmount) || usdAmount <= 0) {
        errors.upfront_capital_usd = true;
      }
    }

    if (formData.property_payer && !validateEthereumAddress(formData.property_payer)) {
      errors.property_payer = true;
    }

    setValidationErrors(errors);
    return Object.keys(errors).length === 0;
  };

  const handleSubmit = async () => {
    if (!validateForm()) return;

    setLoading(true);
    setError('');
    setSuccess(false);

    try {
      // Map token standard to backend format (HYBRID -> ERC721, ERC1155 -> ERC1155)
      const backendTokenStandard = tokenStandard === 'HYBRID' ? 'ERC721' : tokenStandard;

      // Build submitData with backend-expected field names
      const submitData = {
        property_token_id: formData.property_token_id,
        upfront_capital: formatUsdToWei(formData.upfront_capital_usd, ethUsdPrice), // Backend expects 'upfront_capital' (wei)
        upfront_capital_usd: parseFloat(formData.upfront_capital_usd), // Backend also expects USD amount
        term_months: parseInt(formData.term_months),
        annual_roi_basis_points: formatPercentToBasisPoints(formData.annual_roi_percent), // Backend expects basis points
        property_payer: formData.property_payer || '',
        grace_period_days: parseInt(formData.grace_period_days),
        default_penalty_rate: formatPercentToBasisPoints(formData.default_penalty_rate),
        default_threshold: parseInt(formData.default_threshold),
        allow_partial_repayments: formData.allow_partial_repayments,
        allow_early_repayment: formData.allow_early_repayment,
        token_standard: backendTokenStandard,
      };

      console.log('Submitting yield agreement:', submitData);
      const response = await createYieldAgreement(submitData);
      console.log('Yield agreement response:', response);
      console.log('Response data:', response.data);
      console.log('Setting calculated payments and success state...');
      setCalculatedPayments(response.data);
      setSuccess(true);
      setValidationErrors({}); // Clear validation errors on success
      console.log('Success state should be true now');
    } catch (err) {
      console.error('Yield agreement creation error:', err);
      setError(err.message || 'Failed to create yield agreement');
    } finally {
      setLoading(false);
    }
  };

  return (
    <KeyboardAvoidingView
      style={styles.container}
      behavior={Platform.OS === 'ios' ? 'padding' : 'height'}>
      <ScrollView
        testID="yield_agreement_form_scrollview"
        contentContainerStyle={styles.scrollContainer}
        keyboardShouldPersistTaps="handled"
        showsVerticalScrollIndicator={true}
        scrollEnabled={true}
        nestedScrollEnabled={true}>
        <Text variant="headlineMedium" style={styles.title}>
          Create Yield Agreement
        </Text>

        {/* User Profile Switcher */}
        <Card style={styles.profileCard}>
          <Card.Title title="Select Agreement Owner" />
          <Card.Content>
            <UserProfilePicker 
              onProfileChange={handleProfileChange}
              currentProfile={currentProfile}
            />
          </Card.Content>
        </Card>

        <Banner style={styles.banner}>
          <Text variant="titleSmall" style={styles.bannerTitle}>
            Token Standard: {getLabel()}
          </Text>
          <Text variant="bodySmall" style={styles.bannerText}>
            {getDescription()}
          </Text>
        </Banner>

        <TextInput
          mode="outlined"
          label="Property Token ID"
          value={formData.property_token_id}
          onChangeText={(value) => handleChange('property_token_id', value)}
          error={validationErrors.property_token_id}
          style={styles.input}
          keyboardType="numeric"
          placeholder="1"
          editable={!route.params?.propertyTokenId}
        />
        <HelperText type="error" visible={validationErrors.property_token_id}>
          Property token ID is required
        </HelperText>

        <TextInput
          testID="upfront_capital_usd_input"
          mode="outlined"
          label="Upfront Capital (USD)"
          value={formatCurrency(formData.upfront_capital_usd)}
          onChangeText={handleCurrencyChange}
          error={validationErrors.upfront_capital_usd}
          style={styles.input}
          keyboardType="numeric"
          placeholder="50,000"
          left={<TextInput.Icon icon="currency-usd" />}
        />
        <HelperText type="error" visible={validationErrors.upfront_capital_usd}>
          Valid USD amount is required
        </HelperText>
        {ethEquivalent ? (
          <Text variant="bodySmall" style={styles.ethEquivalent}>
            {ethEquivalent} at ${ethUsdPrice.toFixed(2)}/ETH
          </Text>
        ) : null}

        {/* Token Standard - Read-only */}
        <TextInput
          mode="outlined"
          label="Token Standard"
          value={tokenStandard === 'HYBRID' ? 'ERC-721 + ERC-20' : tokenStandard}
          disabled
          style={styles.input}
          left={<TextInput.Icon icon="shield-check" />}
        />
        <HelperText type="info">
          Token standard determined by property type (read-only)
        </HelperText>

        {/* Total Token Supply - Read-only, calculated from upfront capital */}
        <TextInput
          mode="outlined"
          label="Total Token Supply"
          value={formData.upfront_capital_usd ? 
            `${parseFloat(formData.upfront_capital_usd.replace(/,/g, '')).toLocaleString()} shares` : 
            'Enter capital amount first'}
          disabled
          style={styles.input}
          left={<TextInput.Icon icon="chart-box" />}
        />
        <HelperText type="info">
          Total shares = Upfront capital (USD) amount (1 token = $1 USD)
        </HelperText>

        <View style={styles.sliderContainer}>
          <View style={styles.sliderHeader}>
            <Text variant="titleSmall" style={styles.sliderLabel}>
              Agreement Term: {formData.term_months} months ({(formData.term_months / 12).toFixed(1)} years)
            </Text>
            <View style={styles.sliderMarkers}>
              <Text style={styles.markerText}>1m</Text>
              <Text style={styles.markerText}>90m</Text>
              <Text style={styles.markerText}>180m</Text>
              <Text style={styles.markerText}>270m</Text>
              <Text style={styles.markerText}>360m</Text>
            </View>
          </View>
          <Slider
            testID="term_months_slider"
            style={styles.slider}
            minimumValue={1}
            maximumValue={360}
            step={1}
            value={formData.term_months}
            onValueChange={(value) => handleChange('term_months', Math.round(value))}
            minimumTrackTintColor="#1976d2"
            maximumTrackTintColor="#e0e0e0"
            thumbTintColor="#1976d2"
          />
        </View>

        <View style={styles.sliderContainer}>
          <View style={styles.sliderHeader}>
            <Text variant="titleSmall" style={styles.sliderLabel}>
              Annual ROI: {formData.annual_roi_percent.toFixed(2)}%
            </Text>
            <View style={styles.sliderMarkers}>
              <Text style={styles.markerText}>0.01%</Text>
              <Text style={styles.markerText}>12.5%</Text>
              <Text style={styles.markerText}>25%</Text>
              <Text style={styles.markerText}>37.5%</Text>
              <Text style={styles.markerText}>50%</Text>
            </View>
          </View>
          <Slider
            testID="annual_roi_slider"
            style={styles.slider}
            minimumValue={0.01}
            maximumValue={50}
            step={0.1}
            value={formData.annual_roi_percent}
            onValueChange={(value) => handleChange('annual_roi_percent', Math.round(value * 10) / 10)}
            minimumTrackTintColor="#1976d2"
            maximumTrackTintColor="#e0e0e0"
            thumbTintColor="#1976d2"
          />
        </View>

        <Text variant="titleSmall" style={styles.sectionTitle}>
          Advanced Parameters
        </Text>

        <TextInput
          testID="property_payer_input"
          mode="outlined"
          label="Property Payer Address"
          value={formData.property_payer}
          onChangeText={(value) => handleChange('property_payer', value)}
          error={validationErrors.property_payer}
          style={[styles.input, styles.addressInput]}
          placeholder="0x..."
          autoCapitalize="none"
          autoCorrect={false}
          multiline={false}
          numberOfLines={1}
        />
        <View testID="generate_mock_wallet_container">
          <Button
            testID="generate_mock_wallet_button"
            mode="outlined"
            icon="wallet"
            onPress={handleMockWallet}
            style={styles.mockWalletButton}>
            Generate Mock Wallet
          </Button>
        </View>
        <HelperText type="error" visible={validationErrors.property_payer}>
          Valid Ethereum address required
        </HelperText>

        <TextInput
          mode="outlined"
          label="Grace Period (Days)"
          value={formData.grace_period_days.toString()}
          onChangeText={(value) => handleChange('grace_period_days', parseInt(value) || 30)}
          style={styles.input}
          keyboardType="numeric"
        />

        <TextInput
          mode="outlined"
          label="Default Penalty Rate (%)"
          value={formData.default_penalty_rate.toString()}
          onChangeText={(value) => handleChange('default_penalty_rate', parseFloat(value) || 2)}
          style={styles.input}
          keyboardType="decimal-pad"
        />

        <TextInput
          mode="outlined"
          label="Default Threshold (Months)"
          value={formData.default_threshold.toString()}
          onChangeText={(value) => handleChange('default_threshold', parseInt(value) || 3)}
          style={styles.input}
          keyboardType="numeric"
        />

        <View style={styles.switchContainer}>
          <Text variant="bodyMedium">Allow Partial Repayments</Text>
          <Switch
            value={formData.allow_partial_repayments}
            onValueChange={(value) => handleChange('allow_partial_repayments', value)}
          />
        </View>

        <View style={styles.switchContainer}>
          <Text variant="bodyMedium">Allow Early Repayment</Text>
          <Switch
            value={formData.allow_early_repayment}
            onValueChange={(value) => handleChange('allow_early_repayment', value)}
          />
        </View>

        {calculatedPayments && (
          <Banner style={[styles.banner, styles.projectionBanner]}>
            <Text variant="titleSmall" style={styles.projectionTitle}>
              Financial Projections
            </Text>
            <Text>Monthly Payment: {formatDualCurrency(calculatedPayments.monthly_payment, ethUsdPrice)}</Text>
            <Text>Total Expected: {formatDualCurrency(calculatedPayments.total_expected, ethUsdPrice)}</Text>
          </Banner>
        )}

        <View testID="create_agreement_submit_container">
          <Button
            testID="create_agreement_submit_button"
            mode="contained"
            onPress={handleSubmit}
            loading={loading}
            disabled={loading}
            style={styles.button}>
            {loading ? 'Creating...' : 'Create Yield Agreement'}
          </Button>
        </View>

        {success && (
          <Banner testID="success_banner" style={[styles.banner, styles.successBanner]} visible={true}>
            <View style={styles.successContent}>
              <Text variant="titleMedium" style={styles.successTitle}>
                Yield Agreement Created Successfully! ✅
              </Text>
              {calculatedPayments ? (
                <View style={styles.paymentsContainer}>
                  <Text variant="titleSmall" style={styles.projectionTitle}>
                    Payment Summary:
                  </Text>
                  {(() => {
                    // Calculate static USD values using simple interest (same as YieldAgreementsList)
                    const upfrontCapital = parseFloat(formData.upfront_capital_usd) || 0;
                    const annualRate = formData.annual_roi_percent / 100; // Convert percent to decimal
                    const timeInYears = formData.term_months / 12;
                    const totalRepayment = upfrontCapital * (1 + annualRate * timeInYears);
                    const monthlyPayment = totalRepayment / formData.term_months;
                    
                    return (
                      <>
                        <Text style={styles.paymentText}>
                          Monthly Payment: ${monthlyPayment.toFixed(2).replace(/\B(?=(\d{3})+(?!\d))/g, ',')}
                        </Text>
                        <Text style={styles.paymentText}>
                          Total Expected: ${totalRepayment.toFixed(2).replace(/\B(?=(\d{3})+(?!\d))/g, ',')}
                        </Text>
                      </>
                    );
                  })()}
                  {calculatedPayments.agreement_id && (
                    <Text style={styles.paymentText}>
                      Agreement ID: #{calculatedPayments.agreement_id}
                    </Text>
                  )}
                  {calculatedPayments.tx_hash && (
                    <Text style={styles.txHash}>
                      Transaction: {calculatedPayments.tx_hash.slice(0, 10)}...{calculatedPayments.tx_hash.slice(-8)}
                    </Text>
                  )}
                </View>
              ) : (
                <Text style={styles.debugText}>Agreement created but payment details not available</Text>
              )}
              <Button
                testID="view_agreements_button"
                mode="contained"
                onPress={() => navigation.navigate('Agreements')}
                style={styles.viewButton}>
                View All Agreements
              </Button>
            </View>
          </Banner>
        )}

        {error && (
          <Banner style={[styles.banner, styles.errorBanner]}>
            <Text>{error}</Text>
          </Banner>
        )}
      </ScrollView>
    </KeyboardAvoidingView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#f5f5f5',
  },
  scrollContainer: {
    padding: 16,
    paddingBottom: 32,
  },
  title: {
    textAlign: 'center',
    marginBottom: 16,
    color: '#1976d2',
    fontWeight: 'bold',
  },
  profileCard: {
    marginBottom: 16,
    elevation: 2,
  },
  banner: {
    marginBottom: 16,
  },
  bannerTitle: {
    fontWeight: 'bold',
    marginBottom: 4,
  },
  bannerText: {
    color: '#666',
  },
  input: {
    marginBottom: 4,
  },
  addressInput: {
    fontSize: 11,
  },
  mockWalletButton: {
    marginTop: 8,
    marginBottom: 8,
  },
  ethEquivalent: {
    marginBottom: 16,
    color: '#666',
    textAlign: 'center',
  },
  sliderContainer: {
    marginBottom: 16,
  },
  sliderHeader: {
    marginBottom: 4,
  },
  sliderLabel: {
    marginBottom: 8,
    color: '#1976d2',
  },
  sliderMarkers: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    paddingHorizontal: 4,
    marginBottom: 4,
  },
  markerText: {
    fontSize: 10,
    color: '#999',
  },
  slider: {
    width: '100%',
    height: 40,
  },
  sectionTitle: {
    marginTop: 16,
    marginBottom: 8,
    color: '#1976d2',
    fontWeight: 'bold',
  },
  switchContainer: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 16,
  },
  projectionBanner: {
    backgroundColor: '#e3f2fd',
  },
  projectionTitle: {
    fontWeight: 'bold',
    marginBottom: 8,
  },
  button: {
    marginTop: 16,
    marginBottom: 16,
  },
  successBanner: {
    backgroundColor: '#e8f5e8',
    marginBottom: 16,
  },
  successContent: {
    padding: 8,
  },
  successTitle: {
    fontWeight: 'bold',
    marginBottom: 12,
    color: '#2e7d32',
  },
  paymentsContainer: {
    marginTop: 8,
    marginBottom: 16,
    backgroundColor: '#fff',
    padding: 12,
    borderRadius: 8,
  },
  projectionTitle: {
    fontWeight: 'bold',
    marginBottom: 8,
    color: '#1976d2',
  },
  paymentText: {
    fontSize: 14,
    marginBottom: 6,
    color: '#333',
  },
  txHash: {
    fontSize: 12,
    marginTop: 4,
    color: '#666',
    fontFamily: 'monospace',
  },
  debugText: {
    color: '#666',
    marginTop: 8,
    marginBottom: 8,
  },
  errorBanner: {
    backgroundColor: '#ffebee',
  },
  viewButton: {
    marginTop: 8,
  },
});
// React Native Paper components replace Material-UI, mobile-optimized sliders replace web sliders, USD-first display maintained with live ETH conversion, form validation identical to web for consistency, and explicit token standard labeling preserved.


