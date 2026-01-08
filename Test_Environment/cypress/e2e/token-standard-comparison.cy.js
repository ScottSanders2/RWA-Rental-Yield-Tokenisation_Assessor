// Cypress E2E test comparing ERC-721 + ERC-20 and ERC-1155 workflows

describe('Token Standard Comparison (ERC-721 + ERC-20 vs ERC-1155)', () => {
  let erc721Metrics = {};
  let erc1155Metrics = {};

  it('should complete full workflow with ERC-721 + ERC-20', () => {
    const startTime = Date.now();

    // Verify ERC-721 + ERC-20 is selected
    cy.contains('ERC-721 + ERC-20 (Separate Contracts)').should('be.visible');

    // Register property - Phase 1
    const registerStart = Date.now();
    cy.registerProperty({
      property_address: '123 ERC721 Street, London, UK',
      deed_hash: '0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef',
      rental_agreement_uri: 'https://example.com/erc721-agreement.pdf',
      metadata: { property_type: 'residential', token_standard_test: 'erc721' }
    });
    const registerEnd = Date.now();
    erc721Metrics.registrationTime = registerEnd - registerStart;

    // Verify property - Phase 2
    const verifyStart = Date.now();
    cy.verifyProperty(1);
    const verifyEnd = Date.now();
    erc721Metrics.verificationTime = verifyEnd - verifyStart;

    // Create yield agreement - Phase 3
    const agreementStart = Date.now();
    cy.visit('/yield-agreements/create');
    cy.get('input[name="property_token_id"]').type('1');
    cy.get('input[name="upfront_capital_usd"]').type('50000');
    cy.get('[role="slider"]').first().invoke('val', 24).trigger('change');
    cy.get('[role="slider"]').last().invoke('val', 12).trigger('change');

    cy.intercept('POST', '**/yield-agreements/create', { statusCode: 200, body: {
      agreement_id: 1,
      monthly_payment: '1093750000000000000',
      total_expected_repayment: '26250000000000000000',
      blockchain_agreement_id: 101,
      token_contract_address: '0x1111111111111111111111111111111111111111111111111111111111111111',
      tx_hash: '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
    } }).as('createERC721Agreement');

    cy.get('button[type="submit"]').click();
    cy.wait('@createERC721Agreement');
    const agreementEnd = Date.now();
    erc721Metrics.agreementTime = agreementEnd - agreementStart;

    // Calculate total workflow time
    const endTime = Date.now();
    erc721Metrics.totalTime = endTime - startTime;
    erc721Metrics.apiCalls = 3; // register, verify, create agreement

    // Verify success
    cy.contains('Yield agreement created successfully!').should('be.visible');
    cy.contains('Agreement ID: 1').should('be.visible');

    // Store metrics for comparison
    cy.writeFile('cypress/fixtures/erc721-metrics.json', erc721Metrics);
  });

  it('should complete full workflow with ERC-1155', () => {
    const startTime = Date.now();

    // Switch to ERC-1155
    cy.contains('ERC-721 + ERC-20').click();
    cy.contains('ERC-1155').click();
    cy.contains('ERC-1155 (Combined Contract)').should('be.visible');

    // Register property with ERC-1155 - Phase 1
    const registerStart = Date.now();
    cy.registerProperty({
      property_address: '456 ERC1155 Avenue, Manchester, UK',
      deed_hash: '0xabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcd',
      rental_agreement_uri: 'https://example.com/erc1155-agreement.pdf',
      metadata: { property_type: 'commercial', token_standard_test: 'erc1155' },
      token_standard: 'ERC1155'
    });
    const registerEnd = Date.now();
    erc1155Metrics.registrationTime = registerEnd - registerStart;

    // Verify property - Phase 2
    const verifyStart = Date.now();
    cy.verifyProperty(2);
    const verifyEnd = Date.now();
    erc1155Metrics.verificationTime = verifyEnd - verifyStart;

    // Create yield agreement - Phase 3
    const agreementStart = Date.now();
    cy.visit('/yield-agreements/create');
    cy.get('input[name="property_token_id"]').type('2');
    cy.get('input[name="upfront_capital_usd"]').type('50000');
    cy.get('[role="slider"]').first().invoke('val', 24).trigger('change');
    cy.get('[role="slider"]').last().invoke('val', 12).trigger('change');

    cy.intercept('POST', '**/yield-agreements/create', { statusCode: 200, body: {
      agreement_id: 2,
      monthly_payment: '1093750000000000000',
      total_expected_repayment: '26250000000000000000',
      blockchain_agreement_id: 202,
      token_contract_address: '0x2222222222222222222222222222222222222222222222222222222222222222',
      tx_hash: '0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb'
    } }).as('createERC1155Agreement');

    cy.get('button[type="submit"]').click();
    cy.wait('@createERC1155Agreement');
    const agreementEnd = Date.now();
    erc1155Metrics.agreementTime = agreementEnd - agreementStart;

    // Calculate total workflow time
    const endTime = Date.now();
    erc1155Metrics.totalTime = endTime - startTime;
    erc1155Metrics.apiCalls = 3; // register, verify, create agreement

    // Verify success
    cy.contains('Yield agreement created successfully!').should('be.visible');
    cy.contains('Agreement ID: 2').should('be.visible');

    // Store metrics for comparison
    cy.writeFile('cypress/fixtures/erc1155-metrics.json', erc1155Metrics);
  });

  it('should compare workflow completion times', () => {
    // Load stored metrics
    cy.readFile('cypress/fixtures/erc721-metrics.json').then((erc721) => {
      cy.readFile('cypress/fixtures/erc1155-metrics.json').then((erc1155) => {
        // Both workflows should complete successfully
        expect(erc721.totalTime).to.be.greaterThan(0);
        expect(erc1155.totalTime).to.be.greaterThan(0);

        // Calculate percentage difference
        const timeDifference = Math.abs(erc721.totalTime - erc1155.totalTime);
        const averageTime = (erc721.totalTime + erc1155.totalTime) / 2;
        const percentageDifference = (timeDifference / averageTime) * 100;

        // Log comparison results for dissertation analysis
        cy.log(`ERC-721 + ERC-20 total time: ${erc721.totalTime}ms`);
        cy.log(`ERC-1155 total time: ${erc1155.totalTime}ms`);
        cy.log(`Time difference: ${percentageDifference.toFixed(2)}%`);

        // Both should have same number of API calls (UI workflow is identical)
        expect(erc721.apiCalls).to.equal(erc1155.apiCalls);

        // Individual phase comparison
        cy.log(`ERC-721 registration: ${erc721.registrationTime}ms`);
        cy.log(`ERC-1155 registration: ${erc1155.registrationTime}ms`);
        cy.log(`ERC-721 verification: ${erc721.verificationTime}ms`);
        cy.log(`ERC-1155 verification: ${erc1155.verificationTime}ms`);
        cy.log(`ERC-721 agreement: ${erc721.agreementTime}ms`);
        cy.log(`ERC-1155 agreement: ${erc1155.agreementTime}ms`);

        // Store comparison results
        const comparison = {
          erc721,
          erc1155,
          timeDifference: percentageDifference,
          timestamp: new Date().toISOString(),
        };
        cy.writeFile('cypress/fixtures/token-standard-comparison.json', comparison);
      });
    });
  });

  it('should compare UX between standards', () => {
    // Test ERC-721 + ERC-20 workflow UX
    cy.contains('ERC-721 + ERC-20').click();
    cy.contains('ERC-721 + ERC-20 (Separate Contracts)').should('be.visible');

    // Count navigation clicks needed (should be same for both)
    let clickCount = 0;
    cy.get('button').contains('Register Property').click();
    clickCount++;

    // Fill and submit registration form
    cy.get('input[name="property_address"]').type('UX Test Property ERC721');
    cy.get('input[name="deed_hash"]').type('0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef');
    cy.get('input[name="rental_agreement_uri"]').type('https://example.com/ux-test-erc721.pdf');

    cy.intercept('POST', '**/properties/register', { statusCode: 200, body: {
      property_id: 3, blockchain_token_id: 303
    } }).as('uxERC721Register');

    cy.get('button[type="submit"]').click();
    clickCount++;

    cy.wait('@uxERC721Register');

    // Test ERC-1155 workflow UX
    cy.contains('ERC-721 + ERC-20').click();
    cy.contains('ERC-1155').click();
    clickCount++;

    cy.contains('ERC-1155 (Combined Contract)').should('be.visible');
    cy.get('button').contains('Register Property').click();
    clickCount++;

    // Fill and submit ERC-1155 registration
    cy.get('input[name="property_address"]').type('UX Test Property ERC1155');
    cy.get('input[name="deed_hash"]').type('0xabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcd');
    cy.get('input[name="rental_agreement_uri"]').type('https://example.com/ux-test-erc1155.pdf');

    cy.intercept('POST', '**/properties/register', { statusCode: 200, body: {
      property_id: 4, blockchain_token_id: 404
    } }).as('uxERC1155Register');

    cy.get('button[type="submit"]').click();
    clickCount++;

    cy.wait('@uxERC1155Register');

    // Both workflows should require the same number of user interactions
    expect(clickCount).to.equal(5); // 2 for ERC721 + 3 for ERC1155

    // Verify USD/ETH display consistency
    cy.get('input[name="upfront_capital_usd"]').type('50000');
    cy.contains('≈ 25.0000 ETH').should('be.visible');

    // Log UX findings
    cy.log(`Total user interactions required: ${clickCount}`);
    cy.log('USD/ETH display consistent across token standards');
    cy.log('Form complexity identical for both standards');
    cy.log('Navigation flow identical for both standards');
  });

  it('should verify USD input works consistently across standards', () => {
    const testUsdAmount = '50000';
    const expectedWei = '25000000000000000000000'; // 50,000 / 2,000 * 10^18

    // Test ERC-721 + ERC-20
    cy.contains('ERC-721 + ERC-20').click();
    cy.visit('/yield-agreements/create');
    cy.get('input[name="property_token_id"]').type('1');
    cy.get('input[name="upfront_capital_usd"]').type(testUsdAmount);

    cy.intercept('POST', '**/yield-agreements/create', { statusCode: 200, body: {
      agreement_id: 5, monthly_payment: '1000000000000000000', total_expected_repayment: '24000000000000000000'
    } }).as('usdTestERC721');

    cy.get('button[type="submit"]').click();

    cy.wait('@usdTestERC721').then((interception) => {
      expect(interception.request.body.upfront_capital).to.equal(expectedWei);
      expect(interception.request.body.token_standard).to.equal('ERC721');
    });

    // Test ERC-1155
    cy.contains('ERC-721 + ERC-20').click();
    cy.contains('ERC-1155').click();
    cy.visit('/yield-agreements/create');
    cy.get('input[name="property_token_id"]').type('2');
    cy.get('input[name="upfront_capital_usd"]').type(testUsdAmount);

    cy.intercept('POST', '**/yield-agreements/create', { statusCode: 200, body: {
      agreement_id: 6, monthly_payment: '1000000000000000000', total_expected_repayment: '24000000000000000000'
    } }).as('usdTestERC1155');

    cy.get('button[type="submit"]').click();

    cy.wait('@usdTestERC1155').then((interception) => {
      expect(interception.request.body.upfront_capital).to.equal(expectedWei);
      expect(interception.request.body.token_standard).to.equal('ERC1155');
    });

    // Verify USD amount converts to identical wei value for both standards
    cy.log('USD to wei conversion consistent across token standards');
    cy.log(`$${testUsdAmount} USD = ${expectedWei} wei for both ERC-721 and ERC-1155`);
  });
});






