describe('Test Environment Health Check', () => {
  it('should load the frontend successfully', () => {
    cy.visit('/');
    cy.contains('RWA Tokenization Platform');
  });

  it('should verify backend health endpoint', () => {
    cy.healthCheck();
  });
});
