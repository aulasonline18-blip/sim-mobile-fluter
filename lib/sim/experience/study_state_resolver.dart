import '../lesson/lesson_material_cache.dart';
import '../lesson/lesson_models.dart';
import '../state/student_learning_state.dart';

String normalizeStudyKey(Object? value) {
  if (value == null) return '';
  final decomposed = value.toString().trim().toLowerCase();
  const accents = {
    'á': 'a',
    'à': 'a',
    'ã': 'a',
    'â': 'a',
    'ä': 'a',
    'é': 'e',
    'è': 'e',
    'ê': 'e',
    'ë': 'e',
    'í': 'i',
    'ì': 'i',
    'î': 'i',
    'ï': 'i',
    'ó': 'o',
    'ò': 'o',
    'õ': 'o',
    'ô': 'o',
    'ö': 'o',
    'ú': 'u',
    'ù': 'u',
    'û': 'u',
    'ü': 'u',
    'ç': 'c',
    'ñ': 'n',
  };
  final buffer = StringBuffer();
  for (final rune in decomposed.runes) {
    final char = String.fromCharCode(rune);
    buffer.write(accents[char] ?? char);
  }
  return buffer
      .toString()
      .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

enum ExistingStudyReadySource {
  readyLessonMaterials,
  currentLessonMaterial,
  lessonCache,
}

class ExistingStudyResolution {
  const ExistingStudyResolution({
    required this.curriculumExists,
    required this.curriculumMatchesObjective,
    required this.placementSettled,
    required this.startMarker,
    required this.initialItemIndex,
    required this.initialMarker,
    required this.readyMaterialExists,
    required this.readySource,
    required this.needsCurriculumGeneration,
    required this.needsLessonGeneration,
    required this.destination,
  });

  final bool curriculumExists;
  final bool curriculumMatchesObjective;
  final bool placementSettled;
  final String? startMarker;
  final int initialItemIndex;
  final String? initialMarker;
  final bool readyMaterialExists;
  final ExistingStudyReadySource? readySource;
  final bool needsCurriculumGeneration;
  final bool needsLessonGeneration;
  final String? destination;
}

class ExistingStudyResolverArgs {
  const ExistingStudyResolverArgs({
    required this.onboarding,
    required this.curriculum,
    required this.placement,
    required this.placementEnabled,
    required this.lessonLocalId,
    required this.learningState,
    this.cache,
    this.buildInitialParams,
  });

  final JsonMap onboarding;
  final StudentCurriculum? curriculum;
  final JsonMap? placement;
  final bool placementEnabled;
  final String lessonLocalId;
  final StudentLearningState? learningState;
  final LessonMaterialCache? cache;
  final CompleteLessonParams? Function(int itemIndex)? buildInitialParams;
}

ExistingStudyResolution resolveExistingStudyStateBeforeGeneration(
  ExistingStudyResolverArgs args,
) {
  final curriculum = args.curriculum;
  final curriculumExists = curriculum != null &&
      curriculum.items.isNotEmpty &&
      !curriculum.provisional;
  final objective = args.onboarding['objetivo'];
  final curriculumMatchesObjective = curriculumExists &&
      normalizeStudyKey(curriculum.topic) == normalizeStudyKey(objective);

  final placementStatus = args.placement?['pretest_status']?.toString();
  final placementSettled = !args.placementEnabled ||
      placementStatus == 'done' ||
      placementStatus == 'skipped';

  final startMarker = args.placementEnabled
      ? _cleanString(args.placement?['start_marker'])
      : null;
  final items =
      curriculumMatchesObjective ? curriculum.items : const <CurriculumItem>[];
  final matchedIndex = startMarker == null
      ? 0
      : items.indexWhere((item) => item.marker.trim() == startMarker);
  final initialItemIndex = matchedIndex >= 0 ? matchedIndex : 0;
  final initialMarker = items.isEmpty
      ? null
      : items[initialItemIndex.clamp(0, items.length - 1)].marker;

  ExistingStudyReadySource? readySource;
  if (curriculumMatchesObjective && initialMarker != null) {
    final state = args.learningState;
    final preparedKey = preparedLessonMaterialKey(
      initialItemIndex,
      initialMarker,
      LessonLayer.l1,
    );
    final prepared = state?.readyLessonMaterials[preparedKey];
    if (prepared?['text_status'] == 'ready') {
      readySource = ExistingStudyReadySource.readyLessonMaterials;
    }

    final current = state?.currentLessonMaterial;
    if (readySource == null &&
        current?['text_status'] == 'ready' &&
        current?['for_itemIdx'] == initialItemIndex &&
        current?['for_marker'] == initialMarker &&
        current?['for_layer'] == 1) {
      readySource = ExistingStudyReadySource.currentLessonMaterial;
    }

    final params = args.buildInitialParams?.call(initialItemIndex);
    if (readySource == null && params != null) {
      final cached = args.cache?.peek(lessonKeyFor(params));
      if (cached != null) readySource = ExistingStudyReadySource.lessonCache;
    }
  }

  final needsCurriculumGeneration = !curriculumMatchesObjective;
  final readyMaterialExists = readySource != null;
  return ExistingStudyResolution(
    curriculumExists: curriculumExists,
    curriculumMatchesObjective: curriculumMatchesObjective,
    placementSettled: placementSettled,
    startMarker: startMarker,
    initialItemIndex: initialItemIndex,
    initialMarker: initialMarker,
    readyMaterialExists: readyMaterialExists,
    readySource: readySource,
    needsCurriculumGeneration: needsCurriculumGeneration,
    needsLessonGeneration:
        curriculumMatchesObjective && placementSettled && !readyMaterialExists,
    destination: curriculumMatchesObjective
        ? placementSettled
            ? '/cyber/aula'
            : '/cyber/placement'
        : null,
  );
}

String preparedLessonMaterialKey(
  int itemIndex,
  String marker,
  LessonLayer layer,
) {
  return '$itemIndex::$marker::${layer.value}';
}

String? _cleanString(Object? value) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty) return null;
  return text;
}
