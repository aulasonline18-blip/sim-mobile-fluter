import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/sim/billing/payments_functions.dart';
import 'package:sim_mobile/sim/billing/sim_server_billing_clients.dart';
import 'package:sim_mobile/sim/cloud/cloud_functions.dart';
import 'package:sim_mobile/sim/cloud/sim_server_cloud_functions.dart';
import 'package:sim_mobile/sim/cloud/supabase_client_contract.dart';
import 'package:sim_mobile/sim/external_ai/sim_ai_server_config.dart';
import 'package:sim_mobile/sim/external_ai/sim_http_transport.dart';
import 'package:sim_mobile/sim/external_ai/sim_server_attachment_client.dart';
import 'package:sim_mobile/sim/state/student_learning_state.dart';

class RecordingTransport implements SimHttpTransport {
  Uri? lastUri;
  Map<String, String>? lastHeaders;
  Object? lastBody;
  String jsonBody = '{}';

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
          '{"extractedText":"texto do arquivo","method":"pdf-text","charsExtracted":16}',
    );
  }
}

void main() {
  SimAiServerConfig config() => SimAiServerConfig(
    baseUrl: 'https://gemini-aid-pal.lovable.app',
    accessTokenProvider: () async => 'user-token',
  );

  test(
    'storage/anexos envia multipart autenticado sem chave secreta',
    () async {
      final transport = RecordingTransport();
      final client = SimServerAttachmentClient(
        config: config(),
        transport: transport,
      );

      final result = await client.processAttachment(
        const SimAttachmentFile(
          name: 'lista.pdf',
          contentType: 'application/pdf',
          bytes: [1, 2, 3],
        ),
      );

      expect(transport.lastUri.toString(), endsWith('/api/process-attachment'));
      expect(transport.lastHeaders?['authorization'], 'Bearer user-token');
      expect((transport.lastBody as Map)['fieldName'], 'file');
      expect(result.method, 'pdf-text');
      expect(
        transport.lastHeaders.toString(),
        isNot(contains('LOVABLE_API_KEY')),
      );
    },
  );

  test('Stripe hosted checkout manda apenas packId e URLs ao servidor', () async {
    final transport = RecordingTransport()
      ..jsonBody =
          '{"url":"https://checkout.stripe.com/c/pay","sessionId":"cs_test_123"}';
    final client = SimServerPaymentsClient(
      config: config(),
      transport: transport,
    );

    final result = await client.createCreditsCheckoutHosted(
      const CreateCreditsCheckoutHostedInput(
        packId: 'credits_100',
        successUrl: 'https://gemini-aid-pal.lovable.app/checkout/return',
        cancelUrl: 'https://gemini-aid-pal.lovable.app/creditos',
        environment: StripeEnvironment.sandbox,
      ),
    );

    expect(result.ok, true);
    expect(transport.lastUri.toString(), contains('/api/payments/'));
    expect((transport.lastBody as Map).keys, isNot(contains('amount')));
    expect((transport.lastBody as Map)['packId'], 'credits_100');
  });

  test('cloud sync client envia snapshot completo com bearer', () async {
    final transport = RecordingTransport()
      ..jsonBody =
          '{"lessonLocalId":"l1","highWaterMark":12,"schemaVersion":1}';
    final client = SimServerCloudFunctions(
      config: config(),
      transport: transport,
    );
    final state = StudentLearningState.empty(lessonLocalId: 'l1', now: 1);

    final result = await client.persistStudentState(
      PersistStudentStateInput(
        lessonLocalId: 'l1',
        state: state,
        clientUpdatedAt: state.updatedAt,
        clientScore: 12,
      ),
      const SupabaseSession(accessToken: 'session-token', userId: 'u1'),
    );

    expect(result.highWaterMark, 12);
    expect(transport.lastHeaders?['Authorization'], 'Bearer session-token');
    expect((transport.lastBody as Map)['state'], isA<Map>());
  });

  test('permissoes Android incluem internet camera e leitura de imagem', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    expect(manifest, contains('android.permission.INTERNET'));
    expect(manifest, contains('android.permission.CAMERA'));
    expect(manifest, contains('android.permission.READ_MEDIA_IMAGES'));
  });
}
