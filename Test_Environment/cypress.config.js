const { defineConfig } = require('cypress');
const fs = require('fs');
const path = require('path');

module.exports = defineConfig({
  e2e: {
    setupNodeEvents(on, config) {
      // Enable code coverage tracking
      require('@cypress/code-coverage/task')(on, config);
      
      // Custom task for metrics logging
      on('task', {
        logMetrics(metrics) {
          const metricsFile = path.join(__dirname, 'test-results', 'e2e-metrics.json');
          
          // Ensure test-results directory exists
          const testResultsDir = path.join(__dirname, 'test-results');
          if (!fs.existsSync(testResultsDir)) {
            fs.mkdirSync(testResultsDir, { recursive: true });
          }
          
          // Append metrics to JSON file
          let existingMetrics = [];
          if (fs.existsSync(metricsFile)) {
            try {
              const fileContent = fs.readFileSync(metricsFile, 'utf8');
              existingMetrics = JSON.parse(fileContent);
            } catch (error) {
              console.warn('Warning: Could not parse existing metrics file, creating new one');
              existingMetrics = [];
            }
          }
          
          existingMetrics.push({
            ...metrics,
            timestamp: new Date().toISOString()
          });
          
          fs.writeFileSync(metricsFile, JSON.stringify(existingMetrics, null, 2));
          
          console.log(`\n📊 Test Metrics Logged:`);
          console.log(`   Duration: ${metrics.duration}s`);
          console.log(`   API Calls: ${metrics.apiCallCount}`);
          console.log(`   Transactions: ${metrics.transactionCount}`);
          console.log(`   Steps Completed: ${metrics.steps?.length || 0}\n`);
          
          return null;
        },
        
        // Custom task for logging individual step metrics
        logStepMetric(stepData) {
          const stepMetricsFile = path.join(__dirname, 'test-results', 'step-metrics.json');
          
          const testResultsDir = path.join(__dirname, 'test-results');
          if (!fs.existsSync(testResultsDir)) {
            fs.mkdirSync(testResultsDir, { recursive: true });
          }
          
          let existingSteps = [];
          if (fs.existsSync(stepMetricsFile)) {
            try {
              const fileContent = fs.readFileSync(stepMetricsFile, 'utf8');
              existingSteps = JSON.parse(fileContent);
            } catch (error) {
              existingSteps = [];
            }
          }
          
          existingSteps.push({
            ...stepData,
            timestamp: new Date().toISOString()
          });
          
          fs.writeFileSync(stepMetricsFile, JSON.stringify(existingSteps, null, 2));
          
          return null;
        },
        
        // Custom task for clearing old metrics
        clearMetrics() {
          const metricsFile = path.join(__dirname, 'test-results', 'e2e-metrics.json');
          const stepMetricsFile = path.join(__dirname, 'test-results', 'step-metrics.json');
          
          if (fs.existsSync(metricsFile)) {
            fs.unlinkSync(metricsFile);
          }
          if (fs.existsSync(stepMetricsFile)) {
            fs.unlinkSync(stepMetricsFile);
          }
          
          console.log('✓ Metrics files cleared');
          return null;
        }
      });
      
      return config;
    },
    
    // Base URL for Test Environment frontend
    baseUrl: 'http://rwa-test-frontend:5173',
    
    // Spec pattern for E2E tests
    specPattern: 'cypress/e2e/**/*.cy.{js,jsx,ts,tsx}',
    
    // Support file
    supportFile: 'cypress/support/e2e.js',
    
    // Video recording
    video: true,
    videosFolder: 'test-results/videos',
    videoCompression: 32,
    
    // Screenshots on failure
    screenshotOnRunFailure: true,
    screenshotsFolder: 'test-results/screenshots',
    
    // Timeouts (increased for blockchain transactions)
    defaultCommandTimeout: 15000, // 15 seconds
    requestTimeout: 20000, // 20 seconds for API requests
    responseTimeout: 20000, // 20 seconds for API responses
    pageLoadTimeout: 30000, // 30 seconds for page loads
    
    // Viewport settings
    viewportWidth: 1280,
    viewportHeight: 720,
    
    // Retry configuration
    retries: {
      runMode: 2, // Retry failed tests 2 times in CI
      openMode: 0 // No retries in interactive mode
    },
    
    // Environment variables
    env: {
      backendUrl: 'http://rwa-test-backend:8000',
      frontendUrl: 'http://rwa-test-frontend:5173',
      coverageEnabled: true
    },
    
    // Experimental features
    experimentalStudio: false,
    experimentalWebKitSupport: false,
    
    // Additional configuration
    chromeWebSecurity: false, // Disable for cross-origin testing
    watchForFileChanges: false,
    
    // Test isolation
    testIsolation: true,
    
    // Exclude patterns
    excludeSpecPattern: [
      '**/examples/**',
      '**/__snapshots__/**'
    ]
  },
  
  // Component testing configuration (if needed in future)
  component: {
    devServer: {
      framework: 'react',
      bundler: 'vite'
    },
    specPattern: 'src/**/*.cy.{js,jsx,ts,tsx}',
    supportFile: 'cypress/support/component.js'
  }
});

