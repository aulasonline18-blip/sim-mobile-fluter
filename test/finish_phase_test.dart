import 'package:flutter/material.dart';
import 'package:sim_mobile/features/classroom/aula_widgets.dart';
import 'package:sim_mobile/sim/classroom/classroom_models.dart';
import 'package:sim_mobile/sim/classroom/lesson_main_view_model.dart';
import 'package:sim_mobile/sim/classroom/lesson_runtime_engine.dart';
import 'package:sim_mobile/sim/external_ai/sim_ai_server_config.dart';
import 'package:sim_mobile/sim/external_ai/sim_http_transport.dart';
import 'package:sim_mobile/sim/external_ai/sim_server_attachment_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/main.dart';
import 'package:sim_mobile/sim/lesson/lesson_models.dart';
import 'package:sim_mobile/sim/support/sim_finish_contract.dart';
import 'package:sim_mobile/sim/state/student_learning_state.dart';

class FakeAttachmentTransport implements SimHttpTransport {
  int calls = 0;

  @override
  Future<SimHttpResponse> postJson(
    Uri uri, {
    required Map<String, String> headers,
    required Object? body,
    Duration timeout = const Duration(seconds: 45),
  }) async => const SimHttpResponse(statusCode: 200, body: '{}');

  @override
  Stream<String> postEventStream(
    Uri uri, {
    required Map<String, String> headers,
    required Object? body,
    Duration timeout = const Duration(seconds: 140),
  }) async* {}

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
    calls += 1;
    return const SimHttpResponse(
      statusCode: 200,
      body:
          '{"extractedText":"texto real extraido pelo servidor","method":"vision","charsExtracted":32}',
    );
  }
}

void main() {
  test('acabamento cobre todos os itens mandatarios', () {
    expect(simFinishIsComplete(), true);
    expect(simFinishRequirements.length, SimFinishArea.values.length);
    expect(
      simFinishRequirements.map((r) => r.label).join('\n'),
      contains('Audio com estado visivel'),
    );
    expect(
      simFinishRequirements.map((r) => r.label).join('\n'),
      contains('Imagem com estado visivel'),
    );
  });

  testWidgets('objetivo processa anexo pelo client real sem texto fixo', (
    WidgetTester tester,
  ) async {
    final transport = FakeAttachmentTransport();
    final session =
        LabSession(
            attachmentClient: SimServerAttachmentClient(
              config: const SimAiServerConfig(baseUrl: 'https://sim.test'),
              transport: transport,
            ),
          )
          ..authed = true
          ..authReady = true
          ..credits = 3
          ..route = '/cyber/objeto';

    await tester.pumpWidget(SimMobileApp(initialSession: session));
    session.addLabAttachment('gallery');
    expect(session.attachments.single.status, 'reading');
    await tester.pumpAndSettle();

    expect(transport.calls, 1);
    expect(session.attachments.single.status, 'ready');
    expect(
      session.attachments.single.extractedText,
      'texto real extraido pelo servidor',
    );
    expect(session.attachments.single.extractedText, isNot(contains('MOCK')));
  });

  testWidgets('aula mostra imagem audio feedback loading e erro visual', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    final session = LabSession()
      ..authed = true
      ..authReady = true
      ..credits = 3
      ..selectedLanguageCode = 'pt'
      ..stableLang = 'Portuguese'
      ..freeText = 'Fracoes equivalentes explicadas com exemplos simples.';
    expect(session.saveObjectiveEntry(), isTrue);
    session.route = '/cyber/aula';
    await session.launchExperience();
    await session.openAulaRuntime();

    await tester.pumpWidget(SimMobileApp(initialSession: session));
    expect(find.text('Imagem da aula'), findsOneWidget);
    expect(find.text('Audio da aula ligado'), findsOneWidget);
    expect(find.text('Gerar imagem'), findsNothing);

    await tester.tap(find.byIcon(Icons.volume_up_outlined).first);
    await tester.pump();
    expect(find.text('Preparando audio da aula...'), findsOneWidget);
    await tester.pumpAndSettle();

    final optionB = find.text('B');
    await tester.ensureVisible(optionB);
    await tester.tap(optionB);
    await tester.pumpAndSettle();
    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('painel mostra oferta paga antes de gerar imagem', (
    tester,
  ) async {
    final session = LabSession()
      ..aulaSnapshot = const LessonRuntimeSnapshot(
        authReady: true,
        authed: true,
        hasCurriculum: true,
        isDone: false,
        viewModel: LessonMainViewModel(
          progress: 0,
          headerLabel: 'aula_item_of:1/1:aula_layer_1',
          options: [],
          locked: false,
          nextLabel: '',
        ),
        phase: ClassroomPhase.reading(),
        history: [],
        conteudo: LessonContent(
          explanation: 'Explicacao',
          question: 'Pergunta?',
          options: {
            AnswerLetter.A: 'A',
            AnswerLetter.B: 'B',
            AnswerLetter.C: 'C',
          },
          correctAnswer: AnswerLetter.A,
          visualTrigger: {
            'needs_image': true,
            'pedagogical_need': 'important',
            'render_strategy': 'ai',
            'image_prompt': 'foto realista de um coração humano',
            'topic': 'coração humano',
            'visual_type': 'anatomy',
          },
        ),
        imagem: null,
        itemMarker: 'M1',
        itemText: 'Sistema circulatório',
      );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: LessonImagePanel(session: session)),
      ),
    );

    expect(find.text('Imagem opcional da aula'), findsOneWidget);
    expect(find.text('Sem imagem'), findsOneWidget);
    expect(find.text('Gerar'), findsOneWidget);
  });
}
