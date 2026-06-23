import 'dart:convert';

import '../state/student_learning_state.dart';
import 'sim_ai_server_config.dart';
import 'sim_http_transport.dart';

const String simProcessAttachmentPath = '/api/process-attachment';
const int simMaxAttachmentBytes = 10 * 1024 * 1024;

class SimAttachmentFile {
  const SimAttachmentFile({
    required this.name,
    required this.contentType,
    required this.bytes,
  });

  final String name;
  final String contentType;
  final List<int> bytes;
}

class SimProcessedAttachment {
  const SimProcessedAttachment({
    required this.extractedText,
    required this.method,
    required this.charsExtracted,
    this.error,
  });

  final String extractedText;
  final String method;
  final int charsExtracted;
  final String? error;
}

class SimServerAttachmentClient {
  SimServerAttachmentClient({
    required this.config,
    SimHttpTransport? transport,
    this.path = simProcessAttachmentPath,
    this.timeout = const Duration(seconds: 90),
  }) : transport = transport ?? DartIoSimHttpTransport();

  final SimAiServerConfig config;
  final SimHttpTransport transport;
  final String path;
  final Duration timeout;

  Future<SimProcessedAttachment> processAttachment(
    SimAttachmentFile file,
  ) async {
    _validate(file);
    final response = await transport.postMultipart(
      config.uri(path),
      headers: await config.jsonHeaders(),
      fieldName: 'file',
      filename: file.name,
      contentType: file.contentType,
      bytes: file.bytes,
      timeout: timeout,
    );
    if (!response.ok) {
      throw SimExternalAiException(
        response.body,
        statusCode: response.statusCode,
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw const SimExternalAiException('Anexo retornou resposta invalida.');
    }
    final json = JsonMap.from(decoded);
    return SimProcessedAttachment(
      extractedText: (json['extractedText'] ?? '').toString(),
      method: (json['method'] ?? '').toString(),
      charsExtracted: (json['charsExtracted'] as num?)?.toInt() ?? 0,
      error: json['error']?.toString(),
    );
  }

  void _validate(SimAttachmentFile file) {
    if (file.name.trim().isEmpty) {
      throw const SimExternalAiException('Arquivo sem nome.');
    }
    if (file.bytes.length > simMaxAttachmentBytes) {
      throw const SimExternalAiException('Arquivo maior que 10MB.');
    }
    if (file.contentType.startsWith('audio/')) {
      throw const SimExternalAiException('AUDIO_NOT_SUPPORTED');
    }
    if (file.contentType.startsWith('video/')) {
      throw const SimExternalAiException('VIDEO_NOT_SUPPORTED');
    }
  }
}
