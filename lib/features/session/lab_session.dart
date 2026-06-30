// ignore_for_file: unused_import, unnecessary_import
import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../sim/billing/sim_server_billing_clients.dart';
import '../../sim/cloud/sim_server_cloud_functions.dart';
import '../../sim/cloud/supabase_flutter_session_provider.dart';
import '../../sim/cloud/supabase_student_state_cloud_storage.dart';
import '../../sim/config/sim_environment.dart';
import '../../sim/external_ai/sim_ai_server_config.dart';
import '../../sim/external_ai/sim_server_ai_clients.dart';
import '../../sim/external_ai/sim_server_attachment_client.dart';
import '../../sim/classroom/classroom_models.dart';
import '../../sim/classroom/lesson_runtime_engine.dart';
import '../../sim/classroom/lesson_main_view_model.dart';
import '../../sim/experience/student_experience_types.dart';
import '../../sim/organism/sim_organism.dart';
import '../../sim/organism/sim_organism_provider.dart';
import '../../session/auth_session.dart';
import '../../session/entry_form_state.dart';
import '../../session/lesson_ui_state.dart';
import '../../session/navigation_state.dart';
import '../../sim/lesson/lesson_models.dart';
import '../../sim/media/audio_core.dart';
import '../../sim/media/audio_preference.dart';
import '../../sim/media/lesson_audio_controller.dart';
import '../../sim/media/student_lesson_media_service.dart';
import '../../sim/state/shared_prefs_state_storage.dart';
import '../../sim/state/student_learning_state.dart';
import '../../sim/state/student_state_store.dart';
import '../../sim/ui/sim_i18n.dart';
import '../../sim/ui/widgets/cyber_step_shell.dart';
import '../../sim/ui/widgets/sim_preparation_experience.dart';
import '../../sim/ui/widgets/sim_typewriter.dart';
import '../../sim/auxiliary/aux_room_models.dart';
import '../../sim/ui/widgets/doubt_progress_bar.dart';

import '../../core/utils/sim_constants.dart';
import '../session/lab_session.dart';
import '../portal/portal_flow.dart';
import '../auth/login_screen.dart';
import '../onboarding/onboarding_screens.dart';
import '../onboarding/preparation_and_placement.dart';
import '../classroom/aula_screen.dart';
import '../classroom/aux_room_screens.dart';
import '../classroom/aula_widgets.dart';
import '../billing/billing_and_simple_pages.dart';
import '../../shared/widgets/shared_widgets.dart';
class LabSession extends ChangeNotifier {
  LabSession({
    StudentStateStore? canonicalStore,
    this._attachmentClient,
    this.prefs,
  }) : canonicalStore =
           canonicalStore ??
           StudentStateStore(local: MemoryStudentStateLocalStorage()) {
    entryForm.addListener(_notifyFromChild);
    authSession.addListener(_notifyFromChild);
    navigationState.addListener(_notifyFromChild);
    lessonUiState.addListener(_notifyFromChild);
  }

  final SharedPreferences? prefs;
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
    prefs: prefs!,
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
    if (prefs == null && route == '/cyber/curriculo') return;
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
      payload: {'objective_length': objective.length, 'language': language},
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
    notifyListeners();
  }

  void openSupport(String path) {
    navigationState.openRoute(path);
    notifyListeners();
  }

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

  LessonContent _devLessonContent() => const LessonContent(
    explanation:
        'Vamos estudar fraÃ§Ãµes equivalentes com uma explicaÃ§Ã£o curta antes do desafio.',
    question: 'Qual alternativa representa uma fraÃ§Ã£o equivalente a 1/2?',
    options: {
      AnswerLetter.A: '1/3',
      AnswerLetter.B: '2/4',
      AnswerLetter.C: '3/5',
    },
    correctAnswer: AnswerLetter.B,
  );

  LessonRuntimeSnapshot _devAulaSnapshot({
    ClassroomPhase phase = const ClassroomPhase.reading(),
  }) {
    final content = _devLessonContent();
    return LessonRuntimeSnapshot(
      authReady: authReady,
      authed: authed,
      hasCurriculum: true,
      isDone: false,
      viewModel: LessonMainViewModel(
        progress: 0,
        headerLabel: 'aula_item_of:1/1:aula_layer_1',
        options: [
          LessonOptionModel(
            letter: AnswerLetter.A,
            text: content.options[AnswerLetter.A] ?? '',
          ),
          LessonOptionModel(
            letter: AnswerLetter.B,
            text: content.options[AnswerLetter.B] ?? '',
          ),
          LessonOptionModel(
            letter: AnswerLetter.C,
            text: content.options[AnswerLetter.C] ?? '',
          ),
        ],
        locked:
            phase.type == ClassroomPhaseType.processando ||
            phase.type == ClassroomPhaseType.concluido,
        nextLabel: phase.type == ClassroomPhaseType.concluido
            ? 'aula_next'
            : '',
      ),
      phase: phase,
      history: const [],
      conteudo: content,
      itemMarker: 'M-1',
      itemText: 'FraÃ§Ãµes equivalentes',
    );
  }

  Future<void> openAulaRuntime() async {
    if (aulaRuntimeLoading) return;
    aulaRuntimeLoading = true;
    aulaRuntimeError = null;
    notifyListeners();
    try {
      if (prefs == null) {
        aulaSnapshot = _devAulaSnapshot();
        return;
      }
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
    final answer = AnswerLetter.values.firstWhere(
      (value) => value.name == letter,
      orElse: () => AnswerLetter.A,
    );
    if (prefs == null) {
      aulaSnapshot = _devAulaSnapshot(phase: ClassroomPhase.expanded(answer));
      notifyListeners();
      return;
    }
    final organism = _activeOrganism ?? _organismForActiveLesson();
    organism.lessonRuntimeEngine.select(answer);
    aulaSnapshot = organism.lessonRuntimeEngine.snapshot();
    notifyListeners();
  }

  void submitAulaSignal(int value) {
    final signal = switch (value) {
      1 => DecisionSignal.one,
      2 => DecisionSignal.two,
      3 => DecisionSignal.three,
      _ => DecisionSignal.one,
    };
    if (prefs == null) {
      aulaSnapshot = _devAulaSnapshot(
        phase: ClassroomPhase.completed(
          message: 'aula_fb_correct',
          wasCorrect: true,
          signal: signal,
        ),
      );
      notifyListeners();
      return;
    }
    final organism = _activeOrganism ?? _organismForActiveLesson();
    unawaited(_doSignal(organism, signal));
  }

  Future<void> _doSignal(SimOrganism organism, DecisionSignal signal) async {
    aulaRuntimeLoading = true;
    aulaRuntimeError = null;
    notifyListeners();
    try {
      await organism.lessonRuntimeEngine.signal(signal);
      aulaSnapshot = organism.lessonRuntimeEngine.snapshot();
      _persistActiveLessonToCloud();
    } catch (error) {
      aulaRuntimeError = error.toString();
    } finally {
      aulaRuntimeLoading = false;
      notifyListeners();
    }
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
        audioError = 'Ãudio ainda nÃ£o estÃ¡ disponÃ­vel.';
      }
    } catch (_) {
      audioError = 'NÃ£o foi possÃ­vel preparar o Ã¡udio agora.';
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




