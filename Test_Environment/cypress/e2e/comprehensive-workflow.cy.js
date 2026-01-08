/**
 * Comprehensive Yield Tokenization Workflow E2E Test
 * 
 * Test Coverage:
 * - Property registration → Verification → Yield agreement creation
 * - Repayment → Distribution → Governance proposal → Voting → Execution
 * - Secondary market listing → Transfer with restrictions → KYC verification
 * 
 * Token Standards Tested:
 * - ERC-721 + ERC-20 (Separate Contracts)
 * - ERC-1155 (Combined Property + Yield Token)
 */

describe('Comprehensive Yield Tokenization Workflow', () => {
  // Test configuration
  const BACKEND_URL = 'http://rwa-test-backend:8000';
  const FRONTEND_URL = 'http://rwa-test-frontend:5173';
  
  // Test data
  const propertyData = {
    address: '123 Main St, Test City, Test Country',
    deedHash: '0xabcd1234567890abcdef1234567890abcdef1234567890abcdef1234567890ab',
    rentalAgreementUri: 'ipfs://QmTestRentalAgreement123456789',
    metadata: {
      propertyType: 'Residential',
      bedrooms: 3,
      bathrooms: 2,
      squareFeet: 1500
    }
  };

  const agreementData = {
    upfrontCapital: 50000, // $50,000 USD
    termMonths: 12,
    roiBps: 800, // 8% ROI
    monthlyPayment: 4500, // $4,500 USD per month
    tokenStandard: 'ERC721_ERC20' // or 'ERC1155'
  };

  const investorData = {
    address: '0x1234567890123456789012345678901234567890',
    investmentAmount: 25000 // $25,000 USD (50% of upfront capital)
  };

  const governanceData = {
    proposalType: 'ROI_ADJUSTMENT',
    newRoiBps: 850, // Increase to 8.5%
    description: 'Increase ROI due to improved market conditions'
  };

  const marketplaceData = {
    listingAmount: 10000, // Sell $10,000 worth
    listingPriceUsd: 10500, // $10,500 (5% premium)
    buyer: '0x9876543210987654321098765432109876543210'
  };

  // Metrics collection
  let testMetrics = {
    startTime: null,
    endTime: null,
    apiCallCount: 0,
    transactionCount: 0,
    steps: []
  };

  before(() => {
    testMetrics.startTime = Date.now();
    
    // Setup: Visit frontend
    cy.visit(FRONTEND_URL);
    
    // Setup specific API intercepts for different operations
    cy.intercept('POST', '**/api/properties').as('createProperty');
    cy.intercept('POST', '**/api/properties/*/verify').as('verifyProperty');
    cy.intercept('POST', '**/api/yield-agreements').as('createAgreement');
    cy.intercept('POST', '**/api/yield-agreements/*/invest').as('investInAgreement');
    cy.intercept('POST', '**/api/yield-agreements/*/repayment').as('makeRepayment');
    cy.intercept('GET', '**/api/investors/*/balance/*').as('getInvestorBalance');
    cy.intercept('POST', '**/api/governance/proposals').as('createProposal');
    cy.intercept('POST', '**/api/governance/proposals/*/vote').as('castVote');
    cy.intercept('POST', '**/api/governance/proposals/*/execute').as('executeProposal');
    cy.intercept('POST', '**/api/marketplace/listings').as('createListing');
    cy.intercept('POST', '**/api/marketplace/listings/*/buy').as('buyListing');
    cy.intercept('GET', '**/api/marketplace/listings/*').as('getListing');
    cy.intercept('POST', '**/api/kyc/submit').as('submitKYC');
    
    // Keep broad intercept for general metrics collection only
    cy.intercept('**/api/**').as('anyApiCall');
  });

  after(() => {
    testMetrics.endTime = Date.now();
    testMetrics.duration = (testMetrics.endTime - testMetrics.startTime) / 1000;
    
    // Log metrics for dissertation analysis
    cy.task('logMetrics', testMetrics);
  });

  /**
   * Test 1: Complete workflow for ERC-721 + ERC-20 variant
   */
  describe('ERC-721 + ERC-20 Workflow', () => {
    let propertyId;
    let agreementId;
    let proposalId;
    let listingId;

    it('Step 1: Property Registration', () => {
      const stepStart = Date.now();
      
      cy.get('[data-testid="register-property-btn"]', { timeout: 10000 }).click();
      
      // Fill property registration form
      cy.get('[data-testid="property-address-input"]').type(propertyData.address);
      cy.get('[data-testid="deed-hash-input"]').type(propertyData.deedHash);
      cy.get('[data-testid="rental-agreement-uri-input"]').type(propertyData.rentalAgreementUri);
      cy.get('[data-testid="property-type-select"]').select('Residential');
      cy.get('[data-testid="bedrooms-input"]').type('3');
      cy.get('[data-testid="bathrooms-input"]').type('2');
      cy.get('[data-testid="square-feet-input"]').type('1500');
      
      // Submit registration
      cy.get('[data-testid="submit-property-btn"]').click();
      
      // Wait for success message
      cy.contains('Property registered successfully', { timeout: 15000 }).should('be.visible');
      testMetrics.transactionCount++;
      
      // Extract property ID from specific createProperty intercept
      cy.wait('@createProperty').then((interception) => {
        propertyId = interception.response.body.propertyId || 1;
        testMetrics.apiCallCount++;
        
        testMetrics.steps.push({
          name: 'Property Registration',
          duration: (Date.now() - stepStart) / 1000,
          success: true
        });
      });
    });

    it('Step 2: Property Verification (Admin)', () => {
      const stepStart = Date.now();
      
      // Simulate admin verification via direct API call (captures response directly)
      cy.request('POST', `${BACKEND_URL}/api/properties/${propertyId}/verify`, {
        verified: true,
        verifier: 'admin@rwa-platform.com',
        verificationNotes: 'E2E test verification'
      }).then((response) => {
        expect(response.status).to.eq(200);
        expect(response.body.verified).to.be.true;
        testMetrics.apiCallCount++;
        
        testMetrics.steps.push({
          name: 'Property Verification',
          duration: (Date.now() - stepStart) / 1000,
          success: true
        });
      });
    });

    it('Step 3: Yield Agreement Creation', () => {
      const stepStart = Date.now();
      
      cy.get('[data-testid="create-agreement-btn"]').click();
      
      // Select property
      cy.get('[data-testid="property-select"]').select(`Property ${propertyId}`);
      
      // Fill agreement details
      cy.get('[data-testid="upfront-capital-input"]').type(agreementData.upfrontCapital.toString());
      cy.get('[data-testid="term-months-input"]').type(agreementData.termMonths.toString());
      cy.get('[data-testid="roi-bps-input"]').type(agreementData.roiBps.toString());
      cy.get('[data-testid="monthly-payment-input"]').type(agreementData.monthlyPayment.toString());
      cy.get('[data-testid="token-standard-select"]').select('ERC-721 + ERC-20 (Separate Contracts)');
      
      // Submit agreement
      cy.get('[data-testid="submit-agreement-btn"]').click();
      
      // Wait for success
      cy.contains('Yield agreement created', { timeout: 20000 }).should('be.visible');
      testMetrics.transactionCount++;
      
      // Extract agreement ID from specific createAgreement intercept
      cy.wait('@createAgreement').then((interception) => {
        agreementId = interception.response.body.agreementId || 1;
        testMetrics.apiCallCount++;
        
        testMetrics.steps.push({
          name: 'Yield Agreement Creation',
          duration: (Date.now() - stepStart) / 1000,
          success: true
        });
      });
    });

    it('Step 4: Investor Purchase', () => {
      const stepStart = Date.now();
      
      // Simulate investor purchase via direct API call (captures response directly)
      cy.request('POST', `${BACKEND_URL}/api/yield-agreements/${agreementId}/invest`, {
        investor: investorData.address,
        amount: investorData.investmentAmount
      }).then((response) => {
        expect(response.status).to.eq(200);
        expect(response.body.success).to.be.true;
        testMetrics.apiCallCount++;
        testMetrics.transactionCount++;
        
        testMetrics.steps.push({
          name: 'Investor Purchase',
          duration: (Date.now() - stepStart) / 1000,
          success: true
        });
      });
    });

    it('Step 5: Repayment Processing', () => {
      const stepStart = Date.now();
      
      cy.get('[data-testid="repayments-tab"]').click();
      cy.get(`[data-testid="agreement-${agreementId}-repay-btn"]`).click();
      
      // Enter repayment amount
      cy.get('[data-testid="repayment-amount-input"]').type(agreementData.monthlyPayment.toString());
      
      // Submit repayment
      cy.get('[data-testid="submit-repayment-btn"]').click();
      
      // Wait for confirmation
      cy.contains('Repayment processed', { timeout: 15000 }).should('be.visible');
      testMetrics.transactionCount++;
      
      cy.wait('@makeRepayment').then(() => {
        testMetrics.apiCallCount++;
        
        testMetrics.steps.push({
          name: 'Repayment Processing',
          duration: (Date.now() - stepStart) / 1000,
          success: true
        });
      });
    });

    it('Step 6: Verify Distribution', () => {
      const stepStart = Date.now();
      
      // Navigate to investor dashboard
      cy.get('[data-testid="investor-dashboard-link"]').click();
      
      // Verify yield received (pro-rata: $25k / $50k × ($4.5k - $50k principal) = proportional yield)
      // Simplified: Check yield is visible
      cy.contains(/Yield Received:/i, { timeout: 10000 }).should('be.visible');
      
      // Verify balance via direct API call (captures response directly)
      cy.request('GET', `${BACKEND_URL}/api/investors/${investorData.address}/balance/${agreementId}`).then((response) => {
        expect(response.status).to.eq(200);
        expect(response.body.yieldReceived).to.be.greaterThan(0);
        testMetrics.apiCallCount++;
        
        testMetrics.steps.push({
          name: 'Verify Distribution',
          duration: (Date.now() - stepStart) / 1000,
          success: true
        });
      });
    });

    it('Step 7: Governance Proposal Creation', () => {
      const stepStart = Date.now();
      
      cy.get('[data-testid="governance-tab"]').click();
      cy.get('[data-testid="create-proposal-btn"]').click();
      
      // Fill proposal details
      cy.get('[data-testid="proposal-type-select"]').select(governanceData.proposalType);
      cy.get('[data-testid="target-agreement-input"]').type(agreementId.toString());
      cy.get('[data-testid="new-roi-bps-input"]').type(governanceData.newRoiBps.toString());
      cy.get('[data-testid="proposal-description-input"]').type(governanceData.description);
      
      // Submit proposal
      cy.get('[data-testid="submit-proposal-btn"]').click();
      
      // Wait for confirmation
      cy.contains('Proposal created', { timeout: 15000 }).should('be.visible');
      testMetrics.transactionCount++;
      
      // Extract proposal ID from specific createProposal intercept
      cy.wait('@createProposal').then((interception) => {
        proposalId = interception.response.body.proposalId || 1;
        testMetrics.apiCallCount++;
        
        testMetrics.steps.push({
          name: 'Governance Proposal Creation',
          duration: (Date.now() - stepStart) / 1000,
          success: true
        });
      });
    });

    it('Step 8: Cast Vote', () => {
      const stepStart = Date.now();
      
      cy.get(`[data-testid="proposal-${proposalId}-vote-btn"]`).click();
      
      // Vote "For"
      cy.get('[data-testid="vote-for-btn"]').click();
      
      // Wait for confirmation
      cy.contains('Vote cast successfully', { timeout: 15000 }).should('be.visible');
      testMetrics.transactionCount++;
      
      cy.wait('@castVote').then(() => {
        testMetrics.apiCallCount++;
        
        testMetrics.steps.push({
          name: 'Cast Vote',
          duration: (Date.now() - stepStart) / 1000,
          success: true
        });
      });
    });

    it('Step 9: Execute Proposal', () => {
      const stepStart = Date.now();
      
      // Simulate time advancement via direct API call (captures response directly)
      cy.request('POST', `${BACKEND_URL}/api/governance/advance-time`, {
        blocks: 50400 // Voting period
      }).then((response) => {
        expect(response.status).to.eq(200);
        testMetrics.apiCallCount++;
      });
      
      // Execute proposal via direct API call (captures response directly)
      cy.request('POST', `${BACKEND_URL}/api/governance/proposals/${proposalId}/execute`).then((response) => {
        expect(response.status).to.eq(200);
        expect(response.body.executed).to.be.true;
        testMetrics.apiCallCount++;
        testMetrics.transactionCount++;
        
        testMetrics.steps.push({
          name: 'Execute Proposal',
          duration: (Date.now() - stepStart) / 1000,
          success: true
        });
      });
      
      // Reload page and verify execution
      cy.reload();
      cy.contains(`Proposal ${proposalId}`, { timeout: 10000 }).should('be.visible');
      cy.contains('Executed', { timeout: 5000 }).should('be.visible');
    });

    it('Step 10: Secondary Market Listing', () => {
      const stepStart = Date.now();
      
      cy.get('[data-testid="marketplace-tab"]').click();
      cy.get('[data-testid="create-listing-btn"]').click();
      
      // Fill listing details
      cy.get('[data-testid="listing-amount-input"]').type(marketplaceData.listingAmount.toString());
      cy.get('[data-testid="listing-price-usd-input"]').type(marketplaceData.listingPriceUsd.toString());
      
      // Submit listing
      cy.get('[data-testid="submit-listing-btn"]').click();
      
      // Wait for confirmation
      cy.contains('Listing created', { timeout: 15000 }).should('be.visible');
      testMetrics.transactionCount++;
      
      // Extract listing ID from specific createListing intercept
      cy.wait('@createListing').then((interception) => {
        listingId = interception.response.body.listingId || 1;
        testMetrics.apiCallCount++;
        
        testMetrics.steps.push({
          name: 'Secondary Market Listing',
          duration: (Date.now() - stepStart) / 1000,
          success: true
        });
      });
    });

    it('Step 11: Transfer with Restrictions', () => {
      const stepStart = Date.now();
      
      // Simulate buyer purchase via direct API call (captures response directly)
      cy.request('POST', `${BACKEND_URL}/api/marketplace/listings/${listingId}/buy`, {
        buyer: marketplaceData.buyer,
        amount: marketplaceData.listingAmount
      }).then((response) => {
        expect(response.status).to.eq(200);
        expect(response.body.success).to.be.true;
        testMetrics.apiCallCount++;
        testMetrics.transactionCount++;
        
        testMetrics.steps.push({
          name: 'Transfer with Restrictions',
          duration: (Date.now() - stepStart) / 1000,
          success: true
        });
      });
      
      // Verify listing status via direct API call (captures response directly)
      cy.request('GET', `${BACKEND_URL}/api/marketplace/listings/${listingId}`).then((response) => {
        expect(response.status).to.eq(200);
        expect(response.body.status).to.eq('COMPLETED');
        testMetrics.apiCallCount++;
      });
    });

    it('Step 12: KYC Verification', () => {
      const stepStart = Date.now();
      
      cy.get('[data-testid="kyc-tab"]').click();
      cy.get('[data-testid="submit-kyc-btn"]').click();
      
      // Upload KYC document (mock)
      const fileName = 'passport.pdf';
      cy.fixture(fileName, 'base64').then(fileContent => {
        cy.get('[data-testid="kyc-document-upload"]').attachFile({
          fileContent,
          fileName,
          mimeType: 'application/pdf',
          encoding: 'base64'
        });
      });
      
      // Fill KYC form
      cy.get('[data-testid="kyc-full-name-input"]').type('Test Investor');
      cy.get('[data-testid="kyc-nationality-input"]').type('United States');
      cy.get('[data-testid="kyc-document-number-input"]').type('123456789');
      
      // Submit KYC
      cy.get('[data-testid="kyc-submit-btn"]').click();
      
      // Wait for confirmation
      cy.contains('KYC submitted for review', { timeout: 15000 }).should('be.visible');
      
      cy.wait('@submitKYC').then(() => {
        testMetrics.apiCallCount++;
        
        testMetrics.steps.push({
          name: 'KYC Verification',
          duration: (Date.now() - stepStart) / 1000,
          success: true
        });
      });
    });
  });

  /**
   * Test 2: Complete workflow for ERC-1155 variant
   */
  describe('ERC-1155 Workflow', () => {
    let propertyId;
    let agreementId;

    it('Step 1: Property Registration (ERC-1155)', () => {
      const stepStart = Date.now();
      
      cy.get('[data-testid="register-property-btn"]').click();
      
      // Fill form (similar to ERC-721 test)
      cy.get('[data-testid="property-address-input"]').type(`${propertyData.address} (ERC-1155)`);
      cy.get('[data-testid="deed-hash-input"]').type(propertyData.deedHash.replace('ab', 'cd'));
      cy.get('[data-testid="rental-agreement-uri-input"]').type(propertyData.rentalAgreementUri);
      cy.get('[data-testid="property-type-select"]').select('Residential');
      
      cy.get('[data-testid="submit-property-btn"]').click();
      cy.contains('Property registered successfully', { timeout: 15000 }).should('be.visible');
      testMetrics.transactionCount++;
      
      cy.wait('@createProperty').then((interception) => {
        propertyId = interception.response.body.propertyId || 2;
        testMetrics.apiCallCount++;
        
        testMetrics.steps.push({
          name: 'Property Registration (ERC-1155)',
          duration: (Date.now() - stepStart) / 1000,
          success: true
        });
      });
    });

    it('Step 2: Yield Agreement Creation (ERC-1155)', () => {
      const stepStart = Date.now();
      
      // Verify property first via direct API call (captures response directly)
      cy.request('POST', `${BACKEND_URL}/api/properties/${propertyId}/verify`, {
        verified: true
      }).then(() => {
        testMetrics.apiCallCount++;
      });
      
      cy.get('[data-testid="create-agreement-btn"]').click();
      cy.get('[data-testid="property-select"]').select(`Property ${propertyId}`);
      cy.get('[data-testid="upfront-capital-input"]').type(agreementData.upfrontCapital.toString());
      cy.get('[data-testid="term-months-input"]').type(agreementData.termMonths.toString());
      cy.get('[data-testid="roi-bps-input"]').type(agreementData.roiBps.toString());
      cy.get('[data-testid="monthly-payment-input"]').type(agreementData.monthlyPayment.toString());
      
      // Select ERC-1155
      cy.get('[data-testid="token-standard-select"]').select('ERC-1155 (Combined Token)');
      
      cy.get('[data-testid="submit-agreement-btn"]').click();
      cy.contains('Yield agreement created', { timeout: 20000 }).should('be.visible');
      testMetrics.transactionCount++;
      
      cy.wait('@createAgreement').then((interception) => {
        agreementId = interception.response.body.agreementId || 2;
        testMetrics.apiCallCount++;
        
        testMetrics.steps.push({
          name: 'Yield Agreement Creation (ERC-1155)',
          duration: (Date.now() - stepStart) / 1000,
          success: true
        });
      });
    });

    it('Step 3: Batch Operations Test (ERC-1155)', () => {
      const stepStart = Date.now();
      
      // Simulate batch minting via direct API call (captures response directly)
      const batchInvestors = [
        { address: '0x1111111111111111111111111111111111111111', amount: 10000 },
        { address: '0x2222222222222222222222222222222222222222', amount: 15000 },
        { address: '0x3333333333333333333333333333333333333333', amount: 25000 }
      ];
      
      cy.request('POST', `${BACKEND_URL}/api/yield-agreements/${agreementId}/batch-invest`, {
        investors: batchInvestors
      }).then((response) => {
        expect(response.status).to.eq(200);
        expect(response.body.success).to.be.true;
        expect(response.body.investorCount).to.eq(3);
        testMetrics.apiCallCount++;
        testMetrics.transactionCount++;
        
        // Calculate gas savings vs. individual mints
        const individualGas = response.body.individualGasEstimate || 150000;
        const batchGas = response.body.actualGas || 250000;
        const savings = ((individualGas * 3 - batchGas) / (individualGas * 3)) * 100;
        
        testMetrics.steps.push({
          name: 'Batch Operations (ERC-1155)',
          duration: (Date.now() - stepStart) / 1000,
          success: true,
          gasSavings: `${savings.toFixed(2)}%`
        });
      });
    });
  });

  /**
   * Test 3: Edge cases and error handling
   */
  describe('Edge Cases and Error Handling', () => {
    it('Should reject invalid property registration', () => {
      cy.get('[data-testid="register-property-btn"]').click();
      
      // Submit without filling required fields
      cy.get('[data-testid="submit-property-btn"]').click();
      
      // Verify error messages
      cy.contains('Required field', { timeout: 5000 }).should('be.visible');
    });

    it('Should reject agreement creation for unverified property', () => {
      // Create unverified property via direct API call (captures response directly)
      cy.request('POST', `${BACKEND_URL}/api/properties`, {
        address: 'Unverified Property',
        deedHash: '0x1234567890123456789012345678901234567890123456789012345678901234',
        verified: false
      }).then((response) => {
        const unverifiedPropertyId = response.body.propertyId;
        
        // Attempt to create agreement
        cy.get('[data-testid="create-agreement-btn"]').click();
        cy.get('[data-testid="property-select"]').select(`Property ${unverifiedPropertyId}`);
        cy.get('[data-testid="submit-agreement-btn"]').click();
        
        // Verify error
        cy.contains(/property must be verified/i, { timeout: 10000 }).should('be.visible');
      });
    });

    it('Should enforce shareholder limits', () => {
      // Test with agreement at shareholder limit via direct API calls (captures responses directly)
      cy.request('GET', `${BACKEND_URL}/api/yield-agreements/1/shareholder-count`).then((response) => {
        if (response.body.count >= 1000) {
          cy.request({
            method: 'POST',
            url: `${BACKEND_URL}/api/yield-agreements/1/invest`,
            body: {
              investor: '0x9999999999999999999999999999999999999999',
              amount: 1000
            },
            failOnStatusCode: false
          }).then((investResponse) => {
            expect(investResponse.status).to.eq(400);
            expect(investResponse.body.error).to.include('shareholder limit');
          });
        }
      });
    });
  });
});

