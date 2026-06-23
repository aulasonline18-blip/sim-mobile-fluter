import '../state/student_learning_state.dart';

class PlacementContext {
  const PlacementContext({
    required this.language,
    required this.objetivo,
    required this.curriculumItems,
    required this.markers,
    this.academicLevel,
    this.studentProfileInternal,
  });

  final String language;
  final String objetivo;
  final String? academicLevel;
  final Object? studentProfileInternal;
  final List<CurriculumItem> curriculumItems;
  final List<String> markers;
}

PlacementContext? buildPlacementContext(StudentLearningState? state) {
  final curriculum = state?.curriculum;
  if (state == null || curriculum == null || curriculum.items.isEmpty) {
    return null;
  }
  final profile = state.profile.toJson();
  final lang = (profile['stableLang'] ??
          profile['STABLE_LANG'] ??
          profile['language'] ??
          profile['idioma'] ??
          'English')
      .toString();
  return PlacementContext(
    language: lang,
    objetivo: (profile['objetivo'] ?? curriculum.topic).toString(),
    academicLevel:
        (profile['academic_level'] ?? profile['ACADEMIC_LEVEL']) as String?,
    studentProfileInternal: profile['student_profile_internal'],
    curriculumItems: curriculum.items,
    markers: curriculum.items.map((item) => item.marker).toList(),
  );
}
