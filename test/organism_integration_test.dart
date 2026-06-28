import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sim_mobile/sim/external_ai/sim_ai_server_config.dart';
import 'package:sim_mobile/sim/media/audio_core.dart';
import 'package:sim_mobile/sim/organism/sim_organism.dart';
import 'package:sim_mobile/sim/organism/sim_organism_router.dart';
import 'package:sim_mobile/sim/school/sim_school_routes.dart';
import 'package:sim_mobile/sim/state/student_state_store.dart';

SimAiServerConfig _testConfig() => const SimAiServerConfig(
      baseUrl: 'http://localhost',
      t00Path: '/api/bootstrap-t00',
      t02Path: '/api/complete-lesson',
    );

Future<SimOrganism> _makeOrganism({String id = 'test', StudentStateStore? store}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return SimOrganism.production(
    lessonLocalId: id,
    aiConfig: _testConfig(),
    prefs: prefs,
    canonicalStore: store,
    playback: NoopAudioPlaybackAdapter(),
  );
}

void main() {
  test('organismo usa o canonicalStore externo quando fornecido', () async {
    final canonicalStore = StudentStateStore(
      local: MemoryStudentStateLocalStorage(),
    );
    final organism = await _makeOrganism(
      id: 'canonical-organism',
      store: canonicalStore,
    );

    organism.stateService.mutate(
      organism.lessonLocalId,
      (state) => state.copyWith(extra: const {'proof': 'canonical'}),
    );

    final stored = canonicalStore.readState('canonical-organism');
    expect(stored.extra['proof'], 'canonical');
  });

  test('organismo ideal nasce com todos os orgaos vivos conectados', () async {
    final organism = await _makeOrganism();

    expect(organism.health.alive, isTrue);
    expect(organism.health.healthyOrgans, contains('sala_de_aula'));
    expect(organism.health.healthyOrgans, contains('nuvem_sync'));
    expect(organism.health.healthyOrgans, contains('creditos_pagamento'));
    expect(organism.health.serverOnlyOrgans, contains('/api/bootstrap-t00'));
    expect(
      organism.health.serverOnlyOrgans,
      contains('/api/generate-lesson-image'),
    );
    expect(
      organism.health.serverOnlyOrgans,
      contains('/api/generate-lesson-audio'),
    );
    expect(
      organism.health.serverOnlyOrgans,
      contains('/api/public/payments/webhook'),
    );
  });

  test(
    'roteador protege ambientes que precisam de identificacao, idioma e objetivo',
    () {
      const router = SimOrganismRouter();

      expect(
        router
            .resolve(
              path: '/cyber/aula',
              authed: false,
              hasLanguage: false,
              hasObjective: false,
            )
            .destination,
        '/login',
      );
      expect(
        router
            .resolve(
              path: '/cyber/aula',
              authed: true,
              hasLanguage: false,
              hasObjective: false,
            )
            .destination,
        '/cyber/idioma',
      );
      expect(
        router
            .resolve(
              path: '/cyber/aula',
              authed: true,
              hasLanguage: true,
              hasObjective: false,
            )
            .destination,
        '/cyber/objeto',
      );
      expect(
        router
            .resolve(
              path: '/api/bootstrap-t00',
              authed: true,
              hasLanguage: true,
              hasObjective: true,
            )
            .guard,
        SimOrganismRouteGuard.serverOnly,
      );
    },
  );

  test(
    'sync, creditos e portas externas permanecem disponiveis sem segredo no app',
    () async {
      final organism = await _makeOrganism();

      organism.sync.enqueuePatch(organism.lessonLocalId);
      expect(organism.sync.debugSnapshot(), contains(organism.lessonLocalId));

      final whatsapp = findSimRoute('https://wa.me/message/RLCYEXAYFUIIA1');
      expect(whatsapp?.kind, SimRouteKind.external);
      expect(organism.health.promptsStayOnServer, isTrue);
      expect(organism.health.secretsStayOnServer, isTrue);
    },
  );

  // Teste de jornada viva omitido: requer T00/T02 via rede real
  // (http://167.179.109.137:3000) — não roda em CI sem servidor.
}
