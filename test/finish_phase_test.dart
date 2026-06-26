import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/main.dart';
import 'package:sim_mobile/sim/support/sim_finish_contract.dart';

void main() {
  test('acabamento cobre todos os itens mandatarios', () {
    expect(simFinishIsComplete(), true);
    expect(simFinishRequirements.length, SimFinishArea.values.length);
    expect(
      simFinishRequirements.map((r) => r.label).join('\n'),
      contains('Audio com estado visivel'),
    );
    expect(
      simFinishRequirements.map((r) => r.label).join('\n'),
      contains('Imagem com estado visivel'),
    );
  });

  testWidgets('aula mostra imagem audio feedback loading e erro visual', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    final session = LabSession()
      ..authed = true
      ..authReady = true
      ..credits = 3
      ..stableLang = 'Portuguese'
      ..freeText = 'Frações equivalentes'
      ..route = '/cyber/aula';

    await tester.pumpWidget(SimMobileApp(initialSession: session));
    expect(find.text('Imagem da aula'), findsOneWidget);
    expect(find.text('Áudio da aula ligado'), findsOneWidget);

    await tester.tap(find.text('Gerar imagem'));
    await tester.pump();
    expect(find.text('Gerando imagem da aula...'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('Imagem da aula pronta'), findsOneWidget);

    await tester.tap(find.byTooltip('Áudio'));
    await tester.pump();
    expect(find.text('Preparando áudio da aula...'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('Áudio ainda não está disponível.'), findsOneWidget);

    await tester.tap(find.textContaining('B. Entendi'));
    await tester.pumpAndSettle();
    expect(find.textContaining('SIM marcou revisão'), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });
}
