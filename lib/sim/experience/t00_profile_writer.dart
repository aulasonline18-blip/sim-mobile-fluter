import '../state/student_learning_state.dart';
import '../state/student_learning_state_service.dart';

class T00ProfileEvent {
  const T00ProfileEvent({
    this.profile,
    this.fichaForNext,
  });

  final String? profile;
  final JsonMap? fichaForNext;
}

JsonMap? persistT00ProfileEvent({
  required StudentLearningStateService service,
  required String lessonLocalId,
  required T00ProfileEvent event,
  required JsonMap data,
}) {
  if (event.fichaForNext != null) {
    final patch = JsonMap.of(event.fichaForNext!);
    _writeProfilePatch(service, lessonLocalId, patch);
    return patch;
  }

  final profile = event.profile?.trim();
  if (profile != null && profile.isNotEmpty) {
    final interpreted = data['interpreted_fields'] is Map
        ? JsonMap.from(data['interpreted_fields'] as Map)
        : <String, dynamic>{};
    final patch = <String, dynamic>{
      'student_profile_notes': profile,
      'student_profile_public_summary': profile,
      'student_profile_internal': {
        'source': 'T00',
        'profile': profile,
      },
      'guidance_for_T01': profile,
      'guidance_for_T02': profile,
      'bootstrap_engine': 'T00',
      'bootstrap_fallback_enabled': false,
      'bootstrap_status': 'running',
      'interpreted_fields': {
        ...interpreted,
        't00_profile': profile,
      },
    };
    _writeProfilePatch(service, lessonLocalId, patch);
    return {...data, ...patch};
  }

  return null;
}

void _writeProfilePatch(
  StudentLearningStateService service,
  String lessonLocalId,
  JsonMap patch,
) {
  service.mutate(lessonLocalId, (state) {
    final merged = {...state.profile.toJson(), ...patch};
    return state.copyWith(profile: StudentProfile.fromJson(merged));
  });
}
