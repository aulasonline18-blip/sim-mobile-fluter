import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/main.dart';

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

    await tester.tap(find.text('3'));
    await tester.pumpAndSettle();
    expect(find.text('Créditos'), findsOneWidget);
    await tester.tap(find.text('100 créditos'));
    await tester.pumpAndSettle();
    expect(find.text('Retorno do pagamento'), findsOneWidget);
    await tester.tap(find.text('Tentar de novo'));
    await tester.pumpAndSettle();
    expect(find.text('500 créditos'), findsOneWidget);

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
    expect(find.text('Solicitar exclusão da conta'), findsWidgets);
    await tester.enterText(find.byType(TextField).first, 'DELETAR');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Solicitar exclusão da conta').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('Solicitação de exclusão'), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('Preenchimento shows doubt review and recovery rooms in aula', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(480, 1200));
    final session = LabSession()
      ..authed = true
      ..authReady = true
      ..credits = 3
      ..stableLang = 'Portuguese'
      ..freeText = 'Frações equivalentes'
      ..route = '/cyber/aula';
    await tester.pumpWidget(SimMobileApp(initialSession: session));

    await tester.tap(find.byIcon(Icons.help_outline));
    await tester.pumpAndSettle();
    expect(find.text('Dúvida'), findsOneWidget);
    await tester.tap(find.textContaining('B. Entendi'));
    await tester.pumpAndSettle();
    expect(find.text('Revisão'), findsOneWidget);
    await tester.tap(find.text('Avançar'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('C. Ainda'));
    await tester.pumpAndSettle();
    expect(find.text('Recuperação'), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });
}
