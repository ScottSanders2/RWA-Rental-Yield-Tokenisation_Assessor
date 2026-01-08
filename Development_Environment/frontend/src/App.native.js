// No polyfills needed for basic app functionality

import React from 'react';
import {NavigationContainer} from '@react-navigation/native';
import {createBottomTabNavigator} from '@react-navigation/bottom-tabs';
import {createStackNavigator} from '@react-navigation/stack';
import {Provider as PaperProvider} from 'react-native-paper';
import Icon from 'react-native-vector-icons/MaterialIcons';

import {TokenStandardProvider} from './context/TokenStandardContext.native';
import {PriceProvider} from './context/PriceContext.native';
import {WalletProvider} from './context/WalletContext';
import theme from './shared/theme.native';

// Import screens
import Dashboard from './screens/Dashboard.native';
import Analytics from './screens/Analytics.native';
import PropertyRegistration from './screens/PropertyRegistration.native';
import YieldAgreementCreation from './screens/YieldAgreementCreation.native';
import YieldAgreementDetail from './screens/YieldAgreementDetail.native';
import PropertiesList from './screens/PropertiesList.native';
import YieldAgreementsList from './screens/YieldAgreementsList.native';
import Governance from './screens/Governance.native';
import GovernanceCreate from './screens/GovernanceCreate.native';
import GovernanceDetail from './screens/GovernanceDetail.native';
import Marketplace from './screens/Marketplace.native';
import Portfolio from './screens/Portfolio.native';
import CreateListing from './screens/CreateListing.native';
import BuyShares from './screens/BuyShares.native';

const Tab = createBottomTabNavigator();
const Stack = createStackNavigator();

function TabNavigator() {
  return (
    <Tab.Navigator
      screenOptions={({route}) => ({
        tabBarIcon: ({focused, color, size}) => {
          let iconName;

          if (route.name === 'Home') {
            iconName = 'home';
          } else if (route.name === 'Analytics') {
            iconName = 'bar-chart';
          } else if (route.name === 'Properties') {
            iconName = 'business';
          } else if (route.name === 'Agreements') {
            iconName = 'assignment';
          } else if (route.name === 'Marketplace') {
            iconName = 'store';
          } else if (route.name === 'Portfolio') {
            iconName = 'account-balance-wallet';
          } else if (route.name === 'Governance') {
            iconName = 'how-to-vote';
          }

          return <Icon name={iconName} size={size} color={color} />;
        },
        tabBarActiveTintColor: theme.colors.primary,
        tabBarInactiveTintColor: 'gray',
      })}>
      <Tab.Screen
        name="Home"
        component={Dashboard}
        options={{
          title: 'Home',
          tabBarTestID: 'dashboard_tab',
          tabBarAccessibilityLabel: 'Home Tab',
        }}
      />
      <Tab.Screen
        name="Analytics"
        component={Analytics}
        options={{
          title: 'Analytics',
          tabBarTestID: 'analytics_tab',
          tabBarAccessibilityLabel: 'Analytics Tab',
        }}
      />
      <Tab.Screen
        name="Properties"
        component={PropertiesList}
        options={{
          title: 'Properties',
          tabBarTestID: 'properties_tab',
          tabBarAccessibilityLabel: 'Properties Tab',
        }}
      />
      <Tab.Screen
        name="Agreements"
        component={YieldAgreementsList}
        options={{
          title: 'Agreements',
          tabBarTestID: 'agreements_tab',
          tabBarAccessibilityLabel: 'Agreements Tab',
        }}
      />
      <Tab.Screen
        name="Marketplace"
        component={Marketplace}
        options={{
          title: 'Marketplace',
          tabBarTestID: 'marketplace_tab',
          tabBarAccessibilityLabel: 'Marketplace Tab',
        }}
      />
      <Tab.Screen
        name="Portfolio"
        component={Portfolio}
        options={{
          title: 'Portfolio',
          tabBarTestID: 'portfolio_tab',
          tabBarAccessibilityLabel: 'Portfolio Tab',
        }}
      />
      <Tab.Screen
        name="Governance"
        component={Governance}
        options={{
          title: 'Governance',
          tabBarTestID: 'governance_tab',
          tabBarAccessibilityLabel: 'Governance Tab',
        }}
      />
    </Tab.Navigator>
  );
}

export default function App() {
  // E2E Testing: Manual-assist approach with 5-second pauses for file selection
  // No automatic detection needed - tests use real native file picker
  
  return (
    <PaperProvider theme={theme}>
      <TokenStandardProvider>
        <PriceProvider>
          <WalletProvider>
            <NavigationContainer>
              <Stack.Navigator>
                <Stack.Screen
                  name="MainTabs"
                  component={TabNavigator}
                  options={{headerShown: false}}
                />
                <Stack.Screen
                  name="PropertyRegistration"
                  component={PropertyRegistration}
                  options={{title: 'Register Property'}}
                />
                <Stack.Screen
                  name="YieldAgreementCreation"
                  component={YieldAgreementCreation}
                  options={{title: 'Create Yield Agreement'}}
                />
                <Stack.Screen
                  name="YieldAgreementDetail"
                  component={YieldAgreementDetail}
                  options={{title: 'Agreement Details'}}
                />
                <Stack.Screen
                  name="GovernanceCreate"
                  component={GovernanceCreate}
                  options={{title: 'Create Governance Proposal'}}
                />
                <Stack.Screen
                  name="GovernanceDetail"
                  component={GovernanceDetail}
                  options={{title: 'Proposal Details'}}
                />
                <Stack.Screen
                  name="CreateListing"
                  component={CreateListing}
                  options={{title: 'Create Marketplace Listing'}}
                />
                <Stack.Screen
                  name="BuyShares"
                  component={BuyShares}
                  options={{title: 'Buy Shares'}}
                />
              </Stack.Navigator>
            </NavigationContainer>
          </WalletProvider>
        </PriceProvider>
      </TokenStandardProvider>
    </PaperProvider>
  );
}
// React Navigation replaces React Router for mobile, bottom tabs provide primary navigation (Home/Properties/Agreements), stack navigator handles detail screens, and all context providers maintain identical API to web version for code sharing.


