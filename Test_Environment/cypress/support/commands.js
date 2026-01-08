// Custom Cypress commands for RWA Tokenization Platform E2E tests
// Commands for property registration, verification, and yield agreement workflows

Cypress.Commands.add('healthCheck', () => {
  cy.request('http://rwa-test-backend:8000/health').its('status').should('eq', 200);
});

/**
 * Register a property via API
 * @param {Object} propertyData - Property registration data
 */
Cypress.Commands.add('registerProperty', (propertyData = {}) => {
  const defaultData = {
    property_address: '123 Test Street, Test City, UK',
    deed_hash: '0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef',
    rental_agreement_uri: 'https://example.com/rental-agreement.pdf',
    metadata: { property_type: 'residential', square_footage: 1200 },
    token_standard: 'ERC721'
  };

  const data = { ...defaultData, ...propertyData };

  cy.request({
    method: 'POST',
    url: 'http://rwa-test-backend:8000/properties/register',
    body: data,
    failOnStatusCode: false
  }).then((response) => {
    expect(response.status).to.eq(200);
    return response.body;
  });
});

/**
 * Verify a property via API
 * @param {number} propertyId - Property ID to verify
 */
Cypress.Commands.add('verifyProperty', (propertyId) => {
  cy.request({
    method: 'POST',
    url: `http://rwa-test-backend:8000/properties/${propertyId}/verify`,
    failOnStatusCode: false
  }).then((response) => {
    expect(response.status).to.eq(200);
    return response.body;
  });
});

/**
 * Create a yield agreement via API
 * @param {Object} agreementData - Yield agreement data
 */
Cypress.Commands.add('createYieldAgreement', (agreementData = {}) => {
  const defaultData = {
    property_token_id: 1,
    upfront_capital_usd: '50000',
    term_months: 24,
    annual_roi_percent: 12,
    property_payer: '',
    grace_period_days: 30,
    default_penalty_rate: 2,
    default_threshold: 3,
    allow_partial_repayments: true,
    allow_early_repayment: true,
    token_standard: 'ERC721'
  };

  const data = { ...defaultData, ...agreementData };

  // Convert USD to wei for API
  const usdValue = parseFloat(data.upfront_capital_usd);
  const ethValue = usdValue / 2000; // Assuming $2000/ETH for tests
  data.upfront_capital = (BigInt(Math.floor(ethValue * 1e18))).toString();

  // Convert percent to basis points
  data.annual_roi_basis_points = Math.round(data.annual_roi_percent * 100);
  delete data.upfront_capital_usd;
  delete data.annual_roi_percent;

  cy.request({
    method: 'POST',
    url: 'http://rwa-test-backend:8000/yield-agreements/create',
    body: data,
    failOnStatusCode: false
  }).then((response) => {
    return response.body;
  });
});

/**
 * Fill property registration form fields
 * @param {Object} data - Form data
 */
Cypress.Commands.add('fillPropertyForm', (data = {}) => {
  if (data.property_address) {
    cy.get('input[name="property_address"]').type(data.property_address);
  }
  if (data.deed_hash) {
    cy.get('input[name="deed_hash"]').type(data.deed_hash);
  }
  if (data.rental_agreement_uri) {
    cy.get('input[name="rental_agreement_uri"]').type(data.rental_agreement_uri);
  }
  if (data.metadata) {
    cy.get('textarea[name="metadata"]').type(JSON.stringify(data.metadata));
  }
});

/**
 * Fill yield agreement form fields
 * @param {Object} data - Form data
 */
Cypress.Commands.add('fillYieldAgreementForm', (data = {}) => {
  if (data.property_token_id) {
    cy.get('input[name="property_token_id"]').type(data.property_token_id.toString());
  }
  if (data.upfront_capital_usd) {
    cy.get('input[name="upfront_capital_usd"]').type(data.upfront_capital_usd);
  }
  if (data.term_months) {
    cy.get('[role="slider"]').first().invoke('val', data.term_months).trigger('change');
  }
  if (data.annual_roi_percent) {
    cy.get('[role="slider"]').last().invoke('val', data.annual_roi_percent).trigger('change');
  }
  if (data.property_payer) {
    cy.get('input[name="property_payer"]').type(data.property_payer);
  }
  if (data.grace_period_days) {
    cy.get('input[name="grace_period_days"]').clear().type(data.grace_period_days.toString());
  }
  if (data.default_penalty_rate) {
    cy.get('input[name="default_penalty_rate"]').clear().type(data.default_penalty_rate.toString());
  }
  if (data.default_threshold) {
    cy.get('input[name="default_threshold"]').clear().type(data.default_threshold.toString());
  }
});

/**
 * Set token standard in the UI
 * @param {string} standard - 'ERC721' or 'ERC1155'
 */
Cypress.Commands.add('setTokenStandard', (standard) => {
  if (standard === 'ERC721') {
    cy.contains('ERC-721 + ERC-20').click();
  } else if (standard === 'ERC1155') {
    cy.contains('ERC-1155').click();
  }
});

/**
 * Capture task completion time for UX metrics
 * @returns {Function} Function to calculate elapsed time
 */
Cypress.Commands.add('captureTaskTime', () => {
  const startTime = Date.now();
  return () => Date.now() - startTime;
});

/**
 * Verify USD/ETH dual currency display format
 * @param {string} usdAmount - Expected USD amount
 * @param {string} ethAmount - Expected ETH amount
 * @param {number} ethUsdPrice - ETH/USD price
 */
Cypress.Commands.add('verifyUsdEthDisplay', (usdAmount, ethAmount, ethUsdPrice) => {
  const expectedText = `$${usdAmount} USD ≈ ${ethAmount} ETH at $${ethUsdPrice.toLocaleString()}/ETH`;
  cy.contains(expectedText).should('be.visible');
});
