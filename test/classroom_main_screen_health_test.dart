import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sim_mobile/main.dart';
import 'package:sim_mobile/sim/classroom/classroom_text_scale.dart';

LabSession _readyAulaSession() {
  final session = LabSession()
    ..authed = true
    ..authReady = true
    ..credits = 3
    ..selectedLanguageCode = 'pt'
    ..stableLang = 'Portuguese'
    ..freeText = 'Fracoes equivalentes com enunciado longo para testar tela.';
  expect(session.saveObjectiveEntry(), isTrue);
  session.route = '/cyber/aula';
  return session;
}

Future<LabSession> _pumpAula(WidgetTester tester) async {
  final session = _readyAulaSession();
  await tester.pumpWidget(SimMobileApp(initialSession: session));
  await session.openAulaRuntime();
  await tester.pumpAndSettle();
  return session;
}

void main() {
  testWidgets('aula font control has five levels and persists choice', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(390, 720));

    await _pumpAula(tester);

    expect(find.byKey(const Key('aula-font-scale-button')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('aula-font-scale-button')),
        matching: find.text('2/5'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('aula-font-scale-button')));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const Key('aula-font-scale-button')),
        matching: find.text('3/5'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('aula-font-scale-button')));
    await tester.tap(find.byKey(const Key('aula-font-scale-button')));
    await tester.tap(find.byKey(const Key('aula-font-scale-button')));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 260));
    expect(
      find.descendant(
        of: find.byKey(const Key('aula-font-scale-button')),
        matching: find.text('1/5'),
      ),
      findsOneWidget,
    );

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt(ClassroomTextScale.prefsKey), 1);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('aula exposes semantics for main classroom actions', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final semantics = tester.ensureSemantics();
    await tester.binding.setSurfaceSize(const Size(390, 720));

    await _pumpAula(tester);

    expect(find.bySemanticsLabel('Abrir menu da aula'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Tocar áudio da aula').evaluate().length +
          find.bySemanticsLabel('Preparando áudio da aula').evaluate().length +
          find.bySemanticsLabel('Parar áudio da aula').evaluate().length,
      1,
    );
    expect(find.bySemanticsLabel('Abrir revisão'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Tamanho da letra: nível 2 de 5'),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Alternativa B'), findsOneWidget);

    await tester.tap(find.text('B'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Sinal 2: Revisar'), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
    semantics.dispose();
  });

  testWidgets(
    'bolha de áudio aparece só com audioPlaying real e tem semantics',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final semantics = tester.ensureSemantics();
      await tester.binding.setSurfaceSize(const Size(390, 720));

      final session = await _pumpAula(tester);
      expect(find.bySemanticsLabel('Áudio da aula tocando'), findsNothing);

      session.audioEnabled = true;
      session.audioPlaying = true;
      session.notifyListeners();
      await tester.pump();

      expect(find.bySemanticsLabel('Áudio da aula tocando'), findsOneWidget);

      session.stopActiveAudio();
      await tester.pump();

      expect(find.bySemanticsLabel('Áudio da aula tocando'), findsNothing);

      await tester.binding.setSurfaceSize(null);
      semantics.dispose();
    },
  );

  testWidgets('sinais abrem como gaveta logo abaixo da alternativa ativa', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final semantics = tester.ensureSemantics();
    await tester.binding.setSurfaceSize(const Size(390, 760));

    await _pumpAula(tester);
    await tester.tap(find.text('B'));
    await tester.pumpAndSettle();

    final selectedRect = tester.getRect(find.bySemanticsLabel('Alternativa B'));
    final signalRect = tester.getRect(
      find.bySemanticsLabel('Sinal 2: Revisar'),
    );
    final nextOptionRect = tester.getRect(
      find.bySemanticsLabel('Alternativa C'),
    );

    expect(signalRect.top, greaterThanOrEqualTo(selectedRect.bottom - 1));
    expect(signalRect.bottom, lessThanOrEqualTo(nextOptionRect.top + 1));

    await tester.binding.setSurfaceSize(null);
    semantics.dispose();
  });

  testWidgets(
    'zoom alto mantém sinais feedback e avançar visíveis em tela pequena',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        ClassroomTextScale.prefsKey: ClassroomTextScale.maxLevel,
      });
      await tester.binding.setSurfaceSize(const Size(360, 560));

      await _pumpAula(tester);
      expect(
        find.descendant(
          of: find.byKey(const Key('aula-font-scale-button')),
          matching: find.text('5/5'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('B'));
      await tester.pumpAndSettle();
      final signalRect = tester.getRect(find.text('2'));
      expect(signalRect.top, greaterThanOrEqualTo(0));
      expect(signalRect.bottom, lessThanOrEqualTo(560));

      await tester.tap(find.text('2'));
      await tester.pumpAndSettle();
      final feedbackRect = tester.getRect(
        find.text('Exato! Você domina este ponto.'),
      );
      expect(feedbackRect.top, greaterThanOrEqualTo(0));
      expect(feedbackRect.bottom, lessThanOrEqualTo(560));
      final nextRect = tester.getRect(find.textContaining('>>').last);
      expect(nextRect.top, greaterThanOrEqualTo(0));
      expect(nextRect.bottom, lessThanOrEqualTo(560));

      await tester.binding.setSurfaceSize(null);
    },
  );
}
