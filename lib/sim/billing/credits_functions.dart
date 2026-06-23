class CreditsSnapshot {
  const CreditsSnapshot({
    required this.balance,
    required this.lifetimeEarned,
    required this.lifetimeSpent,
    this.email,
    this.displayName,
  });

  final int balance;
  final int lifetimeEarned;
  final int lifetimeSpent;
  final String? email;
  final String? displayName;
}

class ChargeLessonGenerationInput {
  const ChargeLessonGenerationInput({
    required this.lessonLocalId,
    this.legacyLessonLocalIds = const [],
  });

  final String lessonLocalId;
  final List<String> legacyLessonLocalIds;

  ChargeLessonGenerationInput normalized() {
    final id = lessonLocalId.trim();
    if (id.isEmpty) throw ArgumentError('lessonLocalId is required');
    return ChargeLessonGenerationInput(
      lessonLocalId: id.length > 160 ? id.substring(0, 160) : id,
      legacyLessonLocalIds: legacyLessonLocalIds
          .map((legacy) => legacy.trim())
          .where((legacy) => legacy.isNotEmpty)
          .map((legacy) => legacy.length > 160 ? legacy.substring(0, 160) : legacy)
          .take(200)
          .toList(growable: false),
    );
  }
}

abstract interface class CreditsFunctions {
  Future<CreditsSnapshot> getMyCredits();

  Future<int> chargeLessonGeneration(ChargeLessonGenerationInput input);
}
