import 'dart:convert';

import '../media/audio_core.dart';
import '../media/lesson_audio_api_contract.dart';
import '../media/lesson_image_api_contract.dart';
import '../media/lesson_visual_pipeline.dart';
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
    final supportMode = request.onboarding['modo'] == 'amparo' ||
        request.onboarding['mode'] == 'support';
    final body = {
      if (supportMode) 'modo': 'amparo',
      'ficha': ficha,
      'timeoutMs': timeout.inMilliseconds,
    };
    await for (final line in transport.postEventStream(
      config.uri(simT00BootstrapPath),
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
    this.timeout = const Duration(seconds: 60),
  }) : transport = transport ?? DartIoSimHttpTransport();

  final SimAiServerConfig config;
  final SimHttpTransport transport;
  final Duration timeout;

  @override
  Future<String?> generateLessonImage({
    required String prompt,
    required String lessonKey,
    String aspectRatio = '1:1',
  }) async {
    final request = GenerateLessonImageRequest(
      prompt: prompt,
      lessonKey: lessonKey,
      aspectRatio: aspectRatio,
    ).normalized();
    final response = await transport.postJson(
      config.uri(simLessonImagePath),
      headers: await config.jsonHeaders(),
      body: {
        'prompt': request.prompt,
        'lessonKey': request.lessonKey,
        'aspectRatio': request.aspectRatio,
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
    if (decoded is! Map) return null;
    final dataUrl = decoded['dataUrl']?.toString();
    if (dataUrl != null && dataUrl.isNotEmpty) return dataUrl;
    final imageUrl = decoded['image_url']?.toString();
    if (imageUrl != null && imageUrl.isNotEmpty) return imageUrl;
    final imageBase64 = decoded['image_base64']?.toString();
    if (imageBase64 != null && imageBase64.isNotEmpty) {
      final mime = decoded['mime_type']?.toString() ?? 'image/png';
      return 'data:$mime;base64,$imageBase64';
    }
    return null;
  }
}

class SimServerGeneratedAudioClient implements GeneratedAudioClient {
  SimServerGeneratedAudioClient({
    required this.config,
    SimHttpTransport? transport,
    this.timeout = const Duration(seconds: 45),
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
    ).normalized();
    final response = await transport.postJson(
      config.uri(simLessonAudioPath),
      headers: await config.jsonHeaders(),
      body: {
        'text': request.text,
        'lang': request.lang,
        'language': request.lang,
        'voice': voice,
        'lessonKey': request.lessonKey,
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
    if (decoded is! Map) return null;
    final dataUrl = decoded['dataUrl']?.toString();
    if (dataUrl != null && dataUrl.isNotEmpty) return dataUrl;
    final audioUrl = decoded['audio_url']?.toString();
    if (audioUrl != null && audioUrl.isNotEmpty) return audioUrl;
    final audioBase64 = decoded['audio_base64']?.toString();
    if (audioBase64 != null && audioBase64.isNotEmpty) {
      final mime = decoded['mime_type']?.toString() ?? 'audio/wav';
      return 'data:$mime;base64,$audioBase64';
    }
    final parsed = GenerateLessonAudioResponse(
      dataUrl: decoded['dataUrl']?.toString() ?? '',
      voice: decoded['voice']?.toString() ?? voiceByLang(request.lang),
      model: decoded['model']?.toString() ?? geminiTtsModel,
    );
    return parsed.dataUrl;
  }
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
        'mode': request.mode == 'amparo' ? 'amparo' : mode,
        if (request.mode == 'amparo') 'modo': 'amparo',
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
    return _parseT02Material(JsonMap.from(decoded));
  }

  T02LessonMaterial _parseT02Material(JsonMap json) {
    final source =
        json['conteudo'] is Map ? JsonMap.from(json['conteudo']) : json;
    final options = source['options'];
    final correct =
        (source['correct_answer'] ?? source['correctAnswer'] ?? 'A').toString();
    return T02LessonMaterial(
      explanation: (source['explanation'] ?? '').toString(),
      question: (source['question'] ?? '').toString(),
      options: {
        AnswerLetter.A: options is Map ? (options['A'] ?? '').toString() : '',
        AnswerLetter.B: options is Map ? (options['B'] ?? '').toString() : '',
        AnswerLetter.C: options is Map ? (options['C'] ?? '').toString() : '',
      },
      correctAnswer: AnswerLetter.values.firstWhere(
        (letter) => letter.name == correct,
        orElse: () => AnswerLetter.A,
      ),
      whyCorrect:
          (source['why_correct'] ?? source['whyCorrect'] ?? '').toString(),
      whyWrong: source['why_wrong'] ?? source['whyWrong'],
      visualTrigger: source['visual_trigger'] is Map
          ? JsonMap.from(source['visual_trigger'] as Map)
          : source['visualTrigger'] is Map
              ? JsonMap.from(source['visualTrigger'] as Map)
              : null,
      generatedAt: DateTime.now(),
      source: (source['source'] ?? 'sim-server-t02').toString(),
    );
  }
}
