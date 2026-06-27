import '../config/app_mode.dart';
import '../state/student_state_store.dart';
import 'sim_organism.dart';

class SimOrganismProvider {
  SimOrganismProvider({required this.mode, required this.canonicalStore});

  final AppMode mode;
  final StudentStateStore canonicalStore;
  final Map<String, SimOrganism> _organisms = {};

  SimOrganism forLesson(String lessonLocalId) {
    if (mode.isProduction) {
      throw StateError(
        'Modo production nao pode usar SimOrganism.laboratory. Configure os clients reais do organismo SIM antes de abrir a aula.',
      );
    }
    return _organisms.putIfAbsent(
      lessonLocalId,
      () => SimOrganism.laboratory(
        lessonLocalId: lessonLocalId,
        canonicalStore: canonicalStore,
      ),
    );
  }
}
