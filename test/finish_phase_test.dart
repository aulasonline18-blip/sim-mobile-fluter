import 'package:flutter/material.dart';
import 'package:sim_mobile/sim/external_ai/sim_ai_server_config.dart';
import 'package:sim_mobile/sim/external_ai/sim_http_transport.dart';
import 'package:sim_mobile/sim/external_ai/sim_server_attachment_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/main.dart';
import 'package:sim_mobile/sim/support/sim_finish_contract.dart';

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
      ..stableLang = 'Portuguese'
      ..freeText = 'Frações equivalentes'
      ..route = '/cyber/aula';

    await tester.pumpWidget(SimMobileApp(initialSession: session));
    expect(find.text('Imagem da aula'), findsOneWidget);
    expect(find.text('Áudio da aula ligado'), findsOneWidget);

    await tester.tap(find.text('Gerar imagem'));
    await tester.pump();
    expect(find.text('Gerando imagem da aula...'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('Imagem da aula pronta'), findsOneWidget);

    await tester.tap(find.byTooltip('Áudio'));
    await tester.pump();
    expect(find.text('Preparando áudio da aula...'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('Áudio ainda não está disponível.'), findsOneWidget);

    await tester.tap(find.textContaining('B. Entendi'));
    await tester.pumpAndSettle();
    expect(find.textContaining('SIM marcou revisão'), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });
}
