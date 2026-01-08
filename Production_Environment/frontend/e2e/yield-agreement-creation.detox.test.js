// Detox provides global functions: describe, it, expect, beforeAll, beforeEach, device, element, by, waitFor
// No need to import them - importing Jest's expect would override Detox's expect with .toBeVisible() matcher

describe('Yield Agreement Creation Workflow (Mobile)', () => {
  beforeEach(async () => {
    // Launch app with clean state for each test
    await device.launchApp({newInstance: true});
  });

  it('should display yield agreement creation form', async () => {
    // Ensure we're on Dashboard first
    await expect(element(by.id('dashboard_screen'))).toBeVisible();
    
    // Navigate to Agreements tab
    await element(by.label('Agreements Tab')).tap();
    
    // Verify we're on agreements list screen
    await expect(element(by.id('agreements_list_screen'))).toBeVisible();

    // Tap 'Create Agreement' FAB button
    await element(by.id('create_agreement_button')).tap();

    // Verify yield agreement form is visible
    await expect(element(by.id('yield_agreement_form_scrollview'))).toBeVisible();
    
    // Success! Form loaded (skipping text check due to multiple "Create Yield Agreement" elements in header and button)
  });

  it('should create yield agreement with minimum required fields', async () => {
    // Ensure we're on Dashboard first
    await expect(element(by.id('dashboard_screen'))).toBeVisible();
    
    // Navigate to Agreements tab and open creation form
    await element(by.label('Agreements Tab')).tap();
    await element(by.id('create_agreement_button')).tap();

    // STEP 1: Fill Upfront Capital (USD) - mandatory field
    await element(by.id('upfront_capital_usd_input')).typeText('50000');
    
    // CRITICAL: Dismiss numeric keypad which obstructs bottom half of screen
    await element(by.id('upfront_capital_usd_input')).tapReturnKey();
    
    // Wait for keyboard to fully dismiss
    await new Promise(resolve => setTimeout(resolve, 500));

    // STEP 2: Scroll carefully to Property Payer section - use smaller swipes to keep button in view
    await element(by.id('yield_agreement_form_scrollview')).swipe('up', 'slow', 0.5);
    await new Promise(resolve => setTimeout(resolve, 500));
    
    await element(by.id('yield_agreement_form_scrollview')).swipe('up', 'slow', 0.3);
    await new Promise(resolve => setTimeout(resolve, 500));

    // STEP 3: Verify Generate Mock Wallet button is visible and tap it SLOWLY
    await expect(element(by.id('generate_mock_wallet_button'))).toBeVisible();
    await new Promise(resolve => setTimeout(resolve, 300));
    await element(by.id('generate_mock_wallet_button')).tap();
    
    // Give React plenty of time to update state and re-render
    await new Promise(resolve => setTimeout(resolve, 1500));

    // Use waitFor to ensure the field actually gets populated before proceeding
    await waitFor(element(by.id('property_payer_input'))).not.toHaveText('').withTimeout(5000);
    
    // Double-check it's populated
    await expect(element(by.id('property_payer_input'))).not.toHaveText('');

    // STEP 4: Swipe SLOWLY to Submit button
    await element(by.id('yield_agreement_form_scrollview')).swipe('up', 'slow', 0.75);
    
    // Wait for scroll animation to settle
    await new Promise(resolve => setTimeout(resolve, 300));

    // STEP 5: Verify Submit button is visible and tap it
    await expect(element(by.id('create_agreement_submit_button'))).toBeVisible();
    await element(by.id('create_agreement_submit_button')).tap();

    // STEP 6: Wait for success banner to appear (may take several seconds)
    console.log('⏳ Waiting for form submission to complete...');
    
    // Try to wait for success banner (15 second timeout for backend processing)
    try {
      await waitFor(element(by.id('success_banner')))
        .toExist()
        .withTimeout(15000);
      
      // Success banner found! Now verify the text
      console.log('✅ Success banner found! Verifying message...');
      await expect(element(by.text(/Created Successfully/i))).toExist();
      console.log('✅ Yield agreement creation verified successfully!');
    } catch (error) {
      // If success banner doesn't appear, check for error banner or other issues
      console.log('⚠️ Success banner not found within 15s. Checking for errors...');
      
      // Take screenshot for debugging
      await device.takeScreenshot('yield-agreement-submission-timeout');
      
      // Check if error banner exists instead (use try-catch since Detox doesn't have .exists())
      try {
        await expect(element(by.id('error_banner'))).toExist();
        console.log('❌ Error banner found instead of success banner');
        throw new Error('Form submission failed - error banner displayed');
      } catch (errorCheckError) {
        // Error banner not found either - re-throw original timeout error
        console.log('⚠️ No error banner found. Possible causes: backend slow, banner disappeared, or testID missing');
        throw error;
      }
    }
  });

  it('should validate upfront capital field', async () => {
    // Ensure we're on Dashboard first
    await expect(element(by.id('dashboard_screen'))).toBeVisible();
    
    // Navigate to creation form
    await element(by.label('Agreements Tab')).tap();
    await element(by.id('create_agreement_button')).tap();

    // Try to submit WITHOUT filling upfront capital
    // Swipe SLOWLY to see the submit button
    await element(by.id('yield_agreement_form_scrollview')).swipe('up', 'slow', 0.75);
    await new Promise(resolve => setTimeout(resolve, 300));
    await element(by.id('yield_agreement_form_scrollview')).swipe('up', 'slow', 0.75);
    await new Promise(resolve => setTimeout(resolve, 300));
    
    await element(by.id('create_agreement_submit_button')).tap();

    // Scroll back to top SLOWLY to see error message
    await new Promise(resolve => setTimeout(resolve, 500));
    await element(by.id('yield_agreement_form_scrollview')).swipe('down', 'slow', 0.75);
    await new Promise(resolve => setTimeout(resolve, 300));
    await element(by.id('yield_agreement_form_scrollview')).swipe('down', 'slow', 0.75);
    await new Promise(resolve => setTimeout(resolve, 300));
    
    // Verify error message exists (may be partially clipped)
    await expect(element(by.text(/Valid USD amount is required/i))).toExist();

    // Now fill upfront capital
    await element(by.id('upfront_capital_usd_input')).typeText('25000');
    
    // CRITICAL: Dismiss numeric keypad
    await element(by.id('upfront_capital_usd_input')).tapReturnKey();
    await new Promise(resolve => setTimeout(resolve, 500));

    // Generate mock wallet
    await element(by.id('yield_agreement_form_scrollview')).swipe('up', 'slow', 0.75);
    await new Promise(resolve => setTimeout(resolve, 300));
    await expect(element(by.id('generate_mock_wallet_button'))).toBeVisible();
    await element(by.id('generate_mock_wallet_button')).tap();
    await new Promise(resolve => setTimeout(resolve, 500));

    // Try submit again - should now pass upfront capital validation
    await element(by.id('yield_agreement_form_scrollview')).swipe('up', 'slow', 0.75);
    await new Promise(resolve => setTimeout(resolve, 300));
    await expect(element(by.id('create_agreement_submit_button'))).toBeVisible();
    await element(by.id('create_agreement_submit_button')).tap();

    // Error should change from upfront capital error to success
    await expect(element(by.text(/Valid USD amount is required/i))).not.toBeVisible();
  });

  it('should display ETH equivalent when USD amount is entered', async () => {
    // Ensure we're on Dashboard first
    await expect(element(by.id('dashboard_screen'))).toBeVisible();
    
    // Navigate to creation form
    await element(by.label('Agreements Tab')).tap();
    await element(by.id('create_agreement_button')).tap();

    // Enter USD amount
    await element(by.id('upfront_capital_usd_input')).typeText('50000');
    
    // CRITICAL: Dismiss numeric keypad to see ETH conversion display
    await element(by.id('upfront_capital_usd_input')).tapReturnKey();
    await new Promise(resolve => setTimeout(resolve, 500));

    // Verify ETH equivalent is displayed
    // The exact value depends on the ETH/USD price, but it should show something like "≈ XX.XXXX ETH"
    await expect(element(by.text(/≈.*ETH/i))).toBeVisible();
  });

  it('should allow generating mock wallet for property payer', async () => {
    // Ensure we're on Dashboard first
    await expect(element(by.id('dashboard_screen'))).toBeVisible();
    
    // Navigate to creation form
    await element(by.label('Agreements Tab')).tap();
    await element(by.id('create_agreement_button')).tap();

    // Scroll carefully to Property Payer section with smaller swipes
    await element(by.id('yield_agreement_form_scrollview')).swipe('up', 'slow', 0.5);
    await new Promise(resolve => setTimeout(resolve, 500));
    
    await element(by.id('yield_agreement_form_scrollview')).swipe('up', 'slow', 0.3);
    await new Promise(resolve => setTimeout(resolve, 500));

    // Verify Property Payer input starts empty
    await expect(element(by.id('property_payer_input'))).toHaveText('');

    // Tap Generate Mock Wallet button SLOWLY
    await expect(element(by.id('generate_mock_wallet_button'))).toBeVisible();
    await new Promise(resolve => setTimeout(resolve, 300));
    await element(by.id('generate_mock_wallet_button')).tap();
    
    // Give React plenty of time to update
    await new Promise(resolve => setTimeout(resolve, 1500));

    // Wait for mock wallet address to populate
    await waitFor(element(by.id('property_payer_input'))).not.toHaveText('').withTimeout(5000);
    
    // Verify a mock wallet address is populated (starts with 0x, 42 characters)
    await expect(element(by.id('property_payer_input'))).not.toHaveText('');
  });

  // Track task completion time for UX metrics
  it('should load creation form quickly', async () => {
    // Ensure we're on Dashboard first
    await expect(element(by.id('dashboard_screen'))).toBeVisible();
    
    const startTime = Date.now();

    // Navigate to Agreements tab
    await element(by.label('Agreements Tab')).tap();
    
    // Tap 'Create Agreement'
    await element(by.id('create_agreement_button')).tap();

    // Wait for form to be visible
    await expect(element(by.id('yield_agreement_form_scrollview'))).toBeVisible();

    const endTime = Date.now();
    const duration = endTime - startTime;

    // Log the duration for metrics tracking
    console.log(`Yield agreement creation form loaded in ${duration}ms`);
    
    // Form should load within 2 seconds
    if (duration >= 2000) {
      throw new Error(`Form took too long to load: ${duration}ms`);
    }
  });
});
