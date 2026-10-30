class ApiUrls {
  // Configurable at compile time via --dart-define=API_BASE_URL=http://...
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8081',
  );

  static const String webSocketbaseUrl = String.fromEnvironment(
    'WS_BASE_URL',
    defaultValue: 'ws://localhost:8081',
  );
}