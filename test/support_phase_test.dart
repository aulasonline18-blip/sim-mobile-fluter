import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/sim/state/student_learning_state.dart';
import 'package:sim_mobile/sim/state/student_learning_state_service.dart';
import 'package:sim_mobile/sim/support/cyber_layout.dart';
import 'package:sim_mobile/sim/support/father_panel.dart';
import 'package:sim_mobile/sim/support/legal_pages.dart';
import 'package:sim_mobile/sim/support/root_layout.dart';

StudentLearningState seedState() {
  return StudentLearningState.empty(lessonLocalId: 'l1', now: 1).copyWith(
    profile: const StudentProfile(
      preferredName: 'Paulo',
      objetivo: 'Estudar biologia',
      stableLang: 'pt-BR',
      academicLevel: 'ensino_medio',
      targetTopic: 'Células',
    ),
    curriculum: StudentCurriculum(
      topic: 'Biologia',
      totalItems: 3,
      generatedAt: 1,
      provisional: false,
      items: const [
        CurriculumItem(marker: 'M1', text: 'Membrana celular'),
        CurriculumItem(marker: 'M2', text: 'Citoplasma'),
        CurriculumItem(marker: 'M3', text: 'Núcleo'),
      ],
    ),
    current: const LessonCurrent(
      itemIdx: 1,
      marker: 'M2',
      layer: LessonLayer.l2,
      amparoLvl: 0,
    ),
    progress: const LessonProgress(
      itemIdx: 1,
      layer: LessonLayer.l2,
      erros: 0,
      amparoLvl: 1,
      historia: ['M1'],
      mainAdvances: 1,
      concluidos: ['M1'],
      pendentesMarkers: ['M3'],
      totalItems: 3,
      pctAvanco: 33,
    ),
    attempts: const [
      LessonAttempt(
        marker: 'M1',
        layer: LessonLayer.l1,
        letra: AnswerLetter.A,
        sinal: DecisionSignal.one,
        correct: true,
        ts: 1,
      ),
      LessonAttempt(
        marker: 'M3',
        layer: LessonLayer.l2,
        letra: AnswerLetter.B,
        sinal: DecisionSignal.three,
        correct: false,
        ts: 2,
      ),
    ],
  );
}

void main() {
  test('father panel builds human snapshot without JSON exposure', () {
    final service = StudentLearningStateService(seed: {'l1': seedState()});
    final panel = FatherPanel(stateService: service);

    final snap = panel.snapshotSync(activeLessonLocalId: 'l1');
    expect(snap.hasSession, true);
    expect(snap.objective, 'Estudar biologia');
    expect(snap.currentMarker, 'M2');
    expect(snap.currentLayer, LessonLayer.l2);
    expect(snap.progressPercent, 33);
    expect(snap.signalsSummary.s1, 1);
    expect(snap.signalsSummary.s3, 1);

    final report = panel.buildStatusReport(snap);
    expect(report, contains('SIM — STATUS PEDAGÓGICO'));
    expect(report, contains('Objetivo        : Estudar biologia'));
    expect(report, contains('[PENDENTE]  M3'));
    expect(report, isNot(contains('{')));
  });

  test('privacy and terms preserve live legal text', () {
    expect(privacyPageContent.route, '/privacidade');
    expect(privacyPageContent.title, 'Politica de Privacidade');
    expect(privacyPageContent.headerLines, contains('Contato: smarttutorbr@gmail.com'));
    expect(
      privacyPageContent.sections.map((s) => s.title),
      contains('Menores de idade'),
    );

    expect(termsPageContent.route, '/termos');
    expect(termsPageContent.title, 'Termos de Uso');
    expect(termsPageContent.sections.map((s) => s.title), contains('Creditos'));
    expect(termsPageContent.sections.last.body, contains('smarttutorbr@gmail.com'));
  });

  test('root layout preserves technical cache migration boundaries', () {
    final storage = MemoryTechnicalCacheStorage()
      ..write('sim-state-v0', 'old')
      ..write('cyber-reviews-v0', 'old')
      ..write('sim-credits-cache-v0', 'cached')
      ..write('lesson-progress', 'do-not-touch');
    final migration = TechnicalCacheMigration(storage: storage);

    migration.run();
    expect(storage.read('sim-state-v0'), isNull);
    expect(storage.read('cyber-reviews-v0'), isNull);
    expect(storage.read('sim-credits-cache-v0'), isNull);
    expect(storage.read('lesson-progress'), 'do-not-touch');
    expect(
      storage.read(TechnicalCacheMigration.versionKey),
      rootLayoutContract.cacheVersion,
    );
  });

  test('root and cyber layout contracts preserve route behavior', () {
    expect(rootLayoutContract.title, 'SIM AI Tutor — Seu tutor de IA pessoal');
    expect(rootLayoutContract.links.map((l) => l.href), contains('/manifest.json'));
    expect(cyberLayoutContract.route, '/cyber');
    expect(cyberLayoutContract.ssr, false);
    expect(cyberLayoutContract.behavior, 'Outlet');
    expect(cyberLayoutContract.definesOwnHead, false);
  });
}
