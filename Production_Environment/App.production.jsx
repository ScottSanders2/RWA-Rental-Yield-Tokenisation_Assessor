import React from 'react'
import { Container, Typography, Box } from '@mui/material'

function App() {
  const environment = 'production'
  const environmentLabel = environment.charAt(0).toUpperCase() + environment.slice(1);

  return (
    <Container maxWidth="lg" sx={{ mt: 4 }}>
      <Box sx={{ textAlign: 'center' }}>
        <Typography variant="h3" component="h1" gutterBottom>
          RWA Tokenization Platform
        </Typography>
        <Typography variant="h6" color="text.secondary" gutterBottom>
          {environmentLabel} Environment
        </Typography>
        <Typography variant="body1" sx={{ mt: 2 }}>
          Frontend stub operational. Full UI for property registration, yield management,
          and investor dashboards will be implemented in subsequent iterations.
        </Typography>
      </Box>
    </Container>
  )
}

export default App
