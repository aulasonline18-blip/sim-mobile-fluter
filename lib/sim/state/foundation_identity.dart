import '../cloud/supabase_client_contract.dart';
import 'student_learning_state.dart';
import 'student_state_store.dart';

class StudentIdentity {
  const StudentIdentity({
    required this.userId,
    this.email,
    this.displayName,
    this.provider = 'google',
  });

  final String userId;
  final String? email;
  final String? displayName;
  final String provider;

  JsonMap toJson() => {
    'user_id': userId,
    'provider': provider,
    if (email != null) 'email': email,
    if (displayName != null) 'display_name': displayName,
  };
}

class FoundationIdentityBinder {
  FoundationIdentityBinder({required this.store});

  final StudentStateStore store;

  CanonicalLearningEvent bindIdentity({
    required String lessonLocalId,
    required StudentIdentity identity,
    String source = 'foundation-identity-binder',
  }) {
    return store.mutateWithEvent(
      lessonLocalId: lessonLocalId,
      type: 'IDENTITY_BOUND',
      userId: identity.userId,
      source: source,
      payload: identity.toJson(),
      mutate: (state, event) {
        return state.copyWith(
          userId: identity.userId,
          extra: {
            ...state.extra,
            'identity': {
              ...identity.toJson(),
              'status': 'bound',
              'bound_at': event.createdAt,
              'event_id': event.eventId,
            },
          },
        );
      },
    );
  }

  CanonicalLearningEvent bindSession({
    required String lessonLocalId,
    required SupabaseSession session,
    String? email,
    String? displayName,
    String source = 'foundation-identity-binder',
  }) {
    return bindIdentity(
      lessonLocalId: lessonLocalId,
      identity: StudentIdentity(
        userId: session.userId,
        email: email,
        displayName: displayName,
      ),
      source: source,
    );
  }

  CanonicalLearningEvent detachIdentity({
    required String lessonLocalId,
    String reason = 'signed_out',
    String source = 'foundation-identity-binder',
  }) {
    return store.mutateWithEvent(
      lessonLocalId: lessonLocalId,
      type: 'IDENTITY_DETACHED',
      source: source,
      payload: {'reason': reason},
      mutate: (state, event) {
        final identity = state.extra['identity'] is Map
            ? JsonMap.from(state.extra['identity'] as Map)
            : <String, dynamic>{};
        return state.copyWith(
          extra: {
            ...state.extra,
            'identity': {
              ...identity,
              'status': 'detached',
              'detached_at': event.createdAt,
              'detach_reason': reason,
              'event_id': event.eventId,
            },
          },
        );
      },
    );
  }
}
