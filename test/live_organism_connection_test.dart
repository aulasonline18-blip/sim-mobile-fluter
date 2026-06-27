import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/main.dart';
import 'package:sim_mobile/sim/config/app_mode.dart';
import 'package:sim_mobile/sim/organism/sim_organism_provider.dart';
import 'package:sim_mobile/sim/state/student_learning_state.dart';
import 'package:sim_mobile/sim/state/student_state_store.dart';

void main() {
  test('modo production bloqueia organismo de laboratorio', () {
    final store = StudentStateStore(local: MemoryStudentStateLocalStorage());
    final provider = SimOrganismProvider(
      mode: AppMode.production,
      canonicalStore: store,
    );

    expect(() => provider.forLesson('lesson-prod'), throwsStateError);
  });

  test(
    'LabSession abre aula viva pelo organismo e escreve tentativa canonica',
    () async {
      final store = StudentStateStore(local: MemoryStudentStateLocalStorage());
      final session = LabSession(
        canonicalStore: store,
        appMode: AppMode.laboratory,
      );
      session.authReady = true;
      session.authed = true;
      session.credits = 1;
      session.selectedLanguageCode = 'pt';
      session.stableLang = 'Portuguese';
      session.setFreeText(
        'Aprender fracoes com exemplos simples e uma pergunta guiada.',
      );

      expect(session.saveObjectiveEntry(), isTrue);
      await session.openAulaRuntime();

      expect(session.aulaSnapshot?.conteudo, isNotNull);
      expect(session.aulaSnapshot?.conteudo?.question, isNotEmpty);
      expect(session.aulaSnapshot?.itemMarker, 'MAIN_001');

      session.chooseAulaAnswer('A');
      expect(session.aulaSnapshot?.phase.letter?.name, 'A');

      session.submitAulaSignal(1);
      final id = session.lessonLocalId!;
      final state = store.readState(id);
      expect(state.attempts, isNotEmpty);
      expect(state.attempts.last.marker, 'MAIN_001');
      expect(state.attempts.last.letra.name, 'A');
      expect(state.attempts.last.sinal.value, 1);
      expect(
        state.events.map((event) => event.type),
        containsAll(<String>['ANSWER_SUBMITTED', 'NEXT_ACTION_DECIDED']),
      );
    },
  );
}
