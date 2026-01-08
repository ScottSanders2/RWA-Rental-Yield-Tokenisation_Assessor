import React, {useState, useEffect} from 'react';
import {View, StyleSheet, FlatList, TouchableOpacity, ActivityIndicator} from 'react-native';
import {Text, Card, Button, FAB, Chip, Banner} from 'react-native-paper';
import {useNavigation, useFocusEffect} from '@react-navigation/native';
import {getYieldAgreements} from '../services/apiClient.native';
import {useEthPrice} from '../context/PriceContext.native';
import {formatWeiToUsd, formatDate} from '../utils/formatters';

const YieldAgreementsList = () => {
  const navigation = useNavigation();
  const {ethUsdPrice} = useEthPrice();
  const [agreements, setAgreements] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  // Fetch agreements when screen comes into focus (auto-refresh)
  useFocusEffect(
    React.useCallback(() => {
      fetchAgreements();
    }, [])
  );

  const fetchAgreements = async () => {
    try {
      setLoading(true);
      setError(null);
      const result = await getYieldAgreements();
      // Sort agreements by ID in descending order (newest first)
      const sortedAgreements = (result.data || []).sort((a, b) => b.id - a.id);
      setAgreements(sortedAgreements);
    } catch (err) {
      setError(err.message || 'Failed to load yield agreements');
      console.error('Error fetching yield agreements:', err);
    } finally {
      setLoading(false);
    }
  };

  const getStatusColor = (status) => {
    switch (status) {
      case 'active': return 'green';
      case 'pending': return 'orange';
      case 'completed': return 'blue';
      case 'cancelled': return 'red';
      default: return 'gray';
    }
  };

  const renderAgreement = ({item}) => {
    // Calculate USD amounts using simple interest formula
    const upfrontCapital = item.upfront_capital_usd || 0;
    // Backend returns basis points (e.g., 1000 = 10%)
    const annualRoiBasisPoints = item.annual_roi_basis_points || 0;
    // Backend returns 'repayment_term_months', not 'term_months'
    const termMonths = item.repayment_term_months || 12;
    
    // Simple interest: Total = Principal × (1 + rate × time)
    // rate = annualRoiBasisPoints / 10000 (convert basis points to decimal)
    // time = termMonths / 12 (convert months to years)
    const annualRate = annualRoiBasisPoints / 10000; // e.g., 1000 basis points = 0.10 = 10%
    const timeInYears = termMonths / 12; // e.g., 24 months = 2 years
    const totalRepayment = upfrontCapital * (1 + annualRate * timeInYears);
    const monthlyPayment = totalRepayment / termMonths;
    
    return (
      <TouchableOpacity onPress={() => {/* Handle agreement detail navigation */}}>
        <Card style={styles.card}>
          <Card.Content>
            <View style={styles.header}>
              <Text style={styles.agreementId}>Agreement #{String(item.id || 'N/A')}</Text>
              <Chip style={{backgroundColor: item.is_active ? 'green' : 'orange'}}>
                {item.is_active ? 'ACTIVE' : 'PENDING'}
              </Chip>
            </View>

            <Text style={styles.propertyAddress}>Property Token ID: {String(item.property_token_id || 'N/A')}</Text>

            <View style={styles.details}>
              <View style={styles.detailRow}>
                <Text style={styles.label}>Upfront Capital:</Text>
                <Text style={styles.value}>${upfrontCapital.toLocaleString()}</Text>
              </View>
              <View style={styles.detailRow}>
                <Text style={styles.label}>Annual ROI:</Text>
                <Text style={styles.value}>{(annualRoiBasisPoints / 100).toFixed(2)}%</Text>
              </View>
              <View style={styles.detailRow}>
                <Text style={styles.label}>Term:</Text>
                <Text style={styles.value}>{termMonths} months</Text>
              </View>
              <View style={styles.detailRow}>
                <Text style={styles.label}>Monthly Payment:</Text>
                <Text style={styles.value}>${monthlyPayment.toFixed(2)}</Text>
              </View>
              <View style={styles.detailRow}>
                <Text style={styles.label}>Total Repayment:</Text>
                <Text style={styles.value}>${totalRepayment.toFixed(2)}</Text>
              </View>
            </View>

            {item.created_at && (
              <View style={styles.dateRow}>
                <Text style={styles.dateLabel}>Created:</Text>
                <Text style={styles.dateValue}>
                  {new Date(item.created_at.endsWith('Z') ? item.created_at : item.created_at + 'Z').toLocaleString('en-US', {
                    year: 'numeric',
                    month: 'short',
                    day: 'numeric',
                    hour: '2-digit',
                    minute: '2-digit',
                  })}
                </Text>
              </View>
            )}
          </Card.Content>
        </Card>
      </TouchableOpacity>
    );
  };

  if (loading) {
    return (
      <View style={[styles.container, styles.centerContent]}>
        <ActivityIndicator size="large" color="#1976d2" />
        <Text style={styles.loadingText}>Loading yield agreements...</Text>
      </View>
    );
  }

  if (error) {
    return (
      <View style={styles.container}>
        <Banner visible={true} style={styles.errorBanner}>
          <Text>{error}</Text>
        </Banner>
        <Button mode="contained" onPress={fetchAgreements} style={styles.retryButton}>
          Retry
        </Button>
      </View>
    );
  }

  return (
    <View testID="agreements_list_screen" style={styles.container}>
      {agreements.length === 0 ? (
        <View style={styles.emptyContainer}>
          <Text style={styles.emptyText}>No yield agreements created yet</Text>
          <View testID="empty_state_create_container">
            <Button 
              testID="empty_state_create_button"
              mode="contained" 
              onPress={() => navigation.navigate('YieldAgreementCreation')}
              style={styles.emptyButton}>
              Create First Agreement
            </Button>
          </View>
        </View>
      ) : (
        <FlatList
          data={agreements}
          renderItem={renderAgreement}
          keyExtractor={(item) => item.id.toString()}
          contentContainerStyle={styles.listContainer}
          onRefresh={fetchAgreements}
          refreshing={loading}
        />
      )}

      <FAB
        testID="create_agreement_button"
        icon="plus"
        style={styles.fab}
        onPress={() => navigation.navigate('YieldAgreementCreation')}
        label="Create Agreement"
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
  agreementId: {
    fontSize: 16,
    fontWeight: 'bold',
    color: '#333',
  },
  propertyAddress: {
    fontSize: 14,
    color: '#666',
    marginBottom: 12,
  },
  details: {
    backgroundColor: '#f9f9f9',
    padding: 12,
    borderRadius: 8,
    marginBottom: 8,
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
  dateRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  dateLabel: {
    fontSize: 12,
    color: '#999',
  },
  dateValue: {
    fontSize: 12,
    color: '#999',
  },
  fab: {
    position: 'absolute',
    margin: 16,
    right: 0,
    bottom: 0,
  },
});

export default YieldAgreementsList;
