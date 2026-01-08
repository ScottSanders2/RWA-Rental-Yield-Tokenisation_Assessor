/**
 * Governance Proposal Creation Screen (React Native)
 * Mobile-optimized touch interface for creating governance proposals
 */

import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  ScrollView,
  TextInput,
  TouchableOpacity,
  StyleSheet,
  ActivityIndicator,
  Alert,
  Platform,
  Modal
} from 'react-native';
import { Picker } from '@react-native-picker/picker';
import { createGovernanceProposal } from '../services/apiClient.native';
import { API_BASE_URL } from '@env';
import axios from 'axios';

const GovernanceCreate = ({ navigation, route }) => {
  const [formData, setFormData] = useState({
    agreement_id: '',
    proposal_type: '',
    target_roi_percent: '',
    target_value_usd: '',
    parameter_name: '', // For AGREEMENT_PARAMETER_UPDATE
    parameter_value: '', // For AGREEMENT_PARAMETER_UPDATE
    description: ''
  });

  const [loading, setLoading] = useState(false);
  const [ethEquivalent, setEthEquivalent] = useState(null);
  const [agreements, setAgreements] = useState([]);
  const [loadingAgreements, setLoadingAgreements] = useState(true);
  
  // Modal states for iOS pickers
  const [showAgreementPicker, setShowAgreementPicker] = useState(false);
  const [showProposalTypePicker, setShowProposalTypePicker] = useState(false);
  const [showParameterNamePicker, setShowParameterNamePicker] = useState(false);
  const [tempAgreementId, setTempAgreementId] = useState('');
  const [tempProposalType, setTempProposalType] = useState('');
  const [tempParameterName, setTempParameterName] = useState('');

  // Placeholder ETH price
  const ethPrice = 2000;
  const tokenStandard = 'ERC721';

  // API base URL - iOS simulator uses localhost, Android emulator uses 10.0.2.2
  const API_BASE_URL = Platform.OS === 'ios' 
    ? 'http://localhost:8000'  // DEVELOPMENT PORT
    : 'http://10.0.2.2:8000'; // Android emulator uses 10.0.2.2 for host - DEVELOPMENT PORT

  // Fetch agreements on component mount
  useEffect(() => {
    const fetchAgreements = async () => {
      try {
        setLoadingAgreements(true);
        const response = await axios.get(`${API_BASE_URL}/yield-agreements`, { timeout: 5000 });
        const data = response.data;
        // Filter only active agreements
        const activeAgreements = data.filter(agreement => agreement.is_active);
        setAgreements(activeAgreements);
      } catch (err) {
        console.error('Error fetching agreements:', err);
        // Don't show alert, just use mock data
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
  }, [formData.target_value_usd, formData.proposal_type]);

  const validateForm = () => {
    if (!formData.agreement_id || formData.agreement_id <= 0) {
      Alert.alert('Validation Error', 'Agreement ID must be greater than 0');
      return false;
    }

    if (!formData.proposal_type) {
      Alert.alert('Validation Error', 'Please select a proposal type');
      return false;
    }

    if (formData.proposal_type === 'ROI_ADJUSTMENT') {
      if (!formData.target_roi_percent || formData.target_roi_percent < 1 || formData.target_roi_percent > 50) {
        Alert.alert('Validation Error', 'ROI must be between 1% and 50%');
        return false;
      }
    }

    if (formData.proposal_type.includes('RESERVE')) {
      if (!formData.target_value_usd || formData.target_value_usd <= 0) {
        Alert.alert('Validation Error', 'Reserve amount must be greater than 0');
        return false;
      }
    }

    if (formData.proposal_type === 'AGREEMENT_PARAMETER_UPDATE') {
      if (!formData.parameter_name) {
        Alert.alert('Validation Error', 'Please select a parameter to update');
        return false;
      }
      if (!formData.parameter_value || parseInt(formData.parameter_value) < 0) {
        Alert.alert('Validation Error', 'Parameter value must be 0 or greater');
        return false;
      }
    }

    if (!formData.description || formData.description.length < 10 || formData.description.length > 500) {
      Alert.alert('Validation Error', 'Description must be between 10 and 500 characters');
      return false;
    }

    return true;
  };

  const handleSubmit = async () => {
    console.log('=== CREATE PROPOSAL FLOW START ===');
    console.log('Form Data:', formData);
    
    if (!validateForm()) {
      console.log('❌ Form validation failed');
      return;
    }
    console.log('✅ Form validation passed');

    setLoading(true);

    try {
      let targetValue;
      let paramId = null;
      let parameterType = null;

      if (formData.proposal_type === 'ROI_ADJUSTMENT') {
        targetValue = Math.floor(parseFloat(formData.target_roi_percent) * 100);
        console.log('ROI Adjustment - Target Value (basis points):', targetValue);
      } else if (formData.proposal_type.includes('RESERVE')) {
        const ethValue = parseFloat(formData.target_value_usd) / ethPrice;
        targetValue = Math.floor(ethValue * 1e18);
        console.log('Reserve Operation - USD:', formData.target_value_usd, 'ETH:', ethValue, 'Wei:', targetValue);
      } else if (formData.proposal_type === 'AGREEMENT_PARAMETER_UPDATE') {
        targetValue = parseInt(formData.parameter_value);
        parameterType = 'AGREEMENT';
        
        // Map parameter name to parameter ID
        const parameterMap = {
          'grace_period': 0,
          'penalty_rate': 1,
          'default_threshold': 2,
          'allow_partial_repayments': 3,
          'allow_early_repayment': 4
        };
        
        paramId = parameterMap[formData.parameter_name];
        console.log('Agreement Parameter Update - Parameter:', formData.parameter_name, 'ID:', paramId, 'Value:', targetValue);
      }

      const proposalData = {
        agreement_id: parseInt(formData.agreement_id),
        proposal_type: formData.proposal_type,
        target_value: targetValue,
        target_value_usd: formData.target_value_usd ? parseFloat(formData.target_value_usd) : null,
        param_id: paramId,  // Required for AGREEMENT_PARAMETER_UPDATE
        parameter_type: parameterType,  // Required for AGREEMENT_PARAMETER_UPDATE
        description: formData.description,
        token_standard: tokenStandard
      };

      console.log('📤 Sending proposal data to API:', JSON.stringify(proposalData, null, 2));
      console.log('API Base URL:', API_BASE_URL);
      console.log('Full endpoint: POST', `${API_BASE_URL}/governance/proposals`);
      
      const startTime = Date.now();
      const { data } = await createGovernanceProposal(proposalData);
      const duration = Date.now() - startTime;
      
      console.log(`✅ Proposal created successfully in ${duration}ms`);
      console.log('Response data:', JSON.stringify(data, null, 2));

      Alert.alert(
        'Success',
        `Proposal created successfully! Proposal ID: ${data.proposal_id} (Blockchain ID: ${data.blockchain_proposal_id})`,
        [
          {
            text: 'OK',
            onPress: () => navigation.navigate('GovernanceDetail', { proposalId: data.proposal_id })
          }
        ]
      );
    } catch (err) {
      console.error('❌ CREATE PROPOSAL ERROR ===');
      console.error('Error message:', err.message);
      console.error('Error status:', err.status);
      console.error('Error response:', err.response);
      console.error('Full error object:', JSON.stringify(err, null, 2));
      console.error('=== END ERROR ===');
      
      Alert.alert('Error', err.message || 'Failed to create proposal');
    } finally {
      setLoading(false);
      console.log('=== CREATE PROPOSAL FLOW END ===');
    }
  };

  return (
    <ScrollView style={styles.container}>
      <View style={styles.header}>
        <Text style={styles.title}>Create Governance Proposal</Text>
        <Text style={styles.subtitle}>Token Standard: {tokenStandard}</Text>
      </View>

      <View style={styles.form}>
        {/* Agreement ID */}
        <Text style={styles.label}>Yield Agreement *</Text>
        <TouchableOpacity
          style={styles.pickerButton}
          onPress={() => {
            setTempAgreementId(formData.agreement_id);
            setShowAgreementPicker(true);
          }}
          disabled={loadingAgreements}
        >
          <Text style={[styles.pickerButtonText, !formData.agreement_id && styles.pickerPlaceholder]}>
            {formData.agreement_id ? 
              (() => {
                const selected = agreements.find(a => a.id === parseInt(formData.agreement_id));
                if (selected) {
                  const roiPercent = selected.annual_roi_basis_points 
                    ? (selected.annual_roi_basis_points / 100).toFixed(2) 
                    : '0';
                  return `Agreement #${selected.id} - Property #${selected.property_id} ($${Math.round(selected.upfront_capital_usd || 0).toLocaleString()} capital, ${roiPercent}% ROI)`;
                }
                return `Agreement #${formData.agreement_id}`;
              })()
              : 'Select yield agreement...'}
          </Text>
          <Text style={styles.pickerArrow}>▼</Text>
        </TouchableOpacity>
        <Text style={styles.helper}>
          {loadingAgreements ? 'Loading agreements from backend...' : 
           agreements.length === 0 ? 'Using mock data (backend not available)' : 
           'Select the yield agreement to govern'}
        </Text>

        {/* Agreement Picker Modal */}
        <Modal
          visible={showAgreementPicker}
          transparent={true}
          animationType="slide"
          onRequestClose={() => setShowAgreementPicker(false)}
        >
          <View style={styles.modalOverlay}>
            <View style={styles.modalContent}>
              <View style={styles.modalHeader}>
                <TouchableOpacity onPress={() => setShowAgreementPicker(false)}>
                  <Text style={styles.modalButton}>Cancel</Text>
                </TouchableOpacity>
                <Text style={styles.modalTitle}>Select Agreement</Text>
                <TouchableOpacity onPress={() => {
                  setFormData({ ...formData, agreement_id: tempAgreementId });
                  setShowAgreementPicker(false);
                }}>
                  <Text style={[styles.modalButton, styles.modalButtonDone]}>Done</Text>
                </TouchableOpacity>
              </View>
              <Picker
                selectedValue={tempAgreementId}
                onValueChange={(value) => setTempAgreementId(value)}
                style={styles.modalPicker}
              >
                <Picker.Item label="Select yield agreement..." value="" />
                {loadingAgreements ? (
                  <Picker.Item label="Loading agreements..." value="" enabled={false} />
                ) : agreements.length === 0 ? (
                  <>
                    <Picker.Item label="No active agreements found" value="" enabled={false} />
                    <Picker.Item label="Agreement #1 (Mock)" value="1" />
                    <Picker.Item label="Agreement #2 (Mock)" value="2" />
                  </>
                ) : (
                  agreements.map((agreement) => {
                    const roiPercent = agreement.annual_roi_basis_points 
                      ? (agreement.annual_roi_basis_points / 100).toFixed(2) 
                      : '0';
                    return (
                      <Picker.Item
                        key={agreement.id}
                        label={`Agreement #${agreement.id} - Property #${agreement.property_id} ($${Math.round(agreement.upfront_capital_usd || 0).toLocaleString()} capital, ${roiPercent}% ROI)`}
                        value={agreement.id}
                      />
                    );
                  })
                )}
              </Picker>
            </View>
          </View>
        </Modal>

        {/* Proposal Type */}
        <Text style={styles.label}>Proposal Type *</Text>
        <TouchableOpacity
          style={styles.pickerButton}
          onPress={() => {
            setTempProposalType(formData.proposal_type);
            setShowProposalTypePicker(true);
          }}
        >
          <Text style={[styles.pickerButtonText, !formData.proposal_type && styles.pickerPlaceholder]}>
            {formData.proposal_type ? 
              (() => {
                const types = {
                  'ROI_ADJUSTMENT': 'ROI Adjustment (±5% bounds)',
                  'RESERVE_ALLOCATION': 'Reserve Allocation (≤20% capital)',
                  'RESERVE_WITHDRAWAL': 'Reserve Withdrawal',
                  'AGREEMENT_PARAMETER_UPDATE': 'Parameter Update'
                };
                return types[formData.proposal_type] || formData.proposal_type;
              })()
              : 'Select proposal type...'}
          </Text>
          <Text style={styles.pickerArrow}>▼</Text>
        </TouchableOpacity>

        {/* Proposal Type Picker Modal */}
        <Modal
          visible={showProposalTypePicker}
          transparent={true}
          animationType="slide"
          onRequestClose={() => setShowProposalTypePicker(false)}
        >
          <View style={styles.modalOverlay}>
            <View style={styles.modalContent}>
              <View style={styles.modalHeader}>
                <TouchableOpacity onPress={() => setShowProposalTypePicker(false)}>
                  <Text style={styles.modalButton}>Cancel</Text>
                </TouchableOpacity>
                <Text style={styles.modalTitle}>Select Proposal Type</Text>
                <TouchableOpacity onPress={() => {
                  setFormData({ ...formData, proposal_type: tempProposalType });
                  setShowProposalTypePicker(false);
                }}>
                  <Text style={[styles.modalButton, styles.modalButtonDone]}>Done</Text>
                </TouchableOpacity>
              </View>
              <Picker
                selectedValue={tempProposalType}
                onValueChange={(value) => setTempProposalType(value)}
                style={styles.modalPicker}
              >
                <Picker.Item label="Select proposal type..." value="" />
                <Picker.Item label="ROI Adjustment (±5% bounds)" value="ROI_ADJUSTMENT" />
                <Picker.Item label="Reserve Allocation (≤20% capital)" value="RESERVE_ALLOCATION" />
                <Picker.Item label="Reserve Withdrawal" value="RESERVE_WITHDRAWAL" />
                <Picker.Item label="Parameter Update" value="AGREEMENT_PARAMETER_UPDATE" />
              </Picker>
            </View>
          </View>
        </Modal>

        {/* Conditional Fields */}
        {formData.proposal_type === 'ROI_ADJUSTMENT' && (
          <>
            <Text style={styles.label}>New Annual ROI (%) *</Text>
            <TextInput
              style={styles.input}
              value={formData.target_roi_percent}
              onChangeText={(text) => setFormData({ ...formData, target_roi_percent: text })}
              keyboardType="decimal-pad"
              placeholder="e.g., 12.6"
            />
            <Text style={styles.helper}>Must be within ±5% of original ROI</Text>
          </>
        )}

        {(formData.proposal_type === 'RESERVE_ALLOCATION' || formData.proposal_type === 'RESERVE_WITHDRAWAL') && (
          <>
            <Text style={styles.label}>Reserve Amount (USD) *</Text>
            <TextInput
              style={styles.input}
              value={formData.target_value_usd}
              onChangeText={(text) => setFormData({ ...formData, target_value_usd: text })}
              keyboardType="decimal-pad"
              placeholder="e.g., 10000"
            />
            {ethEquivalent && (
              <Text style={styles.helper}>≈ {ethEquivalent} ETH (at ${ethPrice}/ETH)</Text>
            )}
            <Text style={styles.helper}>
              {formData.proposal_type === 'RESERVE_ALLOCATION' 
                ? 'Maximum 20% of upfront capital' 
                : 'Amount to return to investors'}
            </Text>
          </>
        )}

        {/* AGREEMENT_PARAMETER_UPDATE Fields */}
        {formData.proposal_type === 'AGREEMENT_PARAMETER_UPDATE' && (
          <>
            <Text style={styles.label}>Parameter to Update *</Text>
            <TouchableOpacity
              style={styles.pickerButton}
              onPress={() => {
                setTempParameterName(formData.parameter_name);
                setShowParameterNamePicker(true);
              }}
            >
              <Text style={[styles.pickerButtonText, !formData.parameter_name && styles.pickerPlaceholder]}>
                {formData.parameter_name ? 
                  (() => {
                    const params = {
                      'grace_period': 'Grace Period (days)',
                      'penalty_rate': 'Penalty Rate (%)',
                      'default_threshold': 'Default Threshold (missed payments)',
                      'allow_partial_repayment': 'Allow Partial Repayment (1=yes, 0=no)',
                      'allow_early_repayment': 'Allow Early Repayment (1=yes, 0=no)'
                    };
                    return params[formData.parameter_name] || formData.parameter_name;
                  })()
                  : 'Select parameter to update...'}
              </Text>
              <Text style={styles.pickerArrow}>▼</Text>
            </TouchableOpacity>
            <Text style={styles.helper}>Select which agreement parameter to modify</Text>

            {/* Parameter Name Picker Modal */}
            <Modal
              visible={showParameterNamePicker}
              transparent={true}
              animationType="slide"
            >
              <View style={styles.modalOverlay}>
                <View style={styles.modalContent}>
                  <View style={styles.modalHeader}>
                    <TouchableOpacity onPress={() => {
                      setShowParameterNamePicker(false);
                      setTempParameterName(formData.parameter_name);
                    }}>
                      <Text style={styles.modalButton}>Cancel</Text>
                    </TouchableOpacity>
                    <Text style={styles.modalTitle}>Select Parameter</Text>
                    <TouchableOpacity onPress={() => {
                      setFormData({ ...formData, parameter_name: tempParameterName });
                      setShowParameterNamePicker(false);
                    }}>
                      <Text style={[styles.modalButton, styles.modalButtonDone]}>Done</Text>
                    </TouchableOpacity>
                  </View>
                  <Picker
                    selectedValue={tempParameterName}
                    onValueChange={(value) => setTempParameterName(value)}
                    style={styles.modalPicker}
                  >
                    <Picker.Item label="Select parameter..." value="" />
                    <Picker.Item label="Grace Period (days)" value="grace_period" />
                    <Picker.Item label="Penalty Rate (%)" value="penalty_rate" />
                    <Picker.Item label="Default Threshold (missed payments)" value="default_threshold" />
                    <Picker.Item label="Allow Partial Repayment (1=yes, 0=no)" value="allow_partial_repayment" />
                    <Picker.Item label="Allow Early Repayment (1=yes, 0=no)" value="allow_early_repayment" />
                  </Picker>
                </View>
              </View>
            </Modal>

            <Text style={styles.label}>New Parameter Value *</Text>
            <TextInput
              style={styles.input}
              value={formData.parameter_value}
              onChangeText={(text) => setFormData({ ...formData, parameter_value: text })}
              keyboardType="number-pad"
              placeholder="e.g., 7 for 7 days grace period"
            />
            <Text style={styles.helper}>
              Grace Period: 1-90 days | Penalty Rate: 1-20% | Default Threshold: 1-12 | Boolean: 1=true, 0=false
            </Text>
          </>
        )}

        {/* Description */}
        <Text style={styles.label}>Proposal Description *</Text>
        <TextInput
          style={[styles.input, styles.textArea]}
          value={formData.description}
          onChangeText={(text) => setFormData({ ...formData, description: text })}
          multiline
          numberOfLines={4}
          placeholder="Explain rationale for this governance action (10-500 characters)"
        />
        <Text style={styles.charCount}>{formData.description.length}/500 characters</Text>

        {/* Submit Button */}
        <TouchableOpacity
          style={[styles.submitButton, loading && styles.submitButtonDisabled]}
          onPress={handleSubmit}
          disabled={loading}
        >
          {loading ? (
            <ActivityIndicator color="#fff" />
          ) : (
            <Text style={styles.submitButtonText}>Create Proposal</Text>
          )}
        </TouchableOpacity>

        {/* Help Text */}
        <View style={styles.helpContainer}>
          <Text style={styles.helpTitle}>Governance Requirements:</Text>
          <Text style={styles.helpText}>• Minimum 1% of tokens to create proposal</Text>
          <Text style={styles.helpText}>• 1 day delay before voting starts</Text>
          <Text style={styles.helpText}>• 7 day voting period</Text>
          <Text style={styles.helpText}>• 10% quorum required</Text>
          <Text style={styles.helpText}>• Simple majority wins (For &gt; Against)</Text>
        </View>
      </View>
    </ScrollView>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#f5f5f5',
  },
  header: {
    padding: 20,
    backgroundColor: '#2196F3',
  },
  title: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#fff',
  },
  subtitle: {
    fontSize: 14,
    color: '#fff',
    marginTop: 4,
  },
  form: {
    padding: 16,
  },
  label: {
    fontSize: 16,
    fontWeight: 'bold',
    color: '#333',
    marginTop: 16,
    marginBottom: 8,
  },
  input: {
    backgroundColor: '#fff',
    borderWidth: 1,
    borderColor: '#ddd',
    borderRadius: 8,
    padding: 12,
    fontSize: 16,
  },
  textArea: {
    height: 100,
    textAlignVertical: 'top',
  },
  pickerContainer: {
    backgroundColor: '#fff',
    borderWidth: 1,
    borderColor: '#ddd',
    borderRadius: 8,
    overflow: 'hidden',
    zIndex: 1,
  },
  picker: {
    height: 50,
    backgroundColor: '#fff',
  },
  pickerItem: {
    backgroundColor: '#fff',
  },
  pickerButton: {
    backgroundColor: '#fff',
    borderWidth: 1,
    borderColor: '#ddd',
    borderRadius: 8,
    padding: 12,
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    minHeight: 50,
  },
  pickerButtonText: {
    fontSize: 16,
    color: '#333',
    flex: 1,
  },
  pickerPlaceholder: {
    color: '#999',
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
  modalContent: {
    backgroundColor: '#fff',
    borderTopLeftRadius: 20,
    borderTopRightRadius: 20,
    paddingBottom: 34, // Safe area for iOS
  },
  modalHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    padding: 16,
    borderBottomWidth: 1,
    borderBottomColor: '#e0e0e0',
  },
  modalButton: {
    fontSize: 16,
    color: '#2196F3',
    paddingHorizontal: 8,
  },
  modalButtonDone: {
    fontWeight: 'bold',
  },
  modalTitle: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#333',
  },
  modalPicker: {
    width: '100%',
    height: 200,
  },
  helper: {
    fontSize: 12,
    color: '#666',
    marginTop: 4,
    marginLeft: 4,
  },
  charCount: {
    fontSize: 12,
    color: '#999',
    textAlign: 'right',
    marginTop: 4,
  },
  submitButton: {
    backgroundColor: '#2196F3',
    padding: 16,
    borderRadius: 8,
    alignItems: 'center',
    marginTop: 24,
  },
  submitButtonDisabled: {
    backgroundColor: '#B0BEC5',
  },
  submitButtonText: {
    color: '#fff',
    fontSize: 18,
    fontWeight: 'bold',
  },
  helpContainer: {
    marginTop: 24,
    padding: 16,
    backgroundColor: '#fff',
    borderRadius: 8,
  },
  helpTitle: {
    fontSize: 16,
    fontWeight: 'bold',
    marginBottom: 12,
    color: '#333',
  },
  helpText: {
    fontSize: 14,
    color: '#666',
    marginBottom: 6,
  },
});

export default GovernanceCreate;

