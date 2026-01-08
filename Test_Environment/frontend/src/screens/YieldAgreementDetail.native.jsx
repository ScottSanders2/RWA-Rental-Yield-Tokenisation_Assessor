import React, { useState, useEffect } from 'react';
import { View, StyleSheet, ScrollView, ActivityIndicator, Alert } from 'react-native';
import { Text, Card, Button, Chip, Divider } from 'react-native-paper';
import { useRoute, useNavigation } from '@react-navigation/native';
import { getYieldAgreement } from '../services/apiClient.native';
import { formatWeiToUsd, formatWeiToEth, formatDualCurrency } from '../utils/formatters';
import { useEthPrice } from '../context/PriceContext.native';

const YieldAgreementDetail = () => {
  const route = useRoute();
  const navigation = useNavigation();
  const { agreementId } = route.params || {};
  const { ethUsdPrice } = useEthPrice();

  const [agreement, setAgreement] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    if (agreementId) {
      fetchAgreement();
    }
  }, [agreementId]);

  const fetchAgreement = async () => {
    try {
      setLoading(true);
      setError(null);
      const result = await getYieldAgreement(agreementId);
      setAgreement(result.data);
    } catch (err) {
      console.error('Error fetching yield agreement:', err);
      setError(err.message || 'Failed to load yield agreement');
      Alert.alert('Error', 'Failed to load yield agreement details');
    } finally {
      setLoading(false);
    }
  };

  const getStatusColor = (status) => {
    switch (status?.toLowerCase()) {
      case 'active':
        return '#4CAF50';
      case 'pending':
        return '#FF9800';
      case 'completed':
        return '#2196F3';
      case 'cancelled':
        return '#F44336';
      default:
        return '#9E9E9E';
    }
  };

  const formatTimestamp = (timestamp) => {
    if (!timestamp) return 'N/A';
    try {
      // Ensure UTC handling
      const date = new Date(timestamp.endsWith('Z') ? timestamp : timestamp + 'Z');
      return date.toLocaleString();
    } catch (e) {
      return 'Invalid Date';
    }
  };

  if (loading) {
    return (
      <View style={styles.centerContainer}>
        <ActivityIndicator size="large" color="#6200ee" />
        <Text style={styles.loadingText}>Loading agreement details...</Text>
      </View>
    );
  }

  if (error || !agreement) {
    return (
      <View style={styles.centerContainer}>
        <Text style={styles.errorText}>{error || 'Agreement not found'}</Text>
        <Button mode="contained" onPress={() => navigation.goBack()} style={styles.backButton}>
          Go Back
        </Button>
      </View>
    );
  }

  return (
    <ScrollView
      style={styles.container}
      contentContainerStyle={styles.scrollContent}
      showsVerticalScrollIndicator={true}
    >
      {/* Header Card */}
      <Card style={styles.card} mode="elevated">
        <Card.Title
          title={`Agreement #${agreement.id}`}
          subtitle={`Property #${agreement.property_id}`}
        />
        <Card.Content>
          <Chip
            style={{ backgroundColor: getStatusColor(agreement.is_active ? 'active' : 'inactive'), alignSelf: 'flex-start' }}
            textStyle={{ color: '#fff' }}
          >
            {agreement.is_active ? 'ACTIVE' : 'INACTIVE'}
          </Chip>
        </Card.Content>
      </Card>

      {/* Financial Summary */}
      <Card style={styles.card} mode="elevated">
        <Card.Title title="Financial Summary" />
        <Card.Content>
          <View style={styles.row}>
            <Text style={styles.label}>Total Token Supply:</Text>
            <Text style={styles.valuePrimary}>
              {agreement.total_token_supply?.toLocaleString() || 0} tokens
            </Text>
          </View>
          <View style={styles.row}>
            <Text style={styles.label}>Upfront Capital:</Text>
            <Text style={styles.valuePrimary}>
              ${agreement.upfront_capital_usd?.toLocaleString() || 0} USD
            </Text>
          </View>
          <View style={styles.row}>
            <Text style={styles.label}>Annual ROI:</Text>
            <Text style={styles.valuePrimary}>
              {((agreement.annual_roi_basis_points || 0) / 100).toFixed(2)}%
            </Text>
          </View>
          <View style={styles.row}>
            <Text style={styles.label}>Monthly Payment:</Text>
            <Text style={styles.valuePrimary}>
              ${((agreement.upfront_capital_usd / agreement.repayment_term_months) + ((agreement.upfront_capital_usd * (agreement.annual_roi_basis_points || 0) / 100) / 100 / 12)).toFixed(2)} USD
            </Text>
          </View>
          <View style={styles.row}>
            <Text style={styles.label}>Total Repayment:</Text>
            <Text style={styles.valuePrimary}>
              ${(agreement.upfront_capital_usd + ((agreement.upfront_capital_usd * (agreement.annual_roi_basis_points || 0) / 100) / 100)).toFixed(2)} USD
            </Text>
          </View>
        </Card.Content>
      </Card>

      {/* Token Information */}
      <Card style={styles.card} mode="elevated">
        <Card.Title title="Token Information" />
        <Card.Content>
          <View style={styles.row}>
            <Text style={styles.label}>Token Standard:</Text>
            <Chip mode="outlined" compact>
              {agreement.token_standard === 'ERC721' ? 'ERC-721 + ERC-20' : agreement.token_standard}
            </Chip>
          </View>
          <View style={styles.row}>
            <Text style={styles.label}>Property Token ID:</Text>
            <Text style={styles.value}>{agreement.property_token_id || 'N/A'}</Text>
          </View>
          <View style={styles.row}>
            <Text style={styles.label}>Yield Token Address:</Text>
            <Text style={styles.valueSmall} numberOfLines={1} ellipsizeMode="middle">
              {agreement.yield_token_address || 'Not deployed'}
            </Text>
          </View>
        </Card.Content>
      </Card>

      {/* Governance & Reserve */}
      <Card style={styles.card} mode="elevated">
        <Card.Title title="Governance & Reserve" />
        <Card.Content>
          <View style={styles.row}>
            <Text style={styles.label}>Governance Enabled:</Text>
            <Chip mode="outlined" compact>
              {agreement.governance_enabled ? 'Yes' : 'No'}
            </Chip>
          </View>
          {agreement.governance_enabled && (
            <>
              <View style={styles.row}>
                <Text style={styles.label}>Quorum Percentage:</Text>
                <Text style={styles.value}>{agreement.quorum_percentage || 0}%</Text>
              </View>
              <View style={styles.row}>
                <Text style={styles.label}>Voting Period:</Text>
                <Text style={styles.value}>{agreement.voting_period_days || 0} days</Text>
              </View>
            </>
          )}
          <View style={styles.row}>
            <Text style={styles.label}>Reserve Pool:</Text>
            <Text style={styles.value}>${(agreement.reserve_pool_balance / 1e18 || 0).toFixed(2)} USD</Text>
          </View>
        </Card.Content>
      </Card>

      {/* Timestamps */}
      <Card style={styles.card} mode="elevated">
        <Card.Title title="Timeline" />
        <Card.Content>
          <View style={styles.row}>
            <Text style={styles.label}>Created:</Text>
            <Text style={styles.value}>{formatTimestamp(agreement.created_at)}</Text>
          </View>
          <View style={styles.row}>
            <Text style={styles.label}>Last Updated:</Text>
            <Text style={styles.value}>{formatTimestamp(agreement.updated_at)}</Text>
          </View>
        </Card.Content>
      </Card>

      {/* Action Buttons */}
      <Card style={styles.card} mode="elevated">
        <Card.Content>
          <Button
            mode="contained"
            onPress={() => navigation.navigate('GovernanceCreate', { agreementId: agreement.id })}
            style={styles.actionButton}
            disabled={!agreement.governance_enabled}
            icon="vote"
          >
            Create Governance Proposal
          </Button>
          <Button
            mode="outlined"
            onPress={() => navigation.goBack()}
            style={styles.actionButton}
            icon="arrow-left"
          >
            Back
          </Button>
        </Card.Content>
      </Card>
    </ScrollView>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#f5f5f5',
  },
  scrollContent: {
    padding: 16,
    paddingBottom: 32,
  },
  centerContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    padding: 32,
  },
  loadingText: {
    marginTop: 16,
    fontSize: 16,
    color: '#757575',
  },
  errorText: {
    fontSize: 16,
    color: '#F44336',
    marginBottom: 16,
    textAlign: 'center',
  },
  backButton: {
    marginTop: 16,
  },
  card: {
    marginBottom: 16,
  },
  row: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 12,
  },
  label: {
    fontSize: 14,
    color: '#757575',
    flex: 1,
  },
  value: {
    fontSize: 14,
    fontWeight: '500',
    color: '#212121',
    flex: 1,
    textAlign: 'right',
  },
  valuePrimary: {
    fontSize: 16,
    fontWeight: '600',
    color: '#6200ee',
    flex: 1,
    textAlign: 'right',
  },
  valueSmall: {
    fontSize: 12,
    fontWeight: '500',
    color: '#212121',
    flex: 1,
    textAlign: 'right',
  },
  actionButton: {
    marginTop: 12,
  },
});

export default YieldAgreementDetail;
