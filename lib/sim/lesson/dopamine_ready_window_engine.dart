import '../experience/curriculum_utils.dart';
import '../state/live_entry_state.dart';
import '../state/student_learning_state.dart';
import '../state/student_learning_state_service.dart';
import 'lesson_models.dart';
import 'lesson_orchestrator.dart';

class DopamineWindowItem {
  const DopamineWindowItem({
    required this.text,
    this.marker,
    this.isReview = false,
    this.reviewLayer,
  });

  final String text;
  final String? marker;
  final bool isReview;
  final LessonLayer? reviewLayer;
}

class DopamineReadySlot {
  const DopamineReadySlot({
    required this.slot,
    required this.itemIdx,
    required this.marker,
    required this.layer,
    required this.params,
    this.expectedKey,
  });

  final String slot;
  final int itemIdx;
  final String? marker;
  final LessonLayer layer;
  final CompleteLessonParams params;
  final String? expectedKey;
}

class DopamineReadyWindowEngine {
  DopamineReadyWindowEngine({
    required this.service,
    required this.orchestrator,
  });

  final StudentLearningStateService service;
  final LessonOrchestrator orchestrator;
  final Map<String, Future<List<bool>>> _inflight = {};

  List<DopamineReadySlot> buildDopamineReadySlots({
    required String lessonLocalId,
    required String source,
    required List<DopamineWindowItem> items,
    required int currentItemIdx,
    required LessonLayer currentLayer,
    required CompleteLessonParams Function(
      DopamineWindowItem item,
      LessonLayer layer,
    ) buildParams,
  }) {
    final slots = <DopamineReadySlot>[];
    ({int itemIdx, LessonLayer layer})? cursor = (
      itemIdx: currentItemIdx < 0 ? 0 : currentItemIdx,
      layer: items.isNotEmpty && items[currentItemIdx].isReview
          ? items[currentItemIdx].reviewLayer ?? LessonLayer.l1
          : currentLayer,
    );

    for (final slotName in const ['A', 'B', 'C']) {
      if (cursor == null) break;
      if (cursor.itemIdx >= items.length) break;
      final item = items[cursor.itemIdx];
      final params = buildParams(item, cursor.layer);
      slots.add(
        DopamineReadySlot(
          slot: slotName,
          itemIdx: cursor.itemIdx,
          marker: item.marker,
          layer: cursor.layer,
          params: params,
          expectedKey: lessonKeyFor(params),
        ),
      );
      cursor = _nextSlot(cursor.itemIdx, cursor.layer, items);
    }
    return slots;
  }

  Future<List<bool>> maintainDopamineReadyWindow({
    required String lessonLocalId,
    required String source,
    required List<DopamineReadySlot> slots,
    String? topic,
    bool returnMode = false,
    int? maxSlots,
  }) async {
    final selected = slots.take(maxSlots ?? (returnMode ? 2 : 3)).toList();
    _event(lessonLocalId, 'DOPAMINE_WINDOW_REQUESTED', {
      'source': source,
      'returnMode': returnMode,
      'slots': selected
          .map((slot) => {
                'slot': slot.slot,
                'itemIdx': slot.itemIdx,
                'marker': slot.marker,
                'layer': slot.layer.value,
              })
          .toList(),
    });

    final results = <bool>[];
    for (var index = 0; index < selected.length; index++) {
      final slot = selected[index];
      final key = lessonKeyFor(slot.params);
      final existing = _readReadyMaterial(
        lessonLocalId,
        slot.itemIdx,
        slot.marker,
        slot.layer,
      );
      if (existing != null) {
        _markFirstLessonIfNeeded(lessonLocalId, slot);
        _event(lessonLocalId, 'DOPAMINE_SLOT_ALREADY_READY', {
          'source': source,
          'slot': slot.slot,
          'storage': 'student_state',
        });
        results.add(true);
        continue;
      }

      final cached = orchestrator.peekCachedLesson(key);
      if (cached != null) {
        _mirrorPreparedLesson(
          lessonLocalId: lessonLocalId,
          slot: slot,
          lesson: cached,
          model: 'DopamineReadyWindowEngine-cache',
        );
        _markFirstLessonIfNeeded(lessonLocalId, slot);
        _event(lessonLocalId, 'DOPAMINE_SLOT_ALREADY_READY', {
          'source': source,
          'slot': slot.slot,
          'storage': 'cache',
        });
        results.add(true);
        continue;
      }

      if (_isFirstLessonSlot(slot)) {
        updateLiveEntryState(
          service,
          lessonLocalId,
          status: LiveEntryStatus.t02FirstLessonRunning,
          firstItemMarker: slot.marker,
          firstLessonMaterialKey: firstLessonMaterialKey(slot.marker),
          firstLessonStartedAt: DateTime.now().millisecondsSinceEpoch,
        );
      }
      _event(lessonLocalId, 'DOPAMINE_SLOT_REQUESTED', {
        'source': source,
        'slot': slot.slot,
        'itemIdx': slot.itemIdx,
        'marker': slot.marker,
        'layer': slot.layer.value,
        'priority': index == 0 ? 'active' : 'background',
      });

      try {
        final lesson = await orchestrator.prefetchCompleteLesson(
          slot.params,
          priority: index == 0 ? 'active' : 'background',
        );
        _mirrorPreparedLesson(
          lessonLocalId: lessonLocalId,
          slot: slot,
          lesson: lesson,
          model: 'DopamineReadyWindowEngine',
        );
        _markFirstLessonIfNeeded(lessonLocalId, slot);
        _event(lessonLocalId, 'DOPAMINE_SLOT_READY', {
          'source': source,
          'slot': slot.slot,
          'itemIdx': slot.itemIdx,
          'marker': slot.marker,
          'layer': slot.layer.value,
        });
        results.add(true);
      } catch (error) {
        if (_isFirstLessonSlot(slot)) {
          updateLiveEntryState(
            service,
            lessonLocalId,
            status: LiveEntryStatus.failedT02,
            error: error.toString(),
            firstItemMarker: slot.marker,
            firstLessonMaterialKey: firstLessonMaterialKey(slot.marker),
          );
        }
        _event(lessonLocalId, 'DOPAMINE_SLOT_FAILED', {
          'source': source,
          'slot': slot.slot,
          'error': error.toString(),
        });
        results.add(false);
      }
    }

    _event(lessonLocalId, 'DOPAMINE_WINDOW_READY', {
      'source': source,
      'ready': results.where((ready) => ready).length,
      'requested': selected.length,
    });
    return results;
  }

  Future<List<bool>> runDopamineReadyWindowFromStudentState({
    required String lessonLocalId,
    required String source,
    int? maxSlots,
    bool returnMode = false,
    int? itemIdx,
    LessonLayer? layer,
    String? marker,
    String? topic,
  }) {
    final existing = _inflight[lessonLocalId];
    if (existing != null) return existing;
    final promise = () async {
      try {
        return await _runDopamineReadyWindowFromStudentState(
          lessonLocalId: lessonLocalId,
          source: source,
          maxSlots: maxSlots,
          returnMode: returnMode,
          itemIdx: itemIdx,
          layer: layer,
          marker: marker,
          topic: topic,
        );
      } finally {
        _inflight.remove(lessonLocalId);
      }
    }();
    _inflight[lessonLocalId] = promise;
    return promise;
  }

  Future<List<bool>> _runDopamineReadyWindowFromStudentState({
    required String lessonLocalId,
    required String source,
    int? maxSlots,
    bool returnMode = false,
    int? itemIdx,
    LessonLayer? layer,
    String? marker,
    String? topic,
  }) async {
    final state = service.read(lessonLocalId);
    final curriculumItems = state?.curriculum?.items ?? const <CurriculumItem>[];
    final items = curriculumItems
        .map((item) => DopamineWindowItem(
              text: itemText(item),
              marker: item.marker,
            ))
        .where((item) => item.text.isNotEmpty)
        .toList();
    if (state == null || items.isEmpty) {
      _event(lessonLocalId, 'DOPAMINE_SLOT_FAILED', {
        'source': source,
        'reason': 'state_has_no_curriculum_items',
      });
      return const [];
    }

    final markerIdx = marker == null
        ? -1
        : items.indexWhere((item) => item.marker == marker);
    final currentItemIdx = itemIdx != null
        ? itemIdx.clamp(0, items.length - 1)
        : markerIdx >= 0
            ? markerIdx
            : state.current?.itemIdx ?? state.progress?.itemIdx ?? 0;
    final currentLayer =
        layer ?? state.current?.layer ?? state.progress?.layer ?? LessonLayer.l1;
    final profile = state.profile.toJson();
    final lang = _langFromProfile(profile);
    final academic = _academicFromProfile(profile);

    final slots = buildDopamineReadySlots(
      lessonLocalId: lessonLocalId,
      source: source,
      items: items,
      currentItemIdx: currentItemIdx,
      currentLayer: currentLayer,
      buildParams: (item, slotLayer) => CompleteLessonParams(
        lessonLocalId: lessonLocalId,
        item: item.text,
        lang: lang,
        academic: academic,
        layer: slotLayer,
        mode: item.isReview ? LessonMode.reforco : LessonMode.session,
        marker: item.marker,
        pedagogicalEnvelope: _pedagogicalEnvelope(profile),
      ),
    );

    return maintainDopamineReadyWindow(
      lessonLocalId: lessonLocalId,
      source: source,
      slots: slots,
      topic: topic ?? state.profile.objetivo ?? state.curriculum?.topic,
      returnMode: returnMode,
      maxSlots: maxSlots,
    );
  }

  ({int itemIdx, LessonLayer layer})? _nextSlot(
    int itemIdx,
    LessonLayer layer,
    List<DopamineWindowItem> items,
  ) {
    final item = items[itemIdx];
    if (!item.isReview && layer != LessonLayer.l3) {
      return (
        itemIdx: itemIdx,
        layer: layer == LessonLayer.l1 ? LessonLayer.l2 : LessonLayer.l3,
      );
    }
    final nextIdx = itemIdx + 1;
    if (nextIdx >= items.length) return null;
    final next = items[nextIdx];
    return (itemIdx: nextIdx, layer: next.reviewLayer ?? LessonLayer.l1);
  }

  JsonMap? _readReadyMaterial(
    String lessonLocalId,
    int itemIdx,
    String? marker,
    LessonLayer layer,
  ) {
    final state = service.read(lessonLocalId);
    final key = preparedLessonMaterialKey(itemIdx, marker, layer);
    final prepared = state?.readyLessonMaterials[key];
    if (prepared?['text_status'] == 'ready') return prepared;
    return null;
  }

  void _mirrorPreparedLesson({
    required String lessonLocalId,
    required DopamineReadySlot slot,
    required CompleteLesson lesson,
    required String model,
  }) {
    final key = preparedLessonMaterialKey(slot.itemIdx, slot.marker, slot.layer);
    service.mutate(lessonLocalId, (state) {
      return state.copyWith(
        readyLessonMaterials: {
          ...state.readyLessonMaterials,
          key: {
            ...preparedMaterialFromLesson(
              lesson: lesson,
              itemIdx: slot.itemIdx,
              marker: slot.marker,
              layer: slot.layer,
            ),
            'model': model,
          },
        },
      );
    });
  }

  void _markFirstLessonIfNeeded(String lessonLocalId, DopamineReadySlot slot) {
    if (!_isFirstLessonSlot(slot)) return;
    updateLiveEntryState(
      service,
      lessonLocalId,
      status: LiveEntryStatus.firstLessonReady,
      firstItemMarker: slot.marker,
      firstLessonMaterialKey: firstLessonMaterialKey(slot.marker),
      firstLessonReadyAt: DateTime.now().millisecondsSinceEpoch,
    );
  }

  bool _isFirstLessonSlot(DopamineReadySlot slot) {
    return slot.slot == 'A' && slot.itemIdx == 0 && slot.layer == LessonLayer.l1;
  }

  void _event(String lessonLocalId, String type, JsonMap payload) {
    service.appendEvent(
      lessonLocalId,
      StudentLearningEvent(
        type: type,
        ts: DateTime.now().millisecondsSinceEpoch,
        payload: payload,
      ),
    );
  }
}

String _pickProfileString(JsonMap profile, List<String> keys) {
  for (final key in keys) {
    final value = profile[key];
    if (value is String && value.trim().isNotEmpty) return value.trim();
  }
  return '';
}

String _langFromProfile(JsonMap profile) {
  final direct = _pickProfileString(
    profile,
    ['stableLang', 'STABLE_LANG', 'language', 'idioma'],
  );
  const map = {
    'pt': 'Portuguese',
    'en': 'English',
    'es': 'Spanish',
    'fr': 'French',
    'ja': 'Japanese',
  };
  return map[direct] ?? (direct.isEmpty ? 'English' : direct);
}

String _academicFromProfile(JsonMap profile) {
  final direct = _pickProfileString(
    profile,
    ['academicLevel', 'academic_level', 'ACADEMIC_LEVEL'],
  );
  if (direct.isNotEmpty) return direct;
  final nivel = _pickProfileString(profile, ['nivel']);
  return switch (nivel) {
    'zero' => 'iniciante absoluto (zero conhecimento)',
    'pouco' => 'iniciante (algum contato previo)',
    'base' => 'intermediario (base solida)',
    'avancado' => 'avancado',
    _ => 'iniciante (nivel incerto, ajustar)',
  };
}

JsonMap _pedagogicalEnvelope(JsonMap profile) {
  return {
    if (profile['student_profile_internal'] != null)
      'student_profile_internal': profile['student_profile_internal'],
    if (profile['guidance_for_T02'] != null)
      'guidance_for_T02': profile['guidance_for_T02'],
    if (_pickProfileString(profile, ['preferred_name']).isNotEmpty)
      'preferred_name': _pickProfileString(profile, ['preferred_name']),
    if (_pickProfileString(profile, ['student_profile_notes']).isNotEmpty)
      'student_profile_notes':
          _pickProfileString(profile, ['student_profile_notes']),
    if (profile['interpreted_fields'] != null)
      'interpreted_fields': profile['interpreted_fields'],
    if (_pickProfileString(profile, ['target_topic', 'TARGET_TOPIC']).isNotEmpty)
      'target_topic': _pickProfileString(profile, ['target_topic', 'TARGET_TOPIC']),
    if (_pickProfileString(profile, ['subject']).isNotEmpty)
      'subject': _pickProfileString(profile, ['subject']),
    if (_pickProfileString(profile, ['exam_goal']).isNotEmpty)
      'exam_goal': _pickProfileString(profile, ['exam_goal']),
    if (_pickProfileString(profile, ['session_goal', 'SESSION_GOAL']).isNotEmpty)
      'session_goal': _pickProfileString(profile, ['session_goal', 'SESSION_GOAL']),
    if (_pickProfileString(profile, ['geographic_zone', 'GEOGRAPHIC_ZONE']).isNotEmpty)
      'geographic_zone':
          _pickProfileString(profile, ['geographic_zone', 'GEOGRAPHIC_ZONE']),
    if (_pickProfileString(profile, ['country_or_curriculum']).isNotEmpty)
      'country_or_curriculum':
          _pickProfileString(profile, ['country_or_curriculum']),
    if (_pickProfileString(profile, ['original_text_preserved', 'objetivo']).isNotEmpty)
      'original_text_preserved':
          _pickProfileString(profile, ['original_text_preserved', 'objetivo']),
  };
}
