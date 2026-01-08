// Cypress E2E test for yield agreement creation workflow with USD input validation

describe('Yield Agreement Creation Workflow', () => {
  beforeEach(() => {
    // Register and verify a property first
    cy.registerProperty({
      property_address: '123 Main Street, London, UK',
      deed_hash: '0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef',
      rental_agreement_uri: 'https://example.com/rental-agreement.pdf',
      metadata: { property_type: 'residential', square_footage: 1200 }
    });

    cy.verifyProperty(1);

    // Navigate to yield agreement creation
    cy.visit('/yield-agreements/create');
    cy.contains('Create Yield Agreement').should('be.visible');
  });

  it('should create yield agreement with USD input and ETH conversion', () => {
    // Verify form loaded
    cy.contains('Create Yield Agreement').should('be.visible');

    // Verify property token ID is auto-generated and read-only
    cy.get('input[name="property_token_id"]').should('have.attr', 'readonly').and('have.value').and('match', /^[1-9]\d{3}$/);

    // Capture the auto-generated property token ID
    let propertyTokenId;
    cy.get('input[name="property_token_id"]').invoke('val').then((val) => {
      propertyTokenId = parseInt(val);
    });

    // Fill upfront capital in USD
    cy.get('input[name="upfront_capital_usd"]').type('50000');

    // Verify live ETH equivalent display
    cy.contains('≈ 25.0000 ETH at $2,000/ETH').should('be.visible');

    // Set term to 24 months using slider
    cy.get('[role="slider"]').first().invoke('val', 24).trigger('change');
    cy.contains('Agreement Term: 24 months').should('be.visible');

    // Set ROI to 12% using slider
    cy.get('[role="slider"]').last().invoke('val', 12).trigger('change');
    cy.contains('Annual ROI: 12%').should('be.visible');

    // Verify default parameters
    cy.get('input[name="grace_period_days"]').should('have.value', '30');
    cy.get('input[name="default_penalty_rate"]').should('have.value', '2');
    cy.get('input[name="default_threshold"]').should('have.value', '3');

    // Intercept API call
    cy.intercept('POST', '**/yield-agreements/create', { statusCode: 200, body: {
      agreement_id: 1,
      monthly_payment: '1093750000000000000', // ~1.09375 ETH in wei
      total_expected_repayment: '26250000000000000000', // ~26.25 ETH in wei
      blockchain_agreement_id: 789,
      token_contract_address: '0xabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcd',
      tx_hash: '0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef'
    } }).as('createAgreement');

    // Submit form
    cy.get('button[type="submit"]').contains('Create Yield Agreement').click();

    // Verify API call with correct conversions
    cy.wait('@createAgreement').then((interception) => {
      expect(interception.request.body).to.deep.include({
        property_token_id: propertyTokenId,
        upfront_capital: '25000000000000000000000', // 25 ETH in wei ($50,000 / $2,000)
        term_months: 24,
        annual_roi_basis_points: 1200, // 12% = 1200 basis points
        grace_period_days: 30,
        default_penalty_rate: 2,
        default_threshold: 3,
        allow_partial_repayments: true,
        allow_early_repayment: true,
        token_standard: 'ERC721'
      });
    });

    // Verify success message
    cy.contains('Yield agreement created successfully!').should('be.visible');

    // Verify calculated financial projections in dual currency
    cy.contains('Monthly Payment: $2,187.50 USD ≈ 1.0938 ETH').should('be.visible');
    cy.contains('Total Expected Repayment: $52,500.00 USD ≈ 26.2500 ETH').should('be.visible');

    // Verify navigation to agreement detail
    cy.url().should('include', '/yield-agreements/1');
  });

  it('should validate property must be verified', () => {
    // Verify property token ID is auto-generated and read-only
    cy.get('input[name="property_token_id"]').should('have.attr', 'readonly').and('have.value').and('match', /^[1-9]\d{3}$/);

    cy.get('input[name="upfront_capital_usd"]').type('50000');

    // Intercept with error for unverified property
    cy.intercept('POST', '**/yield-agreements/create', { statusCode: 400, body: {
      detail: 'Property not verified or does not exist'
    } }).as('createAgreementError');

    cy.get('button[type="submit"]').click();

    cy.wait('@createAgreementError');
    cy.contains('Property not verified or does not exist').should('be.visible');
  });

  it('should calculate financial projections correctly', () => {
    // Verify property token ID is auto-generated and read-only
    cy.get('input[name="property_token_id"]').should('have.attr', 'readonly').and('have.value').and('match', /^[1-9]\d{3}$/);

    cy.get('input[name="upfront_capital_usd"]').type('50000'); // $50,000 at $2,000/ETH = 25 ETH

    // Set term and ROI
    cy.get('[role="slider"]').first().invoke('val', 24).trigger('change'); // 24 months
    cy.get('[role="slider"]').last().invoke('val', 12).trigger('change'); // 12%

    // Mock API response with expected calculations
    cy.intercept('POST', '**/yield-agreements/create', { statusCode: 200, body: {
      agreement_id: 1,
      monthly_payment: '1093750000000000000', // Expected: $50,000 * 0.12 / 12 = $500/month = $2,187.50 at $2,000/ETH = 1.09375 ETH
      total_expected_repayment: '26250000000000000000', // Expected: $50,000 + ($50,000 * 0.12 * 2) = $62,000 = $52,500 at $2,000/ETH = 26.25 ETH
    } }).as('calculateAgreement');

    cy.get('button[type="submit"]').click();

    cy.wait('@calculateAgreement');

    // Verify displayed calculations match expected values
    cy.contains('Monthly Payment: $2,187.50 USD ≈ 1.0938 ETH').should('be.visible');
    cy.contains('Total Expected Repayment: $52,500.00 USD ≈ 26.2500 ETH').should('be.visible');
  });

  it('should support ERC-1155 token standard', () => {
    // Switch to ERC-1155
    cy.contains('ERC-721 + ERC-20').click();
    cy.contains('ERC-1155').click();

    // Verify token standard label
    cy.contains('Current Token Standard: ERC-1155 (Combined Contract)').should('be.visible');

    // Register property with ERC-1155
    cy.registerProperty({
      property_address: '789 Elm Street, Birmingham, UK',
      deed_hash: '0xabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcd',
      rental_agreement_uri: 'https://example.com/rental-erc1155.pdf',
      metadata: { property_type: 'residential' },
      token_standard: 'ERC1155'
    });

    cy.verifyProperty(2);

    // Verify property token ID is auto-generated and read-only
    cy.get('input[name="property_token_id"]').should('have.attr', 'readonly').and('have.value').and('match', /^[1-9]\d{3}$/);

    cy.get('input[name="upfront_capital_usd"]').type('50000');

    cy.intercept('POST', '**/yield-agreements/create', { statusCode: 200, body: {
      agreement_id: 2,
      monthly_payment: '1093750000000000000',
      total_expected_repayment: '26250000000000000000',
    } }).as('createERC1155Agreement');

    cy.get('button[type="submit"]').click();

    cy.wait('@createERC1155Agreement').then((interception) => {
      expect(interception.request.body.token_standard).to.equal('ERC1155');
    });

    cy.contains('Yield agreement created successfully!').should('be.visible');
  });

  it('should validate term months range', () => {
    // Verify property token ID is auto-generated and read-only
    cy.get('input[name="property_token_id"]').should('have.attr', 'readonly').and('have.value').and('match', /^[1-9]\d{3}$/);

    cy.get('input[name="upfront_capital_usd"]').type('50000');

    // Try invalid term (0 months) - if slider allows it
    cy.get('[role="slider"]').first().invoke('val', 0).trigger('change');
    cy.get('button[type="submit"]').click();
    cy.contains('Term must be between 1 and 360 months').should('be.visible');

    // Try invalid term (361 months)
    cy.get('[role="slider"]').first().invoke('val', 361).trigger('change');
    cy.get('button[type="submit"]').click();
    cy.contains('Term must be between 1 and 360 months').should('be.visible');
  });

  it('should validate ROI range', () => {
    // Verify property token ID is auto-generated and read-only
    cy.get('input[name="property_token_id"]').should('have.attr', 'readonly').and('have.value').and('match', /^[1-9]\d{3}$/);

    cy.get('input[name="upfront_capital_usd"]').type('50000');

    // Try invalid ROI (0%)
    cy.get('[role="slider"]').last().invoke('val', 0).trigger('change');
    cy.get('button[type="submit"]').click();
    cy.contains('ROI must be between 0.01% and 50%').should('be.visible');

    // Try invalid ROI (51%)
    cy.get('[role="slider"]').last().invoke('val', 51).trigger('change');
    cy.get('button[type="submit"]').click();
    cy.contains('ROI must be between 0.01% and 50%').should('be.visible');
  });

  it('should validate property payer address format', () => {
    // Verify property token ID is auto-generated and read-only
    cy.get('input[name="property_token_id"]').should('have.attr', 'readonly').and('have.value').and('match', /^[1-9]\d{3}$/);

    cy.get('input[name="upfront_capital_usd"]').type('50000');

    // Enter invalid address
    cy.get('input[name="property_payer"]').type('invalid-address');
    cy.get('button[type="submit"]').click();
    cy.contains('Property payer must be a valid Ethereum address').should('be.visible');

    // Enter valid address
    cy.get('input[name="property_payer"]').clear().type('0x1234567890123456789012345678901234567890');
    cy.get('button[type="submit"]').click();
    cy.contains('Property payer must be a valid Ethereum address').should('not.exist');
  });

  it('should update ETH equivalent when USD input changes', () => {
    // Verify property token ID is auto-generated and read-only
    cy.get('input[name="property_token_id"]').should('have.attr', 'readonly').and('have.value').and('match', /^[1-9]\d{3}$/);

    // Enter $50,000
    cy.get('input[name="upfront_capital_usd"]').type('50000');
    cy.contains('≈ 25.0000 ETH at $2,000/ETH').should('be.visible');

    // Change to $100,000
    cy.get('input[name="upfront_capital_usd"]').clear().type('100000');
    cy.contains('≈ 50.0000 ETH at $2,000/ETH').should('be.visible');

    // Change to $25,000
    cy.get('input[name="upfront_capital_usd"]').clear().type('25000');
    cy.contains('≈ 12.5000 ETH at $2,000/ETH').should('be.visible');
  });

  it('should handle API errors gracefully', () => {
    // Verify property token ID is auto-generated and read-only
    cy.get('input[name="property_token_id"]').should('have.attr', 'readonly').and('have.value').and('match', /^[1-9]\d{3}$/);

    cy.get('input[name="upfront_capital_usd"]').type('50000');

    cy.intercept('POST', '**/yield-agreements/create', { statusCode: 500, body: {
      detail: 'Smart contract deployment failed'
    } }).as('agreementError');

    cy.get('button[type="submit"]').click();

    cy.wait('@agreementError');
    cy.contains('Smart contract deployment failed').should('be.visible');

    // Form should still be accessible
    cy.get('input[name="property_token_id"]').should('be.visible').and('have.attr', 'readonly');
    cy.get('button[type="submit"]').should('be.enabled');
  });
});

