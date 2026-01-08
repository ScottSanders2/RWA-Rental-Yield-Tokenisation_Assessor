// Import polyfills FIRST - before any other imports
import 'react-native-get-random-values';
import '@walletconnect/react-native-compat';

// Simplified Expo entry point for React Native app
import { registerRootComponent } from 'expo';
import App from './src/App.native';

// Ensure Expo initializes the app correctly across environments
registerRootComponent(App);


