// Property registration page component

import React from 'react';
import { Container, Paper, Box } from '@mui/material';
import PropertyRegistrationForm from '../components/PropertyRegistrationForm';

/**
 * PropertyRegistration page component
 * @returns {React.ReactElement} Page component
 */
function PropertyRegistration() {
  return (
    <Container maxWidth="md" sx={{ mt: 4, mb: 4 }}>
      <Paper elevation={3} sx={{ p: 4 }}>
        <PropertyRegistrationForm />
      </Paper>
    </Container>
  );
}

export default PropertyRegistration;






