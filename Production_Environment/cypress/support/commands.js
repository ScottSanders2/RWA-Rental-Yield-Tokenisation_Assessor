// Custom Cypress commands for RWA Tokenization Platform E2E tests
// Commands for wallet connection, property registration, and yield management workflows will be added in future iterations

Cypress.Commands.add('healthCheck', () => {
  cy.request('http://rwa-test-backend:8000/health').its('status').should('eq', 200);
});
