import '../state/student_learning_state.dart';
import 'student_learning_sync.dart';

class LessonCloudBootstrapInput {
  const LessonCloudBootstrapInput({
    required this.curriculum,
    required this.onboarding,
    required this.itemIdx,
    required this.layer,
    required this.mainAdvances,
  });

  final StudentCurriculum? curriculum;
  final JsonMap onboarding;
  final int itemIdx;
  final LessonLayer layer;
  final int mainAdvances;
}

class LessonCloudBootstrap {
  const LessonCloudBootstrap({required this.sync});

  final StudentLearningSync sync;

  Future<bool> run(LessonCloudBootstrapInput input) async {
    final objetivo = input.onboarding['objetivo'];
    if (input.curriculum?.items.isNotEmpty != true ||
        objetivo is! String ||
        objetivo.isEmpty) {
      return false;
    }
    final lessonLocalId = canonicalLessonLocalId(input.onboarding);
    sync.enqueuePatch(lessonLocalId);
    await sync.drain();
    return true;
  }
}

String canonicalLessonLocalId(JsonMap onboarding) {
  final existing = onboarding['lessonLocalId'] ?? onboarding['lesson_local_id'];
  if (existing is String && existing.trim().isNotEmpty) return existing.trim();
  final objetivo = (onboarding['objetivo'] ?? 'sim').toString().trim();
  var hash = 5381;
  for (final unit in objetivo.codeUnits) {
    hash = ((hash << 5) + hash) ^ unit;
  }
  return 'local-${(hash & 0xffffffff).toRadixString(36)}';
}
