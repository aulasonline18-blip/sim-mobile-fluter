import 'dart:convert';

import '../external_ai/sim_ai_server_config.dart';
import '../external_ai/sim_http_transport.dart';
import '../state/student_learning_state.dart';
import 'credits_functions.dart';
import 'student_billing_ledger.dart';

class CreditReservation {
  const CreditReservation({
    required this.reservationId,
    required this.amount,
    required this.reason,
    required this.status,
    required this.balance,
    required this.idempotencyKey,
  });

  final String reservationId;
  final int amount;
  final String reason;
  final String status;
  final int balance;
  final String idempotencyKey;
}

class CreditCaptureResult {
  const CreditCaptureResult({
    required this.balance,
    required this.transaction,
    this.cacheHit = false,
  });

  final int balance;
  final StudentBillingTransaction? transaction;
  final bool cacheHit;
}

class CreditClientException implements Exception {
  const CreditClientException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  bool get insufficientCredits =>
      statusCode == 402 ||
      message.toLowerCase().contains('insufficient') ||
      message.toLowerCase().contains('saldo');

  @override
  String toString() => message;
}

abstract interface class CreditClient {
  Future<CreditsSnapshot> getBalance();

  Future<CreditReservation> reserveCredits({
    required int amount,
    required String reason,
    required String idempotencyKey,
    required JsonMap metadata,
  });

  Future<CreditCaptureResult> captureCredits({
    required String reservationId,
    required String idempotencyKey,
    required JsonMap metadata,
  });

  Future<CreditCaptureResult> refundCredits({
    required String reservationId,
    required String idempotencyKey,
    required JsonMap metadata,
  });

  Future<List<StudentBillingTransaction>> getTransactionHistory();
}

class SimServerCreditClient implements CreditClient {
  SimServerCreditClient({
    required this.config,
    SimHttpTransport? transport,
    this.balancePath = '/api/credits/me',
    this.reservePath = '/api/credits/reserve',
    this.capturePath = '/api/credits/capture',
    this.refundPath = '/api/credits/refund',
    this.historyPath = '/api/credits/transactions',
    this.timeout = const Duration(seconds: 30),
  }) : transport = transport ?? DartIoSimHttpTransport();

  final SimAiServerConfig config;
  final SimHttpTransport transport;
  final String balancePath;
  final String reservePath;
  final String capturePath;
  final String refundPath;
  final String historyPath;
  final Duration timeout;

  @override
  Future<CreditsSnapshot> getBalance() async {
    final data = await _post(balancePath, const {});
    return CreditsSnapshot(
      balance: (data['balance'] as num?)?.toInt() ?? 0,
      lifetimeEarned: (data['lifetimeEarned'] as num?)?.toInt() ??
          (data['lifetime_earned'] as num?)?.toInt() ??
          0,
      lifetimeSpent: (data['lifetimeSpent'] as num?)?.toInt() ??
          (data['lifetime_spent'] as num?)?.toInt() ??
          0,
      email: data['email']?.toString(),
      displayName: data['displayName']?.toString(),
    );
  }

  @override
  Future<CreditReservation> reserveCredits({
    required int amount,
    required String reason,
    required String idempotencyKey,
    required JsonMap metadata,
  }) async {
    final data = await _post(reservePath, {
      'amount': amount,
      'reason': reason,
      'idempotencyKey': idempotencyKey,
      'metadata': metadata,
    });
    return CreditReservation(
      reservationId:
          (data['reservationId'] ?? data['reservation_id'] ?? '').toString(),
      amount: (data['amount'] as num?)?.toInt() ?? amount,
      reason: (data['reason'] ?? reason).toString(),
      status: (data['status'] ?? 'pending').toString(),
      balance: (data['balance'] as num?)?.toInt() ?? 0,
      idempotencyKey:
          (data['idempotencyKey'] ?? data['idempotency_key'] ?? idempotencyKey)
              .toString(),
    );
  }

  @override
  Future<CreditCaptureResult> captureCredits({
    required String reservationId,
    required String idempotencyKey,
    required JsonMap metadata,
  }) {
    return _finish(
      capturePath,
      reservationId: reservationId,
      idempotencyKey: idempotencyKey,
      metadata: metadata,
    );
  }

  @override
  Future<CreditCaptureResult> refundCredits({
    required String reservationId,
    required String idempotencyKey,
    required JsonMap metadata,
  }) {
    return _finish(
      refundPath,
      reservationId: reservationId,
      idempotencyKey: idempotencyKey,
      metadata: metadata,
    );
  }

  @override
  Future<List<StudentBillingTransaction>> getTransactionHistory() async {
    final data = await _post(historyPath, const {});
    final raw = data['transactions'] ?? data['items'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((entry) => StudentBillingTransaction.fromJson(JsonMap.from(entry)))
        .toList(growable: false);
  }

  Future<CreditCaptureResult> _finish(
    String path, {
    required String reservationId,
    required String idempotencyKey,
    required JsonMap metadata,
  }) async {
    final data = await _post(path, {
      'reservationId': reservationId,
      'idempotencyKey': idempotencyKey,
      'metadata': metadata,
    });
    final transaction = data['transaction'] is Map
        ? StudentBillingTransaction.fromJson(
            JsonMap.from(data['transaction'] as Map),
          )
        : null;
    return CreditCaptureResult(
      balance: (data['balance'] as num?)?.toInt() ?? 0,
      transaction: transaction,
      cacheHit: data['cacheHit'] == true || data['cache_hit'] == true,
    );
  }

  Future<JsonMap> _post(String path, Object body) async {
    final response = await transport.postJson(
      config.uri(path),
      headers: await config.jsonHeaders(),
      body: body,
      timeout: timeout,
    );
    if (!response.ok) {
      throw CreditClientException(response.body,
          statusCode: response.statusCode);
    }
    final decoded = jsonDecode(response.body);
    return decoded is Map ? JsonMap.from(decoded) : <String, dynamic>{};
  }
}
