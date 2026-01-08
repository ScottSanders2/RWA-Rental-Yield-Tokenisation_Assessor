import React, { useState, useEffect } from 'react';
import {
  Container,
  Paper,
  Typography,
  Box,
  Grid,
  Card,
  CardContent,
  Button,
  Alert,
  Chip,
  Divider,
} from '@mui/material';
import { getProperties } from '../services/apiClient';
import { formatWeiToUsd } from '../utils/formatters';
import { useEthPrice } from '../context/PriceContext';

/**
 * PropertiesList page component for displaying registered properties
 * @returns {React.ReactElement} Page component
 */
function PropertiesList() {
  const { ethUsdPrice } = useEthPrice();
  const [properties, setProperties] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    const fetchProperties = async () => {
      try {
        setLoading(true);
        setError(null);
        const result = await getProperties();
        setProperties(result.data || []);
      } catch (err) {
        setError(err.message || 'Failed to load properties');
        console.error('Error fetching properties:', err);
      } finally {
        setLoading(false);
      }
    };

    fetchProperties();
  }, []);

  if (loading) {
    return (
      <Container maxWidth="lg" sx={{ mt: 4, mb: 4 }}>
        <Typography variant="h4" component="h1" gutterBottom>
          View Properties
        </Typography>
        <Typography variant="h6">Loading properties...</Typography>
      </Container>
    );
  }

  if (error) {
    return (
      <Container maxWidth="lg" sx={{ mt: 4, mb: 4 }}>
        <Typography variant="h4" component="h1" gutterBottom>
          View Properties
        </Typography>
        <Alert severity="error" sx={{ mt: 2 }}>
          {error}
        </Alert>
      </Container>
    );
  }

  return (
    <Container maxWidth="lg" sx={{ mt: 4, mb: 4 }}>
      <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 3 }}>
        <Typography variant="h4" component="h1">
          View Properties
        </Typography>
        <Button variant="contained" color="primary" href="/properties/register">
          Register New Property
        </Button>
      </Box>

      <Typography variant="subtitle1" color="text.secondary" gutterBottom>
        Monitor your tokenized real estate properties
      </Typography>

      <Divider sx={{ my: 3 }} />

      {properties.length === 0 ? (
        <Alert severity="info" sx={{ mt: 2 }}>
          No properties found. <Button href="/properties/register">Register your first property</Button> to get started.
        </Alert>
      ) : (
        <Grid container spacing={3}>
          {properties.map((property) => (
            <Grid item xs={12} md={6} lg={4} key={property.id}>
              <Card elevation={2}>
                <CardContent>
                  <Typography variant="h6" component="h2" gutterBottom>
                    Property ID: {property.id}
                  </Typography>

                  <Box sx={{ mb: 2 }}>
                    <Chip
                      label={`Token ID: ${property.blockchain_token_id || 'Pending'}`}
                      variant="outlined"
                      size="small"
                      color={property.blockchain_token_id ? 'success' : 'warning'}
                      sx={{ mr: 1, mb: 1 }}
                    />
                    <Chip
                      label={property.is_verified ? 'Verified' : 'Pending Verification'}
                      variant="outlined"
                      size="small"
                      color={property.is_verified ? 'success' : 'warning'}
                    />
                  </Box>

                  <Typography variant="body2" color="text.secondary" sx={{ mb: 1 }}>
                    <strong>Address:</strong> {property.property_address_hash ? `${property.property_address_hash.substring(0, 20)}...` : 'N/A'}
                  </Typography>

                  <Typography variant="body2" color="text.secondary" sx={{ mb: 1 }}>
                    <strong>Token Standard:</strong> {property.token_standard || 'ERC-721'}
                  </Typography>

                  {property.metadata_json && (
                    <Typography variant="body2" color="text.secondary" sx={{ mb: 1 }}>
                      <strong>Type:</strong> {JSON.parse(property.metadata_json).property_type || 'N/A'}
                    </Typography>
                  )}

                  <Typography variant="body2" color="text.secondary" sx={{ mb: 1 }}>
                    <strong>Created:</strong> {new Date(property.created_at).toLocaleDateString()}
                  </Typography>

                  {property.blockchain_token_id && !property.has_active_yield_agreement && (
                    <Button
                      variant="outlined"
                      size="small"
                      sx={{ mt: 2 }}
                      href={`/yield-agreements/create/${property.blockchain_token_id}`}
                    >
                      Create Yield Agreement
                    </Button>
                  )}
                  {property.has_active_yield_agreement && (
                    <Typography variant="body2" color="text.secondary" sx={{ mt: 2, fontStyle: 'italic' }}>
                      Has active yield agreement
                    </Typography>
                  )}
                </CardContent>
              </Card>
            </Grid>
          ))}
        </Grid>
      )}
    </Container>
  );
}

export default PropertiesList;
