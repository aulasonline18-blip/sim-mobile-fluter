import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/sim/organism/sim_live_parity.dart';
import 'package:sim_mobile/sim/organism/sim_organism.dart';

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

  test('jornada viva de laboratorio atravessa A dentro de B', () async {
    final organism = SimOrganism.laboratory();
    final runner = SimLiveParityRunner(organism: organism);

    final result = await runner.runLaboratoryLiveJourney();

    expect(result.parity.complete, isTrue);
    expect(result.route, '/cyber/aula');
    expect(result.state.profile.objetivo, contains('fracoes'));
    expect(result.state.curriculum?.items, isNotEmpty);
    expect(result.state.attempts, isNotEmpty);
    expect(
      result.state.events.map((event) => event.type),
      contains('ANSWER_SUBMITTED'),
    );
    expect(
      result.state.events.map((event) => event.type),
      contains('AUDIO_READY'),
    );
    expect(
      result.state.events.map((event) => event.type),
      contains('IMAGE_READY'),
    );
    expect(organism.sync.debugSnapshot(), isEmpty);
  });
}
