import '../billing/account_deletion.dart';
import '../billing/credits_route_controller.dart';
import '../billing/payment_return_store.dart';
import '../classroom/lesson_answer_progress_controller.dart';
import '../classroom/lesson_hydration_engine.dart';
import '../classroom/lesson_material_controller.dart';
import '../classroom/lesson_position_engine.dart';
import '../classroom/lesson_runtime_engine.dart';
import '../classroom/lesson_session_engine.dart';
import '../cloud/cloud_queue.dart';
import '../cloud/lesson_cloud_bootstrap.dart';
import '../cloud/lesson_curriculum_sync_engine.dart';
import '../cloud/supabase_client_contract.dart';
import '../cloud/student_learning_sync.dart';
import '../experience/student_experience_engine.dart';
import '../experience/student_experience_t00_adapter.dart';
import '../experience/student_experience_t02_adapter.dart';
import '../lesson/dopamine_ready_window_engine.dart';
import '../lesson/lesson_event_bus.dart';
import '../lesson/lesson_material_cache.dart';
import '../lesson/lesson_orchestrator.dart';
import '../lesson/ready_window_worker.dart';
import '../lesson/student_lesson_material_service.dart';
import '../media/audio_core.dart';
import '../media/audio_preference.dart';
import '../media/lesson_audio_controller.dart';
import '../media/lesson_visual_pipeline.dart';
import '../media/student_lesson_media_service.dart';
import '../placement/placement_route_controller.dart';
import '../placement/placement_store.dart';
import '../placement/placement_t02_caller.dart';
import '../placement/student_placement_service.dart';
import '../state/student_learning_state.dart';
import '../state/student_learning_state_service.dart';
import '../state/student_state_store.dart';
import '../state/student_state_store_adapter.dart';
import 'sim_laboratory_adapters.dart';
import 'sim_organism_health.dart';
import 'sim_organism_router.dart';

class SimOrganism {
  SimOrganism._({
    required this.lessonLocalId,
    required this.stateService,
    required this.router,
    required this.health,
    required this.cache,
    required this.eventBus,
    required this.lessonOrchestrator,
    required this.readyWindowEngine,
    required this.readyWindowWorker,
    required this.materialService,
    required this.experienceEngine,
    required this.placementService,
    required this.placementController,
    required this.lessonRuntimeEngine,
    required this.cloudQueue,
    required this.sync,
    required this.cloudBootstrap,
    required this.curriculumSync,
    required this.audioPreference,
    required this.audioCore,
    required this.mediaService,
    required this.lessonAudioController,
    required this.visualPipeline,
    required this.creditsController,
    required this.accountDeletionController,
  });

  final String lessonLocalId;
  final StudentLearningStateService stateService;
  final SimOrganismRouter router;
  final SimOrganismHealthReport health;
  final LessonMaterialCache cache;
  final LessonEventBus eventBus;
  final LessonOrchestrator lessonOrchestrator;
  final DopamineReadyWindowEngine readyWindowEngine;
  final ReadyWindowWorker readyWindowWorker;
  final StudentLessonMaterialService materialService;
  final StudentExperienceEngine experienceEngine;
  final StudentPlacementService placementService;
  final PlacementRouteController placementController;
  final LessonRuntimeEngine lessonRuntimeEngine;
  final CloudQueue cloudQueue;
  final StudentLearningSync sync;
  final LessonCloudBootstrap cloudBootstrap;
  final LessonCurriculumSyncEngine curriculumSync;
  final AudioPreference audioPreference;
  final AudioCore audioCore;
  final StudentLessonMediaService mediaService;
  final LessonAudioController lessonAudioController;
  final LessonVisualPipeline visualPipeline;
  final CreditsRouteController creditsController;
  final AccountDeletionController accountDeletionController;

  StudentLearningState get activeState {
    return stateService.ensure(lessonLocalId: lessonLocalId);
  }

  static SimOrganism laboratory({
    String lessonLocalId = 'lab-live-entry',
    StudentStateStore? canonicalStore,
  }) {
    final activeStore =
        canonicalStore ??
        StudentStateStore(local: MemoryStudentStateLocalStorage());
    final StudentLearningStateService stateService = StudentStateStoreAdapter(
      activeStore,
    );
    stateService.ensure(lessonLocalId: lessonLocalId, userId: 'lab-user');

    const t02Client = LaboratoryT02Client();
    const t00Client = LaboratoryT00Client();
    final cache = LessonMaterialCache();
    final eventBus = LessonEventBus();
    final orchestrator = LessonOrchestrator(
      t02Client: t02Client,
      cache: cache,
      bus: eventBus,
    );
    final readyWindowEngine = DopamineReadyWindowEngine(
      service: stateService,
      orchestrator: orchestrator,
    );
    final materialService = StudentLessonMaterialService(
      stateService: stateService,
      orchestrator: orchestrator,
      readyWindowEngine: readyWindowEngine,
    );
    final readyWindowWorker = ReadyWindowWorker(
      service: stateService,
      processor: readyWindowEngine.runDopamineReadyWindowFromStudentState,
    );

    final t00Adapter = StudentExperienceT00Adapter(
      service: stateService,
      client: t00Client,
    );
    final t02Adapter = StudentExperienceT02Adapter(
      service: stateService,
      materialService: materialService,
    );
    final experienceEngine = StudentExperienceEngine(
      service: stateService,
      t00: t00Adapter,
      t02: t02Adapter,
      placement: const LabPlacementDecisionReader(),
    );

    final placementService = StudentPlacementService(
      stateService: stateService,
      lessonLocalId: lessonLocalId,
    );
    final placementStore = PlacementStore(placementService);
    final placementController = PlacementRouteController(
      lessonLocalId: lessonLocalId,
      stateService: stateService,
      store: placementStore,
      t02Caller: PlacementT02Caller(t02Client: t02Client, enabled: true),
      enabled: true,
    );

    final lessonMaterialController = LessonMaterialController(
      stateService: stateService,
      materialService: materialService,
    );
    final lessonRuntimeEngine = LessonRuntimeEngine(
      stateService: stateService,
      sessionEngine: LessonSessionEngine(service: stateService),
      hydrationEngine: LessonHydrationEngine(materialService: materialService),
      positionEngine: LessonPositionEngine(),
      materialController: lessonMaterialController,
      answerController: LessonAnswerProgressController(
        stateService: stateService,
        materialService: materialService,
        materialController: lessonMaterialController,
        store: activeStore,
      ),
    );

    final cloudFunctions = LaboratoryStudentStateCloudFunctions();
    final cloudQueue = CloudQueue(
      storage: MemoryCloudQueueStorage(),
      stateService: stateService,
      sessionProvider: const LaboratorySessionProvider(
        session: SupabaseSession(accessToken: 'lab-token', userId: 'lab-user'),
      ),
      cloudFunctions: cloudFunctions,
    );
    final sync = StudentLearningSync(cloudQueue);
    final cloudBootstrap = LessonCloudBootstrap(sync: sync);
    final curriculumSync = LessonCurriculumSyncEngine(
      stateService: stateService,
    );

    final audioPreference = AudioPreference();
    final audioCore = AudioCore(
      preference: audioPreference,
      playback: NoopAudioPlaybackAdapter(),
      generatedAudioClient: const LaboratoryGeneratedAudioClient(),
      stableLangProvider: () =>
          stateService.read(lessonLocalId)?.profile.stableLang ?? '',
    );
    final mediaService = StudentLessonMediaService(
      audioCore: audioCore,
      readState: (id) => stateService.ensure(lessonLocalId: id),
      writeState: stateService.write,
    );
    final lessonAudioController = LessonAudioController(
      lessonLocalId: lessonLocalId,
      mediaService: mediaService,
      preference: audioPreference,
    );
    final visualPipeline = LessonVisualPipeline(
      imageClient: const LaboratoryLessonImageClient(),
    );

    final returnStore = PaymentReturnStore();
    final creditsController = CreditsRouteController(
      creditsFunctions: LaboratoryCreditsFunctions(),
      paymentsFunctions: const LaboratoryPaymentsFunctions(),
      returnStore: returnStore,
    );
    final accountDeletionController = AccountDeletionController(
      gateway: LaboratoryAccountDeletionGateway(),
    );

    return SimOrganism._(
      lessonLocalId: lessonLocalId,
      stateService: stateService,
      router: const SimOrganismRouter(),
      health: buildSimOrganismHealthReport(),
      cache: cache,
      eventBus: eventBus,
      lessonOrchestrator: orchestrator,
      readyWindowEngine: readyWindowEngine,
      readyWindowWorker: readyWindowWorker,
      materialService: materialService,
      experienceEngine: experienceEngine,
      placementService: placementService,
      placementController: placementController,
      lessonRuntimeEngine: lessonRuntimeEngine,
      cloudQueue: cloudQueue,
      sync: sync,
      cloudBootstrap: cloudBootstrap,
      curriculumSync: curriculumSync,
      audioPreference: audioPreference,
      audioCore: audioCore,
      mediaService: mediaService,
      lessonAudioController: lessonAudioController,
      visualPipeline: visualPipeline,
      creditsController: creditsController,
      accountDeletionController: accountDeletionController,
    );
  }

  static SimOrganism production({required String lessonLocalId}) {
    throw UnimplementedError(
      'SimOrganism.production() requer clients reais de servidor. '
      'Use --dart-define=FLUTTER_APP_MODE=production apenas quando TC-02 estiver instalado.',
    );
  }
}
