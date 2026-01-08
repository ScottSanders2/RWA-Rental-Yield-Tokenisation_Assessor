import React from 'react';
import {View, ScrollView, StyleSheet, Dimensions} from 'react-native';
import {Text, Card, ActivityIndicator} from 'react-native-paper';
import {useQuery} from '@apollo/client';
import {GET_ANALYTICS_SUMMARY} from '../graphql/queries';
import {useEthPrice} from '../context/PriceContext.native';
import {formatWeiToUsd, formatWeiToEth} from '../utils/formatters';

export default function Analytics() {
  const {ethUsdPrice} = useEthPrice();
  const {data, loading, error} = useQuery(GET_ANALYTICS_SUMMARY, {
    pollInterval: 30000, // Refresh every 30 seconds
  });

  if (loading) {
    return (
      <View style={styles.centerContainer}>
        <ActivityIndicator size="large" />
        <Text style={styles.loadingText}>Loading analytics...</Text>
      </View>
    );
  }

  if (error) {
    return (
      <View style={styles.centerContainer}>
        <Text style={styles.errorText}>Error loading analytics</Text>
        <Text style={styles.errorDetail}>{error.message}</Text>
      </View>
    );
  }

  const summary = data?.analyticsSummary;

  if (!summary) {
    return (
      <View style={styles.centerContainer}>
        <Text style={styles.errorText}>No analytics data available</Text>
      </View>
    );
  }

  return (
    <ScrollView 
      testID="analytics_screen"
      style={styles.container}
      showsVerticalScrollIndicator={true}>
      <Text variant="headlineMedium" style={styles.title}>
        Platform Analytics
      </Text>

      <View style={styles.cardsContainer}>
        {/* Total Capital Deployed */}
        <Card style={styles.card} testID="total_capital_card">
          <Card.Content>
            <Text variant="labelMedium" style={styles.cardLabel}>
              Total Capital Deployed
            </Text>
            <Text variant="headlineMedium" style={styles.cardValue}>
              {formatWeiToUsd(summary.totalCapitalDeployed, ethUsdPrice)}
            </Text>
            <Text variant="bodySmall" style={styles.cardSecondary}>
              ≈ {formatWeiToEth(summary.totalCapitalDeployed)} ETH
            </Text>
          </Card.Content>
        </Card>

        {/* Active Agreements */}
        <Card style={styles.card} testID="active_agreements_card">
          <Card.Content>
            <Text variant="labelMedium" style={styles.cardLabel}>
              Active Agreements
            </Text>
            <Text variant="headlineMedium" style={styles.cardValue}>
              {summary.activeAgreements}
            </Text>
            <Text variant="bodySmall" style={styles.cardSecondary}>
              of {summary.totalAgreements} total
            </Text>
          </Card.Content>
        </Card>

        {/* Total Shareholders */}
        <Card style={styles.card} testID="total_shareholders_card">
          <Card.Content>
            <Text variant="labelMedium" style={styles.cardLabel}>
              Total Shareholders
            </Text>
            <Text variant="headlineMedium" style={styles.cardValue}>
              {summary.totalShareholders}
            </Text>
            <Text variant="bodySmall" style={styles.cardSecondary}>
              Unique investors
            </Text>
          </Card.Content>
        </Card>

        {/* Platform Average ROI */}
        <Card style={styles.card} testID="platform_roi_card">
          <Card.Content>
            <Text variant="labelMedium" style={styles.cardLabel}>
              Platform Avg ROI
            </Text>
            <Text variant="headlineMedium" style={styles.cardValue}>
              {summary.averageROIBasisPoints 
                ? `${(summary.averageROIBasisPoints / 100).toFixed(2)}%`
                : 'N/A'}
            </Text>
            <Text variant="bodySmall" style={styles.cardSecondary}>
              Annual return
            </Text>
          </Card.Content>
        </Card>

        {/* Token Standard Comparison */}
        <Card style={styles.wideCard} testID="token_comparison_card">
          <Card.Content>
            <Text variant="titleMedium" style={styles.sectionTitle}>
              Token Standard Comparison
            </Text>
            <View style={styles.comparisonRow}>
              <View style={styles.comparisonItem}>
                <Text variant="labelMedium">ERC-721 + ERC-20</Text>
                <Text variant="headlineSmall" style={styles.comparisonValue}>
                  {summary.erc721AgreementCount}
                </Text>
                <Text variant="bodySmall" style={styles.cardSecondary}>
                  Agreements
                </Text>
              </View>
              <View style={styles.divider} />
              <View style={styles.comparisonItem}>
                <Text variant="labelMedium">ERC-1155</Text>
                <Text variant="headlineSmall" style={styles.comparisonValue}>
                  {summary.erc1155AgreementCount}
                </Text>
                <Text variant="bodySmall" style={styles.cardSecondary}>
                  Agreements
                </Text>
              </View>
            </View>
          </Card.Content>
        </Card>

        {/* Total Repayments */}
        <Card style={styles.wideCard} testID="total_repayments_card">
          <Card.Content>
            <Text variant="labelMedium" style={styles.cardLabel}>
              Total Repayments Distributed
            </Text>
            <Text variant="headlineMedium" style={styles.cardValue}>
              {formatWeiToUsd(summary.totalRepaymentsDistributed, ethUsdPrice)}
            </Text>
            <Text variant="bodySmall" style={styles.cardSecondary}>
              ≈ {formatWeiToEth(summary.totalRepaymentsDistributed)} ETH
            </Text>
          </Card.Content>
        </Card>

        {/* Governance Stats */}
        {summary.totalGovernanceProposals > 0 && (
          <Card style={styles.wideCard} testID="governance_stats_card">
            <Card.Content>
              <Text variant="titleMedium" style={styles.sectionTitle}>
                Governance Activity
              </Text>
              <View style={styles.comparisonRow}>
                <View style={styles.comparisonItem}>
                  <Text variant="labelMedium">Proposals</Text>
                  <Text variant="headlineSmall" style={styles.comparisonValue}>
                    {summary.totalGovernanceProposals}
                  </Text>
                </View>
                <View style={styles.divider} />
                <View style={styles.comparisonItem}>
                  <Text variant="labelMedium">Votes Cast</Text>
                  <Text variant="headlineSmall" style={styles.comparisonValue}>
                    {summary.totalVotesCast}
                  </Text>
                </View>
              </View>
            </Card.Content>
          </Card>
        )}
      </View>

      <Text variant="bodySmall" style={styles.lastUpdated}>
        Last updated: {new Date(Number(summary.lastUpdated) * 1000).toLocaleString()}
      </Text>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#f5f5f5',
  },
  centerContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    padding: 20,
  },
  loadingText: {
    marginTop: 16,
    fontSize: 16,
    color: '#666',
  },
  errorText: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#d32f2f',
    marginBottom: 8,
  },
  errorDetail: {
    fontSize: 14,
    color: '#666',
    textAlign: 'center',
  },
  title: {
    paddingHorizontal: 16,
    paddingTop: 16,
    paddingBottom: 8,
    fontWeight: 'bold',
  },
  cardsContainer: {
    padding: 16,
    paddingTop: 8,
  },
  card: {
    marginBottom: 16,
    elevation: 2,
  },
  wideCard: {
    marginBottom: 16,
    elevation: 2,
  },
  cardLabel: {
    color: '#666',
    marginBottom: 8,
  },
  cardValue: {
    fontWeight: 'bold',
    marginBottom: 4,
  },
  cardSecondary: {
    color: '#999',
  },
  sectionTitle: {
    fontWeight: 'bold',
    marginBottom: 16,
  },
  comparisonRow: {
    flexDirection: 'row',
    justifyContent: 'space-around',
    alignItems: 'center',
  },
  comparisonItem: {
    flex: 1,
    alignItems: 'center',
  },
  comparisonValue: {
    fontWeight: 'bold',
    marginVertical: 8,
  },
  divider: {
    width: 1,
    height: 60,
    backgroundColor: '#e0e0e0',
    marginHorizontal: 16,
  },
  lastUpdated: {
    textAlign: 'center',
    color: '#999',
    paddingVertical: 16,
  },
});

