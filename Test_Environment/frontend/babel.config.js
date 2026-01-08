module.exports = function (api) {
  api.cache(true);
  return {
    presets: ['babel-preset-expo'],
    plugins: [
      'react-native-paper/babel',
      [
        'module:react-native-dotenv',
        {
          moduleName: '@env',
          path: '.env.mobile',
          safe: false,
          allowUndefined: true,
        },
      ],
    ],
  };
};
// Babel configuration enables React Native JSX transformation, React Native Paper component optimization, and environment variable injection for API_BASE_URL and WALLETCONNECT_PROJECT_ID configuration via react-native-dotenv.


