// Dashboard/home page component with token standard explanation

import React from 'react';
import {
  Container,
  Typography,
  Box,
  Grid,
  Card,
  CardContent,
  CardActions,
  Button,
  Alert,
  Chip,
} from '@mui/material';
// import AccountBalanceIcon from '@mui/icons-material/AccountBalance';
// import AssignmentIcon from '@mui/icons-material/Assignment';
// import ListAltIcon from '@mui/icons-material/ListAlt';
import { useNavigate } from 'react-router-dom';
import { useTokenStandard } from '../context/TokenStandardContext';
import { useEthPrice } from '../context/PriceContext';

/**
 * Dashboard page component
 * @returns {React.ReactElement} Page component
 */
function Dashboard() {
  const navigate = useNavigate();
  const { tokenStandard, getLabel, getDescription } = useTokenStandard();
  const { ethUsdPrice, isUsingFallback } = useEthPrice();

  // Environment detection
  const detectEnvironment = () => {
    const port = window.location.port;
    if (port === '5173') return 'Development';
    if (port === '5174') return 'Test';
    if (port === '80' || port === '') return 'Production';
    return 'Unknown';
  };

  const environment = detectEnvironment();

  const cardData = [
    {
      title: 'Register Property',
      description: 'Mint property NFT and prepare for yield tokenization. Supports both ERC-721 + ERC-20 and ERC-1155 standards.',
      icon: '🏢',
      action: 'Get Started',
      path: '/properties/register',
      enabled: true,
    },
    {
      title: 'Create Yield Agreement',
      description: 'Configure yield terms with USD-based capital input (converted to ETH/wei automatically) and deploy token contract for rental income distribution. View calculated monthly payments in USD and ETH.',
      icon: '📊',
      action: 'Create Agreement',
      path: '/yield-agreements/create',
      enabled: true,
    },
    {
      title: 'View Properties',
      description: 'Browse registered properties, verification status, and linked yield agreements.',
      icon: '📋',
      action: 'View All',
      path: '/properties',
      enabled: true,
    },
    {
      title: 'View Agreements',
      description: 'Monitor active yield agreements, repayment progress, and investor distributions.',
      icon: '📋',
      action: 'View All',
      path: '/yield-agreements',
      enabled: true,
    },
  ];

  const handleCardAction = (path) => {
    navigate(path);
  };

  return (
    <Container maxWidth="lg" sx={{ mt: 4, mb: 4 }}>
      {/* Header */}
      <Box sx={{ textAlign: 'center', mb: 4 }}>
        <Typography
          variant="h3"
          component="h1"
          gutterBottom
          sx={{ fontWeight: 'bold' }}
        >
          RWA Tokenisation Platform
        </Typography>
        <Typography
          variant="h6"
          color="text.secondary"
          gutterBottom
        >
          Real Estate Rental Yield Tokenisation for Financial Inclusion
        </Typography>
        <Typography
          variant="body1"
          color="primary"
          sx={{ fontWeight: 'medium', mt: 1 }}
        >
          {environment} Environment
        </Typography>
      </Box>

      {/* Token Standard Alert */}
      <Alert
        severity="info"
        sx={{ mb: 3 }}
        icon={false}
      >
        <Typography variant="body2" sx={{ fontWeight: 'medium', mb: 0.5 }}>
          Current Token Standard: {getLabel()}
        </Typography>
        <Typography variant="body2" sx={{ opacity: 0.9 }}>
          {getDescription()}
        </Typography>
      </Alert>


      {/* Cards Grid */}
      <Grid container spacing={3}>
        {cardData.map((card, index) => (
          <Grid item xs={12} sm={6} md={6} key={index}>
            <Card
              sx={{
                height: '100%',
                display: 'flex',
                flexDirection: 'column',
                transition: 'transform 0.2s ease-in-out, box-shadow 0.2s ease-in-out',
                '&:hover': card.enabled ? {
                  transform: 'translateY(-4px)',
                  boxShadow: (theme) => theme.shadows[8],
                } : {},
              }}
            >
              <CardContent sx={{ flex: 1, textAlign: 'center', pt: 3 }}>
                <Box sx={{ color: 'primary.main', mb: 2, fontSize: '2.5rem' }}>
                  {card.icon}
                </Box>
                <Typography
                  variant="h6"
                  component="h2"
                  gutterBottom
                  sx={{ fontWeight: 'medium' }}
                >
                  {card.title}
                </Typography>
                <Typography
                  variant="body2"
                  color="text.secondary"
                  sx={{ lineHeight: 1.6 }}
                >
                  {card.description}
                </Typography>
              </CardContent>
              <CardActions sx={{ justifyContent: 'center', pb: 3 }}>
                <Button
                  variant="contained"
                  color="primary"
                  onClick={() => handleCardAction(card.path)}
                  disabled={!card.enabled}
                  sx={{ minWidth: 140 }}
                >
                  {card.action}
                  {!card.enabled && (
                    <Chip
                      label="Coming Soon"
                      size="small"
                      sx={{ ml: 1, fontSize: '0.7rem' }}
                    />
                  )}
                </Button>
              </CardActions>
            </Card>
          </Grid>
        ))}
      </Grid>
    </Container>
  );
}

export default Dashboard;
