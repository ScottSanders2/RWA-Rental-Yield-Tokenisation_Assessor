import {MD3LightTheme} from 'react-native-paper';

const theme = {
  ...MD3LightTheme,
  colors: {
    ...MD3LightTheme.colors,
    primary: '#1976d2', // Matching web theme palette.primary.main
    secondary: '#dc004e', // Matching web theme palette.secondary.main
    background: '#ffffff',
    surface: '#ffffff',
    error: '#B00020',
    onPrimary: '#ffffff',
    onSecondary: '#ffffff',
    onBackground: '#000000',
    onSurface: '#000000',
  },
};

export default theme;
// This React Native Paper theme matches the Material-UI web theme (palette.primary.main: '#1976d2') for consistent branding across web and mobile platforms, using Material Design 3 color system for React Native Paper components.



