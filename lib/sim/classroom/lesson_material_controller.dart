import '../lesson/dopamine_ready_window_engine.dart';
import '../lesson/lesson_models.dart';
import '../lesson/student_lesson_material_service.dart';
import '../state/live_entry_state.dart';
import '../state/student_learning_state.dart';
import '../state/student_learning_state_service.dart';
import 'classroom_models.dart';
import 'lesson_position_engine.dart';

class LessonMaterialController {
  LessonMaterialController({
    required this.stateService,
    required this.materialService,
  });

  final StudentLearningStateService stateService;
  final StudentLessonMaterialService materialService;

  Future<void> carregar({
    required String lessonLocalId,
    required String? topic,
    required LessonPositionState position,
    required String idioma,
    required String academic,
    required LessonMode mode,
    required List<PlannedItem> baseItems,
    bool forceRefresh = false,
  }) async {
    final item = position.itemAtivo;
    if (item == null) {
      position.phase = const ClassroomPhase.doneEnd();
      return;
    }

    final currentState = stateService.read(lessonLocalId);
    final params = CompleteLessonParams(
      lessonLocalId: lessonLocalId,
      item: item.text,
      lang: idioma,
      academic: academic,
      layer: position.layer,
      mode: mode,
      errCount: position.erros,
      history: position.historia,
      marker: item.marker,
      amparoLvl: currentState?.progress?.amparoLvl,
      pedagogicalEnvelope: _pedagogicalEnvelope(
        currentState?.profile.toJson() ?? const {},
        item,
      ),
    );

    final fast = forceRefresh
        ? null
        : materialService.resolveFastLessonMaterialFromStateOrCache(
            ResolveLessonMaterialInput(
              lessonLocalId: lessonLocalId,
              topic: topic,
              itemIdx: position.itemIdx,
              marker: item.marker,
              layer: position.layer,
              params: params,
            ),
          );
    if (fast != null) {
      _applyMaterial(position, fast);
      _mirrorDisplayedPreparedLesson(
        lessonLocalId: lessonLocalId,
        position: position,
        item: item,
        material: fast,
      );
      _markShowingFirstLessonIfNeeded(lessonLocalId, position, item);
      materialService.maintainLessonReadyWindow(
        lessonLocalId: lessonLocalId,
        topic: topic,
        itemIdx: position.itemIdx,
        layer: position.layer,
        items: baseItems
            .map((item) => DopamineWindowItem(text: item.text, marker: item.marker))
            .toList(),
        source: 'cyber.aula.cache-window',
        priority: 'background',
        reason: 'lesson_window_visible',
      );
      return;
    }

    position.phase = const ClassroomPhase.loading();
    position.imagem = null;
    position.teoriaPronta = false;
    final resolved = await materialService.resolveLessonMaterialFromStateOrEngine(
      ResolveLessonMaterialInput(
        lessonLocalId: lessonLocalId,
        topic: topic,
        itemIdx: position.itemIdx,
        marker: item.marker,
        layer: position.layer,
        params: params,
        waitBeforeOrderMs: 0,
        waitAfterOrderMs: 3000,
      ),
    );
    if (resolved == null) {
      position.phase = const ClassroomPhase.engineError(
        'A primeira aula foi liberada, mas a tela nao encontrou o slot A no Estado do aluno.',
      );
      return;
    }
    _applyMaterial(position, resolved);
    _mirrorDisplayedPreparedLesson(
      lessonLocalId: lessonLocalId,
      position: position,
      item: item,
      material: resolved,
    );
    _markShowingFirstLessonIfNeeded(lessonLocalId, position, item);
  }

  void _applyMaterial(
    LessonPositionState position,
    ResolveLessonMaterialResult material,
  ) {
    position.conteudo = material.conteudo;
    position.imagem = material.imagem;
    position.teoriaPronta = true;
    position.phase = const ClassroomPhase.reading();
  }

  void _mirrorDisplayedPreparedLesson({
    required String lessonLocalId,
    required LessonPositionState position,
    required PlannedItem item,
    required ResolveLessonMaterialResult material,
  }) {
    stateService.mutate(lessonLocalId, (state) {
      return state.copyWith(
        currentLessonMaterial: {
          'text_status': 'ready',
          ...material.conteudo.toJson(),
          'generated_at': DateTime.now().toIso8601String(),
          'model': 'T02-display',
          'prompt_contract_version': 'T02_content.v3',
          'for_itemIdx': position.itemIdx,
          'for_marker': item.marker,
          'for_layer': position.layer.value,
        },
      );
    });
  }

  void _markShowingFirstLessonIfNeeded(
    String lessonLocalId,
    LessonPositionState position,
    PlannedItem item,
  ) {
    if (position.itemIdx != 0 || position.layer != LessonLayer.l1) return;
    updateLiveEntryState(
      stateService,
      lessonLocalId,
      status: LiveEntryStatus.showingFirstLesson,
      firstItemMarker: item.marker,
      firstLessonMaterialKey: firstLessonMaterialKey(item.marker),
      firstLessonReadyAt: DateTime.now().millisecondsSinceEpoch,
    );
  }

  JsonMap _pedagogicalEnvelope(JsonMap profile, PlannedItem item) {
    String pick(List<String> keys) {
      for (final key in keys) {
        final value = profile[key];
        if (value is String && value.trim().isNotEmpty) return value.trim();
      }
      return '';
    }

    return {
      if (item.marker.isNotEmpty) 'marker': item.marker,
      if (pick(['stableLang', 'STABLE_LANG', 'idioma']).isNotEmpty)
        'stable_lang': pick(['stableLang', 'STABLE_LANG', 'idioma']),
      if (pick(['academic_level', 'ACADEMIC_LEVEL']).isNotEmpty)
        'academic_level': pick(['academic_level', 'ACADEMIC_LEVEL']),
      if (profile['student_profile_internal'] != null)
        'student_profile_internal': profile['student_profile_internal'],
      if (profile['guidance_for_T02'] != null)
        'guidance_for_T02': profile['guidance_for_T02'],
      if (pick(['preferred_name']).isNotEmpty)
        'preferred_name': pick(['preferred_name']),
      if (pick(['student_profile_notes']).isNotEmpty)
        'student_profile_notes': pick(['student_profile_notes']),
      if (profile['interpreted_fields'] != null)
        'interpreted_fields': profile['interpreted_fields'],
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
