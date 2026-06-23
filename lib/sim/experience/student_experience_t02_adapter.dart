import '../lesson/dopamine_ready_window_engine.dart';
import '../lesson/lesson_models.dart';
import '../lesson/student_lesson_material_service.dart';
import '../state/live_entry_state.dart';
import '../state/student_learning_state.dart';
import '../state/student_learning_state_service.dart';
import 'curriculum_utils.dart';
import 'student_experience_store.dart';
import 'student_experience_types.dart';

class StudentExperienceT02Adapter {
  StudentExperienceT02Adapter({
    required this.service,
    required this.materialService,
  });

  final StudentLearningStateService service;
  final StudentLessonMaterialService materialService;

  Future<void> prepareFirstMinimumLesson({
    required StudentExperienceArgs args,
    required FirstCurriculumItem first,
  }) async {
    final topic =
        (args.onboarding['objetivo'] ?? first.curriculum.topic).toString().trim();
    args.onStage?.call(StudentExperienceRouteStage.lesson);
    writeStudentExperienceSnapshot(
      service,
      lessonLocalId: args.lessonLocalId,
      state: StudentExperienceState.t02PrimeiraAulaStreaming,
      startMarker: first.marker,
      startItemIndex: first.itemIndex,
    );
    publishStudentExperienceEvent(
      service,
      args.lessonLocalId,
      StudentExperienceEventType.t02FirstLessonStarted,
      {
        'marker': first.marker,
        'itemIdx': first.itemIndex,
      },
    );

    final params = CompleteLessonParams(
      lessonLocalId: args.lessonLocalId,
      item: itemText(first.item),
      lang: args.idioma,
      academic: args.academic,
      layer: LessonLayer.l1,
      mode: LessonMode.session,
      errCount: 0,
      history: const [],
      marker: first.marker,
      pedagogicalEnvelope: _pedagogicalEnvelope(args.onboarding),
    );

    updateLiveEntryState(
      service,
      args.lessonLocalId,
      status: LiveEntryStatus.t02FirstLessonRunning,
      firstItemMarker: first.marker,
      firstLessonMaterialKey: entryLessonMaterialKey(
        first.itemIndex,
        first.marker,
      ),
      firstLessonStartedAt: DateTime.now().millisecondsSinceEpoch,
    );

    materialService.maintainLessonReadyWindow(
      lessonLocalId: args.lessonLocalId,
      topic: topic,
      itemIdx: first.itemIndex,
      layer: LessonLayer.l1,
      items: first.curriculum.items
          .map((item) => DopamineWindowItem(text: itemText(item), marker: item.marker))
          .toList(),
      source: 'StudentExperienceEngineV2',
      priority: 'active',
      reason: 'first_experience_minimum',
    );

    final material = await materialService.resolveLessonMaterialFromStateOrEngine(
      ResolveLessonMaterialInput(
        lessonLocalId: args.lessonLocalId,
        topic: topic,
        itemIdx: first.itemIndex,
        marker: first.marker,
        layer: LessonLayer.l1,
        params: params,
        waitBeforeOrderMs: 0,
        waitAfterOrderMs: 45000,
      ),
    );
    if (material == null) {
      throw Exception('T02 nao devolveu a aula minima da primeira experiencia');
    }

    service.mutate(args.lessonLocalId, (state) {
      return state.copyWith(
        current: LessonCurrent(
          itemIdx: first.itemIndex,
          marker: first.marker,
          layer: LessonLayer.l1,
          amparoLvl: 0,
        ),
        progress: LessonProgress(
          itemIdx: first.itemIndex,
          layer: LessonLayer.l1,
          erros: 0,
          amparoLvl: 0,
          historia: const [],
          mainAdvances: first.itemIndex,
          concluidos: const [],
          pendentesMarkers: const [],
          totalItems: first.curriculum.items.length,
          pctAvanco: first.curriculum.items.isEmpty
              ? 0
              : ((first.itemIndex / first.curriculum.items.length) * 100).round(),
        ),
      );
    });

    writeStudentExperienceSnapshot(
      service,
      lessonLocalId: args.lessonLocalId,
      state: StudentExperienceState.primeiraAulaMinimaPronta,
      destination: '/cyber/aula',
      startMarker: first.marker,
      startItemIndex: first.itemIndex,
    );
    publishStudentExperienceEvent(
      service,
      args.lessonLocalId,
      StudentExperienceEventType.t02FirstMinimumLessonReady,
      {
        'marker': first.marker,
        'itemIdx': first.itemIndex,
        'materialKey': entryLessonMaterialKey(first.itemIndex, first.marker),
        'source': material.source.name,
        'waitedMs': material.waitedMs,
      },
    );
  }

  JsonMap _pedagogicalEnvelope(JsonMap onboarding) {
    String pick(List<String> keys) {
      for (final key in keys) {
        final value = onboarding[key];
        if (value is String && value.trim().isNotEmpty) return value.trim();
      }
      return '';
    }

    return {
      if (pick(['stableLang', 'STABLE_LANG', 'idioma']).isNotEmpty)
        'stable_lang': pick(['stableLang', 'STABLE_LANG', 'idioma']),
      if (pick(['academic_level', 'ACADEMIC_LEVEL']).isNotEmpty)
        'academic_level': pick(['academic_level', 'ACADEMIC_LEVEL']),
      if (onboarding['student_profile_internal'] != null)
        'student_profile_internal': onboarding['student_profile_internal'],
      if (onboarding['guidance_for_T02'] != null)
        'guidance_for_T02': onboarding['guidance_for_T02'],
      if (pick(['preferred_name']).isNotEmpty)
        'preferred_name': pick(['preferred_name']),
      if (pick(['student_profile_notes']).isNotEmpty)
        'student_profile_notes': pick(['student_profile_notes']),
      if (onboarding['interpreted_fields'] != null)
        'interpreted_fields': onboarding['interpreted_fields'],
      if (pick(['target_topic', 'TARGET_TOPIC']).isNotEmpty)
        'target_topic': pick(['target_topic', 'TARGET_TOPIC']),
      if (pick(['subject']).isNotEmpty) 'subject': pick(['subject']),
      if (pick(['exam_goal']).isNotEmpty) 'exam_goal': pick(['exam_goal']),
      if (pick(['session_goal', 'SESSION_GOAL']).isNotEmpty)
        'session_goal': pick(['session_goal', 'SESSION_GOAL']),
      if (pick(['geographic_zone', 'GEOGRAPHIC_ZONE']).isNotEmpty)
        'geographic_zone': pick(['geographic_zone', 'GEOGRAPHIC_ZONE']),
      if (pick(['country_or_curriculum']).isNotEmpty)
        'country_or_curriculum': pick(['country_or_curriculum']),
      if (pick(['original_text_preserved']).isNotEmpty)
        'original_text_preserved': pick(['original_text_preserved']),
    };
  }
}
