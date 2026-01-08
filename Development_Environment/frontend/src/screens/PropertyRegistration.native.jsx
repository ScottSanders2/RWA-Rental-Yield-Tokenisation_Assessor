import React, {useState} from 'react';
import {
  View,
  ScrollView,
  KeyboardAvoidingView,
  Platform,
  StyleSheet,
} from 'react-native';
import {
  Text,
  TextInput,
  Button,
  HelperText,
  ActivityIndicator,
  Banner,
  Card,
  IconButton,
  Switch,
} from 'react-native-paper';
import {Picker} from '@react-native-picker/picker';
import * as DocumentPicker from 'expo-document-picker';
import {useNavigation} from '@react-navigation/native';
import {useTokenStandard} from '../context/TokenStandardContext.native';
import {registerProperty} from '../services/apiClient.native';
import {validateDeedHash} from '../utils/formatters';
import UserProfilePicker from '../components/UserProfilePicker.native';

export default function PropertyRegistration() {
  const navigation = useNavigation();
  const {tokenStandard, getLabel, getDescription} = useTokenStandard();

  // User profile state for owner tracking
  const [currentProfile, setCurrentProfile] = useState(null);

  const [formData, setFormData] = useState({
    property_address: '',
    deed_hash: '',
    rental_agreement_uri: '',
    metadata: '',
  });

  // Property details state
  const [propertyDetails, setPropertyDetails] = useState({
    bedrooms: '3',
    bathrooms: '2',
    sqft: '1500',
    propertyType: 'residential',
  });

  // File upload state
  const [deedFile, setDeedFile] = useState(null);
  const [rentalFile, setRentalFile] = useState(null);

  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState(false);
  const [validationErrors, setValidationErrors] = useState({});
  const [autoNavigate, setAutoNavigate] = useState(true);

  const handleChange = (field, value) => {
    setFormData(prev => ({...prev, [field]: value}));
    if (validationErrors[field]) {
      setValidationErrors(prev => ({...prev, [field]: false}));
    }
  };

  const handlePropertyDetailChange = (field, value) => {
    setPropertyDetails(prev => ({...prev, [field]: value}));
  };

  const handleProfileChange = (profile) => {
    setCurrentProfile(profile);
  };

  const handleDeedUpload = async () => {
    try {
      // E2E Testing: Uses real DocumentPicker with 5-second manual-assist pause in tests
      const result = await DocumentPicker.getDocumentAsync({
        type: ['application/pdf', 'text/plain', 'application/msword', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'],
        copyToCacheDirectory: true,
      });

      if (!result.canceled && result.assets && result.assets.length > 0) {
        setDeedFile(result.assets[0]);
        // In a real app, you would hash the file here
        // For now, generate a mock hash
        const mockHash = '0x' + Array(64).fill(0).map(() => 
          Math.floor(Math.random() * 16).toString(16)
        ).join('');
        handleChange('deed_hash', mockHash);
      }
    } catch (err) {
      setError('Failed to pick deed file: ' + err.message);
    }
  };

  const handleRentalUpload = async () => {
    try {
      // E2E Testing: Uses real DocumentPicker with 5-second manual-assist pause in tests
      const result = await DocumentPicker.getDocumentAsync({
        type: ['application/pdf', 'text/plain', 'application/msword', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'],
        copyToCacheDirectory: true,
      });

      if (!result.canceled && result.assets && result.assets.length > 0) {
        setRentalFile(result.assets[0]);
        // In a real app, you would upload to IPFS here
        // For now, generate a mock URI
        const mockUri = `ipfs://Qm${Array(44).fill(0).map(() => 
          'abcdefghijklmnopqrstuvwxyz0123456789'[Math.floor(Math.random() * 36)]
        ).join('')}`;
        handleChange('rental_agreement_uri', mockUri);
      }
    } catch (err) {
      setError('Failed to pick rental agreement file: ' + err.message);
    }
  };

  const validateForm = () => {
    const errors = {};

    if (!formData.property_address.trim()) {
      errors.property_address = true;
    }

    if (!formData.deed_hash.trim()) {
      errors.deed_hash = true;
    } else if (!validateDeedHash(formData.deed_hash)) {
      errors.deed_hash = true;
    }

    if (!formData.rental_agreement_uri.trim()) {
      errors.rental_agreement_uri = true;
    }

    try {
      if (formData.metadata.trim() && JSON.parse(formData.metadata) === undefined) {
        errors.metadata = true;
      }
    } catch {
      errors.metadata = true;
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
      // Build metadata from property details as an object (not string)
      const metadata = {
        bedrooms: parseInt(propertyDetails.bedrooms),
        bathrooms: parseInt(propertyDetails.bathrooms),
        sqft: parseInt(propertyDetails.sqft),
        propertyType: propertyDetails.propertyType,
      };

      // Map token standard to backend format (HYBRID -> ERC721, ERC1155 -> ERC1155)
      const backendTokenStandard = tokenStandard === 'HYBRID' ? 'ERC721' : tokenStandard;

      const response = await registerProperty({
        ...formData,
        metadata,
        token_standard: backendTokenStandard,
        owner_address: currentProfile?.wallet_address || null,
      });

      setSuccess(true);
      // Navigate to yield agreement creation with blockchain token ID if checkbox is selected
      // IMPORTANT: Must use blockchain_token_id (not property_id) to match web frontend behavior
      // This ensures backend can find existing property and doesn't create duplicates
      if (autoNavigate) {
        setTimeout(() => {
          navigation.navigate('YieldAgreementCreation', {
            propertyTokenId: response.data.blockchain_token_id,
          });
        }, 2000);
      }
    } catch (err) {
      // apiClient already formats the error message
      setError(err.message || 'Failed to register property');
    } finally {
      setLoading(false);
    }
  };

  return (
    <ScrollView 
      testID="property_registration_form"
      style={styles.container} 
      contentContainerStyle={styles.scrollContainer}
      keyboardShouldPersistTaps="handled"
      showsVerticalScrollIndicator={true}
      scrollEnabled={true}
      nestedScrollEnabled={true}>
      <Text variant="headlineMedium" style={styles.title}>
        Register Property
      </Text>

      {/* User Profile Switcher */}
      <Card style={styles.profileCard}>
        <Card.Title title="Select Property Owner" />
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
          testID="property_address_input"
          mode="outlined"
          label="Property Address"
          value={formData.property_address}
          onChangeText={(value) => handleChange('property_address', value)}
          error={validationErrors.property_address}
          style={styles.input}
          placeholder="123 Main Street, City, State"
        />
        <HelperText type="error" visible={validationErrors.property_address}>
          Property address is required
        </HelperText>

        {/* File Upload Cards */}
        <View style={styles.uploadSection}>
          <Card style={styles.uploadCard}>
            <Card.Content>
              <Text variant="titleMedium" style={styles.uploadTitle}>
                Property Deed
              </Text>
              <View testID="deed_upload_button_wrapper">
                <Button
                  testID="deed_upload_button"
                  mode="outlined"
                  icon="file-document"
                  onPress={handleDeedUpload}
                  style={styles.uploadButton}>
                  {deedFile ? deedFile.name : 'Choose File'}
                </Button>
              </View>
              {deedFile && (
                <Text variant="bodySmall" style={styles.fileInfo}>
                  {(deedFile.size / 1024).toFixed(2)} KB
                </Text>
              )}
            </Card.Content>
          </Card>

          <Card style={styles.uploadCard}>
            <Card.Content>
              <Text variant="titleMedium" style={styles.uploadTitle}>
                Rental Agreement
              </Text>
              <View testID="rental_upload_button_wrapper">
                <Button
                  testID="rental_upload_button"
                  mode="outlined"
                  icon="file-document"
                  onPress={handleRentalUpload}
                  style={styles.uploadButton}>
                  {rentalFile ? rentalFile.name : 'Choose File'}
                </Button>
              </View>
              {rentalFile && (
                <Text variant="bodySmall" style={styles.fileInfo}>
                  {(rentalFile.size / 1024).toFixed(2)} KB
                </Text>
              )}
            </Card.Content>
          </Card>
        </View>

        {/* Property Details Section */}
        <Text variant="titleMedium" style={styles.sectionTitle}>
          Property Details
        </Text>

        <View style={styles.pickerContainer}>
          <Text variant="bodyMedium" style={styles.pickerLabel}>Bedrooms</Text>
          <Picker
            selectedValue={propertyDetails.bedrooms}
            onValueChange={(value) => handlePropertyDetailChange('bedrooms', value)}
            style={styles.picker}>
            {[1, 2, 3, 4, 5, 6, 7, 8].map((num) => (
              <Picker.Item key={num} label={`${num}`} value={`${num}`} />
            ))}
          </Picker>
        </View>

        <View style={styles.pickerContainer}>
          <Text variant="bodyMedium" style={styles.pickerLabel}>Bathrooms</Text>
          <Picker
            selectedValue={propertyDetails.bathrooms}
            onValueChange={(value) => handlePropertyDetailChange('bathrooms', value)}
            style={styles.picker}>
            {[1, 2, 3, 4, 5, 6].map((num) => (
              <Picker.Item key={num} label={`${num}`} value={`${num}`} />
            ))}
          </Picker>
        </View>

        <TextInput
          mode="outlined"
          label="Square Footage"
          value={propertyDetails.sqft}
          onChangeText={(value) => handlePropertyDetailChange('sqft', value)}
          style={styles.input}
          keyboardType="numeric"
          placeholder="1500"
        />

        <View style={styles.pickerContainer}>
          <Text variant="bodyMedium" style={styles.pickerLabel}>Property Type</Text>
          <Picker
            selectedValue={propertyDetails.propertyType}
            onValueChange={(value) => handlePropertyDetailChange('propertyType', value)}
            style={styles.picker}>
            <Picker.Item label="Residential" value="residential" />
            <Picker.Item label="Commercial" value="commercial" />
            <Picker.Item label="Industrial" value="industrial" />
            <Picker.Item label="Mixed-Use" value="mixed-use" />
          </Picker>
        </View>

        <View style={styles.checkboxContainer}>
          <Switch
            value={autoNavigate}
            onValueChange={setAutoNavigate}
          />
          <Text style={styles.checkboxLabel}>
            Proceed to Create Yield Agreement after registration
          </Text>
        </View>

        <View testID="register_property_submit_button_wrapper">
          <Button
            testID="register_property_submit_button"
            mode="contained"
            onPress={handleSubmit}
            loading={loading}
            disabled={loading || Object.keys(validationErrors).length > 0}
            style={styles.button}>
            {loading ? 'Registering...' : 'Register Property'}
          </Button>
        </View>

        {success && (
          <Banner testID="success_banner" style={[styles.banner, styles.successBanner]}>
            <Text>Property registered successfully!</Text>
          </Banner>
        )}

        {error && (
          <Banner testID="error_banner" style={[styles.banner, styles.errorBanner]}>
            <Text>{error}</Text>
          </Banner>
        )}
      </ScrollView>
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
  uploadSection: {
    marginVertical: 16,
  },
  uploadCard: {
    marginBottom: 16,
  },
  uploadTitle: {
    marginBottom: 12,
    color: '#1976d2',
    fontWeight: 'bold',
  },
  uploadButton: {
    marginBottom: 8,
  },
  fileInfo: {
    color: '#666',
    textAlign: 'center',
  },
  sectionTitle: {
    marginTop: 16,
    marginBottom: 12,
    color: '#1976d2',
    fontWeight: 'bold',
  },
  pickerContainer: {
    marginBottom: 16,
    backgroundColor: '#fff',
    borderRadius: 4,
    borderWidth: 1,
    borderColor: '#ccc',
  },
  pickerLabel: {
    marginTop: 8,
    marginLeft: 12,
    color: '#666',
  },
  picker: {
    marginHorizontal: 8,
  },
  checkboxContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    marginTop: 16,
    marginBottom: 8,
  },
  checkboxLabel: {
    marginLeft: 8,
    flex: 1,
  },
  button: {
    marginTop: 8,
    marginBottom: 16,
  },
  successBanner: {
    backgroundColor: '#e8f5e8',
  },
  errorBanner: {
    backgroundColor: '#ffebee',
  },
});
