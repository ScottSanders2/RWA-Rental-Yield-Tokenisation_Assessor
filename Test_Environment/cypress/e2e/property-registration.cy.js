// Cypress E2E test for complete property registration workflow

describe('Property Registration Workflow', () => {
  beforeEach(() => {
    // Visit the property registration page
    cy.visit('/properties/register');
    cy.contains('Register Property').should('be.visible');
  });

  it('should register property with ERC-721 + ERC-20 standard', () => {
    // Verify token standard shows ERC-721 + ERC-20
    cy.contains('Current Token Standard: ERC-721 + ERC-20 (Separate Contracts)').should('be.visible');

    // Fill property registration form
    cy.get('input[name="property_address"]').type('123 Main Street, London, UK');
    cy.get('input[name="deed_hash"]').type('0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef');
    cy.get('input[name="rental_agreement_uri"]').type('ipfs://QmTest1234567890abcdef1234567890abcdef1234567890abcdef');
    cy.get('textarea[name="metadata"]').type('{"property_type": "residential", "square_footage": 1200}');

    // Intercept the API call
    cy.intercept('POST', '**/properties/register', { statusCode: 200, body: {
      property_id: 1,
      blockchain_token_id: 123,
      tx_hash: '0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890'
    } }).as('registerProperty');

    // Submit the form
    cy.get('button[type="submit"]').contains('Register Property').click();

    // Wait for API call and verify request
    cy.wait('@registerProperty').then((interception) => {
      expect(interception.request.body).to.deep.include({
        property_address: '123 Main Street, London, UK',
        deed_hash: '0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef',
        rental_agreement_uri: 'ipfs://QmTest1234567890abcdef1234567890abcdef1234567890abcdef',
        metadata: { property_type: 'residential', square_footage: 1200 },
        token_standard: 'ERC721'
      });
    });

    // Verify success message
    cy.contains('Property registered successfully!').should('be.visible');
    cy.contains('Property ID: 1').should('be.visible');
    cy.contains('Blockchain Token ID: 123').should('be.visible');
    cy.contains('0xabcdef...567890').should('be.visible');

    // Verify navigation to yield agreement creation
    cy.url().should('include', '/yield-agreements/create/123');
  });

  it('should register property with ERC-1155 standard', () => {
    // Switch to ERC-1155 token standard
    cy.contains('ERC-721 + ERC-20').click();
    cy.contains('ERC-1155').click();

    // Verify token standard shows ERC-1155
    cy.contains('Current Token Standard: ERC-1155 (Combined Contract)').should('be.visible');

    // Fill property registration form
    cy.get('input[name="property_address"]').type('456 Oak Avenue, Manchester, UK');
    cy.get('input[name="deed_hash"]').type('0xabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcd');
    cy.get('input[name="rental_agreement_uri"]').type('https://example.com/rental-agreement.pdf');
    cy.get('textarea[name="metadata"]').type('{"property_type": "commercial", "square_footage": 2000}');

    // Intercept the API call
    cy.intercept('POST', '**/properties/register', { statusCode: 200, body: {
      property_id: 2,
      blockchain_token_id: 456,
      tx_hash: '0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef'
    } }).as('registerPropertyERC1155');

    // Submit the form
    cy.get('button[type="submit"]').contains('Register Property').click();

    // Wait for API call and verify request includes ERC1155
    cy.wait('@registerPropertyERC1155').then((interception) => {
      expect(interception.request.body.token_standard).to.equal('ERC1155');
    });

    // Verify success and navigation
    cy.contains('Property registered successfully!').should('be.visible');
    cy.url().should('include', '/yield-agreements/create/456');
  });

  it('should validate deed hash format', () => {
    // Fill other required fields
    cy.get('input[name="property_address"]').type('123 Main Street, London, UK');
    cy.get('input[name="rental_agreement_uri"]').type('https://example.com/agreement.pdf');

    // Test invalid deed hash - missing 0x
    cy.get('input[name="deed_hash"]').type('1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef');
    cy.get('button[type="submit"]').click();
    cy.contains('Deed hash must be a 0x-prefixed 66-character hexadecimal string').should('be.visible');

    // Test invalid deed hash - wrong length
    cy.get('input[name="deed_hash"]').clear().type('0x1234');
    cy.get('button[type="submit"]').click();
    cy.contains('Deed hash must be a 0x-prefixed 66-character hexadecimal string').should('be.visible');

    // Test valid deed hash - should not show error
    cy.get('input[name="deed_hash"]').clear().type('0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef');
    cy.get('button[type="submit"]').click();
    cy.contains('Deed hash must be a 0x-prefixed 66-character hexadecimal string').should('not.exist');
  });

  it('should validate rental agreement URI format', () => {
    // Fill other required fields
    cy.get('input[name="property_address"]').type('123 Main Street, London, UK');
    cy.get('input[name="deed_hash"]').type('0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef');

    // Test invalid URI
    cy.get('input[name="rental_agreement_uri"]').type('invalid-url');
    cy.get('button[type="submit"]').click();
    cy.contains('Invalid URI format').should('be.visible');

    // Test valid HTTP URI
    cy.get('input[name="rental_agreement_uri"]').clear().type('https://example.com/agreement.pdf');
    cy.get('button[type="submit"]').click();
    cy.contains('Invalid URI format').should('not.exist');

    // Test valid IPFS URI
    cy.get('input[name="rental_agreement_uri"]').clear().type('ipfs://QmTest123');
    cy.get('button[type="submit"]').click();
    cy.contains('Invalid URI format').should('not.exist');
  });

  it('should validate metadata JSON format', () => {
    // Fill other required fields
    cy.get('input[name="property_address"]').type('123 Main Street, London, UK');
    cy.get('input[name="deed_hash"]').type('0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef');
    cy.get('input[name="rental_agreement_uri"]').type('https://example.com/agreement.pdf');

    // Test invalid JSON
    cy.get('textarea[name="metadata"]').type('{invalid: json}');
    cy.get('button[type="submit"]').click();
    cy.contains('Metadata must be valid JSON').should('be.visible');

    // Test valid JSON
    cy.get('textarea[name="metadata"]').clear().type('{"property_type": "residential"}');
    cy.get('button[type="submit"]').click();
    cy.contains('Metadata must be valid JSON').should('not.exist');
  });

  it('should show loading state during submission', () => {
    // Fill form with valid data
    cy.get('input[name="property_address"]').type('123 Main Street, London, UK');
    cy.get('input[name="deed_hash"]').type('0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef');
    cy.get('input[name="rental_agreement_uri"]').type('https://example.com/agreement.pdf');

    // Intercept with delay to show loading state
    cy.intercept('POST', '**/properties/register', { statusCode: 200, body: {
      property_id: 1, blockchain_token_id: 123
    }, delay: 1000 }).as('slowRegister');

    // Submit and verify loading state
    cy.get('button[type="submit"]').click();
    cy.get('[role="progressbar"]').should('be.visible');

    // Wait for completion
    cy.wait('@slowRegister');
    cy.get('[role="progressbar"]').should('not.exist');
  });

  it('should handle API errors gracefully', () => {
    // Fill form with valid data
    cy.get('input[name="property_address"]').type('123 Main Street, London, UK');
    cy.get('input[name="deed_hash"]').type('0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef');
    cy.get('input[name="rental_agreement_uri"]').type('https://example.com/agreement.pdf');

    // Intercept with error
    cy.intercept('POST', '**/properties/register', { statusCode: 500, body: {
      detail: 'Blockchain error: Insufficient funds'
    } }).as('registerError');

    // Submit and verify error handling
    cy.get('button[type="submit"]').click();
    cy.wait('@registerError');

    // Verify error message display
    cy.contains('Blockchain error: Insufficient funds').should('be.visible');

    // Verify form is still accessible for retry
    cy.get('input[name="property_address"]').should('be.visible');
    cy.get('button[type="submit"]').should('be.enabled');
  });
});






