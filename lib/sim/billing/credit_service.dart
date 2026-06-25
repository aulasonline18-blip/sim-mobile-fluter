import 'package:shared_preferences/shared_preferences.dart';

import '../state/student_learning_state.dart';
import '../state/student_learning_state_service.dart';
import 'credit_client.dart';
import 'credits_functions.dart';
import 'student_billing_ledger.dart';

typedef ReservedCreditOperation<T> = Future<T> Function(
    CreditReservation reservation);

class CreditCosts {
  const CreditCosts({
    required this.lessonGeneration,
    required this.imageGeneration,
    required this.audioGeneration,
    required this.t00Bootstrap,
    this.audioBillingOfficial = false,
  });

  final int lessonGeneration;
  final int imageGeneration;
  final int audioGeneration;
  final int t00Bootstrap;
  final bool audioBillingOfficial;
}

const simCreditCosts = CreditCosts(
  lessonGeneration: 3,
  imageGeneration: 10,
  audioGeneration: 0,
  t00Bootstrap: 0,
);

class CreditService {
  CreditService({
    required this.client,
    required this.stateService,
    required this.preferences,
    this.costs = simCreditCosts,
  });

  static const balanceCacheKey = 'sim.credits.balance.v1';

  final CreditClient client;
  final StudentLearningStateService stateService;
  final SharedPreferences preferences;
  final CreditCosts costs;

  int get cachedBalance => preferences.getInt(balanceCacheKey) ?? 0;

  Future<CreditsSnapshot> refreshBalance({
    String? lessonLocalId,
  }) async {
    final snapshot = await client.getBalance();
    await preferences.setInt(balanceCacheKey, snapshot.balance);
    if (lessonLocalId != null) {
      _recordLedgerSummary(
        lessonLocalId: lessonLocalId,
        balance: snapshot.balance,
        transactions: const [],
        eventType: 'CREDIT_BALANCE_REFRESHED',
        payload: {'balance': snapshot.balance},
      );
    }
    return snapshot;
  }

  Future<List<StudentBillingTransaction>> refreshTransactions({
    required String lessonLocalId,
  }) async {
    final transactions = await client.getTransactionHistory();
    _recordLedgerSummary(
      lessonLocalId: lessonLocalId,
      balance: cachedBalance,
      transactions: transactions,
      eventType: 'CREDIT_HISTORY_LOADED',
      payload: {'count': transactions.length},
    );
    return transactions;
  }

  Future<T> runReserved<T>({
    required String lessonLocalId,
    required int amount,
    required String reason,
    required String idempotencyKey,
    required JsonMap metadata,
    required ReservedCreditOperation<T> operation,
  }) async {
    if (amount <= 0) return operation(_freeReservation(reason, idempotencyKey));
    final reservation = await reserveCredits(
      lessonLocalId: lessonLocalId,
      amount: amount,
      reason: reason,
      idempotencyKey: idempotencyKey,
      metadata: metadata,
    );
    try {
      final result = await operation(reservation);
      await captureCredits(
        lessonLocalId: lessonLocalId,
        reservationId: reservation.reservationId,
        idempotencyKey: idempotencyKey,
        metadata: metadata,
      );
      return result;
    } catch (error) {
      await refundCredits(
        lessonLocalId: lessonLocalId,
        reservationId: reservation.reservationId,
        idempotencyKey: idempotencyKey,
        metadata: {...metadata, 'error': error.toString()},
      );
      rethrow;
    }
  }

  Future<CreditReservation> reserveCredits({
    required String lessonLocalId,
    required int amount,
    required String reason,
    required String idempotencyKey,
    required JsonMap metadata,
  }) async {
    try {
      final reservation = await client.reserveCredits(
        amount: amount,
        reason: reason,
        idempotencyKey: idempotencyKey,
        metadata: metadata,
      );
      await preferences.setInt(balanceCacheKey, reservation.balance);
      _recordLedgerSummary(
        lessonLocalId: lessonLocalId,
        balance: reservation.balance,
        transactions: [
          _localTransaction(
            type: StudentBillingTransactionType.reserve,
            status: StudentBillingTransactionStatus.pending,
            amount: -amount,
            reason: reason,
            reservationId: reservation.reservationId,
            idempotencyKey: idempotencyKey,
            metadata: metadata,
          ),
        ],
        eventType: 'CREDIT_RESERVED',
        payload: {
          'amount': amount,
          'reason': reason,
          'reservationId': reservation.reservationId,
          'idempotencyKey': idempotencyKey,
        },
      );
      return reservation;
    } on CreditClientException catch (error) {
      _recordCreditFailure(
        lessonLocalId: lessonLocalId,
        eventType:
            error.insufficientCredits ? 'CREDIT_INSUFFICIENT' : 'CREDIT_FAILED',
        amount: amount,
        reason: reason,
        idempotencyKey: idempotencyKey,
        error: error.toString(),
      );
      rethrow;
    }
  }

  Future<CreditCaptureResult> captureCredits({
    required String lessonLocalId,
    required String reservationId,
    required String idempotencyKey,
    required JsonMap metadata,
  }) async {
    final result = await client.captureCredits(
      reservationId: reservationId,
      idempotencyKey: idempotencyKey,
      metadata: metadata,
    );
    await preferences.setInt(balanceCacheKey, result.balance);
    _recordLedgerSummary(
      lessonLocalId: lessonLocalId,
      balance: result.balance,
      transactions: [
        if (result.transaction != null) result.transaction!,
      ],
      eventType: 'CREDIT_CAPTURED',
      payload: {
        'reservationId': reservationId,
        'idempotencyKey': idempotencyKey,
        'cacheHit': result.cacheHit,
      },
    );
    return result;
  }

  Future<CreditCaptureResult> refundCredits({
    required String lessonLocalId,
    required String reservationId,
    required String idempotencyKey,
    required JsonMap metadata,
  }) async {
    final result = await client.refundCredits(
      reservationId: reservationId,
      idempotencyKey: idempotencyKey,
      metadata: metadata,
    );
    await preferences.setInt(balanceCacheKey, result.balance);
    _recordLedgerSummary(
      lessonLocalId: lessonLocalId,
      balance: result.balance,
      transactions: [
        if (result.transaction != null) result.transaction!,
      ],
      eventType: 'CREDIT_REFUNDED',
      payload: {
        'reservationId': reservationId,
        'idempotencyKey': idempotencyKey,
      },
    );
    return result;
  }

  void _recordLedgerSummary({
    required String lessonLocalId,
    required int balance,
    required List<StudentBillingTransaction> transactions,
    required String eventType,
    required JsonMap payload,
  }) {
    final existing = stateService.ensure(lessonLocalId: lessonLocalId);
    final ledger = StudentBillingLedger.fromJson(existing.extra['billing']);
    final nextTransactions = [
      ...ledger.transactions,
      ...transactions,
    ];
    stateService.write(
      existing.copyWith(
        extra: {
          ...existing.extra,
          'billing': ledger
              .copyWith(balance: balance, transactions: nextTransactions)
              .toJson(),
        },
        events: [
          ...existing.events,
          StudentLearningEvent(
            type: eventType,
            ts: DateTime.now().millisecondsSinceEpoch,
            payload: payload,
          ),
        ],
      ),
    );
  }

  void _recordCreditFailure({
    required String lessonLocalId,
    required String eventType,
    required int amount,
    required String reason,
    required String idempotencyKey,
    required String error,
  }) {
    final existing = stateService.ensure(lessonLocalId: lessonLocalId);
    stateService.write(
      existing.copyWith(
        events: [
          ...existing.events,
          StudentLearningEvent(
            type: eventType,
            ts: DateTime.now().millisecondsSinceEpoch,
            payload: {
              'amount': amount,
              'reason': reason,
              'idempotencyKey': idempotencyKey,
              'error': error,
            },
          ),
        ],
      ),
    );
  }

  CreditReservation _freeReservation(String reason, String idempotencyKey) {
    return CreditReservation(
      reservationId: 'free:$idempotencyKey',
      amount: 0,
      reason: reason,
      status: 'free',
      balance: cachedBalance,
      idempotencyKey: idempotencyKey,
    );
  }
}

StudentBillingTransaction _localTransaction({
  required StudentBillingTransactionType type,
  required StudentBillingTransactionStatus status,
  required int amount,
  required String reason,
  required String reservationId,
  required String idempotencyKey,
  required JsonMap metadata,
}) {
  final now = DateTime.now().millisecondsSinceEpoch;
  return StudentBillingTransaction(
    id: 'local-$idempotencyKey-$now',
    userId: '',
    type: type,
    amount: amount,
    reason: reason,
    status: status,
    createdAt: now,
    updatedAt: now,
    reservationId: reservationId,
    idempotencyKey: idempotencyKey,
    metadata: metadata,
  );
}
