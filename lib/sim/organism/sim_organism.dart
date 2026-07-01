import 'package:shared_preferences/shared_preferences.dart';

import '../billing/account_deletion.dart';
import '../billing/credits_route_controller.dart';
import '../billing/payment_return_store.dart';
import '../billing/sim_server_billing_clients.dart';
import '../classroom/lesson_answer_progress_controller.dart';
import '../classroom/lesson_hydration_engine.dart';
import '../classroom/lesson_material_controller.dart';
import '../classroom/lesson_position_engine.dart';
import '../classroom/lesson_runtime_engine.dart';
import '../classroom/lesson_session_engine.dart';
import '../cloud/cloud_queue.dart';
import '../cloud/lesson_cloud_bootstrap.dart';
import '../cloud/lesson_curriculum_sync_engine.dart';
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
import '../state/learning_decision_engine.dart';
import '../state/student_learning_state_service.dart';
import '../state/student_state_store.dart';
import '../state/student_state_store_adapter.dart';
import '../cloud/sim_server_cloud_functions.dart';
import '../cloud/supabase_flutter_session_provider.dart';
import '../external_ai/sim_ai_server_config.dart';
import '../external_ai/sim_server_ai_clients.dart';
import '../cloud/shared_prefs_cloud_queue_storage.dart';
import '../state/shared_prefs_state_storage.dart';
import '../media/platform_audio_adapter.dart';
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

  static SimOrganism production({
    required String lessonLocalId,
    required SimAiServerConfig aiConfig,
    required SharedPreferences prefs,
    StudentStateStore? canonicalStore,
    AudioPlaybackAdapter? playback,
  }) {
    final sessionProvider = const SupabaseFlutterSessionProvider();

    final localStorage = SharedPrefsStudentStateLocalStorage(
      prefs,
      activeLessonLocalId: lessonLocalId,
    );
    final activeStore =
        canonicalStore ?? StudentStateStore(local: localStorage);
    final stateAdapter = StudentStateStoreAdapter(activeStore);
    final StudentLearningStateService stateService = stateAdapter;
    stateService.ensure(lessonLocalId: lessonLocalId);

    final t00Client = SimServerT00Client(config: aiConfig);
    final t02Client = SimServerT02Client(config: aiConfig);
    final cache = LessonMaterialCache();
    cache.hydrateFromPreferences(prefs);
    final eventBus = LessonEventBus();
    final visualPipeline = LessonVisualPipeline(
      imageClient: SimServerLessonImageClient(config: aiConfig),
      visualRouterClient: SimServerVisualRouterClient(config: aiConfig),
    );
    final orchestrator = LessonOrchestrator(
      t02Client: t02Client,
      cache: cache,
      bus: eventBus,
      visualPipeline: visualPipeline,
    );
    final readyWindowEngine = DopamineReadyWindowEngine(
      service: stateService,
      orchestrator: orchestrator,
    );
    final audioPreference = AudioPreference(
      storage: SharedPrefsAudioPreferenceStorage(prefs),
    );
    final audioCore = AudioCore(
      preference: audioPreference,
      playback: playback ?? PlatformAudioAdapter(),
      generatedAudioClient: SimServerGeneratedAudioClient(config: aiConfig),
      stableLangProvider: () =>
          stateService.read(lessonLocalId)?.profile.stableLang ?? '',
    );
    final mediaService = StudentLessonMediaService(
      audioCore: audioCore,
      readState: (id) => stateService.ensure(lessonLocalId: id),
      writeState: stateService.write,
    );
    orchestrator.setAudioTextPreparer((params, lesson) {
      mediaService.prepareLessonAudioText(
        LessonMediaPosition(
          lessonLocalId: params.lessonLocalId,
          itemMarker: params.marker,
          layer: params.layer,
        ),
        [
          lesson.conteudo.explanation,
          lesson.conteudo.question,
          lesson.conteudo.options[AnswerLetter.A],
          lesson.conteudo.options[AnswerLetter.B],
          lesson.conteudo.options[AnswerLetter.C],
        ],
      );
    });
    final materialService = StudentLessonMaterialService(
      stateService: stateService,
      orchestrator: orchestrator,
      readyWindowEngine: readyWindowEngine,
      mediaService: mediaService,
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
      placement: const SettledPlacementReader(settled: true),
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
      t02Caller: PlacementT02Caller(t02Client: t02Client, enabled: false),
      enabled: false,
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
        audioCore: audioCore,
      ),
    );

    final cloudFunctions = SimServerCloudFunctions(config: aiConfig);
    final cloudQueue = CloudQueue(
      storage: SharedPrefsCloudQueueStorage(prefs),
      stateService: stateService,
      sessionProvider: sessionProvider,
      cloudFunctions: cloudFunctions,
    );
    stateService.setShadowDecisionRunner(
      (id) => runShadowDecision(id, stateService),
    );
    stateAdapter.onWrite = (id) =>
        cloudQueue.enqueueStudentStateSync(lessonLocalId: id);
    readyWindowWorker.startReadyWindowWorker(
      activeLessonLocalId: lessonLocalId,
    );
    final sync = StudentLearningSync(cloudQueue);
    final cloudBootstrap = LessonCloudBootstrap(sync: sync);
    final curriculumSync = LessonCurriculumSyncEngine(
      stateService: stateService,
    );
    final lessonAudioController = LessonAudioController(
      lessonLocalId: lessonLocalId,
      mediaService: mediaService,
      preference: audioPreference,
    );
    final returnStore = PaymentReturnStore();
    final creditsController = CreditsRouteController(
      creditsFunctions: SimServerCreditsClient(config: aiConfig),
      paymentsFunctions: SimServerPaymentsClient(config: aiConfig),
      returnStore: returnStore,
    );
    final accountDeletionController = AccountDeletionController(
      gateway: SimServerAccountDeletionGateway(config: aiConfig),
    );

    // Part VIII.1: wire lifecycle observer + 1s delayed initial drain
    cloudQueue.wireCloudQueueLifecycle();

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
}
