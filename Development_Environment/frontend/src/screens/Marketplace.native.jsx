import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  FlatList,
  TouchableOpacity,
  StyleSheet,
  RefreshControl,
  ActivityIndicator,
} from 'react-native';
import { Card, Button, Chip, Badge, Searchbar } from 'react-native-paper';
import { useNavigation } from '@react-navigation/native';
import { getListings } from '../services/apiClient.native';
import { useEthPrice } from '../context/PriceContext.native';

const MarketplaceScreen = () => {
  const navigation = useNavigation();
  const { ethUsdPrice, isLoading: ethPriceLoading } = useEthPrice();
  
  const [listings, setListings] = useState([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [searchQuery, setSearchQuery] = useState('');
  const [filterStatus, setFilterStatus] = useState('all'); // all, active, sold

  useEffect(() => {
    loadListings();
  }, []);

  const loadListings = async () => {
    setLoading(true);
    try {
      const data = await getListings();
      setListings(data || []);
    } catch (error) {
      console.error('Failed to load marketplace listings:', error);
    } finally {
      setLoading(false);
    }
  };

  const onRefresh = async () => {
    setRefreshing(true);
    await loadListings();
    setRefreshing(false);
  };

  const calculateEthValue = (usdValue) => {
    if (!ethUsdPrice || ethUsdPrice === 0) return 0;
    return (usdValue / ethUsdPrice).toFixed(6);
  };

  const getStatusColor = (status) => {
    switch (status?.toUpperCase()) {
      case 'ACTIVE':
        return '#4CAF50';
      case 'SOLD':
        return '#9E9E9E';
      case 'CANCELLED':
        return '#F44336';
      default:
        return '#757575';
    }
  };

  const getListingType = (listing) => {
    // Determine if this is a primary offering (direct from property owner)
    // vs secondary market (resale)
    return listing.seller_role === 'Owner' ? 'Primary Offering' : 'Secondary Market';
  };

  const filteredListings = listings.filter((listing) => {
    // Filter by status
    if (filterStatus !== 'all' && listing.listing_status?.toLowerCase() !== filterStatus) {
      return false;
    }
    
    // Filter by search query
    if (searchQuery) {
      const query = searchQuery.toLowerCase();
      return (
        listing.agreement_id?.toString().includes(query) ||
        listing.seller_display_name?.toLowerCase().includes(query)
      );
    }
    
    return true;
  });

  const renderListingCard = ({ item }) => {
    const sharesForSale = parseFloat(item.shares_for_sale) / 1e18;
    const totalValueUsd = item.total_listing_value_usd || (sharesForSale * item.price_per_share_usd);
    const totalValueEth = calculateEthValue(totalValueUsd);
    const percentageOfTotal = (item.fractional_availability * 100).toFixed(1);
    const listingType = getListingType(item);

    return (
      <Card style={styles.card} mode="elevated">
        <Card.Content>
          {/* Header */}
          <View style={styles.header}>
            <Text style={styles.agreementId}>Agreement #{item.agreement_id}</Text>
            <Badge
              style={[styles.statusBadge, { backgroundColor: getStatusColor(item.listing_status) }]}
              size={24}
            >
              {item.listing_status?.toUpperCase()}
            </Badge>
          </View>

          {/* Listing Type */}
          <Chip
            style={[
              styles.listingTypeChip,
              listingType === 'Primary Offering' ? styles.primaryChip : styles.secondaryChip,
            ]}
            textStyle={styles.listingTypeText}
            mode="flat"
          >
            {listingType}
          </Chip>

          {/* Seller Info */}
          <View style={styles.sellerSection}>
            <View style={styles.sellerRow}>
              <Text style={styles.label}>Seller:</Text>
              <Text style={styles.sellerName} numberOfLines={1}>{item.seller_display_name || 'Unknown'}</Text>
            </View>
            {item.seller_role && (
              <Chip style={styles.roleChip} textStyle={styles.roleText} mode="outlined" compact>
                {item.seller_role}
              </Chip>
            )}
          </View>

          {/* Shares for Sale */}
          <View style={styles.infoRow}>
            <Text style={styles.label}>Shares for Sale:</Text>
            <View>
              <Text style={styles.valueHighlight}>
                ${sharesForSale.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
              </Text>
              <Text style={styles.subValue}>({percentageOfTotal}% of total)</Text>
            </View>
          </View>

          {/* Price per Share */}
          <View style={styles.infoRow}>
            <Text style={styles.label}>Price per Share:</Text>
            <View>
              <Text style={styles.valuePrimary}>${item.price_per_share_usd.toFixed(2)} USD</Text>
              <Text style={styles.valueSecondary}>≈ {calculateEthValue(item.price_per_share_usd)} ETH</Text>
            </View>
          </View>

          {/* Total Value */}
          <View style={styles.infoRow}>
            <Text style={styles.label}>Total Value:</Text>
            <View>
              <Text style={styles.valuePrimary}>${totalValueUsd.toLocaleString()} USD</Text>
              <Text style={styles.valueSecondary}>≈ {totalValueEth} ETH</Text>
            </View>
          </View>

          {/* Token Standard */}
          <View style={styles.infoRow}>
            <Text style={styles.label}>Token Standard:</Text>
            <Text style={styles.value}>{item.token_standard || 'N/A'}</Text>
          </View>

          {/* Expiry */}
          {item.expires_at && (
            <View style={styles.infoRow}>
              <Text style={styles.label}>Expires:</Text>
              <Text style={styles.value}>
                {new Date(item.expires_at).toLocaleDateString()}
              </Text>
            </View>
          )}
        </Card.Content>

        <Card.Actions style={styles.actions}>
          <Button
            mode="contained"
            onPress={() => navigation.navigate('BuyShares', { listingId: item.id })}
            disabled={item.listing_status?.toUpperCase() !== 'ACTIVE'}
            icon="cart"
            style={styles.buyButton}
          >
            Buy Shares
          </Button>
          <Button
            mode="outlined"
            onPress={() => navigation.navigate('YieldAgreementDetail', { agreementId: item.agreement_id })}
            icon="file-document-outline"
          >
            View Agreement
          </Button>
        </Card.Actions>
      </Card>
    );
  };

  if (loading && !refreshing) {
    return (
      <View style={styles.centerContainer}>
        <ActivityIndicator size="large" color="#6200ee" />
        <Text style={styles.loadingText}>Loading marketplace listings...</Text>
      </View>
    );
  }

  return (
    <View style={styles.container}>
      {/* Search Bar */}
      <Searchbar
        placeholder="Search by agreement ID or seller"
        onChangeText={setSearchQuery}
        value={searchQuery}
        style={styles.searchBar}
      />

      {/* Filter Chips */}
      <View style={styles.filterContainer}>
        <Chip
          selected={filterStatus === 'all'}
          onPress={() => setFilterStatus('all')}
          style={styles.filterChip}
        >
          All
        </Chip>
        <Chip
          selected={filterStatus === 'active'}
          onPress={() => setFilterStatus('active')}
          style={styles.filterChip}
        >
          Active
        </Chip>
        <Chip
          selected={filterStatus === 'sold'}
          onPress={() => setFilterStatus('sold')}
          style={styles.filterChip}
        >
          Sold
        </Chip>
      </View>

      {/* Listings */}
      {filteredListings.length === 0 ? (
        <View style={styles.emptyContainer}>
          <Text style={styles.emptyText}>No listings found</Text>
          <Text style={styles.emptySubtext}>
            {searchQuery ? 'Try adjusting your search' : 'Check back later for new listings'}
          </Text>
        </View>
      ) : (
        <FlatList
          data={filteredListings}
          renderItem={renderListingCard}
          keyExtractor={(item) => item.id.toString()}
          refreshControl={<RefreshControl refreshing={refreshing} onRefresh={onRefresh} />}
          contentContainerStyle={styles.listContainer}
        />
      )}

      {/* Create Listing Button */}
      <Button
        mode="contained"
        onPress={() => navigation.navigate('CreateListing')}
        style={styles.createButton}
        icon="plus"
      >
        Create Listing
      </Button>
    </View>
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
  },
  loadingText: {
    marginTop: 16,
    fontSize: 16,
    color: '#757575',
  },
  searchBar: {
    margin: 16,
    elevation: 2,
  },
  filterContainer: {
    flexDirection: 'row',
    paddingHorizontal: 16,
    paddingBottom: 8,
  },
  filterChip: {
    marginRight: 8,
  },
  listContainer: {
    padding: 16,
    paddingBottom: 100, // Space for create button
  },
  card: {
    marginBottom: 16,
  },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 12,
  },
  agreementId: {
    fontSize: 20,
    fontWeight: 'bold',
    color: '#6200ee',
  },
  statusBadge: {
    fontSize: 12,
  },
  listingTypeChip: {
    alignSelf: 'flex-start',
    marginBottom: 12,
  },
  primaryChip: {
    backgroundColor: '#E3F2FD',
  },
  secondaryChip: {
    backgroundColor: '#FFF3E0',
  },
  listingTypeText: {
    fontSize: 12,
    fontWeight: '600',
  },
  sellerSection: {
    marginBottom: 12,
  },
  sellerRow: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 4,
  },
  sellerName: {
    fontSize: 16,
    fontWeight: '600',
    marginLeft: 8,
    flex: 1,
  },
  roleChip: {
    marginTop: 4,
    alignSelf: 'flex-start',
    height: 28,
  },
  roleText: {
    fontSize: 11,
  },
  infoRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'flex-start',
    marginBottom: 8,
  },
  label: {
    fontSize: 14,
    color: '#757575',
  },
  value: {
    fontSize: 14,
    fontWeight: '500',
    textAlign: 'right',
  },
  valueHighlight: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#6200ee',
    textAlign: 'right',
  },
  subValue: {
    fontSize: 12,
    color: '#757575',
    textAlign: 'right',
  },
  valuePrimary: {
    fontSize: 16,
    fontWeight: '600',
    textAlign: 'right',
  },
  valueSecondary: {
    fontSize: 12,
    color: '#757575',
    textAlign: 'right',
  },
  actions: {
    justifyContent: 'flex-end',
    paddingHorizontal: 8,
    paddingBottom: 8,
  },
  buyButton: {
    marginRight: 8,
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
  },
  emptySubtext: {
    fontSize: 14,
    color: '#9E9E9E',
    textAlign: 'center',
  },
  createButton: {
    position: 'absolute',
    bottom: 16,
    right: 16,
    elevation: 4,
  },
});

export default MarketplaceScreen;

