import 'package:supabase_flutter/supabase_flutter.dart';

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
import '../cloud/supabase_flutter_session_provider.dart';
import '../cloud/student_learning_sync.dart';
import '../experience/student_experience_engine.dart';
import '../experience/student_experience_t00_adapter.dart';
import '../experience/student_experience_t02_adapter.dart';
import '../external_ai/sim_ai_server_config.dart';
import '../external_ai/sim_server_ai_clients.dart';
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
import 'sim_laboratory_adapters.dart';
import 'sim_organism_health.dart';
import 'sim_organism_router.dart';

class SimOrganism {
  SimOrganism._({{
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

  static SimOrganism _build({
    required String lessonLocalId,
    required T02LessonClient t02Client,
    required T00BootstrapClient t00Client,
    required GeneratedAudioClient audioClient,
    required LessonImageClient imageClient,
    required SupabaseSessionProvider sessionProvider,
    required StudentLearningStateService stateService,
  }) {
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
      ),
    );

    final cloudQueue = CloudQueue(
      storage: MemoryCloudQueueStorage(),
      stateService: stateService,
      sessionProvider: sessionProvider,
      cloudFunctions: LaboratoryStudentStateCloudFunctions(),
    );
    final sync = StudentLearningSync(cloudQueue);
    final cloudBootstrap = LessonCloudBootstrap(sync: sync);
    final curriculumSync = LessonCurriculumSyncEngine(stateService: stateService);

    final audioPreference = AudioPreference();
    final audioCore = AudioCore(
      preference: audioPreference,
      playback: NoopAudioPlaybackAdapter(),
      generatedAudioClient: audioClient,
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
    final visualPipeline = LessonVisualPipeline(imageClient: imageClient);

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

  static SimOrganism laboratory({String lessonLocalId = 'lab-live-entry'}) {
    final stateService = StudentLearningStateService();
    stateService.ensure(lessonLocalId: lessonLocalId, userId: 'lab-user');
    return _build(
      lessonLocalId: lessonLocalId,
      t02Client: const LaboratoryT02Client(),
      t00Client: const LaboratoryT00Client(),
      audioClient: const LaboratoryGeneratedAudioClient(),
      imageClient: const LaboratoryLessonImageClient(),
      sessionProvider: const LaboratorySessionProvider(
        session: SupabaseSession(accessToken: 'lab-token', userId: 'lab-user'),
      ),
      stateService: stateService,
    );
  }

  static SimOrganism production({String lessonLocalId = 'live-entry'}) {
    Future<String?> tokenProvider() async =>
        Supabase.instance.client.auth.currentSession?.accessToken;

    final vmConfig = SimAiServerConfig(
      baseUrl: 'http://167.179.109.137:3000',
      accessTokenProvider: tokenProvider,
      t02Path: '/api/complete-lesson',
    );
    final lovableConfig = SimAiServerConfig(
      baseUrl: 'https://gemini-aid-pal.lovable.app',
      accessTokenProvider: tokenProvider,
    );

    final stateService = StudentLearningStateService();
    stateService.ensure(lessonLocalId: lessonLocalId);

    return _build(
      lessonLocalId: lessonLocalId,
      t02Client: SimServerT02Client(config: vmConfig),
      t00Client: SimServerT00Client(config: lovableConfig),
      audioClient: SimServerGeneratedAudioClient(config: lovableConfig),
      imageClient: SimServerLessonImageClient(config: lovableConfig),
      sessionProvider: const SupabaseFlutterSessionProvider(),
      stateService: stateService,
    );
  }
}
