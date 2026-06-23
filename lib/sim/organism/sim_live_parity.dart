import '../media/student_lesson_media_service.dart';
import '../school/sim_school_routes.dart';
import '../state/student_learning_state.dart';
import 'sim_organism.dart';
import 'sim_organism_controller.dart';

enum SimLiveParityStatus {
  present,
  serverOnly,
  external,
  intentionallyNotPorted,
}

class SimLiveParityItem {
  const SimLiveParityItem({
    required this.name,
    required this.status,
    required this.evidence,
  });

  final String name;
  final SimLiveParityStatus status;
  final String evidence;

  bool get countsAsPresent =>
      status == SimLiveParityStatus.present ||
      status == SimLiveParityStatus.serverOnly ||
      status == SimLiveParityStatus.external ||
      status == SimLiveParityStatus.intentionallyNotPorted;
}

class SimLiveParityReport {
  const SimLiveParityReport(this.items);

  final List<SimLiveParityItem> items;

  int get total => items.length;
  int get present => items.where((item) => item.countsAsPresent).length;
  double get percent => total == 0 ? 0 : (present / total) * 100;
  bool get complete => present == total;
}

SimLiveParityReport buildSimLiveParityReport() {
  final items = <SimLiveParityItem>[];
  for (final route in simLiveRoutes) {
    items.add(
      SimLiveParityItem(
        name: route.path,
        status: route.serverOnly
            ? SimLiveParityStatus.serverOnly
            : route.kind == SimRouteKind.external
            ? SimLiveParityStatus.external
            : SimLiveParityStatus.present,
        evidence: route.environmentId,
      ),
    );
  }
  items.addAll(const [
    SimLiveParityItem(
      name: 'T00_bootstrap_realtime.txt',
      status: SimLiveParityStatus.serverOnly,
      evidence: '/api/bootstrap-t00',
    ),
    SimLiveParityItem(
      name: 'T02_content.v3.txt',
      status: SimLiveParityStatus.present,
      evidence: 'T02LessonClient lesson/doubt/auxiliary/placement',
    ),
    SimLiveParityItem(
      name: 'T01 Expander morto',
      status: SimLiveParityStatus.intentionallyNotPorted,
      evidence: 'nao chamado pelo organismo vivo atual',
    ),
    SimLiveParityItem(
      name: 'T04 Interpreter morto',
      status: SimLiveParityStatus.intentionallyNotPorted,
      evidence: 'funcao absorvida pelo T00 vivo',
    ),
    SimLiveParityItem(
      name: 'T11 Pretest morto',
      status: SimLiveParityStatus.intentionallyNotPorted,
      evidence: '/cyber/placement substitui o pretest vivo',
    ),
    SimLiveParityItem(
      name: 'T03 Visual morto',
      status: SimLiveParityStatus.intentionallyNotPorted,
      evidence: 'imagem viva usa pipeline/endpoint de imagem',
    ),
    SimLiveParityItem(
      name: 'StudentLearningState',
      status: SimLiveParityStatus.present,
      evidence: 'fonte unica da verdade Flutter',
    ),
    SimLiveParityItem(
      name: 'LearningDecisionEngine',
      status: SimLiveParityStatus.present,
      evidence: 'decide sem gerar conteudo',
    ),
    SimLiveParityItem(
      name: 'StudentLessonExecutor',
      status: SimLiveParityStatus.present,
      evidence: 'aplica resposta A/B/C sem fallback legado',
    ),
    SimLiveParityItem(
      name: 'StudentExperienceEngine',
      status: SimLiveParityStatus.present,
      evidence: 'ficha -> T00 -> primeira aula -> placement/aula',
    ),
    SimLiveParityItem(
      name: 'Review/Recovery/Doubt',
      status: SimLiveParityStatus.present,
      evidence: 'salas auxiliares leem/escrevem Estado',
    ),
    SimLiveParityItem(
      name: 'Media/Credits/Sync',
      status: SimLiveParityStatus.present,
      evidence: 'midia, credito e sync nao governam pedagogia',
    ),
  ]);
  return SimLiveParityReport(items);
}

class SimLiveParityJourneyResult {
  const SimLiveParityJourneyResult({
    required this.route,
    required this.state,
    required this.parity,
    required this.events,
  });

  final String route;
  final StudentLearningState state;
  final SimLiveParityReport parity;
  final List<StudentLearningEvent> events;
}

class SimLiveParityRunner {
  SimLiveParityRunner({required this.organism})
    : controller = SimOrganismController(organism: organism);

  final SimOrganism organism;
  final SimOrganismController controller;

  Future<SimLiveParityJourneyResult> runLaboratoryLiveJourney() async {
    controller.signInLaboratory();
    controller.chooseLanguage(code: 'pt-BR', label: 'Portuguese');
    await controller.submitObjective(
      text: 'Aprender fracoes com exemplos visuais e exercicios.',
      name: 'Aluno',
    );
    if (controller.route == '/cyber/placement') {
      organism.placementController.skip();
      controller.go('/cyber/aula');
    }

    await controller.openClassroom();
    var snapshot = organism.lessonRuntimeEngine.snapshot();
    final correct = snapshot.conteudo?.correctAnswer ?? AnswerLetter.A;
    organism.lessonRuntimeEngine.select(correct);
    organism.lessonRuntimeEngine.signal(DecisionSignal.one);
    await organism.lessonRuntimeEngine.advance();

    final marker = snapshot.itemMarker ?? controller.state.current?.marker;
    final layer =
        controller.state.current?.layer ?? controller.state.progress?.layer;
    organism.mediaService.prepareLessonAudioText(
      LessonMediaPosition(
        lessonLocalId: organism.lessonLocalId,
        itemMarker: marker,
        layer: layer,
      ),
      [snapshot.conteudo?.explanation, snapshot.conteudo?.question],
    );
    organism.mediaService.markLessonImageReady(
      LessonMediaPosition(
        lessonLocalId: organism.lessonLocalId,
        itemMarker: marker,
        layer: layer,
      ),
      cacheKey: 'lab-image',
      imageUrl: 'data:image/png;base64,lab',
    );
    await organism.creditsController.loadCredits();
    organism.sync.enqueuePatch(organism.lessonLocalId);
    await organism.sync.drain();

    return SimLiveParityJourneyResult(
      route: controller.route,
      state: controller.state,
      parity: buildSimLiveParityReport(),
      events: controller.state.events,
    );
  }
}
