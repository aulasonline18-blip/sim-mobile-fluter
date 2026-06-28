enum AppMode { laboratory, production }

class AppModeConfig {
  const AppModeConfig._();

  static const String raw = String.fromEnvironment(
    'FLUTTER_APP_MODE',
    defaultValue: 'production',
  );

  static AppMode get current => parse(raw);

  static AppMode parse(String value) {
    return switch (value.trim().toLowerCase()) {
      'production' || 'prod' => AppMode.production,
      'laboratory' || 'lab' || '' => AppMode.laboratory,
      _ => throw StateError('FLUTTER_APP_MODE invalido: $value'),
    };
  }
}

extension AppModeLabel on AppMode {
  bool get isProduction => this == AppMode.production;
}
