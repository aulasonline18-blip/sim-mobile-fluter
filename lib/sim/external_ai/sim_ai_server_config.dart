import 'package:flutter/foundation.dart';

typedef SimAccessTokenProvider = Future<String?> Function();

class SimAiServerConfig {
  const SimAiServerConfig({
    required this.baseUrl,
    this.accessTokenProvider,
    this.t00Path,
    this.t02Path,
  });

  final String baseUrl;
  final SimAccessTokenProvider? accessTokenProvider;
  final String? t00Path;
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
    final trimmed = (token ?? '').trim();
    debugPrint('[SIM_CFG] jsonHeaders baseUrl=$baseUrl tokenPresent=${trimmed.isNotEmpty}');
    return {
      'content-type': 'application/json',
      'accept': 'application/json',
      if (trimmed.isNotEmpty) 'authorization': 'Bearer $trimmed',
    };
  }

  Future<Map<String, String>> streamHeaders() async {
    final token = await accessTokenProvider?.call();
    final trimmed = (token ?? '').trim();
    debugPrint('[SIM_CFG] streamHeaders baseUrl=$baseUrl tokenPresent=${trimmed.isNotEmpty}');
    return {
      'content-type': 'application/json',
      'accept': 'text/event-stream',
      if (trimmed.isNotEmpty) 'authorization': 'Bearer $trimmed',
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
