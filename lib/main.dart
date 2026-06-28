import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'sim/billing/sim_server_billing_clients.dart';
import 'sim/cloud/sim_server_cloud_functions.dart';
import 'sim/cloud/supabase_flutter_session_provider.dart';
import 'sim/cloud/supabase_student_state_cloud_storage.dart';
import 'sim/config/sim_environment.dart';
import 'sim/external_ai/sim_ai_server_config.dart';
import 'sim/external_ai/sim_server_ai_clients.dart';
import 'sim/external_ai/sim_server_attachment_client.dart';
import 'sim/classroom/classroom_models.dart';
import 'sim/classroom/lesson_runtime_engine.dart';
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
import 'sim/ui/sim_i18n.dart';
import 'sim/ui/widgets/cyber_step_shell.dart';
import 'sim/ui/widgets/sim_preparation_experience.dart';
import 'sim/ui/widgets/sim_typewriter.dart';
import 'sim/auxiliary/aux_room_models.dart';
import 'sim/ui/widgets/doubt_progress_bar.dart';

const simSupabaseUrl = 'https://qxzwcldfowyqhyikyxcy.supabase.co';
const simSupabaseAnonKey =
    'sb_publishable_-b8arZ8aKEbwU6FEpXAhqg_6bXycrgQ';
const simAuthRedirectUrl = 'sim-mobile://login-callback';
const simApiBaseUrl = SimEnvironment.apiBaseUrl;

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

// §1 tokens globais — hex exatos do SIM Web (src/styles.css :root)
const simDark = Color(0xFF111827);      // foreground / primary
const simMid = Color(0xFF374151);       // success / primary_glow
const simLight = Color(0xFFF3F4F6);    // secondary / muted / accent
const simCard = Color(0xFFF9FAFB);     // card background
const simMuted = Color(0xFF6B7280);    // muted_foreground / warn
const simBorder = Color(0xFFD1D5DB);   // border / input
const simDestructive = Color(0xFF000000);   // destructive (preto)
const simDestructiveFg = Color(0xFFFFFFFF); // destructive_fg
const simSuccess = Color(0xFF374151);  // success = #374151 (cinza-escuro)
const simWarn = Color(0xFF6B7280);     // warn = #6B7280 (cinza-médio)

// gradient_primary: LinearGradient 135° #FFFFFF → #F3F4F6 ("papel premium")
const simGradientPrimary = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFFFFFFFF), Color(0xFFF3F4F6)],
);
// gradient_bg: LinearGradient 180° #FFFFFF → #F3F4F6
const simGradientBg = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [Color(0xFFFFFFFF), Color(0xFFF3F4F6)],
);

// shadow helpers
const simShadowGlow = [
  BoxShadow(
    color: Color(0xFFFFFFFF),
    offset: Offset(0, 1),
    blurRadius: 0,
  ),
  BoxShadow(
    color: Color(0x2E111827),
    offset: Offset(0, 6),
    blurRadius: 18,
    spreadRadius: -10,
  ),
];
const simShadowFloat = [
  BoxShadow(
    color: Color(0x40111827),
    offset: Offset(0, 10),
    blurRadius: 30,
    spreadRadius: -18,
  ),
];

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
    SharedPreferences? prefs,
  }) : // ignore: prefer_initializing_formals — param nomeado 'prefs' não pode ser 'this._prefs'
       _prefs = prefs,
       canonicalStore =
           canonicalStore ??
           StudentStateStore(local: MemoryStudentStateLocalStorage()) {
    entryForm.addListener(_notifyFromChild);
    authSession.addListener(_notifyFromChild);
    navigationState.addListener(_notifyFromChild);
    lessonUiState.addListener(_notifyFromChild);
  }

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
    onAuthenticated: _onAuthenticated,
  );

  late final SimOrganismProvider simOrganismProvider = SimOrganismProvider(
    canonicalStore: canonicalStore!,
    aiConfig: _serverConfig(),
    prefs: _prefs!,
  );
  SimOrganism? _activeOrganism;
  LessonRuntimeSnapshot? aulaSnapshot;
  bool aulaRuntimeLoading = false;
  String? aulaRuntimeError;

  bool _creditsLoaded = false;

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

  ReviewRoomView? get reviewRoom => lessonUiState.reviewRoom;
  RecoveryRoomView? get recoveryRoom => lessonUiState.recoveryRoom;
  DoubtState get doubt => lessonUiState.doubt;

  void setDoubt(DoubtState s) => lessonUiState.setDoubt(s);
  void resetDoubt() => lessonUiState.resetDoubt();
  void openReviewRoom() => lessonUiState.openReviewRoom();
  void closeReviewRoom() => lessonUiState.closeReviewRoom();
  void setReviewRoom(ReviewRoomView v) => lessonUiState.setReviewRoom(v);
  void openRecoveryRoom() => lessonUiState.openRecoveryRoom();
  void closeRecoveryRoom() => lessonUiState.closeRecoveryRoom();
  void setRecoveryRoom(RecoveryRoomView v) => lessonUiState.setRecoveryRoom(v);

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

  Future<void> _warmUpServer() async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 8);
      final req = await client
          .getUrl(Uri.parse('$simApiBaseUrl/health'))
          .timeout(const Duration(seconds: 8));
      final res = await req.close().timeout(const Duration(seconds: 8));
      await res.drain<void>();
      client.close();
    } catch (_) {}
  }

  void start() {
    if (!authed) {
      debugPrint('[SIM] BLOCKED reason=not_authed');
      goLogin(target: '/');
      return;
    }
    if (_creditsLoaded && credits <= 0) {
      debugPrint('[SIM] BLOCKED reason=credits_zero');
      openCredits();
      return;
    }
    unawaited(_warmUpServer());
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
        entryStatus == 'primeira_aula_pronta') {
      return;
    }

    entryStatus = 't00_running';
    entryError = null;
    notifyListeners();

    try {
      debugPrint('[SIM] T00_STARTED lessonLocalId=$id');
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
        'target_topic': freeText.trim(),
        'TARGET_TOPIC': freeText.trim(),
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
      debugPrint('[SIM] CLASSROOM_OPENED route=${result.destination}');
      navigationState.openRoute(result.destination);
      if (result.destination == '/cyber/aula') {
        unawaited(openAulaRuntime());
      }
    } on StudentExperienceEngineException catch (err) {
      debugPrint('[SIM] BLOCKED reason=${err.error.message}');
      entryError = err.error.message;
      entryStatus = 'erro';
      notifyListeners();
    } catch (err) {
      debugPrint('[SIM] BLOCKED reason=${err.toString()}');
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

  void _onAuthenticated() {
    _loadCreditsFromServer();
    _hydrateActiveLessonFromCloud();
  }

  void _loadCreditsFromServer() {
    authSession.credits = 1;
    _creditsLoaded = false;
    unawaited(
      SimServerCreditsClient(config: _serverConfig())
          .getMyCredits()
          .then((snapshot) {
            authSession.credits = snapshot.balance;
            _creditsLoaded = true;
            notifyListeners();
          })
          .catchError((_) {
            _creditsLoaded = false;
          }),
    );
  }

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
      t00Path: '/api/bootstrap-t00',
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
    this.prefs,
  });

  final StudentStateStore? canonicalStore;
  final LabSession? initialSession;
  final SharedPreferences? prefs;

  @override
  State<SimMobileApp> createState() => _SimMobileAppState();
}

class _SimMobileAppState extends State<SimMobileApp> {
  late final LabSession session =
      widget.initialSession ??
      LabSession(
        canonicalStore: widget.canonicalStore,
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
        textTheme: GoogleFonts.interTextTheme(),
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
                        fontFamily: GoogleFonts.jetBrainsMono().fontFamily,
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
                            fontFamily: GoogleFonts.jetBrainsMono().fontFamily,
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
    _showSimDrawer(context, session: session, body: (ctx) => _PortalDrawerBody(session: session, ctx: ctx));
  }
}

class _PortalDrawerBody extends StatelessWidget {
  const _PortalDrawerBody({required this.session, required this.ctx});

  final LabSession session;
  final BuildContext ctx;

  @override
  Widget build(BuildContext context) {
    void close() => Navigator.of(ctx).pop();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        MenuLine(
          label: 'Abrir aula',
          onTap: () { close(); session.openSupport('/cyber/aula'); },
        ),
        MenuLine(
          label: t('recarregar_creditos'),
          onTap: () { close(); session.openCredits(); },
        ),
        MenuLine(
          label: 'Painel do Pai',
          onTap: () { close(); session.openSupport('/pai'); },
        ),
        MenuLine(
          label: 'Privacidade',
          onTap: () { close(); session.openSupport('/privacidade'); },
        ),
        MenuLine(
          label: 'Termos',
          onTap: () { close(); session.openSupport('/termos'); },
        ),
        MenuLine(
          label: 'Solicitar exclusão da conta',
          onTap: () { close(); session.openSupport('/conta/deletar'); },
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
          // §3.3(b) título SIM
          const Text(
            'SIM',
            style: TextStyle(
              color: simDark,
              fontSize: 68,
              height: 1,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.36, // -0.02em de 68px
            ),
          ),
          // §3.3(c) tagline
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 32,
                child: Divider(color: simMid, thickness: 1),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  t('portal_tagline'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: simDark,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const SizedBox(
                width: 32,
                child: Divider(color: simMid, thickness: 1),
              ),
            ],
          ),
          // §3.3(d) parágrafo institucional
          const SizedBox(height: 24),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 34 * 9.5),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: '${t('portal_statement_p1')} '),
                  TextSpan(
                    text: t('portal_statement_real_learning'),
                    style: const TextStyle(
                      color: simDark,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextSpan(text: '${t('portal_statement_p2')}'),
                  TextSpan(text: '${t('portal_statement_p3')} '),
                  TextSpan(
                    text: t('portal_statement_real_progress'),
                    style: const TextStyle(
                      color: simDark,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const TextSpan(text: '.'),
                ],
              ),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: simMuted,
                fontSize: 15.5,
                height: 1.55,
              ),
            ),
          ),
          // §3.3(e) botão principal
          const SizedBox(height: 32),
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
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Mini círculo branco 36×36 com ícone Play
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: simBorder),
                      ),
                      child: const Icon(
                        Icons.play_arrow,
                        size: 16,
                        color: simDark,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      session.authed ? t('portal_btn_start') : t('portal_btn_signin'),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: simDark,
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
                      t('portal_help_title'),
                      style: const TextStyle(
                        color: simDark,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      t('portal_help_body'),
                      style: const TextStyle(
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
                fontFamily: GoogleFonts.jetBrainsMono().fontFamily,
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
                  // §4.1 Logo
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: simBorder),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x52111827),
                          blurRadius: 24,
                          spreadRadius: -18,
                          offset: Offset(0, 10),
                        ),
                      ],
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
                  Text(
                    signup ? 'CREATE ACCOUNT' : 'SIGN IN',
                    style: TextStyle(
                      color: simMuted,
                      fontSize: 12,
                      fontFamily: GoogleFonts.jetBrainsMono().fontFamily,
                      letterSpacing: 0.25 * 12,
                    ),
                  ),
                  const SizedBox(height: 32),
                  // §4.2 Glass card — bg card #F9FAFB, border, radius 18
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: simCard,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: simBorder),
                      boxShadow: simShadowGlow,
                    ),
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
                                  fontFamily: GoogleFonts.jetBrainsMono().fontFamily,
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
                              fontWeight: FontWeight.w500,
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
                                color: Color(0xFFE53E3E),
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
                        fontFamily: GoogleFonts.jetBrainsMono().fontFamily,
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
                            fontFamily: GoogleFonts.jetBrainsMono().fontFamily,
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
                            fontFamily: GoogleFonts.jetBrainsMono().fontFamily,
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
                      fontFamily: GoogleFonts.jetBrainsMono().fontFamily,
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

class IdiomaScreen extends StatefulWidget {
  const IdiomaScreen({required this.session, super.key});

  final LabSession session;

  @override
  State<IdiomaScreen> createState() => _IdiomaScreenState();
}

class _IdiomaScreenState extends State<IdiomaScreen> {
  void _pick(String code, String name) {
    if (code == 'other') {
      widget.session.chooseLanguage(code, widget.session.otherLanguage.trim());
    } else {
      widget.session.chooseLanguage(code, name);
      Future.delayed(const Duration(milliseconds: 160), () {
        if (mounted) {
          // navigation is handled by session state change — just trigger it
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    return CyberStepShell(
      step: 1,
      total: 5,
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
              onTap: () => _pick(language.code, language.name),
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
            onTap: () => _pick('other', session.otherLanguage.trim()),
          ),
          if (session.selectedLanguageCode == 'other') ...[
            const SizedBox(height: 20),
            OtherLanguageBox(session: session),
          ],
        ],
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
    return CyberStepShell(
      step: 3,
      total: 5,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t('objeto_h1'),
            style: const TextStyle(
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
                                        fontFamily: GoogleFonts.jetBrainsMono().fontFamily,
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
                                  Text(
                                    t('objeto_preferred_name'),
                                    style: const TextStyle(
                                      color: simDark,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  SimInput(
                                    hint: t('objeto_name_placeholder'),
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
                                            ? t('objetivo_reading')
                                            : waitingAttachment
                                            ? 'Aguardando leitura do anexo...'
                                            : objectiveTooShort
                                            ? t('objeto_helper')
                                            : t('objeto_save_continue'),
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
                ],
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

  String _toSimStage(String status) => switch (status) {
        'pedido_recebido' => 'profile',
        't00_running'     => 'curriculum',
        't02_running'     => 'lesson',
        'placement'       => 'placement',
        'primeira_aula_pronta' => 'done',
        'erro'            => 'error',
        _                 => 'generic',
      };

  @override
  Widget build(BuildContext context) {
    final status  = widget.session.entryStatus;
    final error   = widget.session.entryError;
    final isError = status == 'erro';
    final isCredits = error?.toLowerCase().contains('crédito') == true ||
        error?.toLowerCase().contains('credit') == true;
    final simStage  = _toSimStage(status);
    final isReady   = status == 'primeira_aula_pronta';

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: isError
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Color(0xFFF87171),
                        size: 48,
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Não consegui preparar agora',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: simDark,
                        ),
                      ),
                      if (error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          error,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: simMuted,
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                      ],
                      const SizedBox(height: 32),
                      if (isCredits)
                        PrimaryWideButton(
                          label: t('aula_buy_credits'),
                          onTap: () => widget.session.openCredits(),
                        )
                      else
                        PrimaryWideButton(
                          label: 'Tentar novamente',
                          onTap: () {
                            _started = false;
                            _launch();
                          },
                        ),
                    ],
                  ),
                ),
              )
            : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                child: Column(
                  children: [
                    // invisible debug labels
                    Text(
                      widget.session.route,
                      style: const TextStyle(color: Colors.transparent, fontSize: 1),
                    ),
                    Text(
                      'entry.status: $status',
                      style: const TextStyle(color: Colors.transparent, fontSize: 1),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        child: SimPreparationExperience(
                          stage: simStage,
                          ready: isReady,
                          onContinue: () {
                            _started = false;
                            _launch();
                          },
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

class PlacementLabScreen extends StatefulWidget {
  const PlacementLabScreen({required this.session, super.key});

  final LabSession session;

  @override
  State<PlacementLabScreen> createState() => _PlacementLabScreenState();
}

// NV-1..NV-4: Nivelamento 4-step sub-flow inside CyberStepShell
// step 1/4 = Choice, 2/4 = Intro, 3/4 = Question, 4/4 = Result
class _PlacementLabScreenState extends State<PlacementLabScreen> {
  // sub-step within placement: 1=choice, 2=intro, 3=question, 4=result
  int _subStep = 1;
  bool _preparing = false;

  void _goToIntro() => setState(() => _subStep = 2);
  void _goToQuestion() async {
    setState(() => _preparing = true);
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (mounted) setState(() { _subStep = 3; _preparing = false; });
  }
  void _goToResult() => setState(() => _subStep = 4);

  @override
  Widget build(BuildContext context) {
    return CyberStepShell(
      step: _subStep,
      total: 4,
      child: _buildSubStep(),
    );
  }

  Widget _buildSubStep() {
    switch (_subStep) {
      case 1: return _PlacementChoice(
        onBeginning: widget.session.skipPlacement,
        onQuick: _goToIntro,
      );
      case 2: return _PlacementIntro(
        onStart: _preparing ? null : _goToQuestion,
        preparing: _preparing,
      );
      case 3: return _PlacementQuestion(
        session: widget.session,
        onDone: _goToResult,
      );
      case 4: return _PlacementResult(
        session: widget.session,
        onContinue: widget.session.finishPlacement,
      );
      default: return const SizedBox.shrink();
    }
  }
}

// NV-1: Choice screen
class _PlacementChoice extends StatelessWidget {
  const _PlacementChoice({required this.onBeginning, required this.onQuick});
  final VoidCallback onBeginning;
  final VoidCallback onQuick;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t('placement_choice_h1'),
          style: const TextStyle(
            color: simDark, fontSize: 28, height: 1.12, fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          t('placement_choice_body'),
          style: const TextStyle(color: simMuted, fontSize: 17, height: 1.45),
        ),
        const SizedBox(height: 32),
        PrimaryWideButton(label: t('placement_start_beginning'), onTap: onBeginning),
        const SizedBox(height: 12),
        SecondaryWideButton(label: t('placement_take_quick'), onTap: onQuick),
      ],
    );
  }
}

// NV-2: Intro screen
class _PlacementIntro extends StatelessWidget {
  const _PlacementIntro({required this.onStart, required this.preparing});
  final VoidCallback? onStart;
  final bool preparing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t('placement_intro_h1'),
          style: const TextStyle(
            color: simDark, fontSize: 28, height: 1.12, fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          t('placement_intro_body'),
          style: const TextStyle(color: simMuted, fontSize: 17, height: 1.45),
        ),
        const SizedBox(height: 32),
        PrimaryWideButton(
          label: preparing ? t('placement_preparing') : t('placement_start'),
          onTap: onStart,
        ),
      ],
    );
  }
}

// NV-3: Question screen
class _PlacementQuestion extends StatelessWidget {
  const _PlacementQuestion({required this.session, required this.onDone});
  final LabSession session;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t('placement_question_of', {'n': '1', 'total': '1'}),
          style: TextStyle(
            fontFamily: GoogleFonts.jetBrainsMono().fontFamily,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: simMuted,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Qual alternativa descreve melhor seu conhecimento atual?',
          style: TextStyle(
            color: simDark, fontSize: 20, height: 1.3, fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 24),
        SecondaryWideButton(label: 'A. Domino bem', onTap: onDone),
        const SizedBox(height: 8),
        SecondaryWideButton(label: 'B. Sei uma parte', onTap: onDone),
        const SizedBox(height: 8),
        SecondaryWideButton(label: 'C. Preciso começar guiado', onTap: onDone),
      ],
    );
  }
}

// NV-4: Result screen
class _PlacementResult extends StatelessWidget {
  const _PlacementResult({required this.session, required this.onContinue});
  final LabSession session;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t('placement_result_h1'),
          style: const TextStyle(
            color: simDark, fontSize: 28, height: 1.12, fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          t('placement_result_body'),
          style: const TextStyle(color: simMuted, fontSize: 17, height: 1.45),
        ),
        const SizedBox(height: 32),
        PrimaryWideButton(label: t('continue'), onTap: onContinue),
      ],
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
  bool _doubtSheetOpen = false;

  @override
  void initState() {
    super.initState();
    widget.session.addListener(_onSessionChange);
  }

  void _onSessionChange() {
    final open = widget.session.doubtOpen;
    if (open && !_doubtSheetOpen) {
      _doubtSheetOpen = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _showDoubtSheet());
    }
  }

  void _showDoubtSheet() {
    if (!mounted) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DoubtInputSheet(
        controller: _doubtController,
        onSubmit: (text) {
          widget.session.toggleDoubt();
          _doubtController.clear();
        },
        onClose: () {
          widget.session.toggleDoubt();
          _doubtController.clear();
        },
      ),
    ).whenComplete(() {
      _doubtSheetOpen = false;
      if (widget.session.doubtOpen) widget.session.toggleDoubt();
    });
  }

  @override
  void dispose() {
    widget.session.removeListener(_onSessionChange);
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

    // Full-screen review/recovery room overlays
    if (session.reviewRoom != null) {
      return _ReviewRoomScreen(session: session);
    }
    if (session.recoveryRoom != null) {
      return _RecoveryRoomScreen(session: session);
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            AulaTopBar(
              session: session,
              doubtEnabled: true,
              progress: viewModel?.progress.toDouble(),
              headerLabel: viewModel != null ? _headerLabelText(viewModel.headerLabel) : null,
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
                    // AUL-3: Loading phase — glass-soft card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: simBorder),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x0F111827),
                            blurRadius: 16,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          const SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: simDark,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            t('preparing_lesson'),
                            style: const TextStyle(
                              color: simMuted,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (session.aulaRuntimeError != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              session.aulaRuntimeError!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: simDark,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 12),
                            SecondaryWideButton(
                              label: t('aula_try_again_2'),
                              onTap: () => unawaited(session.openAulaRuntime()),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ] else if (content != null) ...[
                    SimCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // AUL-4: TEORIA section label
                          Row(children: [
                            Text(
                              t('aula_theory'),
                              style: TextStyle(
                                fontFamily: GoogleFonts.jetBrainsMono().fontFamily,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: simMuted,
                                letterSpacing: 1.2,
                              ),
                            ),
                            if (viewModel != null) ...[
                              const SizedBox(width: 8),
                              Text(
                                '· ${_headerLabelText(viewModel.headerLabel)}',
                                style: const TextStyle(color: simMuted, fontSize: 11),
                              ),
                            ],
                          ]),
                          const SizedBox(height: 8),
                          SimTypewriter(
                            text: content.explanation,
                            style: const TextStyle(
                              color: simDark,
                              fontSize: 15,
                              height: 1.45,
                            ),
                            onTick: _scrollToBottom,
                          ),
                          const SizedBox(height: 12),
                          LessonImagePanel(session: session),
                          // Doubt: processing → progress bar
                          if (session.doubt.status == DoubtStatus.processing) ...[
                            const SizedBox(height: 12),
                            DoubtProgressBar(
                              progress: session.doubt.progress.toDouble(),
                              label: 'Analisando sua dúvida...',
                            ),
                          ],
                          // Doubt: explaining / error → explanation card
                          if (session.doubt.status == DoubtStatus.explaining ||
                              session.doubt.status == DoubtStatus.error) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: simBorder),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x59111827),
                                    blurRadius: 30,
                                    spreadRadius: -24,
                                    offset: Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Explicação da sua dúvida',
                                    style: TextStyle(
                                      color: simDark,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  if (session.doubt.error != null)
                                    Text(
                                      session.doubt.error!,
                                      style: const TextStyle(color: simMuted, fontSize: 14, height: 1.4),
                                    )
                                  else if (session.doubt.response != null)
                                    Text(
                                      session.doubt.response!.explanation,
                                      style: const TextStyle(color: simDark, fontSize: 14, height: 1.5),
                                    ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                          if (session.audioLoading) ...[
                            const StatusLine(
                              icon: Icons.volume_up_outlined,
                              text: 'Preparando audio da aula...',
                              loading: true,
                            ),
                          ] else if (session.audioError != null) ...[
                            StatusLine(icon: Icons.volume_off_outlined, text: session.audioError!),
                          ] else if (session.audioEnabled) ...[
                            const StatusLine(
                              icon: Icons.volume_up_outlined,
                              text: 'Audio da aula ligado',
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // AUL-4: DESAFIO divider
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          const Expanded(child: Divider(color: simBorder)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Text(
                              t('aula_challenge'),
                              style: TextStyle(
                                fontFamily: GoogleFonts.jetBrainsMono().fontFamily,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: simMuted,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                          const Expanded(child: Divider(color: simBorder)),
                        ],
                      ),
                    ),
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
                            _SinalRow(onSignal: session.submitAulaSignal),
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

                    // FeedbackBox + Dúvida button + Próximo
                    if (isCompleted && feedbackKey != null) ...[
                      const SizedBox(height: 10),
                      // "Dúvida" button (spec: concluido state, before FeedbackBox)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: GestureDetector(
                          onTap: session.doubt.status != DoubtStatus.processing
                              ? session.toggleDoubt
                              : null,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: simBorder),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x47111827),
                                  blurRadius: 20,
                                  spreadRadius: -16,
                                  offset: Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Text(
                              session.doubt.status == DoubtStatus.processing
                                  ? 'Dúvida...'
                                  : 'Dúvida',
                              style: TextStyle(
                                color: session.doubt.status == DoubtStatus.processing
                                    ? simMuted
                                    : simDark,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _FeedbackBox(
                        isCorrect: wasCorrect ?? false,
                        message: _feedbackText(feedbackKey),
                        nextLabel: _nextBtnText(nextKey),
                        nextReady: !locked,
                        onNext: () => unawaited(session.advanceAula()),
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

// AUL-5: FeedbackBox with fade+slide-up animation on appear
class _FeedbackBox extends StatefulWidget {
  const _FeedbackBox({
    required this.isCorrect,
    required this.message,
    this.nextLabel,
    this.nextReady = true,
    this.onNext,
  });

  final bool isCorrect;
  final String message;
  final String? nextLabel;
  final bool nextReady;
  final VoidCallback? onNext;

  @override
  State<_FeedbackBox> createState() => _FeedbackBoxState();
}

class _FeedbackBoxState extends State<_FeedbackBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 260))
      ..forward();
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween(begin: const Offset(0, 0.08), end: Offset.zero).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isCorrect ? simSuccess : simWarn;
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _slide,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color.withAlpha(20),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withAlpha(100)),
          ),
          child: Row(
            children: [
              Icon(
                widget.isCorrect
                    ? Icons.check_circle_outline
                    : Icons.cancel_outlined,
                color: color,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.message,
                  style: TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (widget.onNext != null) ...[
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: widget.nextReady ? widget.onNext : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: widget.nextReady ? simDark : simLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${widget.nextLabel ?? ''} >>',
                      style: TextStyle(
                        color: widget.nextReady ? Colors.white : simMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// AUL-8: Row of 3 equal signal buttons, mono-18 number, label-11 uppercase
class _SinalRow extends StatelessWidget {
  const _SinalRow({required this.onSignal});
  final void Function(int) onSignal;

  @override
  Widget build(BuildContext context) {
    final labels = [
      (1, t('aula_sig_certeza')),
      (2, t('aula_sig_revisar')),
      (3, t('aula_sig_nao_sei')),
    ];
    return Row(
      children: [
        for (int i = 0; i < labels.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: _SinalBtn(
              n: labels[i].$1,
              label: labels[i].$2,
              onTap: () => onSignal(labels[i].$1),
            ),
          ),
        ],
      ],
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: simBorder),
        ),
        child: Column(
          children: [
            Text(
              '$n',
              style: TextStyle(
                fontFamily: GoogleFonts.jetBrainsMono().fontFamily,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: simDark,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label.toUpperCase(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: GoogleFonts.jetBrainsMono().fontFamily,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: simMuted,
                letterSpacing: 0.5,
              ),
            ),
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
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: simDark, width: 1.5),
          ),
          child: const Icon(Icons.volume_up, color: simDark, size: 16),
        ),
      ),
    );
  }
}

// §DS DoubtInputSheet — bottom-sheet modal matching DoubtInputSheet.tsx
// Header: title + description, textarea 5 rows max 1200 chars,
// paperclip button (bottom-left), char counter (bottom-right), submit btn.
class _DoubtInputSheet extends StatefulWidget {
  const _DoubtInputSheet({
    required this.controller,
    required this.onSubmit,
    required this.onClose,
  });

  final TextEditingController controller;
  final void Function(String text) onSubmit;
  final VoidCallback onClose;

  @override
  State<_DoubtInputSheet> createState() => _DoubtInputSheetState();
}

class _DoubtInputSheetState extends State<_DoubtInputSheet> {
  String? _error;

  void _submit() {
    final text = widget.controller.text.trim();
    if (text.isEmpty) {
      setState(() => _error = 'Escreva sua dúvida.');
      return;
    }
    setState(() => _error = null);
    widget.onSubmit(text);
  }

  @override
  Widget build(BuildContext context) {
    final charCount = widget.controller.text.length;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: simBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                const Text(
                  'Enviar dúvida',
                  style: TextStyle(
                    color: simDark,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                // Description
                const Text(
                  'Escreva sua dúvida ou envie uma foto do exercício, resolução, fórmula, gráfico ou tabela.',
                  style: TextStyle(color: simMuted, fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 16),
                // Textarea container
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: simBorder),
                  ),
                  child: Stack(
                    children: [
                      TextField(
                        controller: widget.controller,
                        maxLines: 5,
                        maxLength: 1200,
                        buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          hintText: 'Escreva sua dúvida aqui...',
                          hintStyle: TextStyle(color: simMuted, fontSize: 16),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.fromLTRB(12, 12, 12, 44),
                        ),
                        style: const TextStyle(color: simDark, fontSize: 16, height: 1.5),
                      ),
                      // Paperclip button bottom-left
                      Positioned(
                        left: 8,
                        bottom: 8,
                        child: GestureDetector(
                          onTap: () {/* camera/gallery — mobile only */},
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(Icons.attach_file, size: 22, color: simMuted),
                          ),
                        ),
                      ),
                      // Character counter bottom-right
                      Positioned(
                        right: 12,
                        bottom: 12,
                        child: Text(
                          '$charCount/1200',
                          style: TextStyle(
                            fontFamily: GoogleFonts.jetBrainsMono().fontFamily,
                            fontSize: 12,
                            color: simMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 6),
                  Text(_error!, style: const TextStyle(color: simDestructive, fontSize: 13)),
                ],
                const SizedBox(height: 12),
                // Submit button
                GestureDetector(
                  onTap: _submit,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: simBorder),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'Enviar dúvida',
                      style: TextStyle(
                        color: simDark,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
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
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: SingleChildScrollView(
            child: SimPreparationExperience(
              stage: 'done',
              ready: true,
              onContinue: () => session.openSupport('/cyber/objeto'),
            ),
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

// §AUX _AuxQuestionScreen
// Full-screen aux question: header (back btn + 3px progress bar + mono label),
// glass theory card, question h2, A/B/C option buttons with signal row on selection,
// FeedbackBox with ▶ next button in result state.
class _AuxQuestionScreen extends StatelessWidget {
  const _AuxQuestionScreen({
    required this.mode,
    required this.conteudo,
    required this.selected,
    required this.status,
    required this.headerLabel,
    required this.onSelect,
    required this.onSignal,
    required this.onNext,
    this.progressWidth,
    this.resultCorrect,
    this.resultMsg,
    this.onBack,
  });

  final String mode;
  final AuxRoomContent conteudo;
  final AnswerLetter? selected;
  final String status; // 'answering' | 'result'
  final String headerLabel;
  final double? progressWidth;
  final bool? resultCorrect;
  final String? resultMsg;
  final VoidCallback? onBack;
  final void Function(AnswerLetter) onSelect;
  final void Function(DecisionSignal) onSignal;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final isResult = status == 'result';
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              child: Row(
                children: [
                  if (onBack != null)
                    GestureDetector(
                      onTap: onBack,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: simBorder),
                        ),
                        child: const Icon(Icons.arrow_back, color: simDark, size: 20),
                      ),
                    )
                  else
                    const SizedBox(width: 40),
                  const SizedBox(width: 12),
                  if (progressWidth != null)
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: Container(
                          height: 3,
                          color: const Color(0x0F111827),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: FractionallySizedBox(
                              widthFactor: (progressWidth! / 100).clamp(0.0, 1.0),
                              child: Container(
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [Color(0xFFFFFFFF), Color(0xFFF3F4F6)],
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    const Expanded(child: SizedBox()),
                  const SizedBox(width: 12),
                  Text(
                    headerLabel.toUpperCase(),
                    style: TextStyle(
                      fontFamily: GoogleFonts.jetBrainsMono().fontFamily,
                      fontSize: 11,
                      color: simMuted,
                      letterSpacing: 0.18 * 11,
                    ),
                  ),
                ],
              ),
            ),
            // Scrollable body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Glass theory card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: simBorder),
                      ),
                      child: Text(
                        conteudo.explanation,
                        style: const TextStyle(
                          color: simDark,
                          fontSize: 15,
                          height: 1.5,
                        ),
                      ),
                    ),
                    if (conteudo.question.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Text(
                        conteudo.question,
                        style: const TextStyle(
                          color: simDark,
                          fontSize: 19,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    // A/B/C options
                    for (final opt in [AnswerLetter.A, AnswerLetter.B, AnswerLetter.C]) ...[
                      _AuxOptionTile(
                        letter: opt,
                        text: conteudo.options[opt] ?? '',
                        selected: selected == opt,
                        locked: isResult,
                        onSelect: () => onSelect(opt),
                        onSignal: onSignal,
                        showSignals: selected == opt && !isResult,
                      ),
                      const SizedBox(height: 10),
                    ],
                    if (isResult) ...[
                      const SizedBox(height: 4),
                      _AuxFeedbackBox(
                        correct: resultCorrect ?? false,
                        message: resultMsg ?? '',
                        onNext: onNext,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuxOptionTile extends StatelessWidget {
  const _AuxOptionTile({
    required this.letter,
    required this.text,
    required this.selected,
    required this.locked,
    required this.onSelect,
    required this.onSignal,
    required this.showSignals,
  });

  final AnswerLetter letter;
  final String text;
  final bool selected;
  final bool locked;
  final VoidCallback onSelect;
  final void Function(DecisionSignal) onSignal;
  final bool showSignals;

  @override
  Widget build(BuildContext context) {
    final letterStr = letter.name; // 'A', 'B', 'C'
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: locked ? null : onSelect,
          child: Opacity(
            opacity: locked && !selected ? 0.6 : 1.0,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected ? simDark : simBorder,
                  width: selected ? 1.5 : 1.0,
                ),
                boxShadow: selected
                    ? [const BoxShadow(color: Color(0x14111827), blurRadius: 12, offset: Offset(0, 4))]
                    : null,
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: selected ? simDark : const Color(0x0D111827),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      letterStr,
                      style: TextStyle(
                        fontFamily: GoogleFonts.jetBrainsMono().fontFamily,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: selected ? Colors.white : simDark,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      text,
                      style: const TextStyle(color: simDark, fontSize: 15),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (showSignals) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Container(
              padding: const EdgeInsets.only(left: 12),
              decoration: const BoxDecoration(
                border: Border(left: BorderSide(color: simDark, width: 2)),
              ),
              child: Row(
                children: [
                  _SinalBtn(
                    n: 1,
                    label: t('aula_sig_certeza'),
                    onTap: () => onSignal(DecisionSignal.one),
                  ),
                  const SizedBox(width: 8),
                  _SinalBtn(
                    n: 2,
                    label: t('aula_sig_revisar'),
                    onTap: () => onSignal(DecisionSignal.two),
                  ),
                  const SizedBox(width: 8),
                  _SinalBtn(
                    n: 3,
                    label: t('aula_sig_nao_sei'),
                    onTap: () => onSignal(DecisionSignal.three),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _AuxFeedbackBox extends StatelessWidget {
  const _AuxFeedbackBox({
    required this.correct,
    required this.message,
    required this.onNext,
  });

  final bool correct;
  final String message;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final color = correct ? const Color(0xFF374151) : simDark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: correct ? const Color(0xFFF0FDF4) : const Color(0xFFFFF1F1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: correct ? const Color(0xFF86EFAC) : const Color(0xFFFCA5A5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: color, fontSize: 14, height: 1.4),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: onNext,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: simDark,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '▶',
                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// §REVROOM ReviewRoomScreen
class _ReviewRoomScreen extends StatelessWidget {
  const _ReviewRoomScreen({required this.session});
  final LabSession session;

  @override
  Widget build(BuildContext context) {
    final review = session.reviewRoom!;
    final status = review.status;

    if (status == ReviewRoomStatus.choose) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Container(
                padding: const EdgeInsets.all(32),
                constraints: const BoxConstraints(maxWidth: 420),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: simBorder),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      t('aux_review_ask_count'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: simDark,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (final count in [5, 10]) ...[
                          GestureDetector(
                            onTap: () => session.setReviewRoom(
                              review.copyWith(
                                status: ReviewRoomStatus.preparing,
                                count: count,
                              ),
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                              decoration: BoxDecoration(
                                color: simDark,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '$count',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          if (count == 5) const SizedBox(width: 12),
                        ],
                      ],
                    ),
                    const SizedBox(height: 20),
                    GestureDetector(
                      onTap: session.closeReviewRoom,
                      child: Text(
                        t('aux_review_fail_back'),
                        style: const TextStyle(color: simMuted, fontSize: 13),
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

    if (status == ReviewRoomStatus.preparing || status == ReviewRoomStatus.ready) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Center(
            child: SimPreparationExperience(
              stage: 'review',
              ready: status == ReviewRoomStatus.ready,
              onContinue: () => session.setReviewRoom(
                review.copyWith(status: ReviewRoomStatus.answering),
              ),
            ),
          ),
        ),
      );
    }

    if (status == ReviewRoomStatus.failed) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Container(
                padding: const EdgeInsets.all(32),
                constraints: const BoxConstraints(maxWidth: 420),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: simBorder),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      t('aula_gen_fail'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (review.errMsg != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        review.errMsg!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: simMuted, fontSize: 13),
                      ),
                    ],
                    const SizedBox(height: 20),
                    GestureDetector(
                      onTap: session.closeReviewRoom,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(
                          color: simDark,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          t('aux_review_fail_back'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
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
      );
    }

    if (status == ReviewRoomStatus.done) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Center(
            child: SimPreparationExperience(
              stage: 'reviewDone',
              ready: true,
              onContinue: session.closeReviewRoom,
            ),
          ),
        ),
      );
    }

    if (review.conteudo == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Center(
            child: SimPreparationExperience(
              stage: 'review',
              ready: false,
              onContinue: () {},
            ),
          ),
        ),
      );
    }

    final progressWidth = review.count > 0 ? (review.idx / review.count) * 100.0 : 0.0;
    return _AuxQuestionScreen(
      mode: 'review',
      conteudo: review.conteudo!,
      selected: review.letra,
      status: status.name,
      headerLabel: '${t('aux_review_button')} ${review.idx + 1}/${review.count}',
      progressWidth: progressWidth,
      resultCorrect: review.resultCorrect,
      resultMsg: review.errMsg,
      onBack: session.closeReviewRoom,
      onSelect: (letter) => session.setReviewRoom(review.copyWith(letra: letter)),
      onSignal: (signal) => session.setReviewRoom(
        review.copyWith(
          sinal: signal,
          status: ReviewRoomStatus.result,
          resultCorrect: review.letra == review.conteudo!.correctAnswer,
        ),
      ),
      onNext: () {
        final nextIdx = review.idx + 1;
        if (nextIdx >= review.count) {
          session.setReviewRoom(review.copyWith(status: ReviewRoomStatus.done));
        } else {
          session.setReviewRoom(ReviewRoomView(
            status: ReviewRoomStatus.preparing,
            count: review.count,
            queue: review.queue,
            idx: nextIdx,
          ));
        }
      },
    );
  }
}

// §RECROOM RecoveryRoomScreen
class _RecoveryRoomScreen extends StatelessWidget {
  const _RecoveryRoomScreen({required this.session});
  final LabSession session;

  @override
  Widget build(BuildContext context) {
    final recovery = session.recoveryRoom!;
    final status = recovery.status;

    if (status == RecoveryRoomStatus.failed) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Container(
                padding: const EdgeInsets.all(32),
                constraints: const BoxConstraints(maxWidth: 420),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: simBorder),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      t('aula_gen_fail'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (recovery.errMsg != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        recovery.errMsg!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: simMuted, fontSize: 13),
                      ),
                    ],
                    const SizedBox(height: 20),
                    GestureDetector(
                      onTap: session.closeRecoveryRoom,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(
                          color: simDark,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          t('aux_recovery_finish_cta'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
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
      );
    }

    if (status == RecoveryRoomStatus.intro || status == RecoveryRoomStatus.preparing) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Center(
            child: SimPreparationExperience(
              stage: 'recovery',
              ready: recovery.conteudo != null,
              onContinue: () => session.setRecoveryRoom(
                recovery.copyWith(status: RecoveryRoomStatus.answering),
              ),
            ),
          ),
        ),
      );
    }

    if (status == RecoveryRoomStatus.done) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Center(
            child: SimPreparationExperience(
              stage: 'recoveryDone',
              ready: true,
              onContinue: session.closeRecoveryRoom,
            ),
          ),
        ),
      );
    }

    if (recovery.conteudo == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Center(
            child: SimPreparationExperience(
              stage: 'recovery',
              ready: false,
              onContinue: () {},
            ),
          ),
        ),
      );
    }

    return _AuxQuestionScreen(
      mode: 'recovery',
      conteudo: recovery.conteudo!,
      selected: recovery.letra,
      status: status == RecoveryRoomStatus.result ? 'result' : 'answering',
      headerLabel: t('aux_recovery_preparing_title'),
      resultCorrect: recovery.resultCorrect,
      resultMsg: recovery.errMsg,
      onSelect: (letter) => session.setRecoveryRoom(recovery.copyWith(letra: letter)),
      onSignal: (signal) => session.setRecoveryRoom(
        recovery.copyWith(
          sinal: signal,
          status: RecoveryRoomStatus.result,
          resultCorrect: recovery.letra == recovery.conteudo!.correctAnswer,
        ),
      ),
      onNext: () {
        final nextIdx = recovery.idx + 1;
        if (nextIdx >= recovery.queue.length) {
          session.setRecoveryRoom(recovery.copyWith(status: RecoveryRoomStatus.done));
        } else {
          session.setRecoveryRoom(RecoveryRoomView(
            status: RecoveryRoomStatus.preparing,
            queue: recovery.queue,
            idx: nextIdx,
          ));
        }
      },
    );
  }
}

// AUL-1: Fixed header — menu btn + 3px progress bar + header label chip +
// audio toggle + Revisão button (mono, uppercase, BookOpenCheck icon).
// Matches LessonMainScreen.tsx header exactly.
class AulaTopBar extends StatelessWidget {
  const AulaTopBar({
    required this.session,
    this.doubtEnabled = false,
    this.progress,
    this.headerLabel,
    super.key,
  });

  final LabSession session;
  final bool doubtEnabled;
  final double? progress;
  final String? headerLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.96),
        border: const Border(bottom: BorderSide(color: simBorder, width: 1)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 12,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Menu button 36×36, rounded-xl
          _HamburgerBtn(onTap: () => showAulaMenu(context, session)),
          const SizedBox(width: 10),
          // 3px progress bar (flex-1)
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: Container(
                height: 3,
                color: const Color(0x0F111827),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: progress != null
                        ? (progress! / 100).clamp(0.0, 1.0)
                        : 0.0,
                    child: Container(
                      decoration: const BoxDecoration(
                        color: simDark,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Header label chip (10px mono, bg white, border, rounded-lg)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: simBorder),
              boxShadow: const [
                BoxShadow(color: Color(0x1F000000), blurRadius: 8, offset: Offset(0, 2)),
              ],
            ),
            child: Text(
              (headerLabel ?? (session.stableLang ?? 'SIM')).toUpperCase(),
              style: TextStyle(
                fontFamily: GoogleFonts.jetBrainsMono().fontFamily,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: simDark,
                letterSpacing: 0.14 * 10,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Audio toggle
          GestureDetector(
            onTap: session.toggleAudio,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: simBorder),
                boxShadow: const [
                  BoxShadow(color: Color(0x1F000000), blurRadius: 8, offset: Offset(0, 2)),
                ],
              ),
              child: Icon(
                session.audioEnabled ? Icons.volume_up_outlined : Icons.volume_off_outlined,
                color: session.audioEnabled ? simDark : simMuted,
                size: 18,
              ),
            ),
          ),
          // Revisão button (only when doubtEnabled)
          if (doubtEnabled) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: session.openReviewRoom,
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: simDark,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: simDark),
                  boxShadow: const [
                    BoxShadow(color: Color(0x2E111827), blurRadius: 12, offset: Offset(0, 3)),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.menu_book_outlined, color: Colors.white, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      t('aux_review_button').toUpperCase(),
                      style: TextStyle(
                        fontFamily: GoogleFonts.jetBrainsMono().fontFamily,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        letterSpacing: 0.16 * 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HamburgerBtn extends StatelessWidget {
  const _HamburgerBtn({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: simBorder),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14111827),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            for (int i = 0; i < 3; i++) ...[
              if (i > 0) const SizedBox(height: 4),
              Container(
                width: 18,
                height: 3,
                decoration: BoxDecoration(
                  color: simDark,
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF111827).withOpacity(0.15),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
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
                  subtitle: t('pay_pack_lessons_100'),
                  onTap: session.openCheckoutReturn,
                ),
                CreditPackButton(
                  title: '200 créditos',
                  subtitle: t('pay_pack_lessons_200'),
                  onTap: session.openCheckoutReturn,
                ),
                CreditPackButton(
                  title: '500 créditos',
                  subtitle: t('pay_pack_lessons_500'),
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
          'Resumo vivo: idioma ${session.stableLang ?? '-'}, objetivo ${session.freeText.isEmpty ? '-' : session.freeText}, item ${session.currentAulaItemNumber}, camada ${session.currentAulaLayer.value}.',
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
  showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'menu',
    barrierColor: Colors.black.withOpacity(0.5),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (ctx, anim1, anim2) {
      final sw = MediaQuery.of(ctx).size.width;
      final drawerW = (sw * 0.88).clamp(0.0, 360.0);
      return Align(
        alignment: Alignment.centerLeft,
        child: AnimatedBuilder(
          animation: anim1,
          builder: (_, child) => Transform.translate(
            offset: Offset(-drawerW * (1 - anim1.value), 0),
            child: child,
          ),
          child: Material(
            color: const Color(0xFFF0F0F0),
            child: SizedBox(
              width: drawerW,
              height: double.infinity,
              child: SafeArea(
                child: _AulaDrawerContent(session: session, onClose: () => Navigator.of(ctx).pop()),
              ),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (ctx, anim1, anim2, child) => child,
  );
}

class _AulaDrawerContent extends StatefulWidget {
  const _AulaDrawerContent({required this.session, required this.onClose});
  final LabSession session;
  final VoidCallback onClose;
  @override
  State<_AulaDrawerContent> createState() => _AulaDrawerContentState();
}

class _AulaDrawerContentState extends State<_AulaDrawerContent> {
  final TextEditingController _searchCtrl = TextEditingController();
  String? _feedback;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _flash(String msg) {
    setState(() => _feedback = msg);
    Future.delayed(const Duration(milliseconds: 2200), () {
      if (mounted) setState(() => _feedback = null);
    });
  }

  void _handleNovaAula() {
    widget.onClose();
    widget.session.goPortal();
  }

  Future<void> _handleLogout() async {
    widget.onClose();
    widget.session.logout();
  }

  @override
  Widget build(BuildContext context) {
    const panelBg = Color(0xFFF0F0F0);
    const footerBg = Color(0xFFE7E7E7);
    const border = Color(0xFFD4D4D4);
    const text = Color(0xFF1A1A1A);
    const muted = Color(0xFF5A5A5A);

    final session = widget.session;
    final lessonId = session.lessonLocalId;
    final state = lessonId != null ? session.canonicalStore?.readState(lessonId) : null;
    final total = state?.curriculum?.totalItems ?? 0;
    final advances = state?.progress?.itemIdx ?? 0;
    final pct = total > 0 ? ((advances / total) * 100).round() : 0;
    final lessonName = state?.curriculum?.topic ?? lessonId ?? '';

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          decoration: BoxDecoration(
            color: panelBg,
            border: const Border(bottom: BorderSide(color: border, width: 1)),
          ),
          child: Row(
            children: [
              Text(
                t('menu').toUpperCase(),
                style: TextStyle(
                  fontFamily: GoogleFonts.jetBrainsMono().fontFamily,
                  fontSize: 11,
                  letterSpacing: 0.22 * 11,
                  color: muted,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: widget.onClose,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    '✕',
                    style: TextStyle(color: text, fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Top: Nova Aula + Recarregar
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: border, width: 1)),
          ),
          child: Column(
            children: [
              // Nova Aula button (gradient-like: dark bg)
              GestureDetector(
                onTap: _handleNovaAula,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: simDark,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(color: Color(0x2E111827), blurRadius: 12, offset: Offset(0, 4)),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Text('＋', style: TextStyle(color: Colors.white, fontSize: 18)),
                      const SizedBox(width: 12),
                      Text(
                        t('nova_aula'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Recarregar créditos
              GestureDetector(
                onTap: () { widget.onClose(); session.openCredits(); },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: border),
                  ),
                  child: Row(
                    children: [
                      const Text('⚡', style: TextStyle(fontSize: 14)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          t('recarregar_creditos'),
                          style: const TextStyle(
                            color: text,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        'TOP UP',
                        style: TextStyle(
                          fontFamily: GoogleFonts.jetBrainsMono().fontFamily,
                          fontSize: 10,
                          color: muted,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // Middle: History / lesson list
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t('historico').toUpperCase(),
                  style: TextStyle(
                    fontFamily: GoogleFonts.jetBrainsMono().fontFamily,
                    fontSize: 10,
                    letterSpacing: 0.22 * 10,
                    color: muted,
                  ),
                ),
                const SizedBox(height: 8),
                if (lessonName.isEmpty)
                  Text(
                    t('historico_vazio'),
                    style: const TextStyle(color: muted, fontSize: 12),
                  )
                else ...[
                  // Search field
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: border),
                    ),
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (_) => setState(() {}),
                      style: const TextStyle(color: text, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: t('drawer_search_placeholder'),
                        hintStyle: const TextStyle(color: muted, fontSize: 14),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Current lesson item
                  if (_matchSearch(lessonName))
                    Container(
                      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: border),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  lessonName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: text,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  '$pct% · $advances/$total',
                                  style: TextStyle(
                                    fontFamily: GoogleFonts.jetBrainsMono().fontFamily,
                                    fontSize: 10,
                                    color: muted,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),

        // Footer
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: const BoxDecoration(
            color: footerBg,
            border: Border(top: BorderSide(color: border, width: 1)),
          ),
          child: Column(
            children: [
              // Status line
              if (total > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Text(
                        t('drawer_progress'),
                        style: TextStyle(
                          fontFamily: GoogleFonts.jetBrainsMono().fontFamily,
                          fontSize: 11,
                          color: muted,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '$advances/$total',
                        style: TextStyle(
                          fontFamily: GoogleFonts.jetBrainsMono().fontFamily,
                          fontSize: 11,
                          color: text,
                        ),
                      ),
                    ],
                  ),
                ),
              // Export / Import / Status
              Row(
                children: [
                  _DrawerFooterBtn(label: '⤓ ${t("exportar")}', onTap: () => _flash('Em breve')),
                  const SizedBox(width: 6),
                  _DrawerFooterBtn(label: '⤒ ${t("importar")}', onTap: () => _flash('Em breve')),
                  const SizedBox(width: 6),
                  _DrawerFooterBtn(label: 'ⓘ ${t("status")}',  onTap: () => _flash('Em breve')),
                ],
              ),
              if (_feedback != null) ...[
                const SizedBox(height: 6),
                Text(
                  _feedback!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: simDark, fontSize: 11),
                ),
              ],
              const SizedBox(height: 8),
              // Logout button
              GestureDetector(
                onTap: _handleLogout,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: border),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.logout, size: 16, color: text),
                      const SizedBox(width: 8),
                      Text(
                        t('logout'),
                        style: const TextStyle(
                          color: text,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () { widget.onClose(); session.openSupport('/conta/deletar'); },
                child: Text(
                  'Solicitar exclusão da conta',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: muted,
                    fontSize: 11,
                    decoration: TextDecoration.underline,
                    decorationColor: muted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  bool _matchSearch(String name) {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return true;
    return name.toLowerCase().contains(q);
  }
}

class _DrawerFooterBtn extends StatelessWidget {
  const _DrawerFooterBtn({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFD4D4D4)),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF1A1A1A),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

// DR-1..DR-6: Left-side panel drawer (88vw max 360, bg #F0F0F0)
void _showSimDrawer(
  BuildContext context, {
  required LabSession session,
  required Widget Function(BuildContext ctx) body,
}) {
  showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'menu',
    barrierColor: Colors.black.withOpacity(0.35),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (ctx, anim1, anim2) {
      final sw = MediaQuery.of(ctx).size.width;
      final drawerW = (sw * 0.88).clamp(0.0, 360.0);
      return Align(
        alignment: Alignment.centerLeft,
        child: AnimatedBuilder(
          animation: anim1,
          builder: (_, child) => Transform.translate(
            offset: Offset(-drawerW * (1 - anim1.value), 0),
            child: child,
          ),
          child: Material(
            color: const Color(0xFFF0F0F0),
            child: SizedBox(
              width: drawerW,
              height: double.infinity,
              child: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header: MENU label + close
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 16, 4),
                      child: Row(
                        children: [
                          Text(
                            t('menu'),
                            style: const TextStyle(
                              color: simDark,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: () => Navigator.of(ctx).pop(),
                            child: const Padding(
                              padding: EdgeInsets.all(8),
                              child: Text(
                                '✕',
                                style: TextStyle(
                                  color: simDark,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(color: Color(0xFFD1D5DB), height: 1),
                    const SizedBox(height: 8),
                    // Body content
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: body(ctx),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (ctx, anim1, anim2, child) => child,
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
          gradient: active ? simGradientPrimary : null,
          color: active ? null : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: active ? simDark : simBorder,
          ),
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
            boxShadow: const [
              BoxShadow(
                color: Color(0x2E243447),
                blurRadius: 14,
                spreadRadius: -6,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Icon(icon, color: simDark, size: 20),
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

// §3.1 BackgroundDecor — gradiente vertical + anéis radiais laterais
class BackgroundDecor extends StatelessWidget {
  const BackgroundDecor({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Camada 0: gradiente 180deg #FFFFFF 0% → #F3F4F6 60% → #FFFFFF 100%
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.white, Color(0xFFF3F4F6), Colors.white],
              stops: [0, 0.6, 1],
            ),
          ),
          child: SizedBox.expand(),
        ),
        // Camada 1: anéis radiais esquerda (top 25%, left -6px, 160×420)
        Positioned(
          top: MediaQuery.of(context).size.height * 0.25,
          left: -6,
          child: Opacity(
            opacity: 0.4,
            child: _RadialRings(width: 160, height: 420),
          ),
        ),
        // Camada 2: anéis radiais direita (bottom 40px, 160×380)
        Positioned(
          bottom: 40,
          right: 0,
          child: Opacity(
            opacity: 0.4,
            child: _RadialRings(width: 160, height: 380),
          ),
        ),
      ],
    );
  }
}

class _RadialRings extends StatelessWidget {
  const _RadialRings({required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, height),
      painter: _RadialRingsPainter(),
    );
  }
}

class _RadialRingsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x14111827) // rgba(17,24,39,0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final cx = size.width / 2;
    final cy = size.height / 2;
    double r = 19;
    while (r < size.width * 1.5) {
      canvas.drawCircle(Offset(cx, cy), r, paint);
      r += 19;
    }
  }

  @override
  bool shouldRepaint(_RadialRingsPainter oldDelegate) => false;
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
