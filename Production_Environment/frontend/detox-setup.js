const detox = require('detox');
const {device} = require('detox');
const adapter = require('detox/runners/jest/adapter');

jest.setTimeout(120000); // 2 minutes for E2E tests

beforeAll(async () => {
  await detox.init(); // Initialize Detox and connect to device/emulator
});

beforeEach(async () => {
  await device.reloadReactNative(); // Reset app state before each test
});

afterAll(async () => {
  await detox.cleanup(); // Cleanup Detox resources
});
// This setup file initializes Detox before E2E tests, resets app state between tests for isolation, and configures appropriate timeouts for mobile emulator testing in Docker environment.



