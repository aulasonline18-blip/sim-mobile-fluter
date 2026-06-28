import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/sim/organism/sim_organism.dart';
import 'package:sim_mobile/sim/organism/sim_organism_controller.dart';
import 'package:sim_mobile/sim/organism/sim_organism_router.dart';
import 'package:sim_mobile/sim/school/sim_school_routes.dart';
import 'package:sim_mobile/sim/state/student_state_store.dart';

void main() {
  test('organismo usa o canonicalStore externo quando fornecido', () {
    final canonicalStore = StudentStateStore(
      local: MemoryStudentStateLocalStorage(),
    );
    final organism = SimOrganism.laboratory(
      lessonLocalId: 'canonical-organism',
      canonicalStore: canonicalStore,
    );

    organism.stateService.mutate(
      organism.lessonLocalId,
      (state) => state.copyWith(extra: const {'proof': 'canonical'}),
    );

    final stored = canonicalStore.readState('canonical-organism');
    expect(stored.extra['proof'], 'canonical');
    expect(stored.userId, 'lab-user');
  });

  test('organismo ideal nasce com todos os orgaos vivos conectados', () {
    final organism = SimOrganism.laboratory();

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
    'fluxo vivo vai de login para idioma, objetivo, preparo e nivelamento/aula',
    () async {
      final organism = SimOrganism.laboratory();
      final controller = SimOrganismController(organism: organism);

      controller.signInLaboratory();
      expect(controller.route, '/cyber/idioma');

      controller.chooseLanguage(code: 'pt', label: 'Portuguese');
      expect(controller.route, '/cyber/objeto');
      expect(controller.state.profile.stableLang, 'Portuguese');

      await controller.submitObjective(
        text: 'Aprender fracoes com exemplos visuais e exercicios.',
        name: 'Aluno',
      );
      expect(['/cyber/placement', '/cyber/aula'], contains(controller.route));
      expect(controller.state.profile.objetivo, contains('fracoes'));
      expect(controller.state.curriculum?.items, isNotEmpty);
      expect(controller.state.readyLessonMaterials, isNotEmpty);
    },
  );

  test(
    'sync, creditos e portas externas permanecem disponiveis sem segredo no app',
    () async {
      final organism = SimOrganism.laboratory();

      organism.sync.enqueuePatch(organism.lessonLocalId);
      expect(organism.sync.debugSnapshot(), contains(organism.lessonLocalId));

      await organism.creditsController.loadCredits();
      expect(organism.creditsController.state.balance, 3);

      final whatsapp = findSimRoute('https://wa.me/message/RLCYEXAYFUIIA1');
      expect(whatsapp?.kind, SimRouteKind.external);
      expect(organism.health.promptsStayOnServer, isTrue);
      expect(organism.health.secretsStayOnServer, isTrue);
    },
  );
}
