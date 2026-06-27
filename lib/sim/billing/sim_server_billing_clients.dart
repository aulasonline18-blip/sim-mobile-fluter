import 'dart:convert';

import '../external_ai/sim_ai_server_config.dart';
import '../external_ai/sim_http_transport.dart';
import '../state/student_learning_state.dart';
import 'account_deletion.dart';
import 'credits_functions.dart';
import 'payments_functions.dart';

class SimServerPaymentsClient implements PaymentsFunctions {
  SimServerPaymentsClient({
    required this.config,
    SimHttpTransport? transport,
    this.hostedPath = '/api/payments/create-credits-checkout-hosted',
    this.embeddedPath = '/api/payments/create-credits-checkout',
    this.statusPath = '/api/payments/checkout-status',
    this.timeout = const Duration(seconds: 45),
  }) : transport = transport ?? DartIoSimHttpTransport();

  final SimAiServerConfig config;
  final SimHttpTransport transport;
  final String hostedPath;
  final String embeddedPath;
  final String statusPath;
  final Duration timeout;

  @override
  Future<HostedCheckoutResult> createCreditsCheckoutHosted(
    CreateCreditsCheckoutHostedInput input,
  ) async {
    final data = await _post(hostedPath, {
      'packId': input.validate().packId,
      'successUrl': input.successUrl,
      'cancelUrl': input.cancelUrl,
      'environment': input.environment.wire,
    });
    if (data['error'] != null) {
      return HostedCheckoutResult.failure(data['error'].toString());
    }
    return HostedCheckoutResult.success(
      url: (data['url'] ?? '').toString(),
      sessionId: (data['sessionId'] ?? '').toString(),
    );
  }

  @override
  Future<EmbeddedCheckoutResult> createCreditsCheckoutEmbedded(
    CreateCreditsCheckoutEmbeddedInput input,
  ) async {
    final data = await _post(embeddedPath, {
      'packId': input.validate().packId,
      'returnUrl': input.returnUrl,
      'environment': input.environment.wire,
    });
    if (data['error'] != null) {
      return EmbeddedCheckoutResult.failure(data['error'].toString());
    }
    return EmbeddedCheckoutResult.success(
      (data['clientSecret'] ?? '').toString(),
    );
  }

  @override
  Future<CheckoutStatus> getCheckoutStatus({
    required String sessionId,
    required StripeEnvironment environment,
  }) async {
    if (!isValidStripeSessionId(sessionId)) {
      return const CheckoutStatus.failure('Invalid sessionId');
    }
    final data = await _post(statusPath, {
      'sessionId': sessionId,
      'environment': environment.wire,
    });
    if (data['error'] != null) {
      return CheckoutStatus.failure(data['error'].toString());
    }
    return switch (data['status']?.toString()) {
      'complete' => CheckoutStatus.complete(
        credits: (data['credits'] as num?)?.toInt() ?? 0,
        balance: (data['balance'] as num?)?.toInt() ?? 0,
      ),
      'expired' => const CheckoutStatus.expired(),
      _ => const CheckoutStatus.pending(),
    };
  }

  Future<JsonMap> _post(String path, Object body) async {
    final response = await transport.postJson(
      config.uri(path),
      headers: await config.jsonHeaders(),
      body: body,
      timeout: timeout,
    );
    if (!response.ok) {
      throw SimExternalAiException(
        response.body,
        statusCode: response.statusCode,
      );
    }
    final decoded = jsonDecode(response.body);
    return decoded is Map ? JsonMap.from(decoded) : <String, dynamic>{};
  }
}

class SimServerCreditsClient implements CreditsFunctions {
  SimServerCreditsClient({
    required this.config,
    SimHttpTransport? transport,
    this.snapshotPath = '/api/credits/me',
    this.chargeLessonPath = '/api/credits/charge-lesson-generation',
    this.timeout = const Duration(seconds: 30),
  }) : transport = transport ?? DartIoSimHttpTransport();

  final SimAiServerConfig config;
  final SimHttpTransport transport;
  final String snapshotPath;
  final String chargeLessonPath;
  final Duration timeout;

  @override
  Future<CreditsSnapshot> getMyCredits() async {
    final data = await _post(snapshotPath, const {});
    return CreditsSnapshot(
      balance: (data['balance'] as num?)?.toInt() ?? 0,
      lifetimeEarned: (data['lifetimeEarned'] as num?)?.toInt() ?? 0,
      lifetimeSpent: (data['lifetimeSpent'] as num?)?.toInt() ?? 0,
      email: data['email']?.toString(),
      displayName: data['displayName']?.toString(),
    );
  }

  @override
  Future<int> chargeLessonGeneration(ChargeLessonGenerationInput input) async {
    final normalized = input.normalized();
    final data = await _post(chargeLessonPath, {
      'lessonLocalId': normalized.lessonLocalId,
      'legacyLessonLocalIds': normalized.legacyLessonLocalIds,
    });
    return (data['balance'] as num?)?.toInt() ?? 0;
  }

  Future<JsonMap> _post(String path, Object body) async {
    final response = await transport.postJson(
      config.uri(path),
      headers: await config.jsonHeaders(),
      body: body,
      timeout: timeout,
    );
    if (!response.ok) {
      throw SimExternalAiException(
        response.body,
        statusCode: response.statusCode,
      );
    }
    final decoded = jsonDecode(response.body);
    return decoded is Map ? JsonMap.from(decoded) : <String, dynamic>{};
  }
}

class SimServerAccountDeletionGateway implements AccountDeletionGateway {
  SimServerAccountDeletionGateway({
    required this.config,
    SimHttpTransport? transport,
    this.path = '/api/account/request-deletion',
    this.timeout = const Duration(seconds: 30),
  }) : transport = transport ?? DartIoSimHttpTransport();

  final SimAiServerConfig config;
  final SimHttpTransport transport;
  final String path;
  final Duration timeout;

  @override
  Future<void> requestAccountDeletion(AccountDeletionRequest request) async {
    final response = await transport.postJson(
      config.uri(path),
      headers: await config.jsonHeaders(),
      body: {
        'userId': request.userId,
        if (request.emailSnapshot != null) 'email': request.emailSnapshot,
        'reason': request.reason,
      },
      timeout: timeout,
    );
    if (!response.ok) {
      throw SimExternalAiException(response.body, statusCode: response.statusCode);
    }
  }
}
