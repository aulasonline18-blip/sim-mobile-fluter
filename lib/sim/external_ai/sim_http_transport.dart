import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

class SimHttpResponse {
  const SimHttpResponse({
    required this.statusCode,
    required this.body,
    this.headers = const {},
  });

  final int statusCode;
  final String body;
  final Map<String, String> headers;

  bool get ok => statusCode >= 200 && statusCode < 300;
}

abstract interface class SimHttpTransport {
  Future<SimHttpResponse> postJson(
    Uri uri, {
    required Map<String, String> headers,
    required Object? body,
    Duration timeout,
  });

  Stream<String> postEventStream(
    Uri uri, {
    required Map<String, String> headers,
    required Object? body,
    Duration timeout,
  });

  Future<SimHttpResponse> postMultipart(
    Uri uri, {
    required Map<String, String> headers,
    required String fieldName,
    required String filename,
    required String contentType,
    required List<int> bytes,
    Duration timeout,
  });
}

class DartIoSimHttpTransport implements SimHttpTransport {
  DartIoSimHttpTransport({HttpClient? client})
    : client = client ?? HttpClient(),
      _ownsClient = client == null;

  final HttpClient client;
  final bool _ownsClient;

  void dispose() {
    if (_ownsClient) {
      client.close(force: true);
    }
  }

  @override
  Future<SimHttpResponse> postJson(
    Uri uri, {
    required Map<String, String> headers,
    required Object? body,
    Duration timeout = const Duration(seconds: 45),
  }) async {
    debugPrint('[SIM_HTTP] postJson → $uri | tokenPresent=${headers.containsKey('authorization')}');
    HttpClientRequest? request;
    try {
      request = await client.postUrl(uri).timeout(timeout);
      debugPrint('[SIM_HTTP] postJson tcp abriu');
      headers.forEach(request.headers.set);
      debugPrint('[SIM_HTTP] postJson headers ok');
      final encoded = utf8.encode(jsonEncode(body));
      debugPrint('[SIM_HTTP] postJson body encoded ${encoded.length} bytes');
      request.headers.set('content-length', encoded.length.toString());
      request.add(encoded);
      debugPrint('[SIM_HTTP] postJson body escrito, fechando');
      final response = await request.close().timeout(timeout);
      debugPrint('[SIM_HTTP] postJson status ${response.statusCode}');
      final text = await utf8.decoder.bind(response).join().timeout(timeout);
      if (response.statusCode >= 400) {
        debugPrint('[SIM_HTTP] postJson erro ${response.statusCode}: ${text.length > 500 ? text.substring(0, 500) : text}');
      }
      final outHeaders = <String, String>{};
      response.headers.forEach((name, values) {
        outHeaders[name] = values.join(',');
      });
      return SimHttpResponse(
        statusCode: response.statusCode,
        body: text,
        headers: outHeaders,
      );
    } catch (e, st) {
      debugPrint('[SIM_HTTP] postJson ERRO em $uri: $e');
      debugPrint('[SIM_HTTP] postJson stacktrace: $st');
      rethrow;
    }
  }

  @override
  Stream<String> postEventStream(
    Uri uri, {
    required Map<String, String> headers,
    required Object? body,
    Duration timeout = const Duration(seconds: 140),
  }) async* {
    debugPrint('[SIM_HTTP] postEventStream → $uri | tokenPresent=${headers.containsKey('authorization')}');
    final HttpClientResponse response;
    try {
      final request = await client.postUrl(uri).timeout(timeout);
      debugPrint('[SIM_HTTP] postEventStream tcp abriu');
      headers.forEach(request.headers.set);
      debugPrint('[SIM_HTTP] postEventStream headers ok');
      final encoded = utf8.encode(jsonEncode(body));
      debugPrint('[SIM_HTTP] postEventStream body encoded ${encoded.length} bytes');
      request.headers.set('content-length', encoded.length.toString());
      request.add(encoded);
      debugPrint('[SIM_HTTP] postEventStream body escrito, fechando');
      response = await request.close().timeout(timeout);
      debugPrint('[SIM_HTTP] postEventStream status ${response.statusCode}');
    } catch (e, st) {
      debugPrint('[SIM_HTTP] postEventStream ERRO em $uri: $e');
      debugPrint('[SIM_HTTP] postEventStream stacktrace: $st');
      rethrow;
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final text = await utf8.decoder.bind(response).join().timeout(timeout);
      debugPrint('[SIM_HTTP] postEventStream erro ${response.statusCode}: ${text.length > 500 ? text.substring(0, 500) : text}');
      throw HttpException('HTTP ${response.statusCode}: $text', uri: uri);
    }
    yield* response
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .timeout(timeout);
  }

  @override
  Future<SimHttpResponse> postMultipart(
    Uri uri, {
    required Map<String, String> headers,
    required String fieldName,
    required String filename,
    required String contentType,
    required List<int> bytes,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    final boundary = '----sim-mobile-${DateTime.now().microsecondsSinceEpoch}';
    final request = await client.postUrl(uri).timeout(timeout);
    headers.forEach(request.headers.set);
    request.headers.set(
      'content-type',
      'multipart/form-data; boundary=$boundary',
    );
    request.headers.set('accept', 'application/json');
    final safeName = filename.replaceAll('"', '');
    request.write('--$boundary\r\n');
    request.write(
      'Content-Disposition: form-data; name="$fieldName"; filename="$safeName"\r\n',
    );
    request.write('Content-Type: $contentType\r\n\r\n');
    request.add(bytes);
    request.write('\r\n--$boundary--\r\n');
    final response = await request.close().timeout(timeout);
    final text = await utf8.decoder.bind(response).join().timeout(timeout);
    final outHeaders = <String, String>{};
    response.headers.forEach((name, values) {
      outHeaders[name] = values.join(',');
    });
    return SimHttpResponse(
      statusCode: response.statusCode,
      body: text,
      headers: outHeaders,
    );
  }
}
