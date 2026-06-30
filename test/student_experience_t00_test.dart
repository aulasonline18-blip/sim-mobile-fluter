import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/sim/experience/bootstrap_payload.dart';
import 'package:sim_mobile/sim/experience/partial_curriculum_writer.dart';
import 'package:sim_mobile/sim/experience/student_experience_engine.dart';
import 'package:sim_mobile/sim/experience/student_experience_t00_adapter.dart';
import 'package:sim_mobile/sim/experience/student_experience_types.dart';
import 'package:sim_mobile/sim/modules/pedagogical_module_contracts.dart';
import 'package:sim_mobile/sim/state/student_learning_state.dart';
import 'package:sim_mobile/sim/state/student_learning_state_service.dart';

class FakeT00Client implements T00BootstrapClient {
  @override
  Stream<T00BootstrapChunk> runBootstrap(T00BootstrapRequest request) async* {
    yield const T00BootstrapChunk(
      type: 't00_profile',
      payload: {'profile': 'Aluno precisa de base visual.'},
    );
    yield const T00BootstrapChunk(
      type: 't00_fallback_gateway_started',
      payload: {'error': 'gateway slow', 'ts': 1},
    );
    yield const T00BootstrapChunk(
      type: 't00_item_partial',
      payload: {
        'item': {
          'order': 1,
          'marker': 'M1',
          'title': 'Frações',
          'microitem_for_teacher': 'Entender metade e um quarto',
        },
      },
    );
    yield const T00BootstrapChunk(
      type: 't00_partial_ready',
      payload: {'count': 1, 'ms': 12},
    );
    yield const T00BootstrapChunk(
      type: 't00_quality_check',
      payload: {
        'quality_check': {'ok': true},
      },
    );
    yield const T00BootstrapChunk(type: 'done', payload: {'ok': true});
  }
}

void main() {
  test('buildT00Phase1Body preserves the live ficha contract', () {
    final body = buildT00Phase1Body(
      data: const {
        'objetivo': 'Aprender frações',
        'attachments_text': 'foto do exercicio',
        'preferred_name': 'Ana',
        'stableLang': 'pt-BR',
      },
      lang: 'pt-BR',
      academic: 'fundamental',
    );

    final ficha = body['ficha'] as Map<String, dynamic>;
    expect(ficha['free_text'], 'Aprender frações');
    expect(ficha['attachments_text'], 'foto do exercicio');
    expect(ficha['preferred_name'], 'Ana');
    expect(ficha['academic_level'], 'fundamental');
  });

  test('appendPartialCurriculumItemToState writes first item once', () {
    final service = StudentLearningStateService();
    final partials = <CurriculumItem>[];

    final first = appendPartialCurriculumItemToState(
      service: service,
      raw: const T00StreamItem(
        order: 1,
        marker: 'M1',
        microitemForTeacher: 'Primeiro item',
      ),
      partialItems: partials,
      lessonLocalId: 'cyber-x',
      objective: 'Objetivo',
      bootStartedAt: 1,
    );
    final duplicate = appendPartialCurriculumItemToState(
      service: service,
      raw: const T00StreamItem(
        order: 1,
        marker: 'M1',
        microitemForTeacher: 'Primeiro item',
      ),
      partialItems: partials,
      lessonLocalId: 'cyber-x',
      objective: 'Objetivo',
      bootStartedAt: 1,
    );

    expect(first?.count, 1);
    expect(duplicate, isNull);
    expect(service.read('cyber-x')?.curriculum?.items, hasLength(1));
  });

  test(
    'StudentExperienceEngine releases first item and routes to placement',
    () async {
      final service = StudentLearningStateService();
      final t00 = StudentExperienceT00Adapter(
        service: service,
        client: FakeT00Client(),
      );
      final engine = StudentExperienceEngine(
        service: service,
        t00: t00,
        placement: const SettledPlacementReader(settled: false),
      );

      final result = await engine.prepareStudentExperienceEntry(
        const StudentExperienceArgs(
          academic: 'fundamental',
          idioma: 'pt-BR',
          lessonLocalId: 'cyber-fractions',
          onboarding: {'objetivo': 'Aprender frações'},
        ),
      );

      expect(result.destination, '/cyber/placement');
      expect(result.curriculum.items.first.marker, 'M1');
      final state = service.read('cyber-fractions');
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      final settledState = service.read('cyber-fractions');
      expect(state?.entry?.firstItemMarker, 'M1');
      expect(
        state?.events.map((event) => event.type),
        contains('CURRICULUM_GENERATED'),
      );
      final progressEvents = settledState?.events
          .where((event) => event.type == 'PROGRESS_UPDATED')
          .map((event) => event.payload['event'])
          .toList();
      expect(progressEvents, contains('t00FallbackGatewayStarted'));
      expect(progressEvents, contains('t00PartialReady'));
      expect(progressEvents, contains('t00QualityCheckReceived'));
      expect(settledState?.curriculum?.items, hasLength(1));
    },
  );
}
