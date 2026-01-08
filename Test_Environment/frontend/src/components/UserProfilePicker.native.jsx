import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  Modal,
  TouchableOpacity,
  StyleSheet,
  Platform,
  ActivityIndicator
} from 'react-native';
import { Picker } from '@react-native-picker/picker';
import axios from 'axios';

/**
 * UserProfilePicker Component (React Native)
 * 
 * Allows switching between different test user profiles for multi-voter governance testing.
 * Uses Modal-based Picker for iOS-native UX.
 */
const UserProfilePicker = ({ onProfileChange, currentProfile }) => {
  const [profiles, setProfiles] = useState([]);
  const [loading, setLoading] = useState(true);
  const [showPicker, setShowPicker] = useState(false);
  const [tempProfile, setTempProfile] = useState(null);

  const API_BASE_URL = Platform.OS === 'ios' ? 'http://localhost:8001' : 'http://10.0.2.2:8001';

  useEffect(() => {
    fetchProfiles();
  }, []);

  const fetchProfiles = async () => {
    try {
      setLoading(true);
      const response = await axios.get(`${API_BASE_URL}/users/profiles`);
      setProfiles(response.data);
      
      // Set default profile to first investor if no current profile
      if (!currentProfile && response.data.length > 0) {
        const defaultProfile = response.data.find(p => p.role === 'investor') || response.data[0];
        setTempProfile(defaultProfile.wallet_address);
        onProfileChange(defaultProfile);
      } else if (currentProfile) {
        setTempProfile(currentProfile.wallet_address);
      }
    } catch (error) {
      console.error('Error fetching user profiles:', error);
      // Use fallback mock data
      const mockProfiles = [
        {
          wallet_address: '0x0000000000000000000000000000000000000101',
          display_name: 'Investor Alice',
          role: 'investor'
        }
      ];
      setProfiles(mockProfiles);
      if (!currentProfile) {
        setTempProfile(mockProfiles[0].wallet_address);
        onProfileChange(mockProfiles[0]);
      }
    } finally {
      setLoading(false);
    }
  };

  const getRoleLabel = (role) => {
    switch(role) {
      case 'property_owner': return '🏢 Owner';
      case 'investor': return '👤 Investor';
      case 'admin': return '⚙️ Admin';
      default: return role;
    }
  };

  const getRoleColor = (role) => {
    switch(role) {
      case 'property_owner': return '#2196F3';
      case 'investor': return '#4CAF50';
      case 'admin': return '#F44336';
      default: return '#757575';
    }
  };

  const handleDone = () => {
    const selectedProfile = profiles.find(p => p.wallet_address === tempProfile);
    if (selectedProfile) {
      onProfileChange(selectedProfile);
      console.log('👤 Profile switched to:', selectedProfile.display_name, `(${selectedProfile.role})`);
    }
    setShowPicker(false);
  };

  const handleCancel = () => {
    // Reset to current profile
    if (currentProfile) {
      setTempProfile(currentProfile.wallet_address);
    }
    setShowPicker(false);
  };

  if (loading) {
    return (
      <View style={styles.container}>
        <ActivityIndicator size="small" color="#2196F3" />
        <Text style={styles.loadingText}>Loading profiles...</Text>
      </View>
    );
  }

  return (
    <View style={styles.container}>
      <Text style={styles.label}>Testing Mode: User Profile</Text>
      
      <TouchableOpacity
        style={[styles.pickerButton, { borderColor: getRoleColor(currentProfile?.role || 'investor') }]}
        onPress={() => setShowPicker(true)}
      >
        <View style={styles.pickerButtonContent}>
          <View style={[styles.roleBadge, { backgroundColor: getRoleColor(currentProfile?.role || 'investor') }]}>
            <Text style={styles.roleBadgeText}>
              {getRoleLabel(currentProfile?.role || 'investor')}
            </Text>
          </View>
          <Text style={styles.pickerButtonText}>
            {currentProfile?.display_name || 'Select Profile'}
          </Text>
        </View>
        <Text style={styles.pickerArrow}>▼</Text>
      </TouchableOpacity>

      {currentProfile && (
        <View style={styles.walletInfo}>
          <Text style={styles.walletLabel}>Wallet:</Text>
          <Text style={styles.walletAddress}>
            {currentProfile.wallet_address.slice(0, 10)}...{currentProfile.wallet_address.slice(-8)}
          </Text>
        </View>
      )}

      {/* Modal Picker for iOS-native UX */}
      <Modal
        visible={showPicker}
        transparent={true}
        animationType="slide"
        onRequestClose={handleCancel}
      >
        <View style={styles.modalOverlay}>
          <TouchableOpacity
            style={styles.modalOverlayTouchable}
            activeOpacity={1}
            onPress={handleCancel}
          />
          <View style={styles.modalContent}>
            <View style={styles.modalHeader}>
              <TouchableOpacity onPress={handleCancel} style={styles.modalButton}>
                <Text style={styles.modalButtonCancel}>Cancel</Text>
              </TouchableOpacity>
              <Text style={styles.modalTitle}>Select User Profile</Text>
              <TouchableOpacity onPress={handleDone} style={styles.modalButton}>
                <Text style={styles.modalButtonDone}>Done</Text>
              </TouchableOpacity>
            </View>
            
            <Picker
              selectedValue={tempProfile}
              onValueChange={(value) => setTempProfile(value)}
              style={styles.modalPicker}
            >
              {profiles.map((profile) => (
                <Picker.Item
                  key={profile.wallet_address}
                  label={`${getRoleLabel(profile.role)} - ${profile.display_name}`}
                  value={profile.wallet_address}
                />
              ))}
            </Picker>
          </View>
        </View>
      </Modal>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    backgroundColor: '#F5F5F5',
    padding: 16,
    marginBottom: 16,
    borderRadius: 8,
    borderWidth: 1,
    borderColor: '#E0E0E0'
  },
  loadingText: {
    marginTop: 8,
    fontSize: 14,
    color: '#666'
  },
  label: {
    fontSize: 12,
    color: '#666',
    marginBottom: 8,
    fontWeight: '600'
  },
  pickerButton: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    backgroundColor: '#FFF',
    padding: 12,
    borderRadius: 8,
    borderWidth: 2
  },
  pickerButtonContent: {
    flexDirection: 'row',
    alignItems: 'center',
    flex: 1
  },
  roleBadge: {
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 4,
    marginRight: 8
  },
  roleBadgeText: {
    color: '#FFF',
    fontSize: 12,
    fontWeight: 'bold'
  },
  pickerButtonText: {
    fontSize: 16,
    color: '#333',
    flex: 1
  },
  pickerArrow: {
    fontSize: 12,
    color: '#666',
    marginLeft: 8
  },
  walletInfo: {
    flexDirection: 'row',
    alignItems: 'center',
    marginTop: 8
  },
  walletLabel: {
    fontSize: 12,
    color: '#666',
    marginRight: 6
  },
  walletAddress: {
    fontSize: 12,
    fontFamily: Platform.OS === 'ios' ? 'Courier' : 'monospace',
    color: '#333'
  },
  modalOverlay: {
    flex: 1,
    backgroundColor: 'rgba(0, 0, 0, 0.5)',
    justifyContent: 'flex-end'
  },
  modalOverlayTouchable: {
    flex: 1
  },
  modalContent: {
    backgroundColor: '#FFF',
    borderTopLeftRadius: 20,
    borderTopRightRadius: 20,
    paddingBottom: 34
  },
  modalHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    padding: 16,
    borderBottomWidth: 1,
    borderBottomColor: '#E0E0E0'
  },
  modalTitle: {
    fontSize: 17,
    fontWeight: '600',
    color: '#333'
  },
  modalButton: {
    padding: 8
  },
  modalButtonCancel: {
    fontSize: 17,
    color: '#666'
  },
  modalButtonDone: {
    fontSize: 17,
    color: '#2196F3',
    fontWeight: '600'
  },
  modalPicker: {
    height: 200
  }
});

export default UserProfilePicker;

