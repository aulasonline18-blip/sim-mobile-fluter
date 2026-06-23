import '../state/student_learning_state.dart';

JsonMap buildT00Phase1Body({
  required JsonMap data,
  required String lang,
  required String academic,
}) {
  final attachmentsText =
      data['attachments_text'] is String ? data['attachments_text'] : '';

  return {
    'ficha': {
      'free_text': data['objetivo'] ?? '',
      'attachments_text': attachmentsText,
      'preferred_name': data['preferred_name'] ?? '',
      'language': lang,
      'idioma': data['idioma'],
      'stableLang': data['stableLang'] ?? data['STABLE_LANG'],
      'STABLE_LANG': data['STABLE_LANG'] ?? data['stableLang'],
      'nivel': data['nivel'] ?? 'incerto',
      'ACADEMIC_LEVEL': data['ACADEMIC_LEVEL'] ?? academic,
      'academic_level': data['academic_level'] ?? academic,
      'student_age': data['student_age'],
      'age_range': data['age_range'],
      'school_year': data['school_year'],
      'country_or_curriculum': data['country_or_curriculum'],
      'official_curriculum_reference':
          data['official_curriculum_reference'],
      'GEOGRAPHIC_ZONE': data['GEOGRAPHIC_ZONE'],
      'subject': data['subject'],
      'target_topic': data['target_topic'],
      'TARGET_TOPIC': data['TARGET_TOPIC'],
      'objetivo': data['objetivo'] ?? '',
      'learning_goal': data['learning_goal'],
      'exam_goal': data['exam_goal'],
      'SESSION_GOAL': data['SESSION_GOAL'],
      'prior_knowledge': data['prior_knowledge'],
      'known_weaknesses': data['known_weaknesses'],
      'difficulty_level': data['difficulty_level'],
      'student_profile_notes':
          data['student_profile_notes'] ?? data['objetivo'] ?? '',
      'emotional_learning_context': data['emotional_learning_context'],
      'cognitive_learning_context': data['cognitive_learning_context'],
      'learning_care_notes': data['learning_care_notes'],
      'student_profile_public_summary':
          data['student_profile_public_summary'],
      'student_profile_internal': data['student_profile_internal'],
      'interpreted_fields': data['interpreted_fields'],
    },
  };
}
