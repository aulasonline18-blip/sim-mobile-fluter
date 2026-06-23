class SupabasePublicConfig {
  const SupabasePublicConfig({
    required this.url,
    required this.publishableKey,
  });

  final String url;
  final String publishableKey;

  void validate() {
    if (url.trim().isEmpty || publishableKey.trim().isEmpty) {
      throw StateError(
        'Missing Supabase public config. Use only URL and publishable key in the app.',
      );
    }
  }
}

class SupabaseSession {
  const SupabaseSession({required this.accessToken, required this.userId});

  final String accessToken;
  final String userId;
}

abstract interface class SupabaseSessionProvider {
  Future<SupabaseSession?> currentSession();
}

class AuthMiddlewareContract {
  const AuthMiddlewareContract();

  Map<String, String> bearerHeaders(SupabaseSession session) => {
        'Authorization': 'Bearer ${session.accessToken}',
      };
}
