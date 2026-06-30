import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/main.dart';
import 'package:sim_mobile/shared/widgets/shared_widgets.dart';
import 'package:sim_mobile/sim/state/student_learning_state.dart';

void main() {
  testWidgets('Portal shows SIM entry point', (WidgetTester tester) async {
    await tester.pumpWidget(const SimMobileApp());
    expect(find.text('SIM'), findsOneWidget);
    expect(find.text('Sign in to start'), findsOneWidget);
    expect(find.text('Smart Intelligence Mentor'), findsOneWidget);
  });

  testWidgets('Phase 2 saves live entry and reaches curriculum route', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(480, 1200));
    final session = LabSession()
      ..authed = true
      ..authReady = true
      ..credits = 3;
    await tester.pumpWidget(SimMobileApp(initialSession: session));
    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('English'));
    await tester.pumpAndSettle();
    expect(find.text('Tell us about who is going to study'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.attach_file));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Anexar arquivo'));
    await tester.pumpAndSettle();
    expect(find.textContaining('arquivo-1.pdf'), findsOneWidget);
    await tester.enterText(
      find.byType(TextField).first,
      'Quero estudar essa lista para a prova de matemática.',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save and continue'));
    await tester.pumpAndSettle();
    expect(find.text('/cyber/curriculo'), findsOneWidget);
    expect(
      find.textContaining('entry.status: pedido_recebido'),
      findsOneWidget,
    );
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('Preenchimento exposes credits checkout and support rooms', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(480, 1200));
    final session = LabSession()
      ..authed = true
      ..authReady = true
      ..credits = 3;

    await tester.pumpWidget(SimMobileApp(initialSession: session));
    session.openSupport('/creditos');
    await tester.pumpAndSettle();
    expect(find.text('My credits'), findsOneWidget);
    expect(find.text('CURRENT BALANCE'), findsOneWidget);
    await tester.tap(find.text('about 33 lessons'));
    await tester.pumpAndSettle();
    expect(find.text('Retorno do pagamento'), findsOneWidget);
    await tester.tap(find.text('Tentar de novo'));
    await tester.pumpAndSettle();
    expect(find.text('about 166 lessons'), findsOneWidget);

    session.openSupport('/privacidade');
    await tester.pumpAndSettle();
    expect(find.text('Privacidade'), findsOneWidget);
    session.openSupport('/termos');
    await tester.pumpAndSettle();
    expect(find.text('Termos'), findsOneWidget);
    session.openSupport('/pai');
    await tester.pumpAndSettle();
    expect(find.text('Painel do Pai'), findsOneWidget);
    session.openSupport('/conta/deletar');
    await tester.pumpAndSettle();
    expect(find.textContaining('Solicitar'), findsWidgets);
    await tester.enterText(find.byType(TextField).first, 'DELETAR');
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Solicitar').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('Solicita'), findsWidgets);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('Preenchimento shows doubt and qualifier flow in aula', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(480, 1200));
    final session = LabSession()
      ..authed = true
      ..authReady = true
      ..credits = 3
      ..selectedLanguageCode = 'pt'
      ..stableLang = 'Portuguese'
      ..freeText = 'Fracoes equivalentes explicadas com exemplos simples.';
    expect(session.saveObjectiveEntry(), isTrue);
    session.route = '/cyber/aula';
    await session.openAulaRuntime();
    await tester.pumpWidget(SimMobileApp(initialSession: session));

    expect(find.byIcon(Icons.help_outline), findsNothing);
    await tester.tap(find.text('B'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2'));
    await tester.pumpAndSettle();
    expect(find.text('Dúvida'), findsOneWidget);
    await tester.tap(find.text('Dúvida'));
    await tester.pumpAndSettle();
    expect(find.text('Enviar dúvida'), findsWidgets);
    expect(
      find.text(
        'Escreva sua dúvida ou envie uma foto do exercício, resolução, fórmula, gráfico ou tabela.',
      ),
      findsOneWidget,
    );
    expect(find.byType(TextField), findsWidgets);
    await tester.tap(find.byIcon(Icons.attach_file).last);
    await tester.pumpAndSettle();
    expect(find.text('Tirar foto'), findsOneWidget);
    expect(find.text('Escolher imagem'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'Nao entendi a conta.');
    await tester.tap(find.text('Enviar dúvida').last);
    await tester.pump(const Duration(milliseconds: 20));
    expect(session.doubt.status.name, 'explaining');
    expect(session.doubt.response?.explanation, contains('frações'));

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('Aula sem curriculo mostra estado vazio equivalente ao Web', (
    WidgetTester tester,
  ) async {
    final session = LabSession()
      ..authed = true
      ..authReady = true
      ..route = '/cyber/aula'
      ..aulaRuntimeError = 'Aula sem curriculo no Estado do aluno.';

    await tester.pumpWidget(SimMobileApp(initialSession: session));
    await tester.pumpAndSettle();

    expect(find.text('Currículo não encontrado'), findsOneWidget);
    expect(find.text('Volte e monte um novo currículo.'), findsOneWidget);
    await tester.tap(find.text('Voltar ao currículo'));
    await tester.pumpAndSettle();
    expect(find.text('Tell us about who is going to study'), findsOneWidget);
  });

  testWidgets('Drawer lista, busca, renomeia e apaga aulas locais', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(480, 1200));
    final session = LabSession()
      ..authed = true
      ..authReady = true
      ..credits = 3;
    final store = session.canonicalStore!;
    store.writeState(_drawerState('lesson-a', 'Álgebra linear', 1));
    store.writeState(_drawerState('lesson-b', 'Biologia celular', 2));
    session.lessonLocalId = 'lesson-a';

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showAulaMenu(context, session),
            child: const Text('open drawer'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open drawer'));
    await tester.pumpAndSettle();

    expect(find.text('Álgebra linear'), findsOneWidget);
    expect(find.text('Biologia celular'), findsOneWidget);
    expect(find.text('2/2'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'bio');
    await tester.pumpAndSettle();
    expect(find.text('Álgebra linear'), findsNothing);
    expect(find.text('Biologia celular'), findsOneWidget);

    await tester.tap(find.text('✎').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Citologia');
    await tester.tap(find.text('✓'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '');
    await tester.pumpAndSettle();
    expect(find.text('Citologia'), findsOneWidget);

    await tester.tap(find.text('🗑').first);
    await tester.pumpAndSettle();
    expect(find.text('Apagar esta aula?'), findsOneWidget);
    await tester.tap(find.text('🗑').last);
    await tester.pumpAndSettle();
    expect(find.text('Citologia'), findsNothing);
    expect(store.listLocalStates(), hasLength(1));
    expect(store.listLocalStates(includeDeleted: true), hasLength(2));
    await tester.pump(const Duration(milliseconds: 2300));

    await tester.binding.setSurfaceSize(null);
  });
}

StudentLearningState _drawerState(String id, String title, int itemIdx) {
  final now = DateTime(2026, 6, 30).millisecondsSinceEpoch + itemIdx;
  return StudentLearningState.empty(lessonLocalId: id, now: now).copyWith(
    profile: StudentProfile(
      objetivo: title,
      stableLang: 'Portuguese',
      academicLevel: 'ensino_medio',
    ),
    curriculum: StudentCurriculum(
      topic: title,
      totalItems: 3,
      generatedAt: now,
      provisional: false,
      items: const [
        CurriculumItem(marker: 'M1', text: 'Item 1'),
        CurriculumItem(marker: 'M2', text: 'Item 2'),
        CurriculumItem(marker: 'M3', text: 'Item 3'),
      ],
    ),
    progress: LessonProgress(
      itemIdx: itemIdx,
      layer: LessonLayer.l1,
      erros: 0,
      amparoLvl: 0,
      historia: const [],
      mainAdvances: itemIdx,
      concluidos: const [],
      pendentesMarkers: const [],
      totalItems: 3,
      pctAvanco: ((itemIdx / 3) * 100).round(),
    ),
    current: LessonCurrent(
      itemIdx: itemIdx,
      marker: 'M$itemIdx',
      layer: LessonLayer.l1,
      amparoLvl: 0,
    ),
  );
}
