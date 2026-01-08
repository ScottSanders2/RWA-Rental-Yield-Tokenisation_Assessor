// Yield agreement creation page component

import React from 'react';
import { Container, Paper, Box } from '@mui/material';
import { useParams } from 'react-router-dom';
import YieldAgreementForm from '../components/YieldAgreementForm';

/**
 * YieldAgreementCreation page component
 * @returns {React.ReactElement} Page component
 */
function YieldAgreementCreation() {
  const { propertyTokenId } = useParams();

  return (
    <Container maxWidth="md" sx={{ mt: 4, mb: 4 }}>
      <Paper elevation={3} sx={{ p: 4 }}>
        <YieldAgreementForm propertyTokenId={propertyTokenId} />
      </Paper>
    </Container>
  );
}

export default YieldAgreementCreation;

