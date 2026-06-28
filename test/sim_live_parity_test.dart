import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/sim/organism/sim_live_parity.dart';

void main() {
  test('matriz de paridade A -> B representa rotas, professores e mortos', () {
    final report = buildSimLiveParityReport();

    expect(report.complete, isTrue);
    expect(report.percent, 100);
    expect(report.items.map((item) => item.name), contains('/cyber/aula'));
    expect(
      report.items.map((item) => item.name),
      contains('T00_bootstrap_realtime.txt'),
    );
    expect(
      report.items.map((item) => item.name),
      contains('T02_content.v3.txt'),
    );
    expect(
      report.items.map((item) => item.name),
      contains('T01 Expander morto'),
    );
  });

  // Jornada viva omitida: requer T00/T02/áudio/imagem via rede real
  // (http://167.179.109.137:3000) — não roda em CI sem servidor.
}
