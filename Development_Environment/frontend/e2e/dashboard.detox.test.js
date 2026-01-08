describe('Dashboard (Mobile)', () => {
  beforeAll(async () => {
    await device.launchApp({
      newInstance: true,
      launchArgs: {
        detoxPrintBusyIdleResources: 'YES',
      },
    });
  });

  it('should display dashboard screen on launch', async () => {
    // Verify dashboard screen is visible
    await expect(element(by.id('dashboard_screen'))).toBeVisible();
  });

  it('should display wallet connection banner', async () => {
    // Verify connection banner is visible when wallet not connected
    await expect(element(by.text('Connect your wallet to get started'))).toBeVisible();
  });

  it('should display connect wallet button', async () => {
    // Verify connect wallet button is visible
    await expect(element(by.id('connect_wallet_button'))).toBeVisible();
  });
});




