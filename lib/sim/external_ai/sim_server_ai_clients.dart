import 'dart:async';
import 'dart:convert';

import '../media/audio_core.dart';
import '../media/lesson_audio_api_contract.dart';
import '../media/lesson_image_api_contract.dart';
import '../media/lesson_visual_pipeline.dart';
import '../lesson/lesson_content_validator.dart';
import '../modules/pedagogical_module_contracts.dart';
import '../state/student_learning_state.dart';
import 'sim_ai_server_config.dart';
import 'sim_http_transport.dart';

const String simT00BootstrapPath = '/api/bootstrap-t00';
const String simLessonImagePath = '/api/generate-lesson-image';
const String simLessonAudioPath = '/api/generate-lesson-audio';

class SimServerT00Client implements T00BootstrapClient {
  SimServerT00Client({
    required this.config,
    SimHttpTransport? transport,
    this.timeout = const Duration(seconds: 140),
  }) : transport = transport ?? DartIoSimHttpTransport();

  final SimAiServerConfig config;
  final SimHttpTransport transport;
  final Duration timeout;

  @override
  Stream<T00BootstrapChunk> runBootstrap(T00BootstrapRequest request) async* {
    final ficha = {
      ...request.onboarding,
      'lessonLocalId': request.lessonLocalId,
      'language': request.lang,
      'stableLang': request.lang,
      'academic_level': request.academic,
      if (request.onboarding['free_text'] == null)
        'free_text': request.onboarding['objetivo'] ?? '',
    };
    final body = {'ficha': ficha, 'timeoutMs': timeout.inMilliseconds};
    await for (final line in transport.postEventStream(
      config.uri(config.t00Path ?? simT00BootstrapPath),
      headers: await config.streamHeaders(),
      body: body,
      timeout: timeout,
    )) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith(':')) continue;
      if (!trimmed.startsWith('data:')) continue;
      final data = trimmed.substring(5).trim();
      if (data.isEmpty || data == '[DONE]') continue;
      final decoded = jsonDecode(data);
      if (decoded is! Map) continue;
      final payload = JsonMap.from(decoded);
      final type = (payload.remove('type') ?? 'message').toString();
      yield T00BootstrapChunk(type: type, payload: payload);
    }
  }
}

class SimServerLessonImageClient implements LessonImageClient {
  SimServerLessonImageClient({
    required this.config,
    SimHttpTransport? transport,
    this.timeout = const Duration(seconds: 125),
  }) : transport = transport ?? DartIoSimHttpTransport();

  final SimAiServerConfig config;
  final SimHttpTransport transport;
  final Duration timeout;

  @override
  Future<String?> generateLessonImage({
    required String prompt,
    required String lessonKey,
    String aspectRatio = '1:1',
    String? acceptedOfferId,
    String? idempotencyKey,
  }) async {
    final request = GenerateLessonImageRequest(
      prompt: prompt,
      lessonKey: lessonKey,
      aspectRatio: aspectRatio,
    ).normalized();
    final body = {
      'prompt': request.prompt,
      'lessonKey': request.lessonKey,
      'aspectRatio': request.aspectRatio,
    };
    if (acceptedOfferId != null) body['acceptedOfferId'] = acceptedOfferId;
    if (idempotencyKey != null) body['idempotencyKey'] = idempotencyKey;
    final requestId = _mediaRequestId(
      'img',
      '${request.lessonKey}|${request.prompt}',
    );
    final headers = await config.jsonHeaders();
    headers['x-request-id'] = requestId;
    final response = await _postJsonWithTimeout(
      transport,
      config.uri(simLessonImagePath),
      headers: headers,
      body: body,
      timeout: timeout,
      requestId: requestId,
    );
    if (!response.ok) {
      throw _mediaHttpException(response, fallbackRequestId: requestId);
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) return null;
    return decoded['dataUrl']?.toString();
  }
}

class SimServerGeneratedAudioClient implements GeneratedAudioClient {
  SimServerGeneratedAudioClient({
    required this.config,
    SimHttpTransport? transport,
    this.timeout = const Duration(seconds: 95),
  }) : transport = transport ?? DartIoSimHttpTransport();

  final SimAiServerConfig config;
  final SimHttpTransport transport;
  final Duration timeout;

  @override
  Future<String?> generateAudio({
    required String text,
    required String lang,
    required String voice,
    required String lessonKey,
  }) async {
    final request = GenerateLessonAudioRequest(
      text: text,
      lang: lang,
      lessonKey: lessonKey,
      voice: voice,
    ).normalized();
    final requestId = _mediaRequestId(
      'aud',
      '${request.lessonKey}|${request.lang}|${request.voice}|${request.text}',
    );
    final headers = await config.jsonHeaders();
    headers['x-request-id'] = requestId;
    final response = await _postJsonWithTimeout(
      transport,
      config.uri(simLessonAudioPath),
      headers: headers,
      body: {
        'text': request.text,
        'lang': request.lang,
        'lessonKey': request.lessonKey,
        'voice': request.voice,
      },
      timeout: timeout,
      requestId: requestId,
    );
    if (!response.ok) {
      throw _mediaHttpException(response, fallbackRequestId: requestId);
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) return null;
    final parsed = GenerateLessonAudioResponse(
      dataUrl: decoded['dataUrl']?.toString() ?? '',
      voice: decoded['voice']?.toString() ?? voiceByLang(request.lang),
      model: decoded['model']?.toString() ?? geminiTtsModel,
    );
    return parsed.dataUrl;
  }
}

Future<SimHttpResponse> _postJsonWithTimeout(
  SimHttpTransport transport,
  Uri uri, {
  required Map<String, String> headers,
  required Object? body,
  required Duration timeout,
  required String requestId,
}) async {
  try {
    return await transport.postJson(
      uri,
      headers: headers,
      body: body,
      timeout: timeout,
    );
  } on TimeoutException {
    throw SimExternalAiException(
      'Tempo esgotado ao preparar mídia.',
      statusCode: 408,
      requestId: requestId,
      code: 'MEDIA_TIMEOUT',
      retryable: true,
    );
  }
}

SimExternalAiException _mediaHttpException(
  SimHttpResponse response, {
  required String fallbackRequestId,
}) {
  String message = response.body;
  String? requestId = response.headers['x-request-id'] ?? fallbackRequestId;
  String? code;
  bool? retryable;
  try {
    final decoded = jsonDecode(response.body);
    if (decoded is Map) {
      final error = decoded['error'];
      if (error is Map) {
        message = (error['message'] ?? error['reason'] ?? message).toString();
        code = (error['code'] ?? error['reason'])?.toString();
        retryable = error['retryable'] is bool
            ? error['retryable'] as bool
            : null;
      } else if (error != null) {
        message = error.toString();
      }
      requestId = (decoded['requestId'] ?? decoded['request_id'] ?? requestId)
          ?.toString();
      code ??= decoded['code']?.toString();
      retryable ??= decoded['retryable'] is bool
          ? decoded['retryable'] as bool
          : null;
    }
  } catch (_) {
    message = response.body.length > 400
        ? '${response.body.substring(0, 400)}...'
        : response.body;
  }
  return SimExternalAiException(
    message,
    statusCode: response.statusCode,
    requestId: requestId,
    code: code,
    retryable: retryable,
  );
}

String _mediaRequestId(String prefix, String basis) {
  final stamp = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  return 'sim-$prefix-$stamp-${_stableHash(basis)}';
}

String _stableHash(String input) {
  var hash = 5381;
  for (final unit in input.codeUnits) {
    hash = ((hash << 5) + hash) ^ unit;
  }
  return (hash & 0xffffffff).toRadixString(36);
}

class SimServerT02Client implements T02LessonClient {
  SimServerT02Client({
    required this.config,
    SimHttpTransport? transport,
    this.timeout = const Duration(seconds: 45),
  }) : transport = transport ?? DartIoSimHttpTransport();

  final SimAiServerConfig config;
  final SimHttpTransport transport;
  final Duration timeout;

  @override
  Future<T02LessonMaterial> auxiliaryRoom(T02LessonRequest request) {
    return _call(request, mode: 'auxiliary');
  }

  @override
  Future<T02LessonMaterial> completeLesson(T02LessonRequest request) {
    return _call(request, mode: 'lesson');
  }

  @override
  Future<T02LessonMaterial> doubt(T02LessonRequest request) {
    return _call(request, mode: 'doubt');
  }

  @override
  Future<T02LessonMaterial> placement(T02LessonRequest request) {
    return _call(request, mode: 'placement');
  }

  Future<T02LessonMaterial> _call(
    T02LessonRequest request, {
    required String mode,
  }) async {
    final path = config.t02Path;
    if (path == null || path.trim().isEmpty) {
      throw const SimExternalAiException(
        'T02 no SIM atual roda por server function interna. Configure a ponte HTTP do servidor antes de chamar T02 pelo APK.',
      );
    }
    final response = await transport.postJson(
      config.uri(path),
      headers: await config.jsonHeaders(),
      body: {
        'mode': mode,
        'lessonLocalId': request.lessonLocalId,
        'item': request.item,
        'stable_lang': request.lang,
        'academic_level': request.academic,
        'layer': request.layer.value,
        'err_count': request.errCount,
        'lesson_mode': request.mode,
        'history': request.history,
        if (request.marker != null) 'marker': request.marker,
        if (request.addendum != null) 'addendum': request.addendum,
        if (request.amparoLvl != null) 'amparo_level': request.amparoLvl,
        ...request.profile,
      },
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
      throw const SimExternalAiException('T02 retornou resposta invalida.');
    }
    try {
      return _parseT02Material(JsonMap.from(decoded));
    } on LessonContentValidationException catch (error) {
      throw SimExternalAiException(
        'T02 retornou contrato invalido: ${error.message}',
        statusCode: 502,
      );
    }
  }

  T02LessonMaterial _parseT02Material(JsonMap json) {
    final source = json['conteudo'] is Map
        ? JsonMap.from(json['conteudo'])
        : json;
    final content = validatedLessonContentFromJson(source);
    return T02LessonMaterial(
      explanation: content.explanation,
      question: content.question,
      options: content.options,
      correctAnswer: content.correctAnswer,
      whyCorrect: content.whyCorrect ?? '',
      whyWrong: content.whyWrong,
      generatedAt: DateTime.now(),
      source: (source['source'] ?? 'sim-server-t02').toString(),
      visualTrigger: content.visualTrigger,
    );
  }
}
