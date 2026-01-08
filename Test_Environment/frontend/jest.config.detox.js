module.exports = {
  preset: 'react-native',
  testEnvironment: 'detox/runners/jest/testEnvironment',
  testRunner: 'jest-circus/runner',
  testMatch: [
    '**/__tests__/**/*.detox.js',
    '**/*.detox.test.js',
  ],
  globalSetup: 'detox/runners/jest/globalSetup',
  globalTeardown: 'detox/runners/jest/globalTeardown',
  testTimeout: 120000, // 2 minutes for E2E tests
  maxWorkers: 1, // CRITICAL: Run tests serially to prevent Mac resource strain (4 simulators = system overload)
  reporters: [
    'default',
    [
      'jest-junit',
      {
        outputDirectory: './test-results',
        outputName: 'detox-results.xml',
      },
    ],
  ],
  verbose: true, // Detailed logging
};
// This Jest configuration is specifically for Detox E2E tests (separate from component tests), uses Node environment for Detox device control, and generates test reports for dissertation metrics collection.



