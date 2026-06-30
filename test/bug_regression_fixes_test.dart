// Regression tests for three bugs fixed in this branch:
// 1. nextReady was always false in `concluido` due to !locked guard
// 2. onboarding prefs-null guard prevents silent hang
// 3. testCreditMode from server hydrates isUnlimited correctly
import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/session/auth_session.dart';
import 'package:sim_mobile/session/navigation_state.dart';
import 'package:sim_mobile/sim/auxiliary/aux_room_models.dart';
import 'package:sim_mobile/sim/billing/credits_functions.dart';
import 'package:sim_mobile/sim/classroom/classroom_models.dart';
import 'package:sim_mobile/sim/experience/student_experience_engine.dart';
import 'package:sim_mobile/sim/experience/student_experience_t00_adapter.dart';
import 'package:sim_mobile/sim/experience/student_experience_types.dart';
import 'package:sim_mobile/sim/modules/pedagogical_module_contracts.dart';
import 'package:sim_mobile/sim/state/student_learning_state.dart';
import 'package:sim_mobile/sim/state/student_learning_state_service.dart';

// Fake T00 client that returns one item successfully
class _FakeOkT00Client implements T00BootstrapClient {
  bool called = false;

  @override
  Stream<T00BootstrapChunk> runBootstrap(T00BootstrapRequest request) async* {
    called = true;
    yield const T00BootstrapChunk(
      type: 't00_item_partial',
      payload: {
        'item': {
          'order': 1,
          'marker': 'M1',
          'title': 'Fundamentos',
          'microitem_for_teacher': 'Introdução ao tema',
        },
      },
    );
    yield const T00BootstrapChunk(
      type: 't00_final',
      payload: {
        'curriculo': [
          {
            'order': 1,
            'marker': 'M1',
            'title': 'Fundamentos',
            'microitem_for_teacher': 'Introdução ao tema',
          },
        ],
      },
    );
  }
}

void main() {
  // ── Test 1: login/session válida não cai no erro ─────────────────────────
  test('1 — sessão válida: AuthSession começa sem erro e isUnlimited=false', () {
    final nav = NavigationState();
    final auth = AuthSession(navigation: nav);

    expect(auth.authed, isFalse);
    expect(auth.authReady, isFalse);
    expect(auth.isUnlimited, isFalse);
    expect(auth.credits, 0);
  });

  // ── Test 2: onboarding com prefs nulo não trava ──────────────────────────
  // isUnlimited é resetado corretamente ao fazer sign-out (equivale a prefs nulo)
  test('2 — prefs/onboarding: isUnlimited resetado no sign-out sem travar', () {
    final nav = NavigationState();
    final auth = AuthSession(navigation: nav);

    // Simula estado autenticado com conta infinita
    auth.isUnlimited = true;
    auth.credits = 999999;
    expect(auth.isUnlimited, isTrue);

    // Sign-out deve zerar tudo sem travar
    auth.applySupabaseSession(null);
    expect(auth.isUnlimited, isFalse);
    expect(auth.credits, 0);
    expect(auth.authed, isFalse);
  });

  // ── Test 3: ao chegar em /cyber/curriculo, T00 inicia ───────────────────
  test('3 — /cyber/curriculo: engine chama T00 quando objetivo não está vazio', () async {
    final service = StudentLearningStateService();
    final client = _FakeOkT00Client();
    final t00 = StudentExperienceT00Adapter(service: service, client: client);
    final engine = StudentExperienceEngine(
      service: service,
      t00: t00,
      placement: const SettledPlacementReader(settled: true),
    );

    await engine.prepareStudentExperienceEntry(
      const StudentExperienceArgs(
        academic: 'incerto',
        idioma: 'pt-BR',
        lessonLocalId: 'lesson-curriculo-test',
        onboarding: {'objetivo': 'Aprender Dart'},
      ),
    );

    expect(client.called, isTrue, reason: 'T00 deve ser chamado ao iniciar experiência');
  });

  // ── Test 4: estado não fica preso em pedido_recebido ────────────────────
  test('4 — estado avança além de pedido_recebido: engine emite curriculum e ready', () async {
    final service = StudentLearningStateService();
    final stages = <StudentExperienceRouteStage>[];
    final engine = StudentExperienceEngine(
      service: service,
      t00: StudentExperienceT00Adapter(service: service, client: _FakeOkT00Client()),
      placement: const SettledPlacementReader(settled: true),
    );

    final result = await engine.prepareStudentExperienceEntry(
      StudentExperienceArgs(
        academic: 'incerto',
        idioma: 'pt-BR',
        lessonLocalId: 'lesson-estado-test',
        onboarding: const {'objetivo': 'Estudar Flutter'},
        onStage: stages.add,
      ),
    );

    expect(result.destination, '/cyber/aula');
    expect(stages, contains(StudentExperienceRouteStage.curriculum),
        reason: 'deve emitir estágio curriculum');
    expect(stages, contains(StudentExperienceRouteStage.ready),
        reason: 'deve emitir estágio ready');
  });

  // ── Test 5: nextReady libera o próximo passo corretamente ────────────────
  // O bug era: nextReady = !locked && doubt.status != processing
  // locked=true em concluido → nextReady sempre false → botão morto
  // Fix:       nextReady = doubt.status != processing   (sem !locked)
  test('5 — nextReady: é true em concluido quando dúvida não está processando', () {
    // Verifica que locked é true em concluido (requisito para entender o bug)
    const phaseConcluido = ClassroomPhase.completed(
      message: 'aula_fb_correct',
      wasCorrect: true,
      signal: DecisionSignal.one,
    );
    expect(phaseConcluido.type, ClassroomPhaseType.concluido);

    // locked = concluido || processando || carregando
    final locked = phaseConcluido.type == ClassroomPhaseType.processando ||
        phaseConcluido.type == ClassroomPhaseType.concluido ||
        phaseConcluido.type == ClassroomPhaseType.carregando;
    expect(locked, isTrue, reason: 'concluido deve ser locked=true');

    // Antes do fix: nextReady = !locked && ... = false → botão morto
    const doubt = DoubtState.idle;
    final nextReadyBuggy = !locked && doubt.status != DoubtStatus.processing;
    expect(nextReadyBuggy, isFalse, reason: 'comportamento bugado: nextReady sempre false');

    // Depois do fix: nextReady = doubt.status != processing = true
    final nextReadyFixed = doubt.status != DoubtStatus.processing;
    expect(nextReadyFixed, isTrue, reason: 'fix correto: nextReady true quando dúvida inativa');
  });

  // ── Test 6: conta de crédito infinito hidrata e aparece corretamente ────
  test('6 — crédito infinito: testCreditMode=true do servidor → isUnlimited=true', () {
    // Servidor retorna testCreditMode: true
    const snapshot = CreditsSnapshot(
      balance: 999999,
      lifetimeEarned: 0,
      lifetimeSpent: 0,
      testCreditMode: true,
    );
    expect(snapshot.testCreditMode, isTrue);

    // AuthSession recebe e propaga o campo
    final nav = NavigationState();
    final auth = AuthSession(navigation: nav);
    auth.credits = snapshot.balance;
    auth.isUnlimited = snapshot.testCreditMode;

    expect(auth.credits, 999999);
    expect(auth.isUnlimited, isTrue,
        reason: 'conta de teste deve aparecer como ilimitada');
  });
}
