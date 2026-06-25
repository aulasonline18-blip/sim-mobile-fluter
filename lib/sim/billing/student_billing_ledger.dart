import '../state/student_learning_state.dart';

enum StudentBillingTransactionType { purchase, reserve, charge, refund }

enum StudentBillingTransactionStatus { pending, completed, failed }

class StudentBillingTransaction {
  const StudentBillingTransaction({
    required this.id,
    required this.userId,
    required this.type,
    required this.amount,
    required this.reason,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.reservationId,
    this.idempotencyKey,
    this.metadata = const {},
  });

  final String id;
  final String userId;
  final StudentBillingTransactionType type;
  final int amount;
  final String reason;
  final StudentBillingTransactionStatus status;
  final int createdAt;
  final int updatedAt;
  final String? reservationId;
  final String? idempotencyKey;
  final JsonMap metadata;

  JsonMap toJson() => {
        'id': id,
        'user_id': userId,
        'type': type.name,
        'amount': amount,
        'reason': reason,
        'status': status.name,
        'created_at': createdAt,
        'updated_at': updatedAt,
        if (reservationId != null) 'reservation_id': reservationId,
        if (idempotencyKey != null) 'idempotency_key': idempotencyKey,
        'metadata': metadata,
      };

  static StudentBillingTransaction fromJson(JsonMap json) {
    return StudentBillingTransaction(
      id: (json['id'] ?? '').toString(),
      userId: (json['user_id'] ?? json['userId'] ?? '').toString(),
      type: StudentBillingTransactionType.values.firstWhere(
        (value) => value.name == (json['type'] ?? '').toString(),
        orElse: () => StudentBillingTransactionType.charge,
      ),
      amount: (json['amount'] as num?)?.toInt() ?? 0,
      reason: (json['reason'] ?? '').toString(),
      status: StudentBillingTransactionStatus.values.firstWhere(
        (value) => value.name == (json['status'] ?? '').toString(),
        orElse: () => StudentBillingTransactionStatus.pending,
      ),
      createdAt: _parseTs(json['created_at'] ?? json['createdAt']),
      updatedAt: _parseTs(json['updated_at'] ?? json['updatedAt']),
      reservationId:
          (json['reservation_id'] ?? json['reservationId'])?.toString(),
      idempotencyKey:
          (json['idempotency_key'] ?? json['idempotencyKey'])?.toString(),
      metadata: json['metadata'] is Map
          ? JsonMap.from(json['metadata'] as Map)
          : const {},
    );
  }
}

class StudentBillingLedger {
  const StudentBillingLedger({
    this.balance = 0,
    this.transactions = const [],
  });

  final int balance;
  final List<StudentBillingTransaction> transactions;

  JsonMap toJson() => {
        'balance': balance,
        'transactions':
            transactions.map((transaction) => transaction.toJson()).toList(),
      };

  static StudentBillingLedger fromJson(Object? value) {
    if (value is! Map) return const StudentBillingLedger();
    final raw = value['transactions'];
    return StudentBillingLedger(
      balance: (value['balance'] as num?)?.toInt() ?? 0,
      transactions: raw is List
          ? raw
              .whereType<Map>()
              .map((entry) => StudentBillingTransaction.fromJson(
                    JsonMap.from(entry),
                  ))
              .toList(growable: false)
          : const [],
    );
  }

  StudentBillingLedger copyWith({
    int? balance,
    List<StudentBillingTransaction>? transactions,
  }) {
    return StudentBillingLedger(
      balance: balance ?? this.balance,
      transactions: transactions ?? this.transactions,
    );
  }
}

int _parseTs(Object? value) {
  if (value is num) return value.toInt();
  if (value is String) {
    return DateTime.tryParse(value)?.millisecondsSinceEpoch ??
        int.tryParse(value) ??
        0;
  }
  return 0;
}
