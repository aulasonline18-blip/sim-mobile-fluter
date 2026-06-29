import 'package:shared_preferences/shared_preferences.dart';

import '../external_ai/sim_ai_server_config.dart';
import '../state/student_state_store.dart';
import 'sim_organism.dart';

class SimOrganismProvider {
  SimOrganismProvider({
    required this.canonicalStore,
    required this._aiConfig,
    required this._prefs,
  });

  final StudentStateStore canonicalStore;
  final SimAiServerConfig _aiConfig;
  final SharedPreferences _prefs;
  final Map<String, SimOrganism> _organisms = {};

  SimOrganism forLesson(String lessonLocalId) {
    return _organisms.putIfAbsent(
      lessonLocalId,
      () => SimOrganism.production(
        lessonLocalId: lessonLocalId,
        aiConfig: _aiConfig,
        prefs: _prefs,
        canonicalStore: canonicalStore,
      ),
    );
  }
}
