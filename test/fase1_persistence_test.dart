import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sim_mobile/sim/state/shared_prefs_state_storage.dart';
import 'package:sim_mobile/sim/state/student_learning_state.dart';
import 'package:sim_mobile/sim/state/student_state_store.dart';

void main() {
  test(
    'StudentStateStore restores state through SharedPreferences storage',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final firstStore = StudentStateStore(
        local: SharedPrefsStudentStateLocalStorage(prefs),
      );
      firstStore.writeState(
        StudentLearningState.empty(
          lessonLocalId: 'lesson-fase-1',
          userId: 'student-1',
          now: 100,
        ).copyWith(
          updatedAt: 200,
          profile: const StudentProfile(
            preferredName: 'Ana',
            stableLang: 'Portuguese',
          ),
          extra: const {'route': '/cyber/aula'},
        ),
      );

      final reopenedStore = StudentStateStore(
        local: SharedPrefsStudentStateLocalStorage(prefs),
      );
      final restored = reopenedStore.readState('lesson-fase-1');

      expect(restored.userId, 'student-1');
      expect(restored.profile.preferredName, 'Ana');
      expect(restored.profile.stableLang, 'Portuguese');
      expect(restored.extra['route'], '/cyber/aula');
      expect(restored.updatedAt, greaterThanOrEqualTo(200));
    },
  );
}
