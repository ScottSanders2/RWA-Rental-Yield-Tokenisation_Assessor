import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  FlatList,
  StyleSheet,
  RefreshControl,
  ActivityIndicator,
  ScrollView,
} from 'react-native';
import { Card, Button, DataTable, Chip, IconButton } from 'react-native-paper';
import { useNavigation } from '@react-navigation/native';
import { getPortfolio } from '../services/apiClient.native';
import UserProfilePicker from '../components/UserProfilePicker.native';

const PortfolioScreen = () => {
  const navigation = useNavigation();
  const [currentProfile, setCurrentProfile] = useState(null);
  const [portfolio, setPortfolio] = useState(null);
  const [loading, setLoading] = useState(false);
  const [refreshing, setRefreshing] = useState(false);
  const [error, setError] = useState(null);

  // Load portfolio when profile changes
  useEffect(() => {
    if (currentProfile) {
      loadPortfolio(currentProfile.wallet_address);
    }
  }, [currentProfile]);

  const loadPortfolio = async (walletAddress) => {
    setLoading(true);
    setError(null);

    try {
      const data = await getPortfolio(walletAddress);
      setPortfolio(data);
    } catch (err) {
      console.error('Error loading portfolio:', err);
      setError(err.message || 'Failed to load portfolio');
    } finally {
      setLoading(false);
    }
  };

  const onRefresh = async () => {
    if (currentProfile) {
      setRefreshing(true);
      await loadPortfolio(currentProfile.wallet_address);
      setRefreshing(false);
    }
  };

  const handleProfileChange = (profile) => {
    setCurrentProfile(profile);
  };

  const handleCreateListing = (agreementId) => {
    navigation.navigate('CreateListing', { agreementId });
  };

  const renderHolding = ({ item }) => {
    const balanceShares = (parseFloat(item.balance_wei) / 1e18).toLocaleString(undefined, {
      minimumFractionDigits: 2,
      maximumFractionDigits: 2,
    });
    const totalSupplyShares = (item.agreement_total_supply || 0).toLocaleString();
    const ownershipPercent = item.ownership_percentage?.toFixed(2) || '0.00';
    const lastUpdated = item.last_updated
      ? new Date(item.last_updated + (item.last_updated.endsWith('Z') ? '' : 'Z')).toLocaleString()
      : 'N/A';

    return (
      <Card style={styles.holdingCard} mode="elevated">
        <Card.Content>
          {/* Header */}
          <View style={styles.holdingHeader}>
            <Chip mode="outlined" style={styles.agreementChip}>
              Agreement #{item.agreement_id}
            </Chip>
            {item.property_id && (
              <Chip mode="outlined" style={styles.propertyChip}>
                Property #{item.property_id}
              </Chip>
            )}
          </View>

          {/* Agreement Name */}
          {item.agreement_name && (
            <Text style={styles.agreementName}>{item.agreement_name}</Text>
          )}

          {/* Balance Info */}
          <View style={styles.balanceContainer}>
            <View style={styles.balanceRow}>
              <Text style={styles.balanceLabel}>Share Balance:</Text>
              <Text style={styles.balanceValue}>{balanceShares} shares</Text>
            </View>
            <View style={styles.balanceRow}>
              <Text style={styles.balanceLabel}>Total Supply:</Text>
              <Text style={styles.balanceValue}>{totalSupplyShares} shares</Text>
            </View>
            <View style={styles.balanceRow}>
              <Text style={styles.balanceLabel}>Ownership:</Text>
              <Text style={[styles.balanceValue, styles.ownershipValue]}>
                {ownershipPercent}%
              </Text>
            </View>
          </View>

          {/* Token Standard */}
          {item.agreement_token_standard && (
            <View style={styles.infoRow}>
              <Text style={styles.infoLabel}>Token Standard:</Text>
              <Chip mode="flat" style={styles.tokenChip}>
                {item.agreement_token_standard === 'ERC721' ? 'ERC-721 + ERC-20' : item.agreement_token_standard}
              </Chip>
            </View>
          )}

          {/* Last Updated */}
          <Text style={styles.lastUpdated}>Last Updated: {lastUpdated}</Text>
        </Card.Content>

        <Card.Actions style={styles.actions}>
          <Button
            mode="contained"
            onPress={() => handleCreateListing(item.agreement_id)}
            icon="cart-plus"
            compact
          >
            List
          </Button>
          <Button
            mode="outlined"
            onPress={() => navigation.navigate('YieldAgreementDetail', { agreementId: item.agreement_id })}
            icon="file-document-outline"
            compact
          >
            View
          </Button>
        </Card.Actions>
      </Card>
    );
  };

  return (
    <View style={styles.container}>
      {/* User Profile Picker */}
      <View style={styles.profileSection}>
        <UserProfilePicker
          onProfileChange={handleProfileChange}
          currentProfile={currentProfile}
        />
      </View>

      {/* Content */}
      {!currentProfile ? (
        <View style={styles.emptyContainer}>
          <Text style={styles.emptyText}>Select a user profile to view portfolio</Text>
          <Text style={styles.emptySubtext}>Use the dropdown above to choose a user</Text>
        </View>
      ) : loading && !refreshing ? (
        <View style={styles.centerContainer}>
          <ActivityIndicator size="large" color="#6200ee" />
          <Text style={styles.loadingText}>Loading portfolio...</Text>
        </View>
      ) : error ? (
        <View style={styles.errorContainer}>
          <Text style={styles.errorText}>Error: {error}</Text>
          <Button mode="contained" onPress={onRefresh} style={styles.retryButton}>
            Retry
          </Button>
        </View>
      ) : (
        <ScrollView
          refreshControl={<RefreshControl refreshing={refreshing} onRefresh={onRefresh} />}
          contentContainerStyle={styles.scrollContent}
        >
          {/* Portfolio Summary */}
          {portfolio && (
            <Card style={styles.summaryCard} mode="elevated">
              <Card.Title
                title="Portfolio Summary"
                titleStyle={styles.summaryTitle}
                left={(props) => <IconButton {...props} icon="briefcase" />}
              />
              <Card.Content>
                <View style={styles.summaryRow}>
                  <Text style={styles.summaryLabel}>Wallet Address:</Text>
                  <Text style={styles.summaryValue}>
                    {portfolio.user_address?.substring(0, 10)}...
                  </Text>
                </View>
                {portfolio.display_name && (
                  <View style={styles.summaryRow}>
                    <Text style={styles.summaryLabel}>Display Name:</Text>
                    <Text style={styles.summaryValue}>{portfolio.display_name}</Text>
                  </View>
                )}
                {portfolio.role && (
                  <View style={styles.summaryRow}>
                    <Text style={styles.summaryLabel}>Role:</Text>
                    <Chip mode="outlined" style={styles.roleChip}>
                      {portfolio.role}
                    </Chip>
                  </View>
                )}
                <View style={styles.summaryRow}>
                  <Text style={styles.summaryLabel}>Total Holdings:</Text>
                  <Text style={[styles.summaryValue, styles.summaryHighlight]}>
                    {portfolio.total_agreements || 0} Agreement{portfolio.total_agreements !== 1 ? 's' : ''}
                  </Text>
                </View>
              </Card.Content>
            </Card>
          )}

          {/* Holdings List */}
          {portfolio && portfolio.holdings && portfolio.holdings.length > 0 ? (
            <>
              <Text style={styles.holdingsTitle}>Holdings</Text>
              <FlatList
                data={portfolio.holdings}
                renderItem={renderHolding}
                keyExtractor={(item) => `${item.agreement_id}`}
                scrollEnabled={false}
              />
            </>
          ) : (
            <View style={styles.emptyHoldingsContainer}>
              <Text style={styles.emptyHoldingsText}>No holdings found</Text>
              <Text style={styles.emptyHoldingsSubtext}>
                This user doesn't own any yield shares yet
              </Text>
            </View>
          )}
        </ScrollView>
      )}

      {/* Manual Refresh Button */}
      {currentProfile && !loading && (
        <Button
          mode="outlined"
          onPress={onRefresh}
          icon="refresh"
          style={styles.refreshButton}
        >
          Refresh
        </Button>
      )}
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#f5f5f5',
  },
  profileSection: {
    backgroundColor: '#fff',
    padding: 16,
    elevation: 2,
    borderBottomWidth: 1,
    borderBottomColor: '#e0e0e0',
  },
  centerContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  loadingText: {
    marginTop: 16,
    fontSize: 16,
    color: '#757575',
  },
  emptyContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    padding: 32,
  },
  emptyText: {
    fontSize: 18,
    fontWeight: '600',
    color: '#757575',
    marginBottom: 8,
    textAlign: 'center',
  },
  emptySubtext: {
    fontSize: 14,
    color: '#9E9E9E',
    textAlign: 'center',
  },
  errorContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    padding: 32,
  },
  errorText: {
    fontSize: 16,
    color: '#F44336',
    marginBottom: 16,
    textAlign: 'center',
  },
  retryButton: {
    marginTop: 8,
  },
  scrollContent: {
    padding: 16,
    paddingBottom: 80, // Space for refresh button
  },
  summaryCard: {
    marginBottom: 16,
  },
  summaryTitle: {
    fontSize: 18,
    fontWeight: 'bold',
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
    fontWeight: '500',
  },
  summaryHighlight: {
    fontSize: 16,
    fontWeight: 'bold',
    color: '#6200ee',
  },
  roleChip: {
    height: 28,
  },
  holdingsTitle: {
    fontSize: 20,
    fontWeight: 'bold',
    marginBottom: 12,
    color: '#212121',
  },
  holdingCard: {
    marginBottom: 16,
  },
  holdingHeader: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    marginBottom: 8,
  },
  agreementChip: {
    marginRight: 8,
    marginBottom: 4,
  },
  propertyChip: {
    marginBottom: 4,
  },
  agreementName: {
    fontSize: 16,
    fontWeight: '600',
    marginBottom: 12,
    color: '#212121',
  },
  balanceContainer: {
    backgroundColor: '#F5F5F5',
    padding: 12,
    borderRadius: 8,
    marginBottom: 12,
  },
  balanceRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 8,
  },
  balanceLabel: {
    fontSize: 14,
    color: '#616161',
  },
  balanceValue: {
    fontSize: 14,
    fontWeight: '600',
    color: '#212121',
  },
  ownershipValue: {
    fontSize: 16,
    color: '#6200ee',
  },
  infoRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 8,
  },
  infoLabel: {
    fontSize: 14,
    color: '#757575',
  },
  tokenChip: {
    height: 28,
  },
  lastUpdated: {
    fontSize: 12,
    color: '#9E9E9E',
    marginTop: 8,
  },
  actions: {
    justifyContent: 'flex-end',
    paddingHorizontal: 8,
    paddingBottom: 8,
  },
  emptyHoldingsContainer: {
    padding: 32,
    alignItems: 'center',
  },
  emptyHoldingsText: {
    fontSize: 16,
    fontWeight: '600',
    color: '#757575',
    marginBottom: 8,
    textAlign: 'center',
  },
  emptyHoldingsSubtext: {
    fontSize: 14,
    color: '#9E9E9E',
    textAlign: 'center',
  },
  refreshButton: {
    position: 'absolute',
    bottom: 16,
    right: 16,
    left: 16,
    elevation: 2,
    backgroundColor: '#fff',
  },
});

export default PortfolioScreen;

