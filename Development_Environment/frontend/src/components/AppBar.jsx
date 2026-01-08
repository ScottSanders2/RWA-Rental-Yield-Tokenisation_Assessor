// Navigation AppBar component with token standard indicator

import React from 'react';
import {
  AppBar,
  Toolbar,
  Typography,
  Button,
  Box,
  Chip,
  IconButton,
  Drawer,
  List,
  ListItem,
  ListItemButton,
  ListItemText,
  useTheme,
  useMediaQuery,
} from '@mui/material';
// import HomeIcon from '@mui/icons-material/Home';
// import AddCircleIcon from '@mui/icons-material/AddCircle';
// import ListAltIcon from '@mui/icons-material/ListAlt';
// import MenuIcon from '@mui/icons-material/Menu';
import { useNavigate } from 'react-router-dom';
import { useTokenStandard } from '../context/TokenStandardContext';
import { useEthPrice } from '../context/PriceContext';
import TokenStandardToggle from './TokenStandardToggle';

/**
 * NavigationAppBar component with responsive design
 * @returns {React.ReactElement} AppBar component
 */
function NavigationAppBar() {
  const navigate = useNavigate();
  const theme = useTheme();
  const isMobile = useMediaQuery(theme.breakpoints.down('md'));

  const { tokenStandard, getLabel } = useTokenStandard();
  const { ethUsdPrice, isUsingFallback } = useEthPrice();

  const [mobileMenuOpen, setMobileMenuOpen] = React.useState(false);

  const navigationItems = [
    { label: 'Home', icon: '🏠', path: '/' },
    { label: 'Register Property', icon: '🏢', path: '/properties/register' },
    { label: 'View Properties', icon: '📋', path: '/properties' },
    { label: 'Create Agreement', icon: '📄', path: '/yield-agreements/create' },
    { label: 'View Agreements', icon: '📋', path: '/yield-agreements' },
    { label: 'Marketplace', icon: '🛒', path: '/marketplace' },
    { label: 'Portfolio', icon: '💼', path: '/portfolio' },
    { label: 'Analytics', icon: '📊', path: '/analytics' },
    { label: 'Governance', icon: '🗳️', path: '/governance' },
    { label: 'KYC', icon: '👤', path: '/kyc' },
    { label: 'KYC Admin', icon: '🔐', path: '/kyc-admin' },
  ];

  const handleNavigation = (path) => {
    navigate(path);
    setMobileMenuOpen(false);
  };

  const currentPriceDisplay = ethUsdPrice
    ? `$${ethUsdPrice.toLocaleString()}`
    : 'Loading...';

  return (
    <>
      <AppBar position="static" color="primary">
        <Toolbar>
          {/* Mobile menu button */}
          {isMobile && (
            <IconButton
              color="inherit"
              edge="start"
              onClick={() => setMobileMenuOpen(true)}
              sx={{ mr: 2 }}
            >
              ☰
            </IconButton>
          )}

          {/* Title */}
          <Typography
            variant="h6"
            component="div"
            sx={{
              flexGrow: 1,
              fontSize: isMobile ? '1rem' : '1.25rem',
              fontWeight: 'bold',
            }}
          >
            RWA Tokenisation Platform
          </Typography>

          {/* Desktop navigation */}
          {!isMobile && (
            <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
              {navigationItems.map((item) => (
                <Button
                  key={item.path}
                  color="inherit"
                  onClick={() => handleNavigation(item.path)}
                  sx={{
                    display: 'flex',
                    flexDirection: 'column',
                    alignItems: 'center',
                    gap: 0.5,
                    minWidth: 'auto',
                    px: 1.5,
                    py: 0.5,
                    '&:hover': {
                      backgroundColor: 'rgba(255, 255, 255, 0.1)',
                    },
                  }}
                >
                  <Box sx={{ fontSize: '1.2rem' }}>{item.icon}</Box>
                  <Typography variant="caption" sx={{ fontSize: '0.7rem', textTransform: 'none' }}>
                    {item.label}
                  </Typography>
                </Button>
              ))}

              {/* Token Standard Toggle */}
              <TokenStandardToggle />

              {/* ETH/USD Price Chip */}
              <Chip
                label={`ETH: ${currentPriceDisplay}`}
                variant="outlined"
                sx={{
                  color: 'white',
                  // borderColor: isUsingFallback ? 'warning.main' : 'white',
                  borderColor: 'white',
                  '& .MuiChip-label': {
                    fontWeight: 'medium',
                  },
                }}
                title="ETH/USD price display disabled"
              />
            </Box>
          )}

          {/* Mobile price chip */}
          {isMobile && (
            <Chip
              label={`$${ethUsdPrice?.toLocaleString('en-US', { maximumFractionDigits: 0 }) || 'Loading...'}`}
              size="small"
              variant="outlined"
              sx={{
                color: 'white',
                borderColor: isUsingFallback ? 'warning.main' : 'white',
                fontSize: '0.75rem',
              }}
              title={`ETH/USD price: ${ethUsdPrice ? '$' + ethUsdPrice.toLocaleString() : 'Loading...'}`}
            />
          )}
        </Toolbar>
      </AppBar>

      {/* Mobile drawer */}
      <Drawer
        anchor="left"
        open={mobileMenuOpen}
        onClose={() => setMobileMenuOpen(false)}
      >
        <Box
          sx={{
            width: 280,
            pt: 2,
            pb: 2,
            display: 'flex',
            flexDirection: 'column',
            height: '100%',
          }}
        >
          {/* Mobile title */}
          <Typography
            variant="h6"
            sx={{
              px: 2,
              pb: 2,
              fontWeight: 'bold',
              borderBottom: '1px solid',
              borderColor: 'divider',
            }}
          >
            Navigation
          </Typography>

          {/* Mobile navigation items */}
          <List sx={{ flex: 1 }}>
            {navigationItems.map((item) => (
              <ListItem key={item.path} disablePadding>
                <ListItemButton onClick={() => handleNavigation(item.path)}>
                  <Box sx={{ mr: 2, display: 'flex', alignItems: 'center' }}>
                    {item.icon}
                  </Box>
                  <ListItemText primary={item.label} />
                </ListItemButton>
              </ListItem>
            ))}
          </List>

          {/* Mobile token standard toggle */}
          <Box sx={{ px: 2, pb: 2, borderTop: '1px solid', borderColor: 'divider' }}>
            <Typography variant="caption" sx={{ mb: 1, display: 'block', fontWeight: 'medium' }}>
              Current Token Standard:
            </Typography>
            <Typography variant="body2" sx={{ mb: 1 }}>
              {getLabel()}
            </Typography>
            <TokenStandardToggle />
          </Box>
        </Box>
      </Drawer>
    </>
  );
}

export default NavigationAppBar;
