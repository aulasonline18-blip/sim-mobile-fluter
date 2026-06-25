import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sim_mobile/sim/state/student_learning_state.dart';
import 'package:sim_mobile/sim/state/student_learning_state_persistence.dart';
import 'package:sim_mobile/sim/state/student_learning_state_service.dart';

void main() {
  test('StudentLearningState read/write/mutate persists minimum foundation',
      () async {
    SharedPreferences.setMockInitialValues({});
    final persistence =
        await SharedPreferencesStudentLearningStatePersistence.create();
    final service =
        await StudentLearningStateService.persistent(persistence: persistence);

    service.write(
      StudentLearningState.empty(lessonLocalId: 'lesson-1').copyWith(
        profile: const StudentProfile(
          preferredName: 'Ana',
          stableLang: 'Portuguese',
          objetivo: 'Frações equivalentes',
        ),
        curriculum: StudentCurriculum(
          topic: 'Frações',
          totalItems: 1,
          generatedAt: 123,
          provisional: false,
          items: const [
            CurriculumItem(marker: 'M-1', text: 'Frações equivalentes'),
          ],
        ),
      ),
    );
    service.appendAttempt(
      'lesson-1',
      const LessonAttempt(
        marker: 'M-1',
        layer: LessonLayer.l1,
        letra: AnswerLetter.B,
        sinal: DecisionSignal.two,
        correct: true,
        ts: 456,
      ),
    );
    service.mutate(
      'lesson-1',
      (state) => state.copyWith(
        extra: {
          ...state.extra,
          'aulaStep': 2,
          'selectedAnswer': 'B',
          'signalsSolid': 1,
          'signalsUnderstood': 1,
          'signalsFragile': 0,
        },
      ),
    );

    final restored =
        await StudentLearningStateService.persistent(persistence: persistence);
    final state = restored.read('lesson-1');

    expect(state, isNotNull);
    expect(state!.lessonLocalId, 'lesson-1');
    expect(state.profile.stableLang, 'Portuguese');
    expect(state.curriculum!.items.single.marker, 'M-1');
    expect(state.attempts.single.letra, AnswerLetter.B);
    expect(state.extra['aulaStep'], 2);
    expect(state.extra['selectedAnswer'], 'B');
    expect(state.extra['signalsSolid'], 1);
    expect(state.extra['signalsUnderstood'], 1);
    expect(state.extra['signalsFragile'], 0);
  });
}
