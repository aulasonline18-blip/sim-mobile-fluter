import '../state/student_learning_state.dart';
import '../state/student_state_store.dart';
import 'cloud_functions.dart';
import 'supabase_client_contract.dart';

class SupabaseStudentStateCloudStorage implements StudentStateCloudStorage {
  const SupabaseStudentStateCloudStorage({
    required this.cloudFunctions,
    required this.sessionProvider,
  });

  final StudentStateCloudFunctions cloudFunctions;
  final SupabaseSessionProvider sessionProvider;

  @override
  Future<StudentLearningState?> loadCloud(String lessonLocalId) async {
    final session = await sessionProvider.currentSession();
    if (session == null) return null;
    final row = await cloudFunctions.getStudentStateByLesson(
      lessonLocalId,
      session,
    );
    return row?.state;
  }

  @override
  Future<void> persistCloud(StudentLearningState state) async {
    final session = await sessionProvider.currentSession();
    if (session == null) return;
    await cloudFunctions.persistStudentState(
      PersistStudentStateInput(
        lessonLocalId: state.lessonLocalId,
        state: state,
        clientUpdatedAt: state.updatedAt,
        clientScore: scoreOfStudentLearningState(state),
        schemaVersion: studentLearningStateSchemaVersion,
      ),
      session,
    );
  }
}
