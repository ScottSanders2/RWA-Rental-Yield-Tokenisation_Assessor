import React, { useState, useEffect } from 'react';
import {
  Box,
  FormControl,
  InputLabel,
  Select,
  MenuItem,
  Chip,
  Typography,
  Paper,
  Avatar
} from '@mui/material';
import PersonIcon from '@mui/icons-material/Person';
import AdminPanelSettingsIcon from '@mui/icons-material/AdminPanelSettings';
import BusinessIcon from '@mui/icons-material/Business';

/**
 * UserProfileSwitcher Component
 * 
 * Allows switching between different test user profiles for multi-voter governance testing.
 * Fetches user profiles from backend and displays them in a dropdown with role indicators.
 */
const UserProfileSwitcher = ({ onProfileChange, currentProfile }) => {
  const [profiles, setProfiles] = useState([]);
  const [loading, setLoading] = useState(true);
  const [selectedWallet, setSelectedWallet] = useState(currentProfile?.wallet_address || '');

  useEffect(() => {
    fetchProfiles();
  }, []);

  const fetchProfiles = async () => {
    try {
      setLoading(true);
      const response = await fetch('http://localhost:8001/users/profiles');
      
      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`);
      }
      
      const data = await response.json();
      setProfiles(data);
      
      // Set default profile to first investor if no current profile
      if (!currentProfile && data.length > 0) {
        const defaultProfile = data.find(p => p.role === 'investor') || data[0];
        setSelectedWallet(defaultProfile.wallet_address);
        onProfileChange(defaultProfile);
      }
    } catch (error) {
      console.error('Error fetching user profiles:', error);
      // Use fallback mock data for development
      const mockProfiles = [
        {
          wallet_address: '0x0000000000000000000000000000000000000101',
          display_name: 'Investor Alice',
          role: 'investor',
          email: 'alice@test.com'
        }
      ];
      setProfiles(mockProfiles);
      if (!currentProfile) {
        setSelectedWallet(mockProfiles[0].wallet_address);
        onProfileChange(mockProfiles[0]);
      }
    } finally {
      setLoading(false);
    }
  };

  const handleChange = (event) => {
    const wallet = event.target.value;
    const profile = profiles.find(p => p.wallet_address === wallet);
    setSelectedWallet(wallet);
    if (profile) {
      onProfileChange(profile);
      console.log('👤 Profile switched to:', profile.display_name, `(${profile.role})`);
    }
  };

  const getRoleColor = (role) => {
    switch(role) {
      case 'property_owner': return 'primary';
      case 'investor': return 'success';
      case 'admin': return 'error';
      default: return 'default';
    }
  };

  const getRoleIcon = (role) => {
    switch(role) {
      case 'property_owner': return <BusinessIcon fontSize="small" />;
      case 'investor': return <PersonIcon fontSize="small" />;
      case 'admin': return <AdminPanelSettingsIcon fontSize="small" />;
      default: return <PersonIcon fontSize="small" />;
    }
  };

  const getRoleLabel = (role) => {
    switch(role) {
      case 'property_owner': return 'Owner';
      case 'investor': return 'Investor';
      case 'admin': return 'Admin';
      default: return role;
    }
  };

  if (loading) {
    return (
      <Paper sx={{ p: 2, mb: 2 }}>
        <Typography variant="body2" color="text.secondary">
          Loading user profiles...
        </Typography>
      </Paper>
    );
  }

  return (
    <Paper elevation={2} sx={{ p: 2, mb: 3, bgcolor: 'background.default' }}>
      <Box sx={{ display: 'flex', alignItems: 'center', gap: 2 }}>
        <Avatar sx={{ bgcolor: 'primary.main' }}>
          {getRoleIcon(currentProfile?.role || 'investor')}
        </Avatar>
        
        <FormControl fullWidth size="small">
          <InputLabel id="user-profile-select-label">
            Testing Mode: Select User Profile
          </InputLabel>
          <Select
            labelId="user-profile-select-label"
            id="user-profile-select"
            value={selectedWallet}
            label="Testing Mode: Select User Profile"
            onChange={handleChange}
          >
            {profiles.map((profile) => (
              <MenuItem 
                key={profile.wallet_address} 
                value={profile.wallet_address}
                sx={{ display: 'flex', gap: 1, py: 1.5 }}
              >
                <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, width: '100%' }}>
                  <Chip
                    icon={getRoleIcon(profile.role)}
                    label={getRoleLabel(profile.role)}
                    color={getRoleColor(profile.role)}
                    size="small"
                  />
                  <Typography sx={{ flexGrow: 1 }}>
                    {profile.display_name}
                  </Typography>
                  <Typography variant="caption" color="text.secondary">
                    {profile.wallet_address.slice(0, 6)}...{profile.wallet_address.slice(-4)}
                  </Typography>
                </Box>
              </MenuItem>
            ))}
          </Select>
        </FormControl>
      </Box>
      
      {currentProfile && (
        <Box sx={{ mt: 1, display: 'flex', alignItems: 'center', gap: 1 }}>
          <Typography variant="caption" color="text.secondary">
            Current Wallet:
          </Typography>
          <Typography variant="caption" sx={{ fontFamily: 'monospace' }}>
            {currentProfile.wallet_address}
          </Typography>
        </Box>
      )}
    </Paper>
  );
};

export default UserProfileSwitcher;

