import 'package:flutter/foundation.dart';

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
    final topic = (args.onboarding['objetivo'] ?? first.curriculum.topic)
        .toString()
        .trim();
    args.onStage?.call(StudentExperienceRouteStage.lesson);
    writeStudentExperienceSnapshot(
      service,
      lessonLocalId: args.lessonLocalId,
      state: StudentExperienceState.t02PrimeiraAulaStreaming,
      startMarker: first.marker,
      startItemIndex: first.itemIndex,
    );
    debugPrint('[SIM] T02_FIRST_LESSON_STARTED marker=${first.marker}');
    publishStudentExperienceEvent(
      service,
      args.lessonLocalId,
      StudentExperienceEventType.t02FirstLessonStarted,
      {'marker': first.marker, 'itemIdx': first.itemIndex},
    );

    final stateProfile =
        service.read(args.lessonLocalId)?.profile.toJson() ?? {};
    final mergedOnboarding = <String, dynamic>{
      ...stateProfile,
      ...args.onboarding,
      if (stateProfile['guidance_for_T02'] != null &&
          args.onboarding['guidance_for_T02'] == null)
        'guidance_for_T02': stateProfile['guidance_for_T02'],
    };
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
      pedagogicalEnvelope: _pedagogicalEnvelope(mergedOnboarding),
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

    final material =
        await materialService.resolveLessonMaterialFromStateOrEngine(
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
              : ((first.itemIndex / first.curriculum.items.length) * 100)
                  .round(),
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
    debugPrint('[SIM] T02_FIRST_MINIMUM_LESSON_READY marker=${first.marker}');
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

    materialService.prepareReadyWindowInBackground(
      lessonLocalId: args.lessonLocalId,
      topic: topic,
      itemIdx: first.itemIndex,
      layer: LessonLayer.l1,
      marker: first.marker,
      source: 'StudentExperienceEngineV2:first_lesson_open',
    );
  }

  JsonMap _pedagogicalEnvelope(JsonMap onboarding) {
    Object? pickAny(List<String> keys) {
      for (final key in keys) {
        final value = onboarding[key];
        if (value is String && value.trim().isNotEmpty) return value.trim();
        if (value is List && value.isNotEmpty) return value;
        if (value is Map && value.isNotEmpty) return value;
        if (value != null && value is! String) return value;
      }
      return null;
    }

    void put(JsonMap target, String outputKey, List<String> keys) {
      final value = pickAny(keys);
      if (value != null) target[outputKey] = value;
    }

    final envelope = <String, dynamic>{};
    put(envelope, 'stable_lang', [
      'stable_lang',
      'stableLang',
      'STABLE_LANG',
      'idioma',
    ]);
    put(envelope, 'language', [
      'language',
      'stable_lang',
      'stableLang',
      'STABLE_LANG',
      'idioma',
    ]);
    put(envelope, 'preferred_name', ['preferred_name']);
    put(envelope, 'student_age', ['student_age']);
    put(envelope, 'age_range', ['age_range']);
    put(envelope, 'school_year', ['school_year']);
    put(envelope, 'academic_level', ['academic_level', 'ACADEMIC_LEVEL']);
    put(envelope, 'country_or_curriculum', ['country_or_curriculum']);
    put(envelope, 'subject', ['subject']);
    put(envelope, 'target_topic', ['target_topic', 'TARGET_TOPIC']);
    put(envelope, 'learning_goal', ['learning_goal']);
    put(envelope, 'exam_goal', ['exam_goal']);
    put(envelope, 'real_use_goal', ['real_use_goal']);
    put(envelope, 'prior_knowledge', ['prior_knowledge']);
    put(envelope, 'known_weaknesses', ['known_weaknesses', 'knowledge_gaps']);
    put(envelope, 'recent_errors', ['recent_errors', 'recentErrors']);
    put(envelope, 'confidence_pattern', ['confidence_pattern']);
    put(envelope, 'attention_profile', ['attention_profile']);
    put(envelope, 'motivation_profile', ['motivation_profile']);
    put(envelope, 'reading_level', ['reading_level']);
    put(envelope, 'calculation_level', ['calculation_level']);
    put(envelope, 'learning_care_notes', ['learning_care_notes']);
    put(envelope, 'student_profile_notes', ['student_profile_notes']);
    put(envelope, 'student_profile_internal', ['student_profile_internal']);
    put(envelope, 'guidance_for_T02', [
      'guidance_for_T02',
      'teaching_style_for_T02',
    ]);
    put(envelope, 'interpreted_fields', ['interpreted_fields']);
    put(envelope, 'source_status', ['source_status']);
    put(envelope, 'visual_policy', ['visual_policy']);
    put(envelope, 'session_goal', ['session_goal', 'SESSION_GOAL']);
    put(envelope, 'geographic_zone', ['geographic_zone', 'GEOGRAPHIC_ZONE']);
    put(envelope, 'original_text_preserved', ['original_text_preserved']);
    return envelope;
  }
}
