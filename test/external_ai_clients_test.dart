import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/sim/external_ai/sim_ai_server_config.dart';
import 'package:sim_mobile/sim/external_ai/sim_http_transport.dart';
import 'package:sim_mobile/sim/external_ai/sim_server_ai_clients.dart';
import 'package:sim_mobile/sim/modules/pedagogical_module_contracts.dart';
import 'package:sim_mobile/sim/state/student_learning_state.dart';

class RecordingTransport implements SimHttpTransport {
  Uri? lastUri;
  Map<String, String>? lastHeaders;
  Object? lastBody;
  String jsonBody = '{"dataUrl":"data:image/png;base64,abc"}';
  List<String> streamLines = const [];

  @override
  Future<SimHttpResponse> postJson(
    Uri uri, {
    required Map<String, String> headers,
    required Object? body,
    Duration timeout = const Duration(seconds: 45),
  }) async {
    lastUri = uri;
    lastHeaders = headers;
    lastBody = body;
    return SimHttpResponse(statusCode: 200, body: jsonBody);
  }

  @override
  Stream<String> postEventStream(
    Uri uri, {
    required Map<String, String> headers,
    required Object? body,
    Duration timeout = const Duration(seconds: 140),
  }) async* {
    lastUri = uri;
    lastHeaders = headers;
    lastBody = body;
    for (final line in streamLines) {
      yield line;
    }
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
    lastUri = uri;
    lastHeaders = headers;
    lastBody = {
      'fieldName': fieldName,
      'filename': filename,
      'contentType': contentType,
      'bytes': bytes.length,
    };
    return SimHttpResponse(
      statusCode: 200,
      body:
          '{"extractedText":"texto extraido","method":"pdf-text","charsExtracted":14}',
    );
  }
}

void main() {
  SimAiServerConfig config() => SimAiServerConfig(
    baseUrl: 'https://gemini-aid-pal.lovable.app',
    accessTokenProvider: () async => 'user-token',
  );

  test(
    'T00 usa a mesma porta viva /api/bootstrap-t00 com ficha e bearer',
    () async {
      final transport = RecordingTransport()
        ..streamLines = const [
          'data: {"type":"t00_profile","profile":"ok"}',
          'data: {"type":"t00_item_partial","item":{"marker":"M1","text":"Frações"}}',
        ];
      final client = SimServerT00Client(config: config(), transport: transport);

      final chunks = await client
          .runBootstrap(
            const T00BootstrapRequest(
              lessonLocalId: 'lesson-1',
              onboarding: {'objetivo': 'Aprender frações'},
              lang: 'pt-BR',
              academic: 'ano 6',
            ),
          )
          .toList();

      expect(
        transport.lastUri.toString(),
        'https://gemini-aid-pal.lovable.app/api/bootstrap-t00',
      );
      expect(transport.lastHeaders?['authorization'], 'Bearer user-token');
      expect(
        (transport.lastBody as Map)['ficha']['free_text'],
        'Aprender frações',
      );
      expect(chunks.map((chunk) => chunk.type), [
        't00_profile',
        't00_item_partial',
      ]);
    },
  );

  test('imagem usa /api/generate-lesson-image sem chave de provedor', () async {
    final transport = RecordingTransport();
    final client = SimServerLessonImageClient(
      config: config(),
      transport: transport,
    );

    final dataUrl = await client.generateLessonImage(
      prompt: 'uma figura didática',
      lessonKey: 'lesson-1',
      acceptedOfferId: 'offer-1',
      idempotencyKey: 'offer-1',
    );

    expect(dataUrl, startsWith('data:image/'));
    expect(
      transport.lastUri.toString(),
      'https://gemini-aid-pal.lovable.app/api/generate-lesson-image',
    );
    expect(
      (transport.lastBody as Map).keys,
      containsAll([
        'prompt',
        'lessonKey',
        'aspectRatio',
        'acceptedOfferId',
        'idempotencyKey',
      ]),
    );
    expect(transport.lastHeaders.toString(), isNot(contains('GEMINI_API_KEY')));
    expect(
      transport.lastHeaders.toString(),
      isNot(contains('LOVABLE_API_KEY')),
    );
  });

  test('audio usa /api/generate-lesson-audio e devolve dataUrl', () async {
    final transport = RecordingTransport()
      ..jsonBody =
          '{"dataUrl":"data:audio/wav;base64,abc","voice":"Charon","model":"gemini-2.5-flash-preview-tts"}';
    final client = SimServerGeneratedAudioClient(
      config: config(),
      transport: transport,
    );

    final dataUrl = await client.generateAudio(
      text: 'texto da aula',
      lang: 'pt-BR',
      voice: 'Charon',
      lessonKey: 'lesson-1',
    );

    expect(dataUrl, startsWith('data:audio/wav;base64,'));
    expect(
      transport.lastUri.toString(),
      'https://gemini-aid-pal.lovable.app/api/generate-lesson-audio',
    );
    expect((transport.lastBody as Map)['text'], 'texto da aula');
  });

  test(
    'T02 nao inventa rota quando a ponte HTTP do servidor nao existe',
    () async {
      final client = SimServerT02Client(
        config: config(),
        transport: RecordingTransport(),
      );

      expect(
        () => client.completeLesson(
          const T02LessonRequest(
            lessonLocalId: 'lesson-1',
            item: 'Frações',
            lang: 'pt-BR',
            academic: 'ano 6',
            layer: LessonLayer.l1,
            mode: 'session',
            errCount: 0,
            history: [],
          ),
        ),
        throwsA(isA<SimExternalAiException>()),
      );
    },
  );

  test('T02 usa ponte HTTP do servidor quando configurada', () async {
    final transport = RecordingTransport()
      ..jsonBody =
          '{"explanation":"Explique","question":"Pergunta?","options":{"A":"um","B":"dois","C":"tres"},"correct_answer":"A","why_correct":"ok","why_wrong":{"B":"nao","C":"nao"}}';
    final client = SimServerT02Client(
      config: SimAiServerConfig(
        baseUrl: 'https://gemini-aid-pal.lovable.app',
        t02Path: '/api/sim/t02',
        accessTokenProvider: () async => 'user-token',
      ),
      transport: transport,
    );

    final material = await client.completeLesson(
      const T02LessonRequest(
        lessonLocalId: 'lesson-1',
        item: 'Frações',
        lang: 'pt-BR',
        academic: 'ano 6',
        layer: LessonLayer.l1,
        mode: 'session',
        errCount: 0,
        history: [],
      ),
    );

    expect(
      transport.lastUri.toString(),
      'https://gemini-aid-pal.lovable.app/api/sim/t02',
    );
    expect((transport.lastBody as Map)['mode'], 'lesson');
    expect(material.question, 'Pergunta?');
  });
}
