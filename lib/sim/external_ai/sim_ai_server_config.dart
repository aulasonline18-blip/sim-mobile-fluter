typedef SimAccessTokenProvider = Future<String?> Function();

class SimAiServerConfig {
  const SimAiServerConfig({
    required this.baseUrl,
    this.accessTokenProvider,
    this.t02Path,
  });

  final String baseUrl;
  final SimAccessTokenProvider? accessTokenProvider;
  final String? t02Path;

  Uri uri(String path) {
    final cleanBase = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final cleanPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$cleanBase$cleanPath');
  }

  Future<Map<String, String>> jsonHeaders() async {
    final token = await accessTokenProvider?.call();
    return {
      'content-type': 'application/json',
      'accept': 'application/json',
      if (token != null && token.trim().isNotEmpty)
        'authorization': 'Bearer ${token.trim()}',
    };
  }

  Future<Map<String, String>> streamHeaders() async {
    final token = await accessTokenProvider?.call();
    return {
      'content-type': 'application/json',
      'accept': 'text/event-stream',
      if (token != null && token.trim().isNotEmpty)
        'authorization': 'Bearer ${token.trim()}',
    };
  }
}

class SimExternalAiException implements Exception {
  const SimExternalAiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() {
    final status = statusCode == null ? '' : ' HTTP $statusCode';
    return 'SimExternalAiException$status: $message';
  }
}
