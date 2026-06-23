import '../state/student_learning_state.dart';

String itemText(CurriculumItem item) {
  return (item.microitemForTeacher ?? item.title ?? item.text).trim();
}

String normalizeStudyKey(Object? value) {
  return value
      .toString()
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), ' ');
}

List<CurriculumItem> normalizeCurriculumItems(Object? raw) {
  if (raw is! Map) return const [];
  final items = raw['items'];
  if (items is! List) return const [];

  final out = <CurriculumItem>[];
  for (var i = 0; i < items.length; i++) {
    final entry = items[i];
    if (entry is! Map) continue;
    final item = Map<String, dynamic>.from(entry);
    final rawMarker = item['marker_id'] ?? item['marker'] ?? item['id'];
    final marker = rawMarker is num && rawMarker > 0
        ? 'M${rawMarker.toInt()}'
        : rawMarker is String && rawMarker.trim().isNotEmpty
            ? rawMarker.trim()
            : 'M${i + 1}';
    final text = _firstText(
      item['microitem_for_teacher'],
      item['what_student_must_master'],
      item['title'],
      item['titulo'],
      item['item_name'],
      item['text'],
    );
    if (text.isEmpty) continue;
    out.add(
      CurriculumItem(
        marker: marker,
        text: text,
        title: item['title'] is String ? item['title'] as String : text,
        microitemForTeacher: item['microitem_for_teacher'] is String
            ? item['microitem_for_teacher'] as String
            : text,
        extra: item,
      ),
    );
  }
  return out;
}

String _firstText(Object? a, Object? b, Object? c, Object? d, Object? e, Object? f) {
  for (final value in [a, b, c, d, e, f]) {
    if (value is String && value.trim().isNotEmpty) return value.trim();
  }
  return '';
}
