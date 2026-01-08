import React, {useState, useEffect} from 'react';
import {View, StyleSheet, FlatList, TouchableOpacity, ActivityIndicator} from 'react-native';
import {Text, Card, Button, FAB, Chip, Banner} from 'react-native-paper';
import {useNavigation, useFocusEffect} from '@react-navigation/native';
import {getProperties} from '../services/apiClient.native';

const PropertiesList = () => {
  const navigation = useNavigation();
  const [properties, setProperties] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  // Fetch properties when screen comes into focus (auto-refresh)
  useFocusEffect(
    React.useCallback(() => {
      fetchProperties();
    }, [])
  );

  const fetchProperties = async () => {
    try {
      setLoading(true);
      setError(null);
      const result = await getProperties();
      setProperties(result.data || []);
    } catch (err) {
      setError(err.message || 'Failed to load properties');
      console.error('Error fetching properties:', err);
    } finally {
      setLoading(false);
    }
  };

  const getStatusColor = (status) => {
    switch (status) {
      case 'tokenized': return 'green';
      case 'registered': return 'orange';
      case 'tokenizing': return 'blue';
      default: return 'gray';
    }
  };

  const renderProperty = ({item}) => {
    // Parse metadata if it's a JSON string
    let metadata = {};
    if (item.metadata_json) {
      try {
        metadata = typeof item.metadata_json === 'string' 
          ? JSON.parse(item.metadata_json) 
          : item.metadata_json;
      } catch (e) {
        console.error('Error parsing metadata:', e);
      }
    }

    // Handle property address - use hash as fallback if address not available
    const displayAddress = item.property_address || `Hash: ${item.property_address_hash?.substring(0, 10)}...` || 'Address not available';
    
    // Ensure all values are strings or numbers for safe rendering
    const safeId = String(item.id || 'N/A');
    const safeTokenId = String(item.blockchain_token_id || 'Pending');
    const safeTokenStandard = String(item.token_standard?.toUpperCase() || 'ERC721');
    const safePropertyType = String(metadata.propertyType || '');
    const safeBedrooms = String(metadata.bedrooms || '');

    return (
      <TouchableOpacity onPress={() => {/* Handle property detail navigation */}}>
        <Card style={styles.card}>
          <Card.Content>
            <View style={styles.header}>
              <Text style={styles.propertyId}>Property ID: {safeId}</Text>
              <Chip style={{backgroundColor: item.is_verified ? 'green' : 'orange'}}>
                {item.is_verified ? 'VERIFIED' : 'PENDING'}
              </Chip>
            </View>

            <Text style={styles.address}>{displayAddress}</Text>

            <View style={styles.details}>
              <View style={styles.detailRow}>
                <Text style={styles.label}>Token ID:</Text>
                <Text style={styles.value}>{safeTokenId}</Text>
              </View>
              <View style={styles.detailRow}>
                <Text style={styles.label}>Token Standard:</Text>
                <Text style={styles.value}>{safeTokenStandard}</Text>
              </View>
              {safePropertyType && (
                <View style={styles.detailRow}>
                  <Text style={styles.label}>Type:</Text>
                  <Text style={styles.value}>{safePropertyType}</Text>
                </View>
              )}
              {safeBedrooms && (
                <View style={styles.detailRow}>
                  <Text style={styles.label}>Bedrooms:</Text>
                  <Text style={styles.value}>{safeBedrooms}</Text>
                </View>
              )}
            </View>
          </Card.Content>
        </Card>
      </TouchableOpacity>
    );
  };

  if (loading) {
    return (
      <View style={[styles.container, styles.centerContent]}>
        <ActivityIndicator size="large" color="#1976d2" />
        <Text style={styles.loadingText}>Loading properties...</Text>
      </View>
    );
  }

  if (error) {
    return (
      <View style={styles.container}>
        <Banner visible={true} style={styles.errorBanner}>
          <Text>{error}</Text>
        </Banner>
        <Button mode="contained" onPress={fetchProperties} style={styles.retryButton}>
          Retry
        </Button>
      </View>
    );
  }

  return (
    <View testID="properties_list_screen" style={styles.container}>
      {properties.length === 0 ? (
        <View style={styles.emptyContainer}>
          <Text style={styles.emptyText}>No properties registered yet</Text>
          <View testID="empty_state_register_container">
            <Button 
              testID="empty_state_register_button"
              mode="contained" 
              onPress={() => navigation.navigate('PropertyRegistration')}
              style={styles.emptyButton}>
              Register First Property
            </Button>
          </View>
        </View>
      ) : (
        <FlatList
          data={properties}
          renderItem={renderProperty}
          keyExtractor={(item) => item.id.toString()}
          contentContainerStyle={styles.listContainer}
          onRefresh={fetchProperties}
          refreshing={loading}
        />
      )}

      <FAB
        testID="register_property_button"
        icon="plus"
        style={styles.fab}
        onPress={() => navigation.navigate('PropertyRegistration')}
        label="Register Property"
      />
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#f5f5f5',
  },
  centerContent: {
    justifyContent: 'center',
    alignItems: 'center',
  },
  loadingText: {
    marginTop: 16,
    fontSize: 16,
    color: '#666',
  },
  errorBanner: {
    backgroundColor: '#ffebee',
    margin: 16,
  },
  retryButton: {
    margin: 16,
  },
  emptyContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    padding: 32,
  },
  emptyText: {
    fontSize: 18,
    color: '#666',
    marginBottom: 24,
    textAlign: 'center',
  },
  emptyButton: {
    marginTop: 8,
  },
  listContainer: {
    padding: 16,
    paddingBottom: 100, // Space for FAB
  },
  card: {
    marginBottom: 12,
  },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 8,
  },
  propertyId: {
    fontSize: 16,
    fontWeight: 'bold',
    color: '#333',
  },
  address: {
    fontSize: 16,
    color: '#666',
    marginBottom: 12,
  },
  details: {
    backgroundColor: '#f9f9f9',
    padding: 12,
    borderRadius: 8,
  },
  detailRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginBottom: 4,
  },
  label: {
    fontSize: 14,
    color: '#666',
  },
  value: {
    fontSize: 14,
    fontWeight: 'bold',
    color: '#333',
  },
  fab: {
    position: 'absolute',
    margin: 16,
    right: 0,
    bottom: 0,
  },
});

export default PropertiesList;
