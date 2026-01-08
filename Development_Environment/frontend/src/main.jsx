import React from 'react'
import ReactDOM from 'react-dom/client'
import App from './App.jsx'
import { ThemeProvider } from '@mui/material/styles'
import theme from '@shared/theme.js'
import { ApolloProvider } from '@apollo/client'
import apolloClient from './config/apolloClient'

// Set title based on runtime port detection
const detectEnvironment = () => {
  const port = window.location.port;

  if (port === '5173') {
    return 'development';
  }
  if (port === '5174') {
    return 'test';
  }
  if (port === '80' || port === '') {
    return 'production';
  }

  return 'development';
};

const environment = detectEnvironment();
const environmentLabel = environment.charAt(0).toUpperCase() + environment.slice(1);
document.title = `RWA Tokenization Platform - ${environmentLabel}`;

ReactDOM.createRoot(document.getElementById('root')).render(
  <React.StrictMode>
    <ThemeProvider theme={theme}>
      <ApolloProvider client={apolloClient}>
        <App />
      </ApolloProvider>
    </ThemeProvider>
  </React.StrictMode>,
)
