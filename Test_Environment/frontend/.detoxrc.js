module.exports = {
  testRunner: {
    args: {
      $0: 'jest',
      config: 'jest.config.detox.js',
    },
    jest: {
      setupTimeout: 120000,
    },
  },
  apps: {
    'android.debug': {
      type: 'android.apk',
      binaryPath: 'android/app/build/outputs/apk/debug/app-debug.apk',
      build: 'cd android && ./gradlew assembleDebug assembleAndroidTest -DtestBuildType=debug',
    },
    'ios.debug': {
      type: 'ios.app',
      binaryPath: 'eas-build-output/RWATokenizationPlatform.app',
      build: 'E2E_TEST_MODE=1 eas build --profile detox-debug --platform ios --local --non-interactive',
    },
    'ios.release': {
      type: 'ios.app',
      binaryPath: 'RWATokenizationPlatform.app',
      build: 'E2E_TEST_MODE=1 eas build --profile detox --platform ios --local --non-interactive',
    },
  },
  devices: {
    emulator: {
      type: 'android.emulator',
      device: {
        avdName: 'Pixel_4_API_30',
      },
    },
    simulator: {
      type: 'ios.simulator',
      device: {
        // Test environment using standard iPhone 16 Pro (has working file picker with dummy files)
        // UDID: 87B76ECF-886E-4C75-8CA2-C150E634043D
        type: 'iPhone 16 Pro',
        id: '87B76ECF-886E-4C75-8CA2-C150E634043D',
      },
    },
  },
  configurations: {
    'android.emu.debug': {
      device: 'emulator',
      app: 'android.debug',
    },
    'ios.sim.debug': {
      device: 'simulator',
      app: 'ios.debug',
    },
    'ios.sim.release': {
      device: 'simulator',
      app: 'ios.release',
    },
  },
};
// Detox configuration enables automated E2E testing on Android emulator in Docker container, mirroring Cypress workflows for mobile platform, and tracking UX metrics (task completion rates, response times) for dissertation comparative analysis between web and mobile UX.



