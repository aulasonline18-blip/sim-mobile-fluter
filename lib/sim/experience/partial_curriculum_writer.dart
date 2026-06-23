import '../state/student_learning_state.dart';
import '../state/student_learning_state_service.dart';
import 'curriculum_utils.dart';

class T00StreamItem {
  const T00StreamItem({
    this.order,
    this.marker,
    this.text,
    this.title,
    this.microitemForTeacher,
  });

  final int? order;
  final String? marker;
  final String? text;
  final String? title;
  final String? microitemForTeacher;

  factory T00StreamItem.fromJson(JsonMap json) => T00StreamItem(
        order: (json['order'] as num?)?.toInt(),
        marker: json['marker'] as String?,
        text: json['text'] as String?,
        title: json['title'] as String?,
        microitemForTeacher: json['microitem_for_teacher'] as String?,
      );
}

class PartialCurriculumAppendResult {
  const PartialCurriculumAppendResult({
    required this.count,
    required this.marker,
  });

  final int count;
  final String marker;
}

PartialCurriculumAppendResult? appendPartialCurriculumItemToState({
  required StudentLearningStateService service,
  required T00StreamItem raw,
  required List<CurriculumItem> partialItems,
  required String lessonLocalId,
  required String? objective,
  required int bootStartedAt,
}) {
  final marker = raw.marker?.trim().isNotEmpty == true
      ? raw.marker!.trim()
      : raw.order != null
          ? 'M${raw.order}'
          : 'M${partialItems.length + 1}';
  final text = (raw.microitemForTeacher ?? raw.text ?? raw.title ?? '').trim();
  if (marker.isEmpty || text.isEmpty) return null;

  final key = marker.toLowerCase();
  if (partialItems.any((item) => item.marker.trim().toLowerCase() == key)) {
    return null;
  }

  final item = CurriculumItem(
    marker: marker,
    text: text,
    title: raw.title?.trim().isNotEmpty == true ? raw.title!.trim() : text,
    microitemForTeacher: text,
    extra: const {'source_status': 'partial'},
  );
  partialItems.add(item);

  final nowIso = DateTime.now().toIso8601String();
  final status = partialItems.length == 1
      ? CurriculumStatusValue.streaming
      : CurriculumStatusValue.partialReady;
  service.mutate(lessonLocalId, (state) {
    final extra = partialItems.length == 1
        ? {...state.profile.extra, 'first_item_received_at': nowIso}
        : state.profile.extra;
    return state.copyWith(
      profile: state.profile.copyWith(extra: extra),
      curriculum: StudentCurriculum(
        topic: objective ?? '',
        totalItems: partialItems.length,
        generatedAt: DateTime.now().millisecondsSinceEpoch,
        provisional: true,
        items: List.unmodifiable(partialItems),
      ),
      curriculumStatus: StudentCurriculumStatus(
        status: status,
        expansionStatus: CurriculumStatusValue.streaming,
        updatedAt: nowIso,
        objectiveKey: normalizeStudyKey(objective),
        initialCount: partialItems.length,
        totalCount: partialItems.length,
      ),
    );
  });

  return PartialCurriculumAppendResult(
    count: partialItems.length,
    marker: marker,
  );
}
