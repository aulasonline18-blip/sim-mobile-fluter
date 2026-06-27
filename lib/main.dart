import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'sim/cloud/sim_server_cloud_functions.dart';
import 'sim/cloud/supabase_flutter_session_provider.dart';
import 'sim/cloud/supabase_student_state_cloud_storage.dart';
import 'sim/external_ai/sim_ai_server_config.dart';
import 'sim/external_ai/sim_server_ai_clients.dart';
import 'sim/external_ai/sim_server_attachment_client.dart';
import 'sim/classroom/classroom_models.dart';
import 'sim/classroom/lesson_runtime_engine.dart';
import 'sim/config/app_mode.dart';
import 'sim/experience/student_experience_engine.dart';
import 'sim/experience/student_experience_types.dart';
import 'sim/organism/sim_organism.dart';
import 'sim/organism/sim_organism_provider.dart';
import 'session/auth_session.dart';
import 'session/entry_form_state.dart';
import 'session/lesson_ui_state.dart';
import 'session/navigation_state.dart';
import 'sim/lesson/lesson_models.dart';
import 'sim/media/audio_core.dart';
import 'sim/media/audio_preference.dart';
import 'sim/media/lesson_audio_controller.dart';
import 'sim/media/student_lesson_media_service.dart';
import 'sim/state/shared_prefs_state_storage.dart';
import 'sim/state/student_learning_state.dart';
import 'sim/state/student_state_store.dart';

const simSupabaseUrl = 'https://qgdlmxobfexoyllvdlee.supabase.co';
const simSupabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFnZGxteG9iZmV4b3lsbHZkbGVlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzkxODgzNzAsImV4cCI6MjA5NDc2NDM3MH0.szSCxlrkftrovIElV4nbgArJqSsfKOpGy1xvUs4rnL0';
const simAuthRedirectUrl = 'sim-mobile://login-callback';
const simApiBaseUrl = String.fromEnvironment(
  'SIM_SERVER_URL',
  defaultValue: 'http://167.179.109.137:3000',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: simSupabaseUrl,
    publishableKey: simSupabaseAnonKey,
  );
  final prefs = await SharedPreferences.getInstance();
  final stateStorage = SharedPrefsStudentStateLocalStorage(prefs);
  const sessionProvider = SupabaseFlutterSessionProvider();
  final cloudStorage = SupabaseStudentStateCloudStorage(
    cloudFunctions: SimServerCloudFunctions(
      config: const SimAiServerConfig(baseUrl: simApiBaseUrl),
    ),
    sessionProvider: sessionProvider,
  );
  final canonicalStore = StudentStateStore(
    local: stateStorage,
    cloud: cloudStorage,
  );
  runApp(SimMobileApp(canonicalStore: canonicalStore, prefs: prefs));
}

const simDark = Color(0xFF111827);
const simMid = Color(0xFF374151);
const simLight = Color(0xFFF3F4F6);
const simMuted = Color(0xFF6B7280);
const simBorder = Color(0xFFD1D5DB);
const simSuccess = Color(0xFF10B981);
const simWarn = Color(0xFFEF4444);
const maxFreeText = 1500;
const maxAttachments = 3;
const maxAttachmentBytes = 10 * 1024 * 1024;
const minExtractedChars = 20;
const audioNotSupportedMessage =
    'Áudio ainda não está disponível. Envie texto, foto ou arquivo.';
const videoNotSupportedMessage =
    'Vídeo ainda não está disponível. Envie texto, foto ou arquivo.';
const objectiveRequiredMessage =
    'Campo obrigatório. Escreva o que você quer estudar.';
const objectiveRequiredWithAttachmentMessage =
    'Você anexou um arquivo. Agora escreva o que deseja estudar com ele.';

class LabSession extends ChangeNotifier {
  LabSession({
    StudentStateStore? canonicalStore,
    this._attachmentClient,
    AppMode? appMode,
    SharedPreferences? prefs,
  }) : appMode = appMode ?? AppModeConfig.current,
       _prefs = prefs,
       canonicalStore =
           canonicalStore ??
           StudentStateStore(local: MemoryStudentStateLocalStorage()) {
    entryForm.addListener(_notifyFromChild);
    authSession.addListener(_notifyFromChild);
    navigationState.addListener(_notifyFromChild);
    lessonUiState.addListener(_notifyFromChild);
  }

  final AppMode appMode;
  final SharedPreferences? _prefs;
  final StudentStateStore? canonicalStore;
  final SimServerAttachmentClient? _attachmentClient;

  late final EntryFormState entryForm = EntryFormState(
    attachmentClient: _attachmentClient,
    serverConfig: _serverConfig,
  );
  late final NavigationState navigationState = NavigationState();
  late final LessonUiState lessonUiState = LessonUiState();
  late final AuthSession authSession = AuthSession(
    navigation: navigationState,
    onAuthenticated: _hydrateActiveLessonFromCloud,
  );

  late final SimOrganismProvider simOrganismProvider = SimOrganismProvider(
    mode: appMode,
    canonicalStore: canonicalStore!,
    aiConfig: _serverConfig(),
    prefs: _prefs,
  );
  SimOrganism? _activeOrganism;
  LessonRuntimeSnapshot? aulaSnapshot;
  bool aulaRuntimeLoading = false;
  String? aulaRuntimeError;

  final AudioPreference _audioPreference = AudioPreference();
  LessonAudioController? _lessonAudioController;

  void _notifyFromChild() => notifyListeners();

  StudentLearningState? get _activeCanonicalState {
    final id = lessonLocalId;
    if (id == null || id.trim().isEmpty) return null;
    return canonicalStore?.readState(id);
  }

  LessonLayer get currentAulaLayer {
    final state = _activeCanonicalState;
    return state?.current?.layer ?? state?.progress?.layer ?? LessonLayer.l1;
  }

  int get currentAulaItemNumber {
    final state = _activeCanonicalState;
    return (state?.current?.itemIdx ?? state?.progress?.itemIdx ?? 0) + 1;
  }

  bool get authed => authSession.authed;
  set authed(bool value) => authSession.authed = value;
  bool get authReady => authSession.authReady;
  set authReady(bool value) => authSession.authReady = value;
  int get credits => authSession.credits;
  set credits(int value) => authSession.credits = value;
  String? get userId => authSession.userId;
  String? get userEmail => authSession.userEmail;
  String? get userName => authSession.userName;
  String? get authError => authSession.authError;

  String get route => navigationState.route;
  set route(String value) => navigationState.route = value;
  String get returnTo => navigationState.returnTo;
  set returnTo(String value) => navigationState.returnTo = value;
  String? get externalDoorOpened => navigationState.externalDoorOpened;

  String? get selectedLanguageCode => entryForm.selectedLanguageCode;
  set selectedLanguageCode(String? value) =>
      entryForm.selectedLanguageCode = value;
  String? get stableLang => entryForm.stableLang;
  set stableLang(String? value) => entryForm.stableLang = value;
  String get otherLanguage => entryForm.otherLanguage;
  String get freeText => entryForm.freeText;
  set freeText(String value) => entryForm.freeText = value;
  String get preferredName => entryForm.preferredName;
  set preferredName(String value) => entryForm.preferredName = value;
  bool get allowPaidImages => entryForm.allowPaidImages;
  List<AttachmentDraft> get attachments => entryForm.attachments;
  String get attachmentsText => entryForm.attachmentsText;
  String get studentProfileNotes => entryForm.studentProfileNotes;
  String? get attachmentError => entryForm.attachmentError;

  String? get lessonLocalId => lessonUiState.lessonLocalId;
  set lessonLocalId(String? value) => lessonUiState.lessonLocalId = value;
  String get entryStatus => lessonUiState.entryStatus;
  set entryStatus(String value) => lessonUiState.entryStatus = value;
  String? get entryError => lessonUiState.entryError;
  set entryError(String? value) => lessonUiState.entryError = value;
  bool get placementStarted => lessonUiState.placementStarted;
  bool get placementDone => lessonUiState.placementDone;
  int get aulaStep => lessonUiState.aulaStep;
  String get selectedAnswer => lessonUiState.selectedAnswer;
  String get aulaMessage => lessonUiState.aulaMessage;
  bool get doubtOpen => lessonUiState.doubtOpen;
  bool get audioEnabled => lessonUiState.audioEnabled;
  set audioEnabled(bool value) => lessonUiState.audioEnabled = value;
  bool get audioPlaying => lessonUiState.audioPlaying;
  set audioPlaying(bool value) => lessonUiState.audioPlaying = value;
  bool get audioLoading => lessonUiState.audioLoading;
  set audioLoading(bool value) => lessonUiState.audioLoading = value;
  String? get audioError => lessonUiState.audioError;
  set audioError(String? value) => lessonUiState.audioError = value;
  String get imageStatus => lessonUiState.imageStatus;
  set imageStatus(String value) => lessonUiState.imageStatus = value;
  String? get imageError => lessonUiState.imageError;
  set imageError(String? value) => lessonUiState.imageError = value;
  String get deleteConfirmation => lessonUiState.deleteConfirmation;
  String? get accountDeletionMessage => lessonUiState.accountDeletionMessage;

  void goPortal() => navigationState.goPortal();

  void goLogin({String target = '/'}) =>
      navigationState.goLogin(target: target);

  void bindRealAuth() => authSession.bindRealAuth();

  SupabaseClient? _supabaseClientOrNull() {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  void applySupabaseSession(Session? session) {
    authSession.applySupabaseSession(session);
  }

  // AuthSession keeps the real Supabase OAuth contract: OAuthProvider.google with queryParams {'prompt': 'select_account'} and email signInWithPassword.
  Future<void> signInWithGoogle() => authSession.signInWithGoogle();

  Future<void> signInWithEmailPassword({
    required String email,
    required String password,
  }) {
    return authSession.signInWithEmailPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signUpWithEmailPassword({
    required String email,
    required String password,
    required String name,
  }) {
    return authSession.signUpWithEmailPassword(
      email: email,
      password: password,
      name: name,
    );
  }

  Future<void> signOutReal() => authSession.signOutReal();

  void start() {
    if (!authed) {
      goLogin(target: '/');
      return;
    }
    if (credits <= 0) return;
    entryForm.resetLanguage();
    navigationState.openRoute('/cyber/idioma');
  }

  void chooseLanguage(String code, String name) {
    entryForm.updateLanguage(code, name);
    final cleanName = name.trim();
    if (code != 'other' || cleanName.isNotEmpty) {
      navigationState.openRoute('/cyber/objeto');
    }
  }

  void setOtherLanguage(String value) => entryForm.setOtherLanguage(value);

  void setFreeText(String value) => entryForm.updateFreeText(value);

  void setPreferredName(String value) => entryForm.updatePreferredName(value);

  void addLabAttachment(String source) => entryForm.addLabAttachment(source);

  void removeAttachment(int index) => entryForm.removeAttachment(index);

  void clearAttachments() => entryForm.clearAttachments();

  bool saveObjectiveEntry() {
    final freeTrim = freeText.trim();
    if (freeTrim.length < 10) return false;
    final clipped = freeTrim.length > maxFreeText
        ? freeTrim.substring(0, maxFreeText)
        : freeTrim;
    entryForm.attachmentsText = entryForm.buildAttachmentsText();
    final language = stableLang ?? 'English';
    final id = _deriveLessonLocalId(clipped, selectedLanguageCode ?? language);
    lessonLocalId = id;
    entryForm.studentProfileNotes = attachmentsText.isEmpty
        ? clipped
        : '$clipped\n\n$attachmentsText';
    entryForm.freeText = clipped;
    _saveProfileToState(id: id, objective: clipped, language: language);
    entryStatus = 'pedido_recebido';
    entryError = null;
    navigationState.openRoute('/cyber/curriculo');
    return true;
  }

  Future<void> launchExperience() async {
    final id = lessonLocalId;
    if (id == null || id.trim().isEmpty) return;
    if (entryStatus == 't00_running' ||
        entryStatus == 't02_running' ||
        entryStatus == 'primeira_aula_pronta') return;

    entryStatus = 't00_running';
    entryError = null;
    notifyListeners();

    try {
      final organism = simOrganismProvider.forLesson(id);
      final onboarding = <String, dynamic>{
        'objetivo': freeText.trim(),
        'free_text': freeText.trim(),
        'idioma': stableLang ?? 'pt-BR',
        'language': selectedLanguageCode ?? stableLang ?? 'pt-BR',
        'stableLang': stableLang ?? 'pt-BR',
        'STABLE_LANG': stableLang ?? 'pt-BR',
        'ACADEMIC_LEVEL': 'incerto',
        'academic_level': 'incerto',
        'nivel': 'incerto',
        if (preferredName.trim().isNotEmpty)
          'preferred_name': preferredName.trim(),
        if (studentProfileNotes.isNotEmpty)
          'student_profile_notes': studentProfileNotes,
        if (attachmentsText.isNotEmpty) 'attachments_text': attachmentsText,
      };
      final args = StudentExperienceArgs(
        academic: 'incerto',
        idioma: stableLang ?? 'pt-BR',
        lessonLocalId: id,
        onboarding: onboarding,
        onStage: (stage) {
          final next = switch (stage) {
            StudentExperienceRouteStage.curriculum => 't00_running',
            StudentExperienceRouteStage.lesson => 't02_running',
            StudentExperienceRouteStage.ready => 'primeira_aula_pronta',
            StudentExperienceRouteStage.placement => 'placement',
            _ => entryStatus,
          };
          entryStatus = next;
          notifyListeners();
        },
      );

      final result = await organism.experienceEngine
          .prepareStudentExperienceEntry(args);

      entryStatus = 'primeira_aula_pronta';
      notifyListeners();

      await Future<void>.delayed(const Duration(milliseconds: 650));
      navigationState.openRoute(result.destination);
      if (result.destination == '/cyber/aula') {
        unawaited(openAulaRuntime());
      }
    } on StudentExperienceEngineException catch (err) {
      entryError = err.error.message;
      entryStatus = 'erro';
      notifyListeners();
    } catch (err) {
      entryError = err.toString();
      entryStatus = 'erro';
      notifyListeners();
    }
  }

  void retryExperience() {
    entryStatus = 'pedido_recebido';
    entryError = null;
    notifyListeners();
    unawaited(launchExperience());
  }

  void _saveProfileToState({
    required String id,
    required String objective,
    required String language,
  }) {
    canonicalStore?.patchState(id, (state) {
      return state.copyWith(
        userId: userId,
        profile: state.profile.copyWith(
          preferredName: preferredName.trim().isEmpty
              ? state.profile.preferredName
              : preferredName.trim(),
          language: selectedLanguageCode ?? language,
          stableLang: stableLang ?? language,
          objetivo: objective,
          targetTopic: objective,
          sessionGoal: objective,
        ),
      );
    });
    canonicalStore?.appendEvent(
      lessonLocalId: id,
      type: 'STUDENT_FORM_SUBMITTED',
      payload: {
        'objective_length': objective.length,
        'language': language,
      },
      source: 'lab_session',
      userId: userId,
    );
  }

  void openCredits() {
    if (!authed) {
      goLogin(target: '/creditos');
      return;
    }
    navigationState.openRoute('/creditos');
  }

  void openSupport(String path) => navigationState.openRoute(path);

  void openExternalDoor(String url) => navigationState.openExternalDoor(url);

  void openCheckoutReturn() => navigationState.openRoute('/checkout/return');

  void _hydrateActiveLessonFromCloud() {
    final id = lessonLocalId;
    if (id == null || id.trim().isEmpty) return;
    final store = canonicalStore;
    if (store == null) return;
    unawaited(
      store.hydrateFromCloud(id).catchError((_) => store.readState(id)),
    );
  }

  void _persistActiveLessonToCloud() {
    final id = lessonLocalId;
    if (id == null || id.trim().isEmpty) return;
    final store = canonicalStore;
    if (store == null) return;
    unawaited(store.persistCloud(id).catchError((_) {}));
  }

  SimAiServerConfig _serverConfig() {
    return SimAiServerConfig(
      baseUrl: simApiBaseUrl,
      t02Path: '/api/complete-lesson',
      accessTokenProvider: () async =>
          _supabaseClientOrNull()?.auth.currentSession?.accessToken,
    );
  }

  LessonAudioController _audioControllerFor(String id) {
    final existing = _lessonAudioController;
    if (existing != null && existing.lessonLocalId == id) return existing;
    final store = canonicalStore;
    final controller = LessonAudioController(
      lessonLocalId: id,
      preference: _audioPreference,
      mediaService: StudentLessonMediaService(
        audioCore: AudioCore(
          preference: _audioPreference,
          playback: NoopAudioPlaybackAdapter(),
          generatedAudioClient: SimServerGeneratedAudioClient(
            config: _serverConfig(),
          ),
          stableLangProvider: () =>
              stableLang ?? selectedLanguageCode ?? 'pt-BR',
        ),
        readState: (lessonLocalId) =>
            store?.readState(lessonLocalId) ??
            StudentLearningState.empty(lessonLocalId: lessonLocalId),
        writeState: (state) => store?.writeState(state) ?? state,
      ),
    );
    _lessonAudioController = controller;
    return controller;
  }

  LessonContent _currentLessonContentForAudio() {
    final content = aulaSnapshot?.conteudo;
    if (content == null) {
      throw StateError('Conteudo de aula ainda nao esta pronto para audio.');
    }
    return content;
  }

  SimOrganism _organismForActiveLesson() {
    final id = lessonLocalId;
    if (id == null || id.trim().isEmpty) {
      throw StateError('lessonLocalId ausente para abrir organismo SIM.');
    }
    final organism = simOrganismProvider.forLesson(id);
    _activeOrganism = organism;
    return organism;
  }

  Future<void> openAulaRuntime() async {
    if (aulaRuntimeLoading) return;
    aulaRuntimeLoading = true;
    aulaRuntimeError = null;
    notifyListeners();
    try {
      final organism = _organismForActiveLesson();
      aulaSnapshot = await organism.lessonRuntimeEngine.open(
        lessonLocalId: organism.lessonLocalId,
        authReady: authReady,
        authed: authed,
      );
      if (aulaSnapshot?.hasCurriculum != true) {
        aulaRuntimeError = 'Aula sem curriculo no Estado do aluno.';
      }
    } catch (error) {
      aulaRuntimeError = error.toString();
    } finally {
      aulaRuntimeLoading = false;
      notifyListeners();
    }
  }

  void preparationDone() {
    lessonUiState.markPreparationDone();
    navigationState.openRoute('/cyber/placement');
    _persistActiveLessonToCloud();
  }

  void skipPlacement() {
    lessonUiState.skipPlacement();
    navigationState.openRoute('/cyber/aula');
    unawaited(openAulaRuntime());
  }

  void startPlacement() => lessonUiState.startPlacement();

  void finishPlacement() {
    lessonUiState.finishPlacement();
    navigationState.openRoute('/cyber/aula');
    unawaited(openAulaRuntime());
  }

  void chooseAulaAnswer(String letter) {
    final organism = _activeOrganism ?? _organismForActiveLesson();
    final answer = AnswerLetter.values.firstWhere(
      (value) => value.name == letter,
      orElse: () => AnswerLetter.A,
    );
    organism.lessonRuntimeEngine.select(answer);
    aulaSnapshot = organism.lessonRuntimeEngine.snapshot();
    notifyListeners();
  }

  void submitAulaSignal(int value) {
    final organism = _activeOrganism ?? _organismForActiveLesson();
    final signal = switch (value) {
      1 => DecisionSignal.one,
      2 => DecisionSignal.two,
      3 => DecisionSignal.three,
      _ => DecisionSignal.one,
    };
    organism.lessonRuntimeEngine.signal(signal);
    aulaSnapshot = organism.lessonRuntimeEngine.snapshot();
    _persistActiveLessonToCloud();
    notifyListeners();
  }

  void setDeleteConfirmation(String value) {
    lessonUiState.setDeleteConfirmation(value);
  }

  void requestAccountDeletion() => lessonUiState.requestAccountDeletion();

  Future<void> advanceAula() async {
    final organism = _activeOrganism ?? _organismForActiveLesson();
    aulaRuntimeLoading = true;
    aulaRuntimeError = null;
    notifyListeners();
    try {
      await organism.lessonRuntimeEngine.advance();
      aulaSnapshot = organism.lessonRuntimeEngine.snapshot();
      _persistActiveLessonToCloud();
    } catch (error) {
      aulaRuntimeError = error.toString();
    } finally {
      aulaRuntimeLoading = false;
      notifyListeners();
    }
  }

  void toggleDoubt() => lessonUiState.toggleDoubt();

  Future<void> toggleAudio() async {
    if (audioLoading) return;
    audioError = null;
    final id =
        lessonLocalId ??
        _deriveLessonLocalId(
          freeText.trim().isEmpty ? 'aula-sim' : freeText,
          selectedLanguageCode ?? stableLang ?? 'pt',
        );
    if (audioPlaying) {
      _lessonAudioController?.pararAudio();
      audioPlaying = false;
      audioEnabled = false;
      _audioPreference.setAudioEnabled(false);
      notifyListeners();
      return;
    }
    audioEnabled = true;
    _audioPreference.setAudioEnabled(true);
    audioLoading = true;
    notifyListeners();
    await Future<void>.delayed(Duration.zero);
    try {
      final snapshot = aulaSnapshot;
      final started = await _audioControllerFor(id).playConteudo(
        _currentLessonContentForAudio(),
        snapshot?.itemMarker ?? 'item-1',
        currentAulaLayer,
        language: stableLang,
      );
      audioPlaying = started;
      if (!started) {
        audioError = 'Áudio ainda não está disponível.';
      }
    } catch (_) {
      audioError = 'Não foi possível preparar o áudio agora.';
      audioPlaying = false;
    } finally {
      audioLoading = false;
      notifyListeners();
    }
  }

  Future<void> requestLessonImage() async {
    if (imageStatus == 'loading') return;
    imageError = null;
    imageStatus = 'loading';
    notifyListeners();
    await Future<void>.delayed(const Duration(milliseconds: 180));
    imageStatus = 'ready';
    notifyListeners();
  }

  @override
  void dispose() {
    entryForm.removeListener(_notifyFromChild);
    authSession.removeListener(_notifyFromChild);
    navigationState.removeListener(_notifyFromChild);
    lessonUiState.removeListener(_notifyFromChild);
    authSession.dispose();
    _lessonAudioController?.pararAudio();
    super.dispose();
  }
}

String safeReturnTo(String raw) {
  if (!raw.startsWith('/')) return '/';
  if (raw.startsWith('//')) return '/';
  return raw;
}

String _deriveLessonLocalId(String objetivo, String idioma) {
  final obj = objetivo.trim().toLowerCase();
  final idi = idioma.trim().toLowerCase();
  final input = idi.isEmpty ? obj : '$idi|$obj';
  var h = 5381;
  for (final unit in input.codeUnits) {
    h = ((h << 5) + h) ^ unit;
  }
  final unsigned = h & 0xFFFFFFFF;
  return 'cyber-${unsigned.toRadixString(36)}';
}

class SimMobileApp extends StatefulWidget {
  const SimMobileApp({
    super.key,
    this.canonicalStore,
    this.initialSession,
    this.appMode,
    this.prefs,
  });

  final StudentStateStore? canonicalStore;
  final LabSession? initialSession;
  final AppMode? appMode;
  final SharedPreferences? prefs;

  @override
  State<SimMobileApp> createState() => _SimMobileAppState();
}

class _SimMobileAppState extends State<SimMobileApp> {
  late final LabSession session =
      widget.initialSession ??
      LabSession(
        canonicalStore: widget.canonicalStore,
        appMode: widget.appMode,
        prefs: widget.prefs,
      );

  @override
  void initState() {
    super.initState();
    session.addListener(_onSessionChanged);
    session.bindRealAuth();
  }

  @override
  void dispose() {
    session.removeListener(_onSessionChanged);
    session.dispose();
    super.dispose();
  }

  void _onSessionChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    Widget screen;
    switch (session.route) {
      case '/login':
        screen = LoginScreen(session: session);
      case '/cyber/idioma':
        screen = IdiomaScreen(session: session);
      case '/cyber/objeto':
        screen = ObjetoScreen(session: session);
      case '/cyber/curriculo':
        screen = PhaseBoundaryScreen(session: session);
      case '/cyber/placement':
        screen = PlacementLabScreen(session: session);
      case '/cyber/aula':
        screen = AulaLabScreen(session: session);
      case '/creditos':
        screen = CreditsLabScreen(session: session);
      case '/checkout/return':
        screen = CheckoutReturnScreen(session: session);
      case '/pai':
        screen = FatherLabScreen(session: session);
      case '/privacidade':
        screen = LegalLabScreen(session: session, title: 'Privacidade');
      case '/termos':
        screen = LegalLabScreen(session: session, title: 'Termos');
      case '/conta/deletar':
        screen = DeleteAccountLabScreen(session: session);
      default:
        screen = PortalScreen(session: session);
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SIM',
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Roboto',
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(
          seedColor: simDark,
          brightness: Brightness.light,
          surface: Colors.white,
        ),
      ),
      home: SimFrame(child: screen),
    );
  }
}

class SimFrame extends StatelessWidget {
  const SimFrame({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: simDark,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: child,
        ),
      ),
    );
  }
}

class PortalScreen extends StatelessWidget {
  const PortalScreen({required this.session, super.key});

  final LabSession session;

  @override
  Widget build(BuildContext context) {
    final displayBalance = session.authed ? session.credits : 0;
    return Scaffold(
      body: Stack(
        children: [
          const BackgroundDecor(),
          SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        session.authed
                            ? RoundIconButton(
                                icon: Icons.menu,
                                tooltip: 'Open lessons menu',
                                onTap: () => _showLabDrawer(context),
                              )
                            : const SizedBox(width: 48, height: 48),
                        CreditsPill(
                          value: displayBalance,
                          onTap: session.openCredits,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    PortalHeroCard(session: session),
                    const SizedBox(height: 16),
                    const Text(
                      'SIM v1  •  Cyber-Premium',
                      style: TextStyle(
                        color: simMuted,
                        fontSize: 12,
                        fontFamily: 'monospace',
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                    HelpCard(session: session),
                    const SizedBox(height: 24),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: pillDecoration(),
                        child: const Text(
                          '1/5',
                          style: TextStyle(
                            color: simMuted,
                            fontSize: 12,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showLabDrawer(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Menu',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: simDark,
              ),
            ),
            const SizedBox(height: 10),
            _PortalDrawerBody(session: session),
          ],
        ),
      ),
    );
  }
}

class _PortalDrawerBody extends StatelessWidget {
  const _PortalDrawerBody({required this.session});

  final LabSession session;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        MenuLine(
          label: 'Abrir aula',
          onTap: () {
            Navigator.pop(context);
            session.openSupport('/cyber/aula');
          },
        ),
        MenuLine(
          label: 'Créditos',
          onTap: () {
            Navigator.pop(context);
            session.openCredits();
          },
        ),
        MenuLine(
          label: 'Painel do Pai',
          onTap: () {
            Navigator.pop(context);
            session.openSupport('/pai');
          },
        ),
        MenuLine(
          label: 'Privacidade',
          onTap: () {
            Navigator.pop(context);
            session.openSupport('/privacidade');
          },
        ),
        MenuLine(
          label: 'Termos',
          onTap: () {
            Navigator.pop(context);
            session.openSupport('/termos');
          },
        ),
        MenuLine(
          label: 'Solicitar exclusão da conta',
          onTap: () {
            Navigator.pop(context);
            session.openSupport('/conta/deletar');
          },
        ),
      ],
    );
  }
}

class PortalHeroCard extends StatelessWidget {
  const PortalHeroCard({required this.session, super.key});

  final LabSession session;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
      decoration: glassDecoration(radius: 28),
      child: Column(
        children: [
          SizedBox(
            width: 132,
            height: 132,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 152,
                  height: 152,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(color: simDark.withAlpha(31)),
                  ),
                ),
                Container(
                  width: 132,
                  height: 132,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: simBorder),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x33111827),
                        blurRadius: 30,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Image.asset(
                    'assets/monkey-logo.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'SIM',
            style: TextStyle(
              color: simDark,
              fontSize: 68,
              height: 1,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(width: 32, child: Divider(color: simMid, thickness: 1)),
              SizedBox(width: 12),
              Flexible(
                child: Text(
                  'Smart Intelligence Mentor',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: simDark,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              SizedBox(width: 12),
              SizedBox(width: 32, child: Divider(color: simMid, thickness: 1)),
            ],
          ),
          const SizedBox(height: 24),
          const Text.rich(
            TextSpan(
              children: [
                TextSpan(text: 'Guided artificial intelligence for '),
                TextSpan(
                  text: 'real learning',
                  style: TextStyle(color: simDark, fontWeight: FontWeight.w700),
                ),
                TextSpan(text: ' - '),
                TextSpan(
                  text: 'adapted to the learner',
                  style: TextStyle(color: simDark, fontWeight: FontWeight.w700),
                ),
                TextSpan(
                  text:
                      ', supervised by the system, and built to turn effort into ',
                ),
                TextSpan(
                  text: 'real progress',
                  style: TextStyle(color: simDark, fontWeight: FontWeight.w700),
                ),
                TextSpan(text: '.'),
              ],
            ),
            textAlign: TextAlign.center,
            style: TextStyle(color: simMuted, fontSize: 15.5, height: 1.55),
          ),
          const SizedBox(height: 30),
          SizedBox(
            width: double.infinity,
            height: 64,
            child: DecoratedBox(
              decoration: primaryButtonDecoration(radius: 16),
              child: TextButton(
                onPressed: session.start,
                style: TextButton.styleFrom(
                  foregroundColor: simDark,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Positioned(
                      left: 14,
                      child: Icon(Icons.play_arrow, size: 22, color: simDark),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 44),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          session.authed ? 'Start' : 'Sign in to start',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: simDark,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class HelpCard extends StatelessWidget {
  const HelpCard({required this.session, super.key});

  final LabSession session;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: glassDecoration(radius: 24),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: simLight,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: simBorder),
                ),
                child: const Icon(
                  Icons.favorite_border,
                  color: simDark,
                  size: 22,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Help improve SIM.',
                      style: TextStyle(
                        color: simDark,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Send suggestions, report difficulties, and talk directly to the developer.',
                      style: TextStyle(
                        color: simMuted,
                        fontSize: 13.5,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 20,
            runSpacing: 12,
            children: [
              ContactButton(
                asset: 'assets/whatsapp-logo.png',
                label: 'Contact us on WhatsApp',
                onTap: () => session.openExternalDoor(
                  'https://wa.me/message/RLCYEXAYFUIIA1',
                ),
              ),
              ContactButton(
                asset: 'assets/messenger-logo.png',
                label: 'Contact us on Messenger',
                onTap: () =>
                    session.openExternalDoor('https://m.me/61557707493807'),
              ),
            ],
          ),
          if (session.externalDoorOpened != null) ...[
            const SizedBox(height: 10),
            Text(
              'Porta externa: ${session.externalDoorOpened}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: simMuted,
                fontSize: 11,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class ContactButton extends StatelessWidget {
  const ContactButton({
    required this.asset,
    required this.label,
    required this.onTap,
    super.key,
  });

  final String asset;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      button: true,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 56,
          height: 56,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: simBorder),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33243447),
                blurRadius: 20,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: ColorFiltered(
            colorFilter: const ColorFilter.matrix(<double>[
              0.2126,
              0.7152,
              0.0722,
              0,
              0,
              0.2126,
              0.7152,
              0.0722,
              0,
              0,
              0.2126,
              0.7152,
              0.0722,
              0,
              0,
              0,
              0,
              0,
              1,
              0,
            ]),
            child: Image.asset(asset, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({required this.session, super.key});

  final LabSession session;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool loading = false;
  String? error;
  bool signup = false;
  late final TextEditingController emailController = TextEditingController();
  late final TextEditingController passwordController = TextEditingController();
  late final TextEditingController nameController = TextEditingController();

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    nameController.dispose();
    super.dispose();
  }

  Future<void> google() async {
    if (loading) return;
    setState(() {
      loading = true;
      error = null;
    });
    await widget.session.signInWithGoogle();
    if (!mounted) return;
    setState(() {
      loading = false;
      error = widget.session.authError;
    });
  }

  Future<void> emailSubmit() async {
    if (loading) return;
    setState(() {
      loading = true;
      error = null;
    });
    final email = emailController.text.trim();
    final password = passwordController.text;
    if (signup) {
      await widget.session.signUpWithEmailPassword(
        email: email,
        password: password,
        name: nameController.text,
      );
    } else {
      await widget.session.signInWithEmailPassword(
        email: email,
        password: password,
      );
    }
    if (!mounted) return;
    setState(() {
      loading = false;
      error = widget.session.authError;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 448),
              child: Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: simBorder),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'S',
                      style: TextStyle(
                        color: simDark,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'SIM',
                    style: TextStyle(
                      color: simMid,
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Sign in',
                    style: TextStyle(
                      color: simMuted,
                      fontSize: 12,
                      fontFamily: 'monospace',
                      letterSpacing: 3,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: glassDecoration(radius: 18),
                    child: Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: OutlinedButton(
                            onPressed: loading ? null : google,
                            style: OutlinedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF1A1A1A),
                              side: const BorderSide(color: simBorder),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const GoogleMark(),
                                const SizedBox(width: 10),
                                Text(
                                  loading
                                      ? 'Please wait...'
                                      : 'Continue with Google',
                                  style: const TextStyle(
                                    color: Color(0xFF1A1A1A),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Row(
                          children: [
                            Expanded(child: Divider(color: simBorder)),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              child: Text(
                                'or',
                                style: TextStyle(
                                  color: simMuted,
                                  fontSize: 12,
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Expanded(child: Divider(color: simBorder)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (signup) ...[
                          SimInput(
                            hint: 'Your name',
                            controller: nameController,
                            onChanged: (_) {},
                          ),
                          const SizedBox(height: 12),
                        ],
                        SimInput(
                          hint: 'email@example.com',
                          controller: emailController,
                          keyboardType: TextInputType.emailAddress,
                          onChanged: (_) {},
                        ),
                        const SizedBox(height: 12),
                        SimInput(
                          hint: 'Password (min. 6 characters)',
                          controller: passwordController,
                          obscureText: true,
                          onChanged: (_) {},
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: DecoratedBox(
                            decoration: primaryButtonDecoration(radius: 12),
                            child: TextButton(
                              onPressed: loading ? null : emailSubmit,
                              child: Text(
                                loading
                                    ? 'Please wait...'
                                    : signup
                                    ? 'Create account and get 3 free lessons'
                                    : 'Sign in',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: simDark,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextButton(
                          onPressed: loading
                              ? null
                              : () {
                                  setState(() {
                                    error = null;
                                    signup = !signup;
                                  });
                                },
                          child: Text(
                            signup
                                ? 'Already have an account? Sign in'
                                : 'No account? Create one now',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: simMuted,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                        if (error != null) ...[
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              error!,
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextButton(
                    onPressed: widget.session.goPortal,
                    child: const Text(
                      '← Back to portal',
                      style: TextStyle(
                        color: simMuted,
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton(
                        onPressed: () =>
                            widget.session.openSupport('/privacidade'),
                        child: const Text(
                          'Privacidade',
                          style: TextStyle(
                            color: simMuted,
                            fontSize: 12,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () => widget.session.openSupport('/termos'),
                        child: const Text(
                          'Termos',
                          style: TextStyle(
                            color: simMuted,
                            fontSize: 12,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'GOOGLE AUTH VIA SUPABASE',
                    style: TextStyle(
                      color: simMuted,
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class GoogleMark extends StatelessWidget {
  const GoogleMark({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 20,
      height: 20,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            'G',
            style: TextStyle(
              color: Color(0xFF4285F4),
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class IdiomaScreen extends StatelessWidget {
  const IdiomaScreen({required this.session, super.key});

  final LabSession session;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const StepHeader(step: 1, total: 5, label: 'Step 1 of 5'),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 32, 20, 32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 576),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Choose your language',
                        style: TextStyle(
                          color: simDark,
                          fontSize: 30,
                          height: 1.1,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'SIM will use this language for the app, lessons, explanations, images, audio and all guidance — from this point onward.',
                        style: TextStyle(
                          color: simMuted,
                          fontSize: 18,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 28),
                      for (final language in supportedLangs) ...[
                        LanguageButton(
                          language: language,
                          active: session.selectedLanguageCode == language.code,
                          onTap: () => session.chooseLanguage(
                            language.code,
                            language.name,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      LanguageButton(
                        language: const SupportedLang(
                          code: 'other',
                          name: 'Other language',
                          native: '',
                          flag: '🌐',
                        ),
                        active: session.selectedLanguageCode == 'other',
                        onTap: () => session.chooseLanguage(
                          'other',
                          session.otherLanguage.trim(),
                        ),
                      ),
                      if (session.selectedLanguageCode == 'other') ...[
                        const SizedBox(height: 20),
                        OtherLanguageBox(session: session),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OtherLanguageBox extends StatefulWidget {
  const OtherLanguageBox({required this.session, super.key});

  final LabSession session;

  @override
  State<OtherLanguageBox> createState() => _OtherLanguageBoxState();
}

class _OtherLanguageBoxState extends State<OtherLanguageBox> {
  late final TextEditingController controller = TextEditingController(
    text: widget.session.otherLanguage,
  );

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final value = controller.text.trim();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: simBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Type your language',
            style: TextStyle(
              color: simMuted,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'e.g. Italian, German, Arabic, Kiribati…',
              border: InputBorder.none,
            ),
            style: const TextStyle(color: simDark, fontSize: 18),
            onChanged: (v) {
              widget.session.setOtherLanguage(v);
              setState(() {});
            },
          ),
          Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              height: 56,
              child: DecoratedBox(
                decoration: primaryButtonDecoration(radius: 12),
                child: TextButton(
                  onPressed: value.isEmpty
                      ? null
                      : () => widget.session.chooseLanguage('other', value),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'Continue',
                      style: TextStyle(
                        color: simDark,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ObjetoScreen extends StatefulWidget {
  const ObjetoScreen({required this.session, super.key});

  final LabSession session;

  @override
  State<ObjetoScreen> createState() => _ObjetoScreenState();
}

class _ObjetoScreenState extends State<ObjetoScreen> {
  bool attachmentMenuOpen = false;
  bool sending = false;
  String? error;
  late final TextEditingController objectiveController = TextEditingController(
    text: widget.session.freeText,
  );
  late final TextEditingController nameController = TextEditingController(
    text: widget.session.preferredName,
  );

  bool get waitingAttachment => widget.session.attachments.any(
    (a) => a.status == 'uploading' || a.status == 'processing',
  );
  bool get objectiveTooShort => widget.session.freeText.trim().length < 10;
  bool get canContinue => !sending && !waitingAttachment && !objectiveTooShort;

  @override
  void dispose() {
    objectiveController.dispose();
    nameController.dispose();
    super.dispose();
  }

  void showObjectiveRequired() {
    setState(() {
      error = widget.session.attachments.isNotEmpty
          ? objectiveRequiredWithAttachmentMessage
          : objectiveRequiredMessage;
    });
  }

  Future<void> saveAndContinue() async {
    if (waitingAttachment) return;
    if (objectiveTooShort) {
      showObjectiveRequired();
      return;
    }
    if (!canContinue) return;
    setState(() {
      error = null;
      sending = true;
    });
    await Future<void>.delayed(const Duration(milliseconds: 160));
    widget.session.saveObjectiveEntry();
  }

  void addAttachment(String source) {
    if (widget.session.attachments.length >= maxAttachments) {
      setState(() => error = 'Limite de 3 anexos por envio.');
      return;
    }
    setState(() {
      error = null;
      attachmentMenuOpen = false;
    });
    widget.session.addLabAttachment(source);
  }

  @override
  Widget build(BuildContext context) {
    final remaining = maxFreeText - widget.session.freeText.length;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const StepHeader(step: 3, total: 5, label: 'Entrada pedagógica'),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 576),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Tell us about who is going to study',
                        style: TextStyle(
                          color: simDark,
                          fontSize: 28,
                          height: 1.12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 24),
                      SimCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const CardTitle(
                              icon: Icons.chat_bubble_outline,
                              title: 'What should SIM help with?',
                            ),
                            AttachmentPreviewList(
                              attachments: widget.session.attachments,
                              onRemove: (index) => setState(
                                () => widget.session.removeAttachment(index),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: simBorder),
                              ),
                              child: Stack(
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Campo obrigatório',
                                        style: TextStyle(
                                          color: Colors.black,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.4,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      const Text(
                                        'Escreva o que você quer estudar. Se anexar um arquivo ou foto, explique o que deseja aprender com ele.',
                                        style: TextStyle(
                                          color: simMuted,
                                          fontSize: 13,
                                          height: 1.35,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      TextField(
                                        controller: objectiveController,
                                        minLines: 6,
                                        maxLines: 8,
                                        maxLength: maxFreeText,
                                        decoration: const InputDecoration(
                                          hintText:
                                              'Ex: Quero estudar essa lista para a prova.',
                                          border: InputBorder.none,
                                          counterText: '',
                                          contentPadding: EdgeInsets.only(
                                            bottom: 48,
                                          ),
                                        ),
                                        style: const TextStyle(
                                          color: simDark,
                                          fontSize: 16,
                                          height: 1.4,
                                        ),
                                        onChanged: (value) {
                                          widget.session.setFreeText(value);
                                          if (error ==
                                                  objectiveRequiredMessage ||
                                              error ==
                                                  objectiveRequiredWithAttachmentMessage) {
                                            setState(() => error = null);
                                          } else {
                                            setState(() {});
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                  Positioned(
                                    left: 0,
                                    bottom: 0,
                                    child: IconButton(
                                      tooltip: 'Abrir menu de anexos',
                                      onPressed: () => setState(
                                        () => attachmentMenuOpen =
                                            !attachmentMenuOpen,
                                      ),
                                      icon: const Icon(
                                        Icons.attach_file,
                                        color: simDark,
                                        size: 24,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    right: 4,
                                    bottom: 12,
                                    child: Text(
                                      '${widget.session.freeText.length}/$maxFreeText',
                                      style: const TextStyle(
                                        color: simMuted,
                                        fontSize: 12,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                  ),
                                  if (attachmentMenuOpen)
                                    Positioned(
                                      left: 4,
                                      bottom: 46,
                                      child: AttachmentMenu(
                                        onPick: addAttachment,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Conte do seu jeito: idade, série, matéria, tema, prova, prazo, dificuldade ou foto/lista que precisa estudar.',
                              style: TextStyle(
                                color: simMuted,
                                fontSize: 13,
                                height: 1.35,
                              ),
                            ),
                            if (widget.session.attachments.isNotEmpty &&
                                objectiveTooShort) ...[
                              const SizedBox(height: 8),
                              const Text(
                                objectiveRequiredWithAttachmentMessage,
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                            if (remaining < 0) ...[
                              const SizedBox(height: 6),
                              const Text(
                                'Texto muito longo.',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      SimCard(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const CircleIcon(
                              icon: Icons.person_outline,
                              top: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Preferred name',
                                    style: TextStyle(
                                      color: simDark,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  SimInput(
                                    hint: 'What should SIM call the student?',
                                    controller: nameController,
                                    onChanged: widget.session.setPreferredName,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (error != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          error!,
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 14,
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      GestureDetector(
                        onTap: () {
                          if (!canContinue && !waitingAttachment) {
                            showObjectiveRequired();
                          }
                        },
                        child: SizedBox(
                          width: double.infinity,
                          height: 64,
                          child: DecoratedBox(
                            decoration: primaryButtonDecoration(radius: 16),
                            child: TextButton(
                              onPressed: canContinue ? saveAndContinue : null,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  if (sending)
                                    const Positioned(
                                      left: 16,
                                      child: SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: simDark,
                                        ),
                                      ),
                                    ),
                                  if (!sending &&
                                      !waitingAttachment &&
                                      !objectiveTooShort)
                                    const Positioned(
                                      right: 16,
                                      child: Icon(
                                        Icons.arrow_forward,
                                        color: simDark,
                                      ),
                                    ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 42,
                                    ),
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        sending
                                            ? 'Reading…'
                                            : waitingAttachment
                                            ? 'Aguardando leitura do anexo...'
                                            : objectiveTooShort
                                            ? 'Escreva o objetivo primeiro'
                                            : 'Save and continue',
                                        style: const TextStyle(
                                          color: simDark,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AttachmentPreviewList extends StatelessWidget {
  const AttachmentPreviewList({
    required this.attachments,
    required this.onRemove,
    super.key,
  });

  final List<AttachmentDraft> attachments;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    if (attachments.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (int i = 0; i < attachments.length; i++)
            AttachmentChip(
              attachment: attachments[i],
              onRemove: () => onRemove(i),
            ),
        ],
      ),
    );
  }
}

class AttachmentChip extends StatelessWidget {
  const AttachmentChip({
    required this.attachment,
    required this.onRemove,
    super.key,
  });

  final AttachmentDraft attachment;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final icon = attachment.type.startsWith('image/')
        ? '📷'
        : attachment.type == 'application/pdf'
        ? '📄'
        : '📝';
    final suffix =
        attachment.status == 'uploading' || attachment.status == 'processing'
        ? ' lendo...'
        : attachment.status == 'error'
        ? ' erro'
        : '';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: simBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$icon ${attachment.name}$suffix',
            style: const TextStyle(color: simDark, fontSize: 12),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: onRemove,
            child: const Text(
              '✕',
              style: TextStyle(color: simMuted, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class AttachmentMenu extends StatelessWidget {
  const AttachmentMenu({required this.onPick, super.key});

  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 220,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: simBorder),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33111827),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MenuLine(label: 'Anexar arquivo', onTap: () => onPick('document')),
            MenuLine(label: 'Tirar foto', onTap: () => onPick('camera')),
            MenuLine(label: 'Escolher imagem', onTap: () => onPick('image')),
          ],
        ),
      ),
    );
  }
}

class MenuLine extends StatelessWidget {
  const MenuLine({required this.label, required this.onTap, super.key});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        width: double.infinity,
        height: 44,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              label,
              style: const TextStyle(color: simDark, fontSize: 14),
            ),
          ),
        ),
      ),
    );
  }
}

class PhaseBoundaryScreen extends StatefulWidget {
  const PhaseBoundaryScreen({required this.session, super.key});

  final LabSession session;

  @override
  State<PhaseBoundaryScreen> createState() => _PhaseBoundaryScreenState();
}

class _PhaseBoundaryScreenState extends State<PhaseBoundaryScreen> {
  bool _started = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _launch());
  }

  void _launch() {
    if (_started) return;
    _started = true;
    unawaited(widget.session.launchExperience());
  }

  String _stageLabel(String status) => switch (status) {
        't00_running' => 'Montando currículo...',
        't02_running' => 'Preparando primeira aula...',
        'placement' => 'Preparando nivelamento...',
        'primeira_aula_pronta' => 'Tudo pronto!',
        'erro' => 'Algo deu errado',
        _ => 'Processando ficha...',
      };

  double _progress(String status) => switch (status) {
        'pedido_recebido' => 0.10,
        't00_running' => 0.40,
        't02_running' => 0.70,
        'placement' => 0.85,
        'primeira_aula_pronta' => 1.0,
        _ => 0.05,
      };

  @override
  Widget build(BuildContext context) {
    final status = widget.session.entryStatus;
    final error = widget.session.entryError;
    final isError = status == 'erro';
    final isCredits = error?.toLowerCase().contains('crédito') == true ||
        error?.toLowerCase().contains('credit') == true;

    return Scaffold(
      backgroundColor: simDark,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'SIM',
                style: TextStyle(
                  color: simLight,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 48),
              if (!isError) ...[
                _RobotAvatar(status: status),
                const SizedBox(height: 32),
                Text(
                  _stageLabel(status),
                  style: const TextStyle(
                    color: simLight,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'O aluno não pode ficar preso na porta da escola.',
                  style: TextStyle(
                    color: simMuted,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.05, end: _progress(status)),
                    duration: const Duration(milliseconds: 600),
                    builder: (_, value, __) => LinearProgressIndicator(
                      value: value,
                      minHeight: 6,
                      backgroundColor: simMid,
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(simLight),
                    ),
                  ),
                ),
              ] else ...[
                const SizedBox(height: 40),
                const Icon(Icons.error_outline, color: Color(0xFFF87171), size: 48),
                const SizedBox(height: 20),
                const Text(
                  'Não consegui preparar agora',
                  style: TextStyle(
                    color: simLight,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                if (error != null)
                  Text(
                    error,
                    style: const TextStyle(
                      color: simMuted,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                const SizedBox(height: 32),
                if (isCredits)
                  PrimaryWideButton(
                    label: 'Comprar créditos',
                    onPressed: () => widget.session.openCredits(),
                  )
                else
                  PrimaryWideButton(
                    label: 'Tentar novamente',
                    onPressed: () {
                      _started = false;
                      _launch();
                    },
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RobotAvatar extends StatelessWidget {
  const _RobotAvatar({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final done = status == 'primeira_aula_pronta';
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: done ? simLight : simMid,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(
        done ? Icons.school_rounded : Icons.psychology_alt_rounded,
        color: simDark,
        size: 36,
      ),
    );
  }
}

class PlacementLabScreen extends StatelessWidget {
  const PlacementLabScreen({required this.session, super.key});

  final LabSession session;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const StepHeader(step: 5, total: 5, label: 'Nivelamento'),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: SimCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Você já conhece esse assunto?',
                        style: TextStyle(
                          color: simDark,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        session.placementStarted
                            ? 'Pergunta de nivelamento: escolha a opção que melhor representa seu ponto de partida.'
                            : 'SIM pode começar do zero ou fazer uma pergunta rápida para sugerir o ponto certo.',
                        style: const TextStyle(
                          color: simMuted,
                          fontSize: 15,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 22),
                      if (!session.placementStarted) ...[
                        PrimaryWideButton(
                          label: 'Começar do zero',
                          onTap: session.skipPlacement,
                        ),
                        const SizedBox(height: 12),
                        SecondaryWideButton(
                          label: 'Fazer nivelamento',
                          onTap: session.startPlacement,
                        ),
                      ] else ...[
                        const Text(
                          'Qual alternativa descreve melhor seu conhecimento?',
                          style: TextStyle(
                            color: simDark,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SecondaryWideButton(
                          label: 'A. Domino bem',
                          onTap: session.finishPlacement,
                        ),
                        const SizedBox(height: 8),
                        SecondaryWideButton(
                          label: 'B. Sei uma parte',
                          onTap: session.finishPlacement,
                        ),
                        const SizedBox(height: 8),
                        SecondaryWideButton(
                          label: 'C. Preciso começar guiado',
                          onTap: session.finishPlacement,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _feedbackText(String key) => switch (key) {
  'aula_fb_correct' => 'Exato! Você domina este ponto.',
  'aula_fb_correct_rev' => 'Certo, mas vamos reforçar.',
  'aula_fb_dont_know' => 'Acertou no chute. Vamos revisar com cuidado.',
  'aula_fb_redo' => 'Não foi dessa vez. Vamos tentar de novo.',
  'aula_fb_review_none' => 'Ótimo! Revisão concluída.',
  'aula_fb_review_light' => 'Quase lá. Mais um reforço.',
  'aula_fb_review_heavy' => 'Precisa de mais prática neste ponto.',
  _ => key,
};

String _nextBtnText(String key) => switch (key) {
  'aula_next' => 'Próximo',
  'aula_next_item' => 'Próximo tópico',
  'aula_consolidate' => 'Consolidar',
  'aula_layer_label_2' => 'Próxima camada',
  'aula_layer_label_3' => 'Camada final',
  _ => 'Avançar',
};

String _headerLabelText(String key) {
  if (key.startsWith('aula_item_of:')) {
    final rest = key.substring('aula_item_of:'.length);
    final parts = rest.split(':');
    final fraction = parts.isNotEmpty ? parts[0] : '';
    final layerKey = parts.length > 1 ? parts[1] : '';
    final layer = switch (layerKey) {
      'aula_layer_1' => 'Camada 1',
      'aula_layer_2' => 'Camada 2',
      'aula_layer_3' => 'Camada 3',
      _ => layerKey,
    };
    return 'Item $fraction · $layer';
  }
  if (key.startsWith('aula_review_review:')) return 'Revisão';
  return key;
}

class AulaLabScreen extends StatefulWidget {
  const AulaLabScreen({required this.session, super.key});

  final LabSession session;

  @override
  State<AulaLabScreen> createState() => _AulaLabScreenState();
}

class _AulaLabScreenState extends State<AulaLabScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _doubtController = TextEditingController();
  int _lastHistoryLen = 0;
  bool _lastHasContent = false;

  @override
  void dispose() {
    _scrollController.dispose();
    _doubtController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final snapshot = session.aulaSnapshot;
    final phase = snapshot?.phase;
    final content = snapshot?.conteudo;
    final history = snapshot?.history ?? const <QuestionHistoryEntry>[];
    final viewModel = snapshot?.viewModel;
    final selected = phase?.letter;
    final isExpanded = phase?.type == ClassroomPhaseType.expandida;
    final isProcessing = phase?.type == ClassroomPhaseType.processando;
    final isCompleted = phase?.type == ClassroomPhaseType.concluido;
    final isEngineError = phase?.type == ClassroomPhaseType.erroEngine;
    final isDone = snapshot?.isDone ?? false;
    final wasCorrect = phase?.wasCorrect;
    final feedbackKey = phase?.message;
    final nextKey = viewModel?.nextLabel ?? '';
    final locked = viewModel?.locked ?? false;

    // Auto-scroll when new history or content arrives
    final hasContent = content != null;
    if (history.length != _lastHistoryLen || hasContent != _lastHasContent) {
      _lastHistoryLen = history.length;
      _lastHasContent = hasContent;
      _scrollToBottom();
    }

    if (isDone) {
      return _LessonDoneScreen(session: session);
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            AulaTopBar(session: session, doubtEnabled: isCompleted),
            if (viewModel != null)
              SizedBox(
                height: 4,
                child: LinearProgressIndicator(
                  value: viewModel.progress / 100,
                  backgroundColor: simLight,
                  valueColor: const AlwaysStoppedAnimation<Color>(simDark),
                ),
              ),
            Expanded(
              child: ListView(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
                children: [
                  // Past answered questions — dimmed, non-interactive
                  for (final entry in history)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Opacity(
                        opacity: 0.6,
                        child: IgnorePointer(child: _QuestionHistoryBlock(entry: entry)),
                      ),
                    ),

                  // Active content card
                  if (session.aulaRuntimeLoading && content == null) ...[
                    const SizedBox(height: 20),
                    const StatusLine(
                      icon: Icons.auto_awesome_outlined,
                      text: 'Preparando sua aula...',
                      loading: true,
                    ),
                    if (session.aulaRuntimeError != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        session.aulaRuntimeError!,
                        style: const TextStyle(color: simDark, fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 12),
                      SecondaryWideButton(
                        label: 'Tentar novamente',
                        onTap: () => unawaited(session.openAulaRuntime()),
                      ),
                    ],
                  ] else if (content != null) ...[
                    SimCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (viewModel != null) ...[
                            Text(
                              _headerLabelText(viewModel.headerLabel),
                              style: const TextStyle(color: simMuted, fontSize: 12),
                            ),
                            const SizedBox(height: 8),
                          ],
                          Text(
                            content.explanation,
                            style: const TextStyle(color: simDark, fontSize: 15, height: 1.45),
                          ),
                          const SizedBox(height: 12),
                          LessonImagePanel(session: session),
                          if (session.audioLoading) ...[
                            const SizedBox(height: 8),
                            const StatusLine(
                              icon: Icons.volume_up_outlined,
                              text: 'Carregando áudio...',
                              loading: true,
                            ),
                          ] else if (session.audioError != null) ...[
                            const SizedBox(height: 8),
                            StatusLine(icon: Icons.volume_off_outlined, text: session.audioError!),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Active question block
                    SimCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            content.question,
                            style: const TextStyle(color: simDark, fontSize: 15, height: 1.4, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 10),
                          AnswerButton(
                            label: 'A',
                            text: content.options[AnswerLetter.A] ?? '',
                            active: selected == AnswerLetter.A,
                            onTap: locked ? () {} : () => session.chooseAulaAnswer('A'),
                          ),
                          AnswerButton(
                            label: 'B',
                            text: content.options[AnswerLetter.B] ?? '',
                            active: selected == AnswerLetter.B,
                            onTap: locked ? () {} : () => session.chooseAulaAnswer('B'),
                          ),
                          AnswerButton(
                            label: 'C',
                            text: content.options[AnswerLetter.C] ?? '',
                            active: selected == AnswerLetter.C,
                            onTap: locked ? () {} : () => session.chooseAulaAnswer('C'),
                          ),

                          // Sinal 1/2/3 — appears after A/B/C selection
                          if (isExpanded) ...[
                            const SizedBox(height: 14),
                            const Text(
                              'Como ficou para você?',
                              style: TextStyle(color: simDark, fontSize: 14, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 8),
                            _SinalBtn(n: 1, label: 'Sei', onTap: () => session.submitAulaSignal(1)),
                            const SizedBox(height: 6),
                            _SinalBtn(n: 2, label: 'Quase', onTap: () => session.submitAulaSignal(2)),
                            const SizedBox(height: 6),
                            _SinalBtn(n: 3, label: 'Não sei', onTap: () => session.submitAulaSignal(3)),
                          ],

                          if (isProcessing) ...[
                            const SizedBox(height: 14),
                            const StatusLine(
                              icon: Icons.auto_awesome_outlined,
                              text: 'Registrando...',
                              loading: true,
                            ),
                          ],
                        ],
                      ),
                    ),

                    // FeedbackBox + Próximo
                    if (isCompleted && feedbackKey != null) ...[
                      const SizedBox(height: 10),
                      _FeedbackBox(
                        isCorrect: wasCorrect ?? false,
                        message: _feedbackText(feedbackKey),
                      ),
                      const SizedBox(height: 10),
                      PrimaryWideButton(
                        label: _nextBtnText(nextKey),
                        onTap: () => unawaited(session.advanceAula()),
                      ),
                    ],
                  ] else if (isEngineError && phase?.message != null) ...[
                    const SizedBox(height: 12),
                    SimCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(phase!.message!, style: const TextStyle(color: simDark, fontSize: 14, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 12),
                          SecondaryWideButton(
                            label: 'Tentar novamente',
                            onTap: () => unawaited(session.openAulaRuntime()),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // DoubtInputSheet (inline, only when phase=concluido)
                  if (session.doubtOpen && isCompleted) ...[
                    const SizedBox(height: 10),
                    _DoubtInputSheet(
                      controller: _doubtController,
                      onSubmit: (_) {
                        session.toggleDoubt();
                        _doubtController.clear();
                      },
                      onClose: session.toggleDoubt,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      // FixedBubble — pulsa enquanto áudio toca
      bottomSheet: (session.audioEnabled && session.audioPlaying)
          ? const _FixedBubble()
          : null,
    );
  }
}

class _QuestionHistoryBlock extends StatelessWidget {
  const _QuestionHistoryBlock({required this.entry});

  final QuestionHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    return SimCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            entry.text,
            style: const TextStyle(color: simDark, fontSize: 14, height: 1.4, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          for (final opt in entry.options)
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: opt.id == entry.chosenOptionId
                    ? (entry.correct ? simSuccess.withAlpha(25) : simWarn.withAlpha(25))
                    : simLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: opt.id == entry.chosenOptionId
                      ? (entry.correct ? simSuccess : simWarn)
                      : simBorder,
                ),
              ),
              child: Row(
                children: [
                  Text(
                    opt.id.name,
                    style: const TextStyle(color: simDark, fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(opt.text, style: const TextStyle(color: simDark, fontSize: 13))),
                  if (opt.id == entry.chosenOptionId)
                    Icon(
                      entry.correct ? Icons.check_circle_outline : Icons.cancel_outlined,
                      size: 16,
                      color: entry.correct ? simSuccess : simWarn,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _FeedbackBox extends StatelessWidget {
  const _FeedbackBox({required this.isCorrect, required this.message});

  final bool isCorrect;
  final String message;

  @override
  Widget build(BuildContext context) {
    final color = isCorrect ? simSuccess : simWarn;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(100)),
      ),
      child: Row(
        children: [
          Icon(
            isCorrect ? Icons.check_circle_outline : Icons.cancel_outlined,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _SinalBtn extends StatelessWidget {
  const _SinalBtn({required this.n, required this.label, required this.onTap});

  final int n;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: simDark,
          side: const BorderSide(color: simBorder),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          alignment: Alignment.centerLeft,
        ),
        child: Row(
          children: [
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: simDark,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '$n',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12),
              ),
            ),
            const SizedBox(width: 12),
            Text(label, style: const TextStyle(color: simDark, fontSize: 15, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _FixedBubble extends StatefulWidget {
  const _FixedBubble();

  @override
  State<_FixedBubble> createState() => _FixedBubbleState();
}

class _FixedBubbleState extends State<_FixedBubble> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      color: Colors.transparent,
      alignment: Alignment.center,
      child: ScaleTransition(
        scale: _anim,
        child: Container(
          width: 34,
          height: 34,
          decoration: const BoxDecoration(color: simDark, shape: BoxShape.circle),
          child: const Icon(Icons.volume_up, color: Colors.white, size: 16),
        ),
      ),
    );
  }
}

class _DoubtInputSheet extends StatelessWidget {
  const _DoubtInputSheet({
    required this.controller,
    required this.onSubmit,
    required this.onClose,
  });

  final TextEditingController controller;
  final void Function(String text) onSubmit;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: simBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Dúvida', style: TextStyle(color: simDark, fontSize: 16, fontWeight: FontWeight.w700)),
              const Spacer(),
              GestureDetector(
                onTap: onClose,
                child: const Icon(Icons.close, size: 20, color: simMuted),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: controller,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Escreva sua dúvida...',
              hintStyle: TextStyle(color: simMuted, fontSize: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
              contentPadding: EdgeInsets.all(12),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.photo_camera_outlined, size: 16, color: simMuted),
              const SizedBox(width: 6),
              const Text('Foto (em breve)', style: TextStyle(color: simMuted, fontSize: 12)),
              const Spacer(),
              OutlinedButton(
                onPressed: () {
                  final text = controller.text.trim();
                  if (text.isNotEmpty) onSubmit(text);
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: simDark,
                  side: const BorderSide(color: simDark),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                child: const Text('Enviar', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LessonDoneScreen extends StatelessWidget {
  const _LessonDoneScreen({required this.session});

  final LabSession session;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              const Icon(Icons.emoji_events_outlined, size: 64, color: simDark),
              const SizedBox(height: 20),
              const Text(
                'Aula concluída!',
                style: TextStyle(color: simDark, fontSize: 26, fontWeight: FontWeight.w800),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              const Text(
                'Parabéns! Você concluiu todos os itens desta aula.',
                style: TextStyle(color: simMuted, fontSize: 16, height: 1.4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              PrimaryWideButton(
                label: 'Voltar ao início',
                onTap: () => session.openSupport('/cyber/objeto'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AuxRoomCard extends StatelessWidget {
  const AuxRoomCard({required this.title, required this.body, super.key});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return SimCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: simDark,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: const TextStyle(color: simMuted, fontSize: 14, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class AulaTopBar extends StatelessWidget {
  const AulaTopBar({required this.session, this.doubtEnabled = false, super.key});

  final LabSession session;
  final bool doubtEnabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: simBorder)),
      ),
      child: Row(
        children: [
          RoundIconButton(
            icon: Icons.menu,
            tooltip: 'Menu',
            onTap: () => showAulaMenu(context, session),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              session.stableLang ?? 'SIM',
              style: const TextStyle(
                color: simDark,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Opacity(
            opacity: doubtEnabled ? 1.0 : 0.35,
            child: RoundIconButton(
              icon: Icons.help_outline,
              tooltip: 'Dúvida',
              onTap: doubtEnabled ? session.toggleDoubt : () {},
            ),
          ),
          const SizedBox(width: 8),
          RoundIconButton(
            icon: session.audioEnabled
                ? Icons.volume_up_outlined
                : Icons.volume_off_outlined,
            tooltip: 'Áudio',
            onTap: session.toggleAudio,
          ),
        ],
      ),
    );
  }
}

class LessonImagePanel extends StatelessWidget {
  const LessonImagePanel({required this.session, super.key});

  final LabSession session;

  @override
  Widget build(BuildContext context) {
    final loading = session.imageStatus == 'loading';
    final ready = session.imageStatus == 'ready';
    return Container(
      height: 168,
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: simLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: simBorder),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (loading)
            const SizedBox(
              width: 34,
              height: 34,
              child: CircularProgressIndicator(strokeWidth: 2, color: simDark),
            )
          else if (ready)
            const Icon(Icons.image, size: 46, color: simDark)
          else
            const Icon(Icons.image_outlined, size: 46, color: simMuted),
          const SizedBox(height: 10),
          Text(
            loading
                ? 'Gerando imagem da aula...'
                : ready
                ? 'Imagem da aula pronta'
                : 'Imagem da aula',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: simDark,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 32,
            child: OutlinedButton.icon(
              onPressed: loading ? null : session.requestLessonImage,
              icon: const Icon(Icons.auto_awesome, size: 16),
              label: Text(ready ? 'Gerar novamente' : 'Gerar imagem'),
              style: OutlinedButton.styleFrom(
                foregroundColor: simDark,
                side: const BorderSide(color: simBorder),
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class StatusLine extends StatelessWidget {
  const StatusLine({
    required this.icon,
    required this.text,
    this.loading = false,
    super.key,
  });

  final IconData icon;
  final String text;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (loading)
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: simDark),
          )
        else
          Icon(icon, size: 16, color: simMuted),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: simMuted, fontSize: 13, height: 1.35),
          ),
        ),
      ],
    );
  }
}

class CreditsLabScreen extends StatelessWidget {
  const CreditsLabScreen({required this.session, super.key});

  final LabSession session;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: SimCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Créditos',
                  style: TextStyle(
                    color: simDark,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Saldo atual: ${session.credits}',
                  style: const TextStyle(color: simMuted, fontSize: 15),
                ),
                const SizedBox(height: 18),
                CreditPackButton(
                  title: '100 créditos',
                  subtitle: 'Aulas e uso básico',
                  onTap: session.openCheckoutReturn,
                ),
                CreditPackButton(
                  title: '200 créditos',
                  subtitle: 'Mais aulas e imagem quando disponível',
                  onTap: session.openCheckoutReturn,
                ),
                CreditPackButton(
                  title: '500 créditos',
                  subtitle: 'Uso prolongado do SIM',
                  onTap: session.openCheckoutReturn,
                ),
                const SizedBox(height: 16),
                PrimaryWideButton(
                  label: 'Voltar para aula',
                  onTap: () => session.openSupport('/cyber/aula'),
                ),
                const SizedBox(height: 10),
                SecondaryWideButton(label: 'Portal', onTap: session.goPortal),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CreditPackButton extends StatelessWidget {
  const CreditPackButton({
    required this.title,
    required this.subtitle,
    required this.onTap,
    super.key,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: simDark,
          side: const BorderSide(color: simBorder),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.all(14),
        ),
        child: Row(
          children: [
            const Icon(Icons.credit_card, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(color: simMuted, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CheckoutReturnScreen extends StatelessWidget {
  const CheckoutReturnScreen({required this.session, super.key});

  final LabSession session;

  @override
  Widget build(BuildContext context) {
    return SimpleLabPage(
      title: 'Retorno do pagamento',
      body:
          'O pagamento volta para o SIM, valida a sessão do checkout e devolve o aluno para a aula ou para tentar novamente.',
      primary: 'Continuar aula',
      onPrimary: () => session.openSupport('/cyber/aula'),
      session: session,
      secondary: 'Tentar de novo',
      onSecondary: session.openCredits,
    );
  }
}

class FatherLabScreen extends StatelessWidget {
  const FatherLabScreen({required this.session, super.key});

  final LabSession session;

  @override
  Widget build(BuildContext context) {
    return SimpleLabPage(
      title: 'Painel do Pai',
      body:
          'Resumo vivo: idioma ${session.stableLang ?? '-'}, objetivo ${session.freeText.isEmpty ? '-' : session.freeText}, avanço ${session.aulaStep}.',
      primary: 'Voltar',
      onPrimary: () => session.openSupport('/cyber/aula'),
      session: session,
    );
  }
}

class LegalLabScreen extends StatelessWidget {
  const LegalLabScreen({required this.session, required this.title, super.key});

  final LabSession session;
  final String title;

  @override
  Widget build(BuildContext context) {
    return SimpleLabPage(
      title: title,
      body: title == 'Privacidade'
          ? 'Página de privacidade preservada como ambiente de apoio do SIM.'
          : 'Página de termos preservada como ambiente de apoio do SIM.',
      primary: 'Voltar',
      onPrimary: () => session.openSupport('/cyber/aula'),
      session: session,
    );
  }
}

class DeleteAccountLabScreen extends StatelessWidget {
  const DeleteAccountLabScreen({required this.session, super.key});

  final LabSession session;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: SimCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Solicitar exclusão da conta',
                  style: TextStyle(
                    color: simDark,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Digite DELETAR para registrar a solicitação de exclusão. A execução real acontece no servidor, sem chave secreta dentro do app.',
                  style: TextStyle(color: simMuted, fontSize: 15, height: 1.45),
                ),
                const SizedBox(height: 16),
                SimInput(
                  hint: 'DELETAR',
                  onChanged: session.setDeleteConfirmation,
                ),
                if (session.accountDeletionMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    session.accountDeletionMessage!,
                    style: const TextStyle(
                      color: simDark,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                PrimaryWideButton(
                  label: 'Solicitar exclusão da conta',
                  onTap: session.requestAccountDeletion,
                ),
                const SizedBox(height: 10),
                SecondaryWideButton(
                  label: 'Voltar',
                  onTap: () => session.openSupport('/cyber/aula'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SimpleLabPage extends StatelessWidget {
  const SimpleLabPage({
    required this.title,
    required this.body,
    required this.primary,
    required this.onPrimary,
    required this.session,
    this.secondary,
    this.onSecondary,
    super.key,
  });

  final String title;
  final String body;
  final String primary;
  final VoidCallback onPrimary;
  final LabSession session;
  final String? secondary;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SimCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: simDark,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    body,
                    style: const TextStyle(
                      color: simMuted,
                      fontSize: 15,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 20),
                  PrimaryWideButton(label: primary, onTap: onPrimary),
                  const SizedBox(height: 10),
                  if (secondary != null && onSecondary != null) ...[
                    SecondaryWideButton(label: secondary!, onTap: onSecondary!),
                    const SizedBox(height: 10),
                  ],
                  SecondaryWideButton(label: 'Portal', onTap: session.goPortal),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PrimaryWideButton extends StatelessWidget {
  const PrimaryWideButton({
    required this.label,
    required this.onTap,
    super.key,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: DecoratedBox(
        decoration: primaryButtonDecoration(radius: 14),
        child: TextButton(
          onPressed: onTap,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: simDark,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class SecondaryWideButton extends StatelessWidget {
  const SecondaryWideButton({
    required this.label,
    required this.onTap,
    super.key,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: simDark,
          side: const BorderSide(color: simBorder),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class AnswerButton extends StatelessWidget {
  const AnswerButton({
    required this.label,
    required this.text,
    required this.active,
    required this.onTap,
    super.key,
  });

  final String label;
  final String text;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: active ? simLight : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: active ? simDark : simBorder),
          ),
          child: Text(
            '$label. $text',
            style: const TextStyle(
              color: simDark,
              fontSize: 14.5,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

void showAulaMenu(BuildContext context, LabSession session) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (context) => Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          MenuLine(
            label: 'Recarregar créditos',
            onTap: () {
              Navigator.pop(context);
              session.openCredits();
            },
          ),
          MenuLine(
            label: 'Painel do Pai',
            onTap: () {
              Navigator.pop(context);
              session.openSupport('/pai');
            },
          ),
          MenuLine(
            label: 'Privacidade',
            onTap: () {
              Navigator.pop(context);
              session.openSupport('/privacidade');
            },
          ),
          MenuLine(
            label: 'Termos',
            onTap: () {
              Navigator.pop(context);
              session.openSupport('/termos');
            },
          ),
          MenuLine(
            label: 'Solicitar exclusão da conta',
            onTap: () {
              Navigator.pop(context);
              session.openSupport('/conta/deletar');
            },
          ),
        ],
      ),
    ),
  );
}

class SupportedLang {
  const SupportedLang({
    required this.code,
    required this.name,
    required this.native,
    required this.flag,
  });
  final String code;
  final String name;
  final String native;
  final String flag;
}

const supportedLangs = <SupportedLang>[
  SupportedLang(code: 'en', name: 'English', native: 'English', flag: '🇺🇸'),
  SupportedLang(
    code: 'pt',
    name: 'Portuguese',
    native: 'Português',
    flag: '🇧🇷',
  ),
  SupportedLang(code: 'es', name: 'Spanish', native: 'Español', flag: '🇪🇸'),
  SupportedLang(code: 'fr', name: 'French', native: 'Français', flag: '🇫🇷'),
  SupportedLang(code: 'ja', name: 'Japanese', native: '日本語', flag: '🇯🇵'),
];

class LanguageButton extends StatelessWidget {
  const LanguageButton({
    required this.language,
    required this.active,
    required this.onTap,
    super.key,
  });

  final SupportedLang language;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = language.native.isEmpty
        ? language.name
        : '${language.name} · ${language.native}';
    return SizedBox(
      width: double.infinity,
      height: 64,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: active ? simLight : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: simBorder),
          boxShadow: active
              ? const [
                  BoxShadow(
                    color: Color(0x22111827),
                    blurRadius: 18,
                    offset: Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(
            foregroundColor: simDark,
            alignment: Alignment.centerLeft,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: Row(
            children: [
              Text(language.flag, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StepHeader extends StatelessWidget {
  const StepHeader({
    required this.step,
    required this.total,
    required this.label,
    super.key,
  });

  final int step;
  final int total;
  final String label;

  @override
  Widget build(BuildContext context) {
    final pct = step / total;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 8,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: simBorder),
              ),
              clipBehavior: Clip.antiAlias,
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: pct,
                  child: Container(color: simLight),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(
              color: simMuted,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class SimInput extends StatelessWidget {
  const SimInput({
    required this.hint,
    required this.onChanged,
    this.controller,
    this.obscureText = false,
    this.keyboardType,
    super.key,
  });

  final String hint;
  final TextEditingController? controller;
  final bool obscureText;
  final TextInputType? keyboardType;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: simBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: simDark),
        ),
      ),
    );
  }
}

class SimCard extends StatelessWidget {
  const SimCard({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: simBorder),
      ),
      child: child,
    );
  }
}

class CardTitle extends StatelessWidget {
  const CardTitle({required this.icon, required this.title, super.key});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          CircleIcon(icon: icon),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: simDark,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CircleIcon extends StatelessWidget {
  const CircleIcon({required this.icon, this.top = 0, super.key});

  final IconData icon;
  final double top;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: top),
      child: Container(
        width: 32,
        height: 32,
        decoration: const BoxDecoration(
          color: simLight,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: simDark, size: 18),
      ),
    );
  }
}

class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: simBorder),
          ),
          child: Icon(icon, color: simDark, size: 22),
        ),
      ),
    );
  }
}

class CreditsPill extends StatelessWidget {
  const CreditsPill({required this.value, required this.onTap, super.key});

  final int value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: pillDecoration(),
        child: Row(
          children: [
            const Icon(Icons.link, color: simDark, size: 17),
            const SizedBox(width: 8),
            Text(
              '$value',
              style: const TextStyle(
                color: simDark,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BackgroundDecor extends StatelessWidget {
  const BackgroundDecor({super.key});

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white, simLight, Colors.white],
          stops: [0, 0.6, 1],
        ),
      ),
      child: SizedBox.expand(),
    );
  }
}

BoxDecoration glassDecoration({required double radius}) {
  return BoxDecoration(
    color: Colors.white.withAlpha(217),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: Colors.white),
    boxShadow: const [
      BoxShadow(
        color: Color(0x2E111827),
        blurRadius: 60,
        offset: Offset(0, 30),
      ),
      BoxShadow(
        color: Color(0x2E243447),
        blurRadius: 30,
        offset: Offset(0, 10),
      ),
    ],
  );
}

BoxDecoration pillDecoration() {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(999),
    border: Border.all(color: simBorder),
    boxShadow: const [
      BoxShadow(color: Color(0x2E243447), blurRadius: 14, offset: Offset(0, 4)),
    ],
  );
}

BoxDecoration primaryButtonDecoration({required double radius}) {
  return BoxDecoration(
    gradient: const LinearGradient(
      colors: [Colors.white, simLight],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: simBorder),
    boxShadow: const [
      BoxShadow(
        color: Color(0x33111827),
        blurRadius: 28,
        offset: Offset(0, 12),
      ),
    ],
  );
}
