import React from 'react';
import {View, ScrollView, StyleSheet} from 'react-native';
import {Text, Card, Button, Chip, Banner} from 'react-native-paper';
import {useNavigation} from '@react-navigation/native';
import {useTokenStandard} from '../context/TokenStandardContext.native';
import {useEthPrice} from '../context/PriceContext.native';
import {useWallet} from '../context/WalletContext';
import {ENVIRONMENT} from '../services/apiClient.native';

export default function Dashboard() {
  const navigation = useNavigation();
  const {tokenStandard, setTokenStandard, getLabel, getDescription} = useTokenStandard();
  const {ethUsdPrice, isUsingFallback} = useEthPrice();
  const {connected, account, connectWallet, error, connecting, mockMode, enableMockMode, disableMockMode} = useWallet();

  const formatAddress = (address) => {
    if (!address) return '';
    return `${address.slice(0, 6)}...${address.slice(-4)}`;
  };

  // Get environment name for display
  const getEnvironmentName = () => {
    const env = ENVIRONMENT || 'development';
    return env.charAt(0).toUpperCase() + env.slice(1);
  };

  return (
    <ScrollView 
      testID="dashboard_screen"
      style={styles.container} 
      contentContainerStyle={styles.scrollContent}
      showsVerticalScrollIndicator={true}
      scrollEnabled={true}
      nestedScrollEnabled={true}>
      <Text variant="headlineLarge" style={styles.title}>
        RWA Tokenisation Platform - {getEnvironmentName()}
      </Text>
      <Text variant="titleMedium" style={styles.subtitle}>
        Real Estate Rental Yield Tokenisation for Financial Inclusion
      </Text>

        {!connected && (
          <Banner visible={!connected} style={styles.banner}>
            <View style={styles.bannerContent}>
              <Text variant="bodyMedium" style={styles.bannerText}>
                Connect your wallet to get started
              </Text>
              <View style={styles.buttonRow}>
                <Button 
                  testID="connect_wallet_button"
                  mode="contained" 
                  onPress={connectWallet} 
                  loading={connecting}
                  disabled={connecting}
                  style={[styles.bannerButton, styles.primaryButton]}>
                  {connecting ? 'Connecting...' : 'Connect Wallet'}
                </Button>
                {!mockMode && (
                  <Button 
                    testID="enable_mock_mode_button"
                    mode="outlined" 
                    onPress={enableMockMode} 
                    disabled={connecting}
                    style={[styles.bannerButton, styles.mockButton]}>
                    Enable Mock (Simulator)
                  </Button>
                )}
                {mockMode && (
                  <Button 
                    testID="disable_mock_mode_button"
                    mode="text" 
                    onPress={disableMockMode} 
                    disabled={connecting}
                    style={styles.mockButton}>
                    Disable Mock
                  </Button>
                )}
              </View>
              {mockMode && (
                <Text testID="mock_mode_text" variant="bodySmall" style={styles.mockText}>
                  Mock mode: Wallet will connect without real app
                </Text>
              )}
            </View>
          </Banner>
        )}

      {connected && (
        <Banner 
          testID="wallet_connected_banner"
          visible={connected} 
          style={[styles.banner, styles.connectedBanner]}>
          <Text testID="account_address_text">Connected: {formatAddress(account)}</Text>
          <Chip icon="wallet" style={styles.chip}>
            Connected
          </Chip>
        </Banner>
      )}

      {error && !connected && (
        <Banner 
          testID="connection_error_message"
          visible={!!error} 
          style={[styles.banner, styles.errorBanner]}>
          <Text>{error}</Text>
          <Button 
            testID="retry_connect_button"
            mode="outlined" 
            onPress={connectWallet}
            style={styles.bannerButton}>
            Retry Connection
          </Button>
        </Banner>
      )}

      {/* Token Standard Selection */}
      <Card style={styles.card}>
        <Card.Content>
          <Text variant="titleMedium" style={styles.cardTitle}>
            Select Token Standard
          </Text>
          <Text variant="bodySmall" style={styles.cardSubtitle}>
            Choose the blockchain token standard for your property
          </Text>
          
          <View style={styles.standardButtons}>
            <Button
              mode={tokenStandard === 'ERC1155' ? 'contained' : 'outlined'}
              onPress={() => setTokenStandard('ERC1155')}
              style={styles.standardButton}>
              ERC-1155
            </Button>
            <Button
              mode={tokenStandard === 'HYBRID' ? 'contained' : 'outlined'}
              onPress={() => setTokenStandard('HYBRID')}
              style={styles.standardButton}>
              ERC-721 + 20
            </Button>
          </View>
          
          <Text variant="bodySmall" style={styles.standardDescription}>
            {getDescription()}
          </Text>
        </Card.Content>
      </Card>

      <Chip
        icon={isUsingFallback ? 'wifi-off' : 'wifi'}
        style={[styles.chip, isUsingFallback && styles.fallbackChip]}
        textStyle={styles.chipText}>
        ETH: ${ethUsdPrice.toFixed(2)}
      </Chip>

      <Card style={styles.card}>
        <Card.Content>
          <Text variant="titleLarge" style={styles.cardTitle}>
            Welcome
          </Text>
          <Text variant="bodyMedium" style={styles.cardText}>
            This platform enables property owners to tokenise their rental yields and access
            upfront capital while maintaining ownership of their property.
          </Text>
        </Card.Content>
      </Card>

      <Card style={styles.card}>
        <Card.Content>
          <Text variant="titleMedium" style={styles.cardTitle}>
            Getting Started
          </Text>
          <Text variant="bodyMedium" style={styles.cardText}>
            1. Register your property{'\n'}
            2. Create a yield agreement{'\n'}
            3. Receive upfront capital{'\n'}
            4. Pay monthly installments
          </Text>
          <Button
            mode="contained"
            onPress={() => navigation.navigate('PropertyRegistration')}
            style={styles.button}>
            Register Property
          </Button>
        </Card.Content>
      </Card>

      <Card style={styles.card}>
        <Card.Content>
          <Text variant="titleMedium" style={styles.cardTitle}>
            Key Features
          </Text>
          <Text variant="bodyMedium" style={styles.cardText}>
            • Property ownership tokenisation{'\n'}
            • Rental yield-backed financing{'\n'}
            • Transparent blockchain records{'\n'}
            • Decentralised marketplace{'\n'}
            • Financial inclusion for property owners
          </Text>
        </Card.Content>
      </Card>

      <Card style={styles.card}>
        <Card.Content>
          <Text variant="titleMedium" style={styles.cardTitle}>
            Quick Actions
          </Text>
          <Button
            mode="outlined"
            onPress={() => navigation.navigate('Properties')}
            style={styles.button}>
            View Properties
          </Button>
          <Button
            mode="outlined"
            onPress={() => navigation.navigate('Agreements')}
            style={styles.button}>
            View Agreements
          </Button>
        </Card.Content>
      </Card>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#f5f5f5',
  },
  scrollContent: {
    padding: 16,
    paddingBottom: 32,
  },
  title: {
    textAlign: 'center',
    marginBottom: 8,
    color: '#1976d2',
    fontWeight: 'bold',
  },
  subtitle: {
    textAlign: 'center',
    marginBottom: 16,
    color: '#666',
  },
  banner: {
    marginBottom: 16,
  },
  bannerContent: {
    alignItems: 'center',
    paddingVertical: 8,
  },
  bannerText: {
    textAlign: 'center',
    marginBottom: 12,
  },
  buttonRow: {
    flexDirection: 'row',
    gap: 8,
    marginTop: 8,
    flexWrap: 'wrap',
  },
  bannerButton: {
    flex: 1,
    minWidth: 120,
  },
  primaryButton: {
    flex: 2,
  },
  mockButton: {
    flex: 1,
  },
  mockText: {
    marginTop: 8,
    fontStyle: 'italic',
    opacity: 0.7,
  },
  connectedBanner: {
    backgroundColor: '#e8f5e9',
  },
  chip: {
    marginVertical: 8,
    alignSelf: 'flex-start',
  },
  standardChip: {
    backgroundColor: '#f3e5f5',
  },
  fallbackChip: {
    backgroundColor: '#ffebee',
  },
  chipText: {
    fontSize: 12,
  },
  card: {
    marginBottom: 16,
    elevation: 2,
  },
  cardTitle: {
    marginBottom: 12,
    fontWeight: 'bold',
  },
  cardSubtitle: {
    marginBottom: 16,
    color: '#666',
  },
  cardText: {
    marginBottom: 12,
    lineHeight: 24,
  },
  standardButtons: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginBottom: 16,
  },
  standardButton: {
    flex: 1,
    marginHorizontal: 4,
  },
  standardDescription: {
    color: '#666',
    fontStyle: 'italic',
    textAlign: 'center',
  },
  button: {
    marginTop: 12,
  },
  errorBanner: {
    backgroundColor: '#ffebee',
  },
});
// React Native Dashboard with ScrollView enabled for full-screen navigation, UK spelling throughout (Tokenisation), improved banner layout with centered Connect Wallet button, token standard selection via two prominent buttons (ERC-721 and ERC-721+ERC-20) replacing non-functional gear icon, providing clear UX for non-crypto-native users, ETH price indicator with fallback warning, property registration and navigation quick actions, and WalletConnect integration with error handling.
