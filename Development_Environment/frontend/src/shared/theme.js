// This is a shared Material-UI theme stub to prevent undefined property errors in styled components.
// Import this theme and wrap your app root in <ThemeProvider theme={theme}> to ensure all MUI styled utilities have access to theme properties.

import { createTheme } from '@mui/material/styles';

const theme = createTheme({
  palette: {
    primary: {
      main: '#1976d2', // Material-UI default blue
    },
    secondary: {
      main: '#dc004e', // Material-UI default pink
    },
    mode: 'light',
  },
  typography: {
    fontFamily: 'Roboto, Arial, sans-serif',
  },
});

export default theme;
