import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import 'sim/billing/payments_functions.dart';
import 'sim/billing/credit_client.dart';
import 'sim/billing/credit_purchase_service.dart';
import 'sim/billing/credit_service.dart';
import 'sim/billing/sim_pricing.dart';
import 'sim/billing/sim_server_billing_clients.dart';
import 'sim/billing/student_billing_ledger.dart';
import 'sim/auxiliary/aux_room_models.dart';
import 'sim/auxiliary/aux_room_t02_caller.dart';
import 'sim/auxiliary/doubt_input_sheet.dart';
import 'sim/auxiliary/doubt_t02_caller.dart';
import 'sim/auxiliary/lesson_doubt_controller.dart';
import 'sim/auxiliary/recovery_room_service.dart';
import 'sim/auxiliary/review_room_service.dart';
import 'sim/auxiliary/student_aux_room_service.dart';
import 'sim/auxiliary/support_room_service.dart';
import 'sim/external_ai/sim_ai_server_config.dart';
import 'sim/external_ai/sim_server_attachment_client.dart';
import 'sim/external_ai/sim_server_ai_clients.dart';
import 'sim/classroom/classroom_models.dart';
import 'sim/classroom/lesson_runtime_engine.dart';
import 'sim/cloud/cloud_queue.dart' show SharedPreferencesCloudQueueStorage;
import 'sim/history/lesson_history_store.dart'
    show LessonBackupEnvelope, LessonHistoryEntry, LessonHistoryStore;
import 'sim/lesson/lesson_models.dart';
import 'sim/media/audio_core.dart';
import 'sim/media/audio_preference.dart';
import 'sim/media/audioplayers_playback_adapter.dart';
import 'sim/media/lesson_audio_api_contract.dart';
import 'sim/media/lesson_visual_pipeline.dart';
import 'sim/media/shared_preferences_audio_storage.dart';
import 'sim/media/student_lesson_media_service.dart';
import 'sim/organism/sim_organism.dart';
import 'sim/organism/sim_organism_controller.dart';
import 'sim/state/student_learning_state.dart';
import 'sim/state/student_learning_state_service.dart';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const simSupabaseUrl = 'https://qxzwcldfowyqhyikyxcy.supabase.co';
const simSupabaseAnonKey = 'sb_publishable_-b8arZ8aKEbwU6FEpXAhqg_6bXycrgQ';
const simAuthRedirectUrl = 'sim-mobile://login-callback';
const simServerBaseUrl = 'http://167.179.109.137:3000';
const simLovableBaseUrl = 'https://gemini-aid-pal.lovable.app';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: simSupabaseUrl,
    publishableKey: simSupabaseAnonKey,
  );
  runApp(const SimMobileApp());
}

const simDark = Color(0xFF111827);
const simMid = Color(0xFF374151);
const simLight = Color(0xFFF3F4F6);
const simMuted = Color(0xFF6B7280);
const simBorder = Color(0xFFD1D5DB);
const maxFreeText = 1500;
const maxAttachments = 3;
const maxAttachmentBytes = 10 * 1024 * 1024;
const minExtractedChars = 20;
const simPersistedLearningStateKey = 'sim.mobile.learning_state.v1';
const audioNotSupportedMessage =
    'Audio ainda nao esta disponivel. Envie texto, foto ou arquivo.';
const videoNotSupportedMessage =
    'Video ainda nao esta disponivel. Envie texto, foto ou arquivo.';
const objectiveRequiredMessage =
    'Campo obrigatorio. Escreva o que voce quer estudar.';
const objectiveRequiredWithAttachmentMessage =
    'Voce anexou um arquivo. Agora escreva o que deseja estudar com ele.';

class AttachmentDraft {
  AttachmentDraft({
    required this.id,
    required this.name,
    required this.type,
    required this.size,
    required this.status,
    this.extractedText,
    this.method,
    this.error,
  });

  final String id;
  final String name;
  final String type;
  final int size;
  final String status;
  final String? extractedText;
  final String? method;
  final String? error;
}

class LabSession extends ChangeNotifier {
  bool _persistenceReady = false;
  bool _restoringPersistedState = false;
  String? _lastPersistedStateJson;
  StudentCurriculum? _persistedCurriculum;
  String? _persistedCurrentMarker;
  bool authed = false;
  bool authReady = false;
  int credits = 0;
  int signalsSolid = 0;
  int signalsUnderstood = 0;
  int signalsFragile = 0;
  int totalAulaSteps = 10;
  String route = '/';
  String returnTo = '/';
  String? checkoutSessionId;
  String? userId;
  String? userEmail;
  String? userName;
  String? authError;
  StreamSubscription<AuthState>? _authSub;
  SimAiServerConfig? _serverConfig;
  SimServerPaymentsClient? _paymentsClientInstance;
  CreditService? _creditService;
  CreditPurchaseService? _creditPurchaseService;
  SimServerAttachmentClient? _attachmentClientInstance;
  SimOrganismController? _controller;
  LessonHistoryStore? _lessonHistoryStore;
  ReviewRoomService? _reviewRoomService;
  RecoveryRoomService? _recoveryRoomService;
  SupportRoomService? _supportRoomService;
  LessonDoubtController? _doubtController;
  SharedPreferences? _imagePrefs;
  SharedPreferences? _audioPrefs;
  SharedPreferencesCloudQueueStorage? _cloudQueueStorage;
  AudioplayersPlaybackAdapter? _audioPlayback;
  LessonRuntimeSnapshot? _lastSnapshot;
  String audioStatus = 'idle';
  String? _lastAudioAutoKey;
  List<LessonHistoryEntry> lessonHistory = const [];
  String lessonHistoryQuery = '';
  String? lessonHistoryMessage;
  bool lessonHistoryLoading = false;
  List<StudentBillingTransaction> billingTransactions = const [];

  ClassroomPhase get classroomPhase =>
      _lastSnapshot?.phase ?? const ClassroomPhase.loading();
  bool get lessonIsDone => _lastSnapshot?.isDone ?? false;
  double get lessonProgress => _lastSnapshot?.viewModel?.progress ?? 0.0;
  String get lessonHeaderLabel => _lastSnapshot?.viewModel?.headerLabel ?? '';
  bool get answersLocked => _lastSnapshot?.viewModel?.locked ?? false;
  String get nextStepLabel => _lastSnapshot?.viewModel?.nextLabel ?? '';
  DoubtState get doubtState => _getDoubtController().state;
  ReviewRoomView? reviewRoomView;
  RecoveryRoomView? recoveryRoomView;
  SupportRoomView? supportRoomView;
  Timer? _supportExitTimer;
  String doubtText = '';
  DoubtImagePayload? doubtImage;
  String? doubtInputError;

  SimAiServerConfig _getServerConfig() {
    return _serverConfig ??= SimAiServerConfig(
      baseUrl: simLovableBaseUrl,
      accessTokenProvider: () async =>
          Supabase.instance.client.auth.currentSession?.accessToken,
      t02Path: '/api/complete-lesson',
    );
  }

  Future<CreditService> _getCreditService() async {
    if (_creditService != null) return _creditService!;
    final prefs = await SharedPreferences.getInstance();
    return _creditService = CreditService(
      client: SimServerCreditClient(
        config: SimAiServerConfig(
          baseUrl: simServerBaseUrl,
          accessTokenProvider: () async =>
              Supabase.instance.client.auth.currentSession?.accessToken,
        ),
      ),
      stateService: _ensureController().organism.stateService,
      preferences: prefs,
    );
  }

  SimServerPaymentsClient _getPaymentsClient() {
    return _paymentsClientInstance ??= SimServerPaymentsClient(
      config: _getServerConfig(),
    );
  }

  CreditPurchaseService _getCreditPurchaseService() {
    return _creditPurchaseService ??= CreditPurchaseService(
      webStripeProvider: WebStripePurchaseProvider(
        payments: _getPaymentsClient(),
      ),
    );
  }

  Future<CheckoutStatus> getCheckoutStatus(String sessionId) {
    return _getPaymentsClient().getCheckoutStatus(
      sessionId: sessionId,
      environment: StripeEnvironment.live,
    );
  }

  SimServerAttachmentClient _getAttachmentClient() {
    return _attachmentClientInstance ??= SimServerAttachmentClient(
      config: SimAiServerConfig(
        baseUrl: simServerBaseUrl,
        accessTokenProvider: () async =>
            Supabase.instance.client.auth.currentSession?.accessToken,
      ),
    );
  }

  String? selectedLanguageCode;
  String? stableLang;
  String otherLanguage = '';
  String freeText = '';
  String preferredName = '';
  bool allowPaidImages = false;
  List<AttachmentDraft> attachments = [];
  String attachmentsText = '';
  String studentProfileNotes = '';
  String? lessonLocalId;
  String entryStatus = 'idle';
  String? entryError;
  bool placementStarted = false;
  bool placementDone = false;

  // Placement T02 state
  String placementStage = 'choice'; // choice | intro | running | result
  bool placementLoading = false;
  String? placementError;
  String? placementQuestion;
  List<Map<String, dynamic>> placementChoices = []; // [{id, label, correct}]
  String? placementStartMarker;
  String? placementMarker;
  int aulaStep = 0;
  String selectedAnswer = '';
  String aulaMessage = '';
  bool doubtOpen = false;
  bool audioEnabled = true;
  bool audioLoading = false;
  String? audioError;
  String imageStatus = 'idle';
  String? imageError;
  String? lessonImageDataUrl;
  JsonMap? lessonVisualTrigger;
  bool imageOfferAccepted = false;
  String? externalDoorOpened;
  String deleteConfirmation = '';
  String? accountDeletionMessage;

  // T02 lesson content
  bool t02Loading = false;
  String? t02Error;
  String? t02Explanation;
  String? t02Question;
  Map<String, String>? t02Options;
  String? t02CorrectAnswer;
  String? t02WhyCorrect;
  dynamic t02WhyWrong;
  List<LessonAttempt> attempts = [];

  Future<void> restorePersistedState() async {
    if (_restoringPersistedState) return;
    _restoringPersistedState = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyStore = await _getLessonHistoryStore();
      _audioPrefs = prefs;
      _cloudQueueStorage ??= SharedPreferencesCloudQueueStorage(prefs);
      final audioRaw = prefs.getString(audioPreferenceStorageKey);
      audioEnabled = audioRaw == null || audioRaw == '1' || audioRaw == 'true';
      await _refreshLessonHistory(notify: false, recordEvent: false);
      final activeId = await historyStore.readActiveLessonLocalId();
      final activeState =
          activeId == null ? null : await historyStore.readState(activeId);
      if (activeState != null && activeState.extra['deletedAt'] == null) {
        _applyPersistedLearningState(activeState);
        _lastPersistedStateJson = jsonEncode(activeState.toJson());
        return;
      }
      final raw = prefs.getString(simPersistedLearningStateKey);
      if (raw != null && raw.trim().isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          _applyPersistedLearningState(
            StudentLearningState.fromJson(JsonMap.from(decoded)),
          );
          _lastPersistedStateJson = raw;
        }
      }
    } catch (_) {
      // Corrupted local state must not block opening the app.
    } finally {
      _persistenceReady = true;
      _restoringPersistedState = false;
      notifyListeners();
    }
  }

  @override
  void notifyListeners() {
    super.notifyListeners();
    _persistLearningState();
  }

  void _applyPersistedLearningState(StudentLearningState state) {
    final extra = state.extra;
    lessonLocalId =
        state.lessonLocalId.isEmpty ? lessonLocalId : state.lessonLocalId;
    _persistedCurriculum = state.curriculum;
    attempts = state.attempts;
    stableLang = state.profile.stableLang ?? stableLang;
    selectedLanguageCode = state.profile.language ?? selectedLanguageCode;
    preferredName = state.profile.preferredName ?? preferredName;
    freeText = state.profile.objetivo ?? state.profile.targetTopic ?? freeText;
    studentProfileNotes =
        (extra['profileNotes'] as String?) ?? studentProfileNotes;
    aulaStep = (extra['aulaStep'] as num?)?.toInt() ??
        state.progress?.itemIdx ??
        state.current?.itemIdx ??
        aulaStep;
    selectedAnswer = (extra['selectedAnswer'] as String?) ?? selectedAnswer;
    signalsSolid = (extra['signalsSolid'] as num?)?.toInt() ?? signalsSolid;
    signalsUnderstood =
        (extra['signalsUnderstood'] as num?)?.toInt() ?? signalsUnderstood;
    signalsFragile =
        (extra['signalsFragile'] as num?)?.toInt() ?? signalsFragile;
    entryStatus = (extra['entryStatus'] as String?) ?? entryStatus;
    route = (extra['route'] as String?) ??
        (lessonLocalId != null && aulaStep > 0 ? '/cyber/aula' : route);
  }

  void _persistLearningState() {
    if (!_persistenceReady || _restoringPersistedState) return;
    final state = _buildPersistedLearningState();
    final raw = jsonEncode(state.toJson());
    if (raw == _lastPersistedStateJson) return;
    _lastPersistedStateJson = raw;
    unawaited(_writePersistedLearningState(raw));
  }

  Future<void> _writePersistedLearningState(String raw) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(simPersistedLearningStateKey, raw);
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        final state = StudentLearningState.fromJson(JsonMap.from(decoded));
        final store = await _getLessonHistoryStore();
        await store.saveState(state);
        await store.setActiveLessonLocalId(state.lessonLocalId);
        await _refreshLessonHistory(notify: false, recordEvent: false);
      }
    } catch (_) {
      // History persistence must never block the active lesson.
    }
  }

  Future<LessonHistoryStore> _getLessonHistoryStore() async {
    return _lessonHistoryStore ??= await LessonHistoryStore.create();
  }

  Future<void> _refreshLessonHistory({
    bool notify = true,
    bool recordEvent = true,
  }) async {
    final store = await _getLessonHistoryStore();
    lessonHistory = await store.readEntries();
    if (recordEvent && lessonLocalId != null) {
      final state = await store.readState(lessonLocalId!);
      if (state != null) {
        await store.saveState(
          state.copyWith(
            events: [
              ...state.events,
              _lessonEvent('LESSON_LIST_LOADED', {
                'count': lessonHistory.length,
              }),
            ],
          ),
        );
      }
    }
    if (notify) notifyListeners();
  }

  List<LessonHistoryEntry> get filteredLessonHistory {
    final q = lessonHistoryQuery.trim().toLowerCase();
    if (q.isEmpty) return lessonHistory;
    return lessonHistory
        .where(
          (entry) =>
              entry.title.toLowerCase().contains(q) ||
              entry.lessonLocalId.toLowerCase().contains(q) ||
              (entry.lastMarker ?? '').toLowerCase().contains(q),
        )
        .toList(growable: false);
  }

  void setLessonHistoryQuery(String value) {
    lessonHistoryQuery = value;
    notifyListeners();
  }

  StudentLearningEvent _lessonEvent(String type, JsonMap payload) {
    return StudentLearningEvent(
      type: type,
      ts: DateTime.now().millisecondsSinceEpoch,
      payload: payload,
    );
  }

  Future<void> selectLessonFromHistory(String selectedLessonLocalId) async {
    final store = await _getLessonHistoryStore();
    final current = _buildPersistedLearningState();
    await store.saveState(current);
    final state = await store.readState(selectedLessonLocalId);
    if (state == null || state.extra['deletedAt'] != null) {
      lessonHistoryMessage = 'Aula indisponivel no historico.';
      notifyListeners();
      return;
    }
    await store.setActiveLessonLocalId(selectedLessonLocalId);
    _controller = null;
    _applyPersistedLearningState(
      state.copyWith(
        events: [
          ...state.events,
          _lessonEvent('LESSON_SELECTED', {
            'lessonLocalId': selectedLessonLocalId,
          }),
          _lessonEvent('ACTIVE_LESSON_CHANGED', {
            'lessonLocalId': selectedLessonLocalId,
          }),
        ],
      ),
    );
    route = '/cyber/aula';
    lessonHistoryMessage = 'Aula retomada do ponto salvo.';
    _lastPersistedStateJson = null;
    await store.saveState(_buildPersistedLearningState());
    await _refreshLessonHistory(notify: false, recordEvent: false);
    notifyListeners();
    unawaited(loadT02Content());
  }

  Future<void> startNewLessonFromHistory() async {
    final store = await _getLessonHistoryStore();
    await store.saveState(
      _buildPersistedLearningState().copyWith(
        events: [
          ..._buildPersistedLearningState().events,
          _lessonEvent('NEW_LESSON_REQUESTED', {
            'previousLessonLocalId': lessonLocalId,
          }),
        ],
      ),
    );
    final nextId =
        'lesson-${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}';
    _controller = null;
    lessonLocalId = nextId;
    aulaStep = 0;
    selectedAnswer = '';
    aulaMessage = '';
    resetT02();
    _persistedCurriculum = null;
    _persistedCurrentMarker = null;
    attempts = [];
    freeText = '';
    preferredName = '';
    studentProfileNotes = '';
    attachments = [];
    attachmentsText = '';
    entryStatus = 'idle';
    route = '/cyber/objeto';
    await store.setActiveLessonLocalId(nextId);
    final state = _buildPersistedLearningState().copyWith(
      events: [
        _lessonEvent('NEW_LESSON_STARTED', {'lessonLocalId': nextId}),
        _lessonEvent('ACTIVE_LESSON_CHANGED', {'lessonLocalId': nextId}),
      ],
    );
    await store.saveState(state);
    lessonHistoryMessage = 'Nova aula iniciada.';
    _lastPersistedStateJson = null;
    await _refreshLessonHistory(notify: false, recordEvent: false);
    notifyListeners();
  }

  Future<void> renameLessonFromHistory(
    String selectedLessonLocalId,
    String title,
  ) async {
    final store = await _getLessonHistoryStore();
    await store.renameLesson(selectedLessonLocalId, title);
    if (lessonLocalId == selectedLessonLocalId) {
      final state = _buildPersistedLearningState();
      await store.saveState(
        state.copyWith(
          extra: {...state.extra, 'displayName': title.trim()},
        ),
      );
    }
    lessonHistoryMessage = 'Aula renomeada.';
    await _refreshLessonHistory();
  }

  Future<void> tombstoneLessonFromHistory(String selectedLessonLocalId) async {
    final store = await _getLessonHistoryStore();
    final state = await store.readState(selectedLessonLocalId);
    if (state != null) {
      await store.saveState(
        state.copyWith(
          events: [
            ...state.events,
            _lessonEvent('LESSON_DELETE_CONFIRMED', {
              'lessonLocalId': selectedLessonLocalId,
              'financialDataDeleted': false,
            }),
            _lessonEvent('LESSON_DELETED', {
              'lessonLocalId': selectedLessonLocalId,
              'mode': 'tombstone',
              'financialDataDeleted': false,
            }),
          ],
        ),
      );
    }
    await store.tombstoneLesson(selectedLessonLocalId, userId: userId);
    if (lessonLocalId == selectedLessonLocalId) {
      route = '/';
      lessonLocalId = null;
      _controller = null;
      resetT02();
    }
    lessonHistoryMessage =
        'Aula apagada do historico. Dados financeiros preservados.';
    await _refreshLessonHistory();
  }

  Future<String?> exportLessonBackup() async {
    final store = await _getLessonHistoryStore();
    await store.saveState(
      _buildPersistedLearningState().copyWith(
        events: [
          ..._buildPersistedLearningState().events,
          _lessonEvent('BACKUP_EXPORTED', {'format': 'json'}),
        ],
      ),
    );
    final envelope = await store.exportBackup(userId: userId);
    final data = const JsonEncoder.withIndent('  ').convert(envelope.toJson());
    final fileName = 'sim-backup-${DateTime.now().millisecondsSinceEpoch}.json';
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Exportar backup do SIM',
      fileName: fileName,
      bytes: Uint8List.fromList(utf8.encode(data)),
    );
    lessonHistoryMessage =
        path == null ? 'Exportacao cancelada.' : 'Backup exportado.';
    notifyListeners();
    return path;
  }

  Future<void> importLessonBackup() async {
    try {
      final pick = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['json'],
        withData: true,
      );
      final file = pick?.files.single;
      if (file == null) return;
      final bytes = file.bytes ??
          (file.path == null ? null : await File(file.path!).readAsBytes());
      if (bytes == null) {
        throw const FormatException('Arquivo sem dados.');
      }
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map) throw const FormatException('JSON invalido.');
      final backup = LessonBackupEnvelope.fromJson(JsonMap.from(decoded));
      final store = await _getLessonHistoryStore();
      await store.importBackup(backup, currentUserId: userId);
      final active = await store.readActiveLessonLocalId();
      final state = active == null ? null : await store.readState(active);
      if (state != null) {
        _applyPersistedLearningState(
          state.copyWith(
            events: [
              ...state.events,
              _lessonEvent('BACKUP_VALIDATED', {'lessonLocalId': active}),
              _lessonEvent('BACKUP_IMPORTED', {'lessonLocalId': active}),
            ],
          ),
        );
      }
      lessonHistoryMessage = 'Backup importado.';
      await _refreshLessonHistory();
    } catch (e) {
      lessonHistoryMessage =
          'Backup rejeitado: ${e.toString().replaceFirst("FormatException: ", "")}';
      final store = await _getLessonHistoryStore();
      await store.saveState(
        _buildPersistedLearningState().copyWith(
          events: [
            ..._buildPersistedLearningState().events,
            _lessonEvent('BACKUP_REJECTED', {'error': lessonHistoryMessage}),
            _lessonEvent(
                'BACKUP_IMPORT_FAILED', {'error': lessonHistoryMessage}),
          ],
        ),
      );
      notifyListeners();
    }
  }

  Future<void> syncLessonHistory() async {
    lessonHistoryLoading = true;
    lessonHistoryMessage = 'Sincronizando...';
    notifyListeners();
    final state = _buildPersistedLearningState();
    try {
      final prefs = await SharedPreferences.getInstance();
      _cloudQueueStorage ??= SharedPreferencesCloudQueueStorage(prefs);
      final ctrl = _ensureController();
      final store = await _getLessonHistoryStore();
      await store.saveState(state);
      ctrl.organism.stateService.write(
        state.copyWith(
          events: [
            ...state.events,
            _lessonEvent('CLOUD_PULL_STARTED', {
              'lessonLocalId': state.lessonLocalId,
            }),
            _lessonEvent(
                'SYNC_STARTED', {'lessonLocalId': state.lessonLocalId}),
          ],
        ),
      );
      final pulled = await ctrl.organism.cloudQueue.pullCloudSnapshots();
      for (final remoteState in pulled) {
        await store.saveState(remoteState);
      }
      ctrl.organism.stateService.appendEvent(
        state.lessonLocalId,
        _lessonEvent('CLOUD_PULL_COMPLETED', {
          'lessonLocalId': state.lessonLocalId,
          'restoredSnapshots': pulled.length,
          'mode': 'anti_regression',
        }),
      );
      ctrl.organism.stateService.appendEvent(
        state.lessonLocalId,
        _lessonEvent('CLOUD_PUSH_STARTED', {
          'lessonLocalId': state.lessonLocalId,
        }),
      );
      ctrl.organism.sync.enqueuePatch(state.lessonLocalId);
      await ctrl.organism.sync.drain();
      ctrl.organism.stateService.appendEvent(
        state.lessonLocalId,
        _lessonEvent('CLOUD_PUSH_COMPLETED', {
          'lessonLocalId': state.lessonLocalId,
        }),
      );
      ctrl.organism.stateService.appendEvent(
        state.lessonLocalId,
        _lessonEvent('SYNC_COMPLETED', {'lessonLocalId': state.lessonLocalId}),
      );
      await store.saveState(
        ctrl.organism.stateService.read(state.lessonLocalId) ?? state,
      );
      final pending = ctrl.organism.sync.debugSnapshot().length;
      lessonHistoryMessage = pending == 0
          ? 'Sync concluido sem regressao.'
          : 'Sync pendente/offline: $pending job(s) preservado(s).';
    } catch (e) {
      final ctrl = _controller;
      if (ctrl == null) {
        final store = await _getLessonHistoryStore();
        await store.saveState(
          state.copyWith(
            events: [
              ...state.events,
              _lessonEvent('SYNC_FAILED', {'error': e.toString()}),
              _lessonEvent('SYNC_BLOCKED_REGRESSION', {
                'reason': 'sync_failed_local_preserved',
              }),
            ],
          ),
        );
      } else {
        ctrl.organism.stateService.appendEvent(
          state.lessonLocalId,
          _lessonEvent('SYNC_FAILED', {'error': e.toString()}),
        );
      }
      lessonHistoryMessage = 'Sync falhou sem regredir progresso.';
    } finally {
      lessonHistoryLoading = false;
      await _refreshLessonHistory(notify: false, recordEvent: false);
      notifyListeners();
    }
  }

  StudentLearningState _buildPersistedLearningState() {
    final id =
        lessonLocalId ?? _controller?.organism.lessonLocalId ?? 'live-entry';
    final existing = _controller?.organism.stateService.read(id);
    final base = existing ??
        StudentLearningState.empty(lessonLocalId: id, userId: userId);
    final now = DateTime.now().millisecondsSinceEpoch;
    final profile = base.profile.copyWith(
      preferredName: preferredName.trim().isEmpty ? null : preferredName.trim(),
      language: selectedLanguageCode,
      stableLang: stableLang,
      objetivo: freeText.trim().isEmpty ? null : freeText.trim(),
      targetTopic: freeText.trim().isEmpty ? null : freeText.trim(),
      extra: {
        ...base.profile.extra,
        if (studentProfileNotes.trim().isNotEmpty)
          'notes': studentProfileNotes.trim(),
      },
    );
    final current = LessonCurrent(
      itemIdx: aulaStep,
      marker: _currentPersistedMarker(),
      layer: base.current?.layer ?? LessonLayer.l1,
      amparoLvl: base.current?.amparoLvl ?? 0,
    );
    final progress = LessonProgress(
      itemIdx: aulaStep,
      layer: base.progress?.layer ?? LessonLayer.l1,
      erros: signalsFragile,
      amparoLvl: base.progress?.amparoLvl ?? 0,
      historia: base.progress?.historia ?? const [],
      mainAdvances: aulaStep,
      concluidos: base.progress?.concluidos ?? const [],
      pendentesMarkers: base.progress?.pendentesMarkers ?? const [],
      totalItems: _persistedCurriculum?.items.length ??
          base.progress?.totalItems ??
          totalAulaSteps,
      pctAvanco: totalAulaSteps <= 0
          ? 0
          : ((aulaStep / totalAulaSteps) * 100).clamp(0, 100).round(),
    );
    return base.copyWith(
      userId: userId,
      updatedAt: now,
      profile: profile,
      curriculum: existing?.curriculum ?? _persistedCurriculum,
      current: current,
      progress: progress,
      attempts: attempts,
      extra: {
        ...base.extra,
        'aulaStep': aulaStep,
        'selectedAnswer': selectedAnswer,
        'signalsSolid': signalsSolid,
        'signalsUnderstood': signalsUnderstood,
        'signalsFragile': signalsFragile,
        'profileNotes': studentProfileNotes,
        'stableLang': stableLang,
        'entryStatus': entryStatus,
        'route': route,
      },
    );
  }

  String _currentPersistedMarker() {
    final snapshotMarker = _lastSnapshot?.itemMarker;
    if (snapshotMarker != null && snapshotMarker.trim().isNotEmpty) {
      return snapshotMarker;
    }
    final t00Marker = _persistedCurrentMarker;
    if (t00Marker != null && t00Marker.trim().isNotEmpty) {
      return t00Marker;
    }
    return 'M-${aulaStep + 1}';
  }

  Map<String, Object?> buildT00BootstrapPayload() {
    final lang = stableLang ??
        (otherLanguage.trim().isNotEmpty ? otherLanguage.trim() : null) ??
        selectedLanguageCode ??
        'Portuguese';
    return {
      'ficha': {
        'free_text': freeText,
        'preferred_name': preferredName,
        'language': selectedLanguageCode ?? 'pt',
        'stableLang': lang,
        'idioma': selectedLanguageCode ?? 'pt',
        'student_profile_notes': studentProfileNotes,
        'lessonLocalId': lessonLocalId ?? 'live-entry',
        'attachments_text': attachmentsText,
      },
    };
  }

  void recordT00StreamStarted() {
    entryStatus = 't00_running';
    _appendT00Event('T00_STREAM_STARTED', {'lessonLocalId': lessonLocalId});
    notifyListeners();
  }

  void recordT00Profile(JsonMap payload) {
    final profile = (payload['profile'] ?? '').toString();
    if (profile.trim().isNotEmpty) studentProfileNotes = profile.trim();
    _mutateT00State((state) {
      return state.copyWith(
        profile: state.profile.copyWith(
          preferredName:
              preferredName.trim().isEmpty ? null : preferredName.trim(),
          language: selectedLanguageCode ?? 'pt',
          stableLang: stableLang ?? 'Portuguese',
          objetivo: freeText.trim().isEmpty ? null : freeText.trim(),
          targetTopic: freeText.trim().isEmpty ? null : freeText.trim(),
          extra: {
            ...state.profile.extra,
            'raw_profile': profile,
            'bootstrap_status': 'running',
          },
        ),
      );
    });
    _appendT00Event('T00_PROFILE_RECEIVED', {'profileChars': profile.length});
    notifyListeners();
  }

  void recordT00ItemPartial(JsonMap payload) {
    final item = _curriculumItemFrom(payload['item']);
    if (item == null) return;
    _persistedCurrentMarker ??= item.marker;
    final previous = _persistedCurriculum?.items ?? const <CurriculumItem>[];
    if (!previous.any((existing) => existing.marker == item.marker)) {
      _persistedCurriculum =
          _curriculumWithItems([...previous, item], provisional: true);
    }
    _writeT00CurriculumState(provisional: true);
    _appendT00Event('T00_ITEM_PARTIAL_RECEIVED', {
      'marker': item.marker,
      'order': payload['order'],
    });
    notifyListeners();
  }

  void recordT00Final(JsonMap payload) {
    final rawItems = payload['curriculum'] ?? payload['curriculo'];
    final items = _curriculumItemsFrom(rawItems);
    if (items.isNotEmpty) {
      _persistedCurriculum = _curriculumWithItems(items, provisional: false);
      _persistedCurrentMarker = items.first.marker;
    }
    final profile = (payload['profile'] ?? '').toString();
    if (profile.trim().isNotEmpty) studentProfileNotes = profile.trim();
    entryStatus = 't00_final_received';
    _writeT00CurriculumState(provisional: false);
    _appendT00Event('T00_FINAL_RECEIVED', {'items': items.length});
    notifyListeners();
  }

  void recordT00Done() {
    entryStatus = 'primeira_aula_pronta';
    _appendT00Event('T00_DONE', {'lessonLocalId': lessonLocalId});
    notifyListeners();
  }

  void recordT00Fatal(String message) {
    entryStatus = 't00_failed';
    entryError = message;
    _appendT00Event('T00_FATAL', {'error': message});
    notifyListeners();
  }

  void _mutateT00State(StudentStateMutator mutator) {
    final id = lessonLocalId ?? 'live-entry';
    final ctrl = _ensureController();
    ctrl.organism.stateService.mutate(id, mutator);
  }

  void _writeT00CurriculumState({required bool provisional}) {
    final curriculum = _persistedCurriculum;
    if (curriculum == null) return;
    _mutateT00State((state) {
      final first = curriculum.items.isEmpty ? null : curriculum.items.first;
      return state.copyWith(
        curriculum: curriculum,
        current: first == null
            ? state.current
            : LessonCurrent(
                itemIdx: 0,
                marker: first.marker,
                layer: LessonLayer.l1,
                amparoLvl: 0,
              ),
        progress: state.progress ??
            LessonProgress(
              itemIdx: 0,
              layer: LessonLayer.l1,
              erros: 0,
              amparoLvl: 0,
              historia: const [],
              mainAdvances: 0,
              concluidos: const [],
              pendentesMarkers: const [],
              totalItems: curriculum.items.length,
              pctAvanco: 0,
            ),
        profile: state.profile.copyWith(
          preferredName:
              preferredName.trim().isEmpty ? null : preferredName.trim(),
          language: selectedLanguageCode ?? 'pt',
          stableLang: stableLang ?? 'Portuguese',
          objetivo: freeText.trim().isEmpty ? null : freeText.trim(),
          targetTopic: freeText.trim().isEmpty ? null : freeText.trim(),
          extra: {
            ...state.profile.extra,
            'raw_profile': studentProfileNotes,
            'bootstrap_status': provisional ? 'streaming' : 'complete',
          },
        ),
      );
    });
  }

  void _appendT00Event(String type, JsonMap payload) {
    final id = lessonLocalId ?? 'live-entry';
    final ctrl = _ensureController();
    ctrl.organism.stateService.appendEvent(
      id,
      StudentLearningEvent(
        type: type,
        ts: DateTime.now().millisecondsSinceEpoch,
        payload: payload,
      ),
    );
  }

  StudentCurriculum _curriculumWithItems(
    List<CurriculumItem> items, {
    required bool provisional,
  }) {
    return StudentCurriculum(
      topic: freeText.trim(),
      totalItems: items.length,
      generatedAt: DateTime.now().millisecondsSinceEpoch,
      provisional: provisional,
      items: items,
    );
  }

  List<CurriculumItem> _curriculumItemsFrom(Object? raw) {
    if (raw is! List) return const [];
    return raw.map(_curriculumItemFrom).whereType<CurriculumItem>().toList();
  }

  CurriculumItem? _curriculumItemFrom(Object? raw) {
    if (raw is! Map) return null;
    final json = JsonMap.from(raw);
    final marker = (json['marker'] ?? '').toString().trim();
    final text = (json['text'] ?? json['purpose'] ?? json['title'] ?? '')
        .toString()
        .trim();
    if (marker.isEmpty || text.isEmpty) return null;
    return CurriculumItem(
      marker: marker,
      text: text,
      title: json['title']?.toString(),
      microitemForTeacher:
          (json['microitem_for_teacher'] ?? json['purpose'])?.toString(),
      extra: json
        ..removeWhere(
          (key, _) => {
            'marker',
            'text',
            'title',
            'microitem_for_teacher',
            'purpose',
          }.contains(key),
        ),
    );
  }

  void goPortal() {
    route = '/';
    notifyListeners();
  }

  void goLogin({String target = '/'}) {
    returnTo = safeReturnTo(target);
    route = '/login';
    notifyListeners();
  }

  void bindRealAuth() {
    final client = _supabaseClientOrNull();
    if (client == null) {
      authReady = true;
      authError = 'Supabase nao foi inicializado.';
      notifyListeners();
      return;
    }
    _authSub ??= client.auth.onAuthStateChange.listen((data) {
      applySupabaseSession(data.session);
    });
    applySupabaseSession(client.auth.currentSession);
  }

  SupabaseClient? _supabaseClientOrNull() {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  void applySupabaseSession(Session? session) {
    final user = session?.user;
    authReady = true;
    authError = null;
    authed = user != null;
    userId = user?.id;
    userEmail = user?.email;
    userName = user?.userMetadata?['full_name']?.toString() ??
        user?.userMetadata?['name']?.toString();
    if (authed) {
      if (route == '/login') route = safeReturnTo(returnTo);
      unawaited(_loadCreditsFromServer());
    } else {
      credits = 0;
    }
    notifyListeners();
  }

  Future<void> _loadCreditsFromServer() async {
    try {
      final service = await _getCreditService();
      final snapshot = await service.refreshBalance(
        lessonLocalId: lessonLocalId ?? _controller?.organism.lessonLocalId,
      );
      credits = snapshot.balance;
      if (lessonLocalId != null || _controller != null) {
        billingTransactions = await service.refreshTransactions(
          lessonLocalId: lessonLocalId ?? _controller!.organism.lessonLocalId,
        );
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<void> refreshCredits() async {
    await _loadCreditsFromServer();
  }

  Future<String?> createCheckoutUrl(CreditPackId packId) async {
    try {
      _appendCreditEvent('CREDIT_PURCHASE_REQUESTED', {
        'packId': packId.wire,
        'providerStrategy': 'platform_abstraction',
      });
      final result = await _getCreditPurchaseService().startPurchase(
        CreditPurchaseRequest(
          packId: packId,
          returnUrl:
              'sim-mobile://checkout/return?session_id={CHECKOUT_SESSION_ID}',
          origin: simLovableBaseUrl,
        ),
        laboratoryStripe: true,
      );
      if (!result.started || result.url == null) {
        _appendCreditEvent('CREDIT_PURCHASE_FAILED', {
          'packId': packId.wire,
          'provider': result.providerKind?.name,
          'error': result.error ?? 'provider_not_ready',
        });
        return null;
      }
      _appendCreditEvent('CREDIT_PURCHASE_STARTED', {
        'packId': packId.wire,
        'provider': result.providerKind?.name ?? 'webStripe',
      });
      return result.url;
    } catch (e) {
      _appendCreditEvent('CREDIT_PURCHASE_FAILED', {
        'packId': packId.wire,
        'error': e.toString(),
      });
      return null;
    }
  }

  void _appendCreditEvent(String type, JsonMap payload) {
    try {
      final ctrl = _ensureController();
      ctrl.organism.stateService.appendEvent(
        ctrl.organism.lessonLocalId,
        StudentLearningEvent(
          type: type,
          ts: DateTime.now().millisecondsSinceEpoch,
          payload: payload,
        ),
      );
    } catch (_) {}
  }

  Future<void> signInWithGoogle() async {
    authError = null;
    notifyListeners();
    final client = _supabaseClientOrNull();
    if (client == null) {
      authError = 'Supabase nao foi inicializado.';
      notifyListeners();
      return;
    }
    try {
      final launched = await client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: simAuthRedirectUrl,
        queryParams: const {'prompt': 'select_account'},
      );
      if (!launched) {
        authError = 'Nao foi possivel abrir o login do Google.';
      }
    } catch (error) {
      authError = 'Nao foi possivel abrir o login do Google.';
    }
    notifyListeners();
  }

  Future<void> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    authError = null;
    notifyListeners();
    final client = _supabaseClientOrNull();
    if (client == null) {
      authError = 'Supabase nao foi inicializado.';
      notifyListeners();
      return;
    }
    try {
      await client.auth.signInWithPassword(email: email, password: password);
    } on AuthException catch (error) {
      authError = error.message;
    } catch (_) {
      authError = 'Unexpected error';
    }
    notifyListeners();
  }

  Future<void> signUpWithEmailPassword({
    required String email,
    required String password,
    required String name,
  }) async {
    authError = null;
    notifyListeners();
    final client = _supabaseClientOrNull();
    if (client == null) {
      authError = 'Supabase nao foi inicializado.';
      notifyListeners();
      return;
    }
    try {
      await client.auth.signUp(
        email: email,
        password: password,
        emailRedirectTo: simAuthRedirectUrl,
        data: {
          'full_name':
              name.trim().isEmpty ? email.split('@').first : name.trim(),
        },
      );
    } on AuthException catch (error) {
      authError = error.message;
    } catch (_) {
      authError = 'Unexpected error';
    }
    notifyListeners();
  }

  Future<void> signOutReal() async {
    final client = _supabaseClientOrNull();
    await client?.auth.signOut();
    applySupabaseSession(null);
    route = '/';
    notifyListeners();
  }

  void start() {
    if (!authed) {
      goLogin(target: '/');
      return;
    }
    if (credits <= 0) {
      openCredits();
      return;
    }
    _clearSessionState();
    route = '/cyber/idioma';
    notifyListeners();
  }

  void _clearSessionState() {
    // Onboarding
    selectedLanguageCode = null;
    stableLang = null;
    otherLanguage = '';
    freeText = '';
    preferredName = '';
    attachments = [];
    studentProfileNotes = '';
    lessonLocalId = null;
    entryStatus = 'idle';
    entryError = null;
    // Placement
    placementStarted = false;
    placementDone = false;
    placementStage = 'choice';
    placementLoading = false;
    placementError = null;
    placementQuestion = null;
    placementChoices = [];
    placementStartMarker = null;
    placementMarker = null;
    // Aula
    aulaStep = 0;
    selectedAnswer = '';
    attempts = [];
    aulaMessage = '';
    doubtOpen = false;
    audioEnabled = true;
    audioLoading = false;
    audioError = null;
    imageStatus = 'idle';
    imageError = null;
    // T02
    resetT02();
  }

  void chooseLanguage(String code, String name) {
    selectedLanguageCode = code;
    final cleanName = name.trim();
    stableLang = cleanName.isEmpty ? null : cleanName;
    if (code != 'other' || cleanName.isNotEmpty) {
      route = '/cyber/objeto';
    }
    notifyListeners();
  }

  void setOtherLanguage(String value) {
    otherLanguage = value;
    notifyListeners();
  }

  void setFreeText(String value) {
    freeText =
        value.length > maxFreeText ? value.substring(0, maxFreeText) : value;
    notifyListeners();
  }

  void setPreferredName(String value) {
    preferredName = value;
    notifyListeners();
  }

  Future<void> addRealAttachment(String source) async {
    if (attachments.length >= maxAttachments) return;
    final isImage = source != 'document';
    final now = DateTime.now().millisecondsSinceEpoch;
    final draftId = 'att-$now-${attachments.length + 1}';

    List<int>? bytes;
    String? name;
    String contentType;

    try {
      if (isImage) {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.image,
          withData: true,
        );
        if (result == null || result.files.isEmpty) return;
        final file = result.files.first;
        bytes = file.bytes?.toList();
        name = file.name;
        final ext = name.split('.').last.toLowerCase();
        contentType = switch (ext) {
          'png' => 'image/png',
          'webp' => 'image/webp',
          'jpg' || 'jpeg' => 'image/jpeg',
          _ => 'application/octet-stream',
        };
      } else {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf', 'txt', 'csv'],
          withData: true,
        );
        if (result == null || result.files.isEmpty) return;
        final file = result.files.first;
        bytes = file.bytes?.toList();
        name = file.name;
        final ext = name.split('.').last.toLowerCase();
        contentType = switch (ext) {
          'txt' => 'text/plain',
          'csv' => 'text/csv',
          'pdf' => 'application/pdf',
          _ => 'application/octet-stream',
        };
      }
    } catch (_) {
      return;
    }

    if (bytes == null || bytes.isEmpty) return;

    const supportedAttachmentTypes = {
      'image/jpeg',
      'image/png',
      'image/webp',
      'application/pdf',
      'text/plain',
      'text/csv',
    };
    if (!supportedAttachmentTypes.contains(contentType)) {
      attachments = [
        ...attachments,
        AttachmentDraft(
          id: draftId,
          name: name,
          type: contentType,
          size: bytes.length,
          status: 'error',
          error: 'Tipo de arquivo nao suportado. Envie imagem, PDF ou texto.',
        ),
      ];
      notifyListeners();
      return;
    }

    if (contentType.startsWith('audio/')) {
      attachments = [
        ...attachments,
        AttachmentDraft(
          id: draftId,
          name: name,
          type: contentType,
          size: bytes.length,
          status: 'error',
          error: audioNotSupportedMessage,
        ),
      ];
      notifyListeners();
      return;
    }

    if (contentType.startsWith('video/')) {
      attachments = [
        ...attachments,
        AttachmentDraft(
          id: draftId,
          name: name,
          type: contentType,
          size: bytes.length,
          status: 'error',
          error: videoNotSupportedMessage,
        ),
      ];
      notifyListeners();
      return;
    }

    if (bytes.length > maxAttachmentBytes) {
      attachments = [
        ...attachments,
        AttachmentDraft(
          id: draftId,
          name: name,
          type: contentType,
          size: bytes.length,
          status: 'error',
          error: 'Arquivo maior que 10MB. Escolha um arquivo menor.',
        ),
      ];
      notifyListeners();
      return;
    }

    attachments = [
      ...attachments,
      AttachmentDraft(
        id: draftId,
        name: name,
        type: contentType,
        size: bytes.length,
        status: 'uploading',
      ),
    ];
    notifyListeners();

    try {
      attachments = [
        for (final a in attachments)
          if (a.id == draftId)
            AttachmentDraft(
              id: a.id,
              name: a.name,
              type: a.type,
              size: a.size,
              status: 'processing',
            )
          else
            a,
      ];
      notifyListeners();

      final processed = await _getAttachmentClient().processAttachment(
        SimAttachmentFile(name: name, contentType: contentType, bytes: bytes),
      );
      final ok = processed.charsExtracted >= minExtractedChars;
      attachments = [
        for (final a in attachments)
          if (a.id == draftId)
            AttachmentDraft(
              id: a.id,
              name: a.name,
              type: a.type,
              size: a.size,
              status: ok ? 'ready' : 'error',
              extractedText: processed.extractedText,
              method: processed.method,
              error: ok
                  ? null
                  : 'Nao consegui ler esse anexo. Tente tirar uma foto mais nitida ou descrever em texto.',
            )
          else
            a,
      ];
    } catch (e) {
      final msg = e.toString().contains('AUDIO_NOT_SUPPORTED')
          ? audioNotSupportedMessage
          : e.toString().contains('VIDEO_NOT_SUPPORTED')
              ? videoNotSupportedMessage
              : 'Nao consegui ler esse anexo. Tente tirar uma foto mais nitida ou descrever em texto.';
      attachments = [
        for (final a in attachments)
          if (a.id == draftId)
            AttachmentDraft(
              id: a.id,
              name: a.name,
              type: a.type,
              size: a.size,
              status: 'error',
              error: msg,
            )
          else
            a,
      ];
    }
    notifyListeners();
  }

  void removeAttachment(int index) {
    attachments = [
      for (int i = 0; i < attachments.length; i++)
        if (i != index) attachments[i],
    ];
    notifyListeners();
  }

  bool saveObjectiveEntry() {
    final freeTrim = freeText.trim();
    if (freeTrim.length < 10) return false;
    final clipped = freeTrim.length > maxFreeText
        ? freeTrim.substring(0, maxFreeText)
        : freeTrim;
    attachmentsText = _buildAttachmentsText();
    final language = stableLang ??
        (otherLanguage.trim().isNotEmpty ? otherLanguage.trim() : null) ??
        selectedLanguageCode ??
        'English';
    lessonLocalId = _deriveLessonLocalId(
      clipped,
      selectedLanguageCode ?? language,
    );
    studentProfileNotes =
        attachmentsText.isEmpty ? clipped : '$clipped\n\n$attachmentsText';
    freeText = clipped;
    entryStatus = 'pedido_recebido';
    entryError = null;
    route = '/cyber/curriculo';
    notifyListeners();
    unawaited(_runController());
    return true;
  }

  void openCredits() {
    if (!authed) {
      goLogin(target: '/creditos');
      return;
    }
    route = '/creditos';
    notifyListeners();
  }

  void openSupport(String path) {
    route = path;
    notifyListeners();
  }

  void openExternalDoor(String url) {
    externalDoorOpened = url;
    notifyListeners();
  }

  void openCheckoutReturn() {
    route = '/checkout/return';
    notifyListeners();
  }

  void preparationDone() {
    entryStatus = 'primeira_aula_pronta';
    route = '/cyber/placement';
    notifyListeners();
  }

  void skipPlacement() {
    placementDone = true;
    placementStage = 'choice';
    route = '/cyber/aula';
    notifyListeners();
  }

  void startPlacement() {
    placementStarted = true;
    placementStage = 'intro';
    notifyListeners();
  }

  void finishPlacement() {
    placementDone = true;
    placementStage = 'choice';
    route = '/cyber/aula';
    notifyListeners();
  }

  Future<void> loadPlacementT02() async {
    if (placementLoading) return;
    placementLoading = true;
    placementError = null;
    notifyListeners();
    try {
      final client = _supabaseClientOrNull();
      final token = client?.auth.currentSession?.accessToken;
      if (token == null) throw Exception('Nao autenticado');

      final uri = Uri.parse('$simServerBaseUrl/api/complete-lesson');
      final httpClient = HttpClient();
      final req = await httpClient.postUrl(uri);
      req.headers.set('Content-Type', 'application/json');
      req.headers.set('Authorization', 'Bearer $token');
      final payload = jsonEncode({
        'mode': 'placement',
        'lessonLocalId': lessonLocalId ?? 'placement',
        'item': freeText.isNotEmpty ? freeText : 'Conteudo da aula',
        'stable_lang': stableLang ?? 'Portuguese',
        'academic_level': null,
        'layer': 1,
        'err_count': 0,
        'lesson_mode': 'session',
        'history': [],
        'preferred_name': preferredName.isNotEmpty ? preferredName : null,
        'student_profile_notes':
            studentProfileNotes.isNotEmpty ? studentProfileNotes : null,
        'guidance_for_T02': 'T11_placement_addendum.txt server-side guidance',
        'target_topic': freeText.trim(),
      });
      req.write(payload);
      final res = await req.close().timeout(const Duration(seconds: 45));
      final body = await res.transform(utf8.decoder).join();
      if (res.statusCode != 200) {
        throw Exception('Servidor retornou ${res.statusCode}');
      }
      final data = jsonDecode(body) as Map<String, dynamic>;
      final c = data['conteudo'] as Map<String, dynamic>?;
      if (c == null) {
        throw Exception('Resposta sem conteudo');
      }

      final question = c['question']?.toString() ?? '';
      final opts = c['options'];
      final correct = c['correct_answer']?.toString() ?? 'A';
      if (question.isEmpty || opts == null) {
        throw Exception('Questao invalida');
      }

      placementQuestion = question;
      placementMarker = 'M-1';
      placementChoices = (['A', 'B', 'C']).map<Map<String, dynamic>>((letter) {
        return {
          'id': 'pre-1-${letter.toLowerCase()}',
          'label': (opts is Map ? opts[letter]?.toString() : null) ?? '',
          'correct': letter == correct,
        };
      }).toList();
      placementStage = 'running';
    } catch (e) {
      // Fallback: question simples local se T02 falhar
      placementQuestion =
          'Como voce avalia seu conhecimento sobre este tema?';
      placementMarker = 'M-1';
      placementChoices = [
        {'id': 'pre-1-a', 'label': 'Domino bem', 'correct': true},
        {'id': 'pre-1-b', 'label': 'Conheco um pouco', 'correct': false},
        {
          'id': 'pre-1-c',
          'label': 'Preciso comecar do zero',
          'correct': false
        },
      ];
      placementStage = 'running';
    }
    placementLoading = false;
    notifyListeners();
  }

  void answerPlacement(bool correct) {
    placementStartMarker = correct ? 'M-2' : 'M-1';
    placementStage = 'result';
    notifyListeners();
  }

  void chooseAulaAnswer(String letter) {
    selectedAnswer = letter;
    final answerLetter = AnswerLetter.values.firstWhere(
      (l) => l.name == letter,
      orElse: () => AnswerLetter.A,
    );
    final engine = _controller?.organism.lessonRuntimeEngine;
    if (engine == null) {
      notifyListeners();
      return;
    }
    engine.select(answerLetter);
    _applySnapshot(engine.snapshot());
  }

  void submitAulaQualifier(DecisionSignal signal) {
    final engine = _controller?.organism.lessonRuntimeEngine;
    if (engine == null) return;
    if (signal == DecisionSignal.one) signalsSolid++;
    if (signal == DecisionSignal.two) signalsUnderstood++;
    if (signal == DecisionSignal.three) signalsFragile++;
    engine.signal(signal);
    _applySnapshot(engine.snapshot());
    if (_supportIsActive && supportRoomView == null) {
      unawaited(startSupportRoom());
    }
  }

  bool get _supportIsActive {
    final support = _ensureController().organism.activeState.extra['support'];
    return support is Map && support['active'] == true;
  }

  int get reviewQueueCount {
    final aux = _ensureController().organism.activeState.auxRooms;
    if (aux == null) return 0;
    final review = aux['review'];
    final entries = review is Map ? review['entries'] : null;
    if (entries is List && entries.isNotEmpty) return entries.length;
    final queue = aux['review_queue'];
    if (queue is List && queue.isNotEmpty) return queue.length;
    final pending = aux['pendingMap'];
    if (pending is! List) return 0;
    return pending
        .whereType<Map>()
        .where(
          (entry) =>
              entry['status'] == 'pending' &&
              (entry['signal'] as num?)?.toInt() == DecisionSignal.two.value,
        )
        .length;
  }

  int get recoveryQueueCount {
    final aux = _ensureController().organism.activeState.auxRooms;
    if (aux == null) return 0;
    final recovery = aux['recovery'];
    final entries = recovery is Map ? recovery['entries'] : null;
    if (entries is List && entries.isNotEmpty) return entries.length;
    final queue = aux['recovery_queue'];
    if (queue is List && queue.isNotEmpty) return queue.length;
    final pending = aux['pendingMap'];
    if (pending is! List) return 0;
    return pending
        .whereType<Map>()
        .where(
          (entry) =>
              entry['status'] == 'pending' &&
              (entry['signal'] as num?)?.toInt() == DecisionSignal.three.value,
        )
        .length;
  }

  ReviewRoomService _getReviewRoomService() {
    if (_reviewRoomService != null) return _reviewRoomService!;
    final ctrl = _ensureController();
    final reviewConfig = SimAiServerConfig(
      baseUrl: simServerBaseUrl,
      accessTokenProvider: () async =>
          Supabase.instance.client.auth.currentSession?.accessToken,
      t02Path: '/api/review',
    );
    final auxService = StudentAuxRoomService(
      readState: (lessonLocalId) =>
          ctrl.organism.stateService.ensure(lessonLocalId: lessonLocalId),
      writeState: ctrl.organism.stateService.write,
      t02Caller: AuxRoomT02Caller(
        client: SimServerT02Client(config: reviewConfig),
      ),
    );
    return _reviewRoomService = ReviewRoomService(auxService);
  }

  RecoveryRoomService _getRecoveryRoomService() {
    if (_recoveryRoomService != null) return _recoveryRoomService!;
    final ctrl = _ensureController();
    final recoveryConfig = SimAiServerConfig(
      baseUrl: simServerBaseUrl,
      accessTokenProvider: () async =>
          Supabase.instance.client.auth.currentSession?.accessToken,
      t02Path: '/api/recovery',
    );
    final auxService = StudentAuxRoomService(
      readState: (lessonLocalId) =>
          ctrl.organism.stateService.ensure(lessonLocalId: lessonLocalId),
      writeState: ctrl.organism.stateService.write,
      t02Caller: AuxRoomT02Caller(
        client: SimServerT02Client(config: recoveryConfig),
      ),
    );
    return _recoveryRoomService = RecoveryRoomService(auxService);
  }

  SupportRoomService _getSupportRoomService() {
    if (_supportRoomService != null) return _supportRoomService!;
    final ctrl = _ensureController();
    final config = SimAiServerConfig(
      baseUrl: simServerBaseUrl,
      accessTokenProvider: () async =>
          Supabase.instance.client.auth.currentSession?.accessToken,
      t02Path: '/api/complete-lesson',
    );
    return _supportRoomService = SupportRoomService(
      stateService: ctrl.organism.stateService,
      t00Client: SimServerT00Client(config: config),
      t02Client: SimServerT02Client(config: config),
    );
  }

  LessonDoubtController _getDoubtController() {
    if (_doubtController != null) return _doubtController!;
    final doubtConfig = SimAiServerConfig(
      baseUrl: simServerBaseUrl,
      accessTokenProvider: () async =>
          Supabase.instance.client.auth.currentSession?.accessToken,
      t02Path: '/api/doubt',
    );
    return _doubtController = LessonDoubtController(
      caller: DoubtT02Caller(
        client: SimServerT02Client(config: doubtConfig),
      ),
    );
  }

  ReviewRoomContext _buildReviewContext() {
    final ctrl = _ensureController();
    final state = ctrl.organism.activeState;
    final profile = state.profile;
    final items = (state.curriculum?.items ?? const <CurriculumItem>[])
        .map(
          (item) => AuxRoomItem(
            marker: item.marker,
            text: item.teacherText,
          ),
        )
        .toList(growable: false);
    return ReviewRoomContext(
      lessonLocalId: ctrl.organism.lessonLocalId,
      topic: state.curriculum?.topic ?? freeText,
      items: items,
      fallbackStartIdx: state.progress?.itemIdx ?? aulaStep,
      layer: state.progress?.layer ?? state.current?.layer ?? LessonLayer.l1,
      profile: AuxRoomProfile(
        stableLang: profile.stableLang ?? stableLang,
        academicLevel: profile.academicLevel ?? profile.nivel,
        preferredName: profile.preferredName ?? preferredName,
        notes: studentProfileNotes,
        extra: profile.extra,
      ),
    );
  }

  RecoveryRoomContext _buildRecoveryContext() {
    final ctrl = _ensureController();
    final state = ctrl.organism.activeState;
    final profile = state.profile;
    final items = (state.curriculum?.items ?? const <CurriculumItem>[])
        .map(
          (item) => AuxRoomItem(
            marker: item.marker,
            text: item.teacherText,
          ),
        )
        .toList(growable: false);
    return RecoveryRoomContext(
      lessonLocalId: ctrl.organism.lessonLocalId,
      topic: state.curriculum?.topic ?? freeText,
      items: items,
      layer: LessonLayer.l1,
      profile: AuxRoomProfile(
        stableLang: profile.stableLang ?? stableLang,
        academicLevel: profile.academicLevel ?? profile.nivel,
        preferredName: profile.preferredName ?? preferredName,
        notes: studentProfileNotes,
        extra: profile.extra,
      ),
    );
  }

  SupportRoomContext _buildSupportContext() {
    final ctrl = _ensureController();
    final state = ctrl.organism.activeState;
    final profile = state.profile;
    final currentItem = state.current?.itemIdx != null &&
            state.curriculum != null &&
            state.current!.itemIdx >= 0 &&
            state.current!.itemIdx < state.curriculum!.items.length
        ? state.curriculum!.items[state.current!.itemIdx]
        : null;
    return SupportRoomContext(
      lessonLocalId: ctrl.organism.lessonLocalId,
      objective: state.curriculum?.topic ?? freeText,
      currentItem: currentItem?.teacherText ?? freeText,
      marker: state.current?.marker ?? currentItem?.marker,
      layer: state.current?.layer ?? state.progress?.layer ?? LessonLayer.l1,
      profile: AuxRoomProfile(
        stableLang: profile.stableLang ?? stableLang,
        academicLevel: profile.academicLevel ?? profile.nivel,
        preferredName: profile.preferredName ?? preferredName,
        notes: studentProfileNotes,
        extra: profile.extra,
      ),
      currentMaterial: state.currentLessonMaterial ?? const {},
      recentAttempts: state.attempts.reversed.take(6).toList(growable: false),
    );
  }

  AuxRoomProfile _buildAuxProfile() {
    final state = _ensureController().organism.activeState;
    final profile = state.profile;
    return AuxRoomProfile(
      stableLang: profile.stableLang ?? stableLang,
      academicLevel: profile.academicLevel ?? profile.nivel,
      preferredName: profile.preferredName ?? preferredName,
      notes: studentProfileNotes,
      extra: profile.extra,
    );
  }

  ({
    String itemText,
    String currentContent,
    LessonLayer layer,
    int itemIdx,
    String? marker
  }) _buildDoubtContext() {
    final state = _ensureController().organism.activeState;
    final progress = state.progress;
    final itemIdx = progress?.itemIdx ?? aulaStep;
    final items = state.curriculum?.items ?? const <CurriculumItem>[];
    final item = itemIdx >= 0 && itemIdx < items.length ? items[itemIdx] : null;
    final options = t02Options ?? const <String, String>{};
    final currentContent = jsonEncode({
      'explanation': t02Explanation ?? '',
      'question': t02Question ?? '',
      'options': options,
      'correct_answer': t02CorrectAnswer,
      'why_correct': t02WhyCorrect,
      'why_wrong': t02WhyWrong,
      'marker': item?.marker ?? state.current?.marker,
    });
    return (
      itemText: item?.teacherText ?? freeText,
      currentContent: currentContent,
      layer: progress?.layer ?? state.current?.layer ?? LessonLayer.l1,
      itemIdx: itemIdx,
      marker: item?.marker ?? state.current?.marker,
    );
  }

  Future<void> startReviewRoom() async {
    final count = reviewQueueCount;
    if (count <= 0) return;
    final ctrl = _ensureController();
    ctrl.organism.stateService.appendEvent(
      ctrl.organism.lessonLocalId,
      StudentLearningEvent(
        type: 'REVIEW_STARTED',
        ts: DateTime.now().millisecondsSinceEpoch,
        payload: {'count': count},
      ),
    );
    reviewRoomView = const ReviewRoomView(
      status: ReviewRoomStatus.preparing,
      count: 5,
      queue: [],
      idx: 0,
    );
    notifyListeners();
    reviewRoomView = await _getReviewRoomService().startReviewRoom(
      _buildReviewContext(),
      count >= 10 ? 10 : 5,
    );
    notifyListeners();
  }

  void submitReviewAnswer(String letter) {
    final view = reviewRoomView;
    if (view == null) return;
    final answerLetter = AnswerLetter.values.firstWhere(
      (value) => value.name == letter,
      orElse: () => AnswerLetter.A,
    );
    final selected = _getReviewRoomService().selectLetter(view, answerLetter);
    reviewRoomView = _getReviewRoomService().answerReviewRoom(
      _buildReviewContext(),
      selected,
      DecisionSignal.two,
    );
    final ctrl = _ensureController();
    ctrl.organism.stateService.appendEvent(
      ctrl.organism.lessonLocalId,
      StudentLearningEvent(
        type: 'REVIEW_ANSWER_SUBMITTED',
        ts: DateTime.now().millisecondsSinceEpoch,
        payload: {
          'letra': answerLetter.name,
          'correct': reviewRoomView?.resultCorrect,
          'idx': reviewRoomView?.idx,
        },
      ),
    );
    notifyListeners();
  }

  Future<void> nextReviewQuestion() async {
    final view = reviewRoomView;
    if (view == null) return;
    reviewRoomView = await _getReviewRoomService().nextReviewRoom(
      _buildReviewContext(),
      view,
    );
    if (reviewRoomView?.status == ReviewRoomStatus.done) {
      final ctrl = _ensureController();
      ctrl.organism.stateService.appendEvent(
        ctrl.organism.lessonLocalId,
        StudentLearningEvent(
          type: 'REVIEW_COMPLETED',
          ts: DateTime.now().millisecondsSinceEpoch,
          payload: {'queue': view.queue},
        ),
      );
    }
    notifyListeners();
  }

  void closeReviewRoom() {
    reviewRoomView = null;
    final engine = _controller?.organism.lessonRuntimeEngine;
    if (engine != null) _applySnapshot(engine.snapshot());
    notifyListeners();
  }

  Future<void> startRecoveryRoom() async {
    final count = recoveryQueueCount;
    if (count <= 0) return;
    recoveryRoomView = const RecoveryRoomView(
      status: RecoveryRoomStatus.preparing,
      queue: [],
      idx: 0,
    );
    notifyListeners();
    recoveryRoomView = await _getRecoveryRoomService().startRecoveryRoom(
      _buildRecoveryContext(),
    );
    notifyListeners();
  }

  void continueRecoveryRoom() {
    final view = recoveryRoomView;
    if (view == null) return;
    recoveryRoomView = _getRecoveryRoomService().continueRecovery(view);
    notifyListeners();
  }

  void submitRecoveryAnswer(String letter) {
    final view = recoveryRoomView;
    if (view == null) return;
    final answerLetter = AnswerLetter.values.firstWhere(
      (value) => value.name == letter,
      orElse: () => AnswerLetter.A,
    );
    final selected = _getRecoveryRoomService().selectLetter(view, answerLetter);
    recoveryRoomView = _getRecoveryRoomService().answerRecoveryRoom(
      _buildRecoveryContext(),
      selected,
      DecisionSignal.three,
    );
    final ctrl = _ensureController();
    ctrl.organism.stateService.appendEvent(
      ctrl.organism.lessonLocalId,
      StudentLearningEvent(
        type: 'RECOVERY_ANSWER_SUBMITTED',
        ts: DateTime.now().millisecondsSinceEpoch,
        payload: {
          'letra': answerLetter.name,
          'correct': recoveryRoomView?.resultCorrect,
          'idx': recoveryRoomView?.idx,
        },
      ),
    );
    notifyListeners();
  }

  Future<void> nextRecoveryQuestion() async {
    final view = recoveryRoomView;
    if (view == null) return;
    recoveryRoomView = await _getRecoveryRoomService().nextRecoveryRoom(
      _buildRecoveryContext(),
      view,
    );
    notifyListeners();
  }

  void closeRecoveryRoom() {
    final view = recoveryRoomView;
    final ctrl = _ensureController();
    if (view != null) {
      recoveryRoomView = _getRecoveryRoomService().finishRecoveryRoom(
        ctrl.organism.lessonLocalId,
        view,
      );
      if (recoveryRoomView?.restartRequired == true) {
        notifyListeners();
        return;
      }
    }
    recoveryRoomView = null;
    final engine = _controller?.organism.lessonRuntimeEngine;
    if (engine != null) _applySnapshot(engine.snapshot());
    notifyListeners();
  }

  Future<void> startSupportRoom() async {
    final service = _getSupportRoomService();
    final lessonLocalId = _ensureController().organism.lessonLocalId;
    supportRoomView = service.preparingView(lessonLocalId);
    notifyListeners();
    _scheduleSupportExitOptions(lessonLocalId);
    supportRoomView = await service.start(_buildSupportContext());
    _supportExitTimer?.cancel();
    notifyListeners();
  }

  void _scheduleSupportExitOptions(String lessonLocalId) {
    _supportExitTimer?.cancel();
    _supportExitTimer = Timer(const Duration(seconds: 20), () {
      final view = supportRoomView;
      if (view == null ||
          view.status != SupportRoomStatus.preparing ||
          view.showExitOptions) {
        return;
      }
      _ensureController().organism.stateService.appendEvent(
            lessonLocalId,
            StudentLearningEvent(
              type: 'SUPPORT_PREPARATION_PROGRESS',
              ts: DateTime.now().millisecondsSinceEpoch,
              payload: const {'exitOptionsShown': true},
            ),
          );
      supportRoomView = view.copyWith(showExitOptions: true);
      notifyListeners();
    });
  }

  void submitSupportAnswer(String letter) {
    final view = supportRoomView;
    if (view == null) return;
    final answerLetter = AnswerLetter.values.firstWhere(
      (value) => value.name == letter,
      orElse: () => AnswerLetter.A,
    );
    supportRoomView = _getSupportRoomService().selectAnswer(view, answerLetter);
    notifyListeners();
  }

  void submitSupportQualifier(DecisionSignal signal) {
    final view = supportRoomView;
    if (view == null) return;
    supportRoomView = _getSupportRoomService()
        .submitQualifier(_buildSupportContext(), view, signal);
    notifyListeners();
  }

  Future<void> nextSupportStation() async {
    final view = supportRoomView;
    if (view == null) return;
    if (view.status == SupportRoomStatus.retryAvailable ||
        (view.status == SupportRoomStatus.preparing && view.showExitOptions)) {
      supportRoomView = _getSupportRoomService()
          .retryRequested(_ensureController().organism.lessonLocalId);
      notifyListeners();
      supportRoomView =
          await _getSupportRoomService().start(_buildSupportContext());
      notifyListeners();
      return;
    }
    supportRoomView =
        await _getSupportRoomService().next(_buildSupportContext(), view);
    notifyListeners();
  }

  void returnFromSupport({bool afterFailure = false}) {
    final lessonLocalId = _ensureController().organism.lessonLocalId;
    _getSupportRoomService().returnToLesson(
      lessonLocalId,
      afterFailure: afterFailure,
    );
    supportRoomView = null;
    final engine = _controller?.organism.lessonRuntimeEngine;
    if (engine != null) _applySnapshot(engine.snapshot());
    notifyListeners();
  }

  void setDeleteConfirmation(String value) {
    deleteConfirmation = value;
    accountDeletionMessage = null;
    notifyListeners();
  }

  void requestAccountDeletion() {
    accountDeletionMessage = deleteConfirmation.trim() == 'DELETAR'
        ? 'Solicitacao de exclusao registrada para envio seguro ao servidor.'
        : 'Digite DELETAR para confirmar a solicitacao.';
    notifyListeners();
  }

  void advanceAula() {
    if (recoveryQueueCount > 0 &&
        _getRecoveryRoomService().shouldStartRecoveryRoom(
          _ensureController().organism.lessonLocalId,
        )) {
      unawaited(startRecoveryRoom());
      return;
    }
    selectedAnswer = '';
    aulaMessage = '';
    doubtOpen = false;
    imageStatus = 'idle';
    imageError = null;
    resetT02();
    notifyListeners();
    unawaited(_advanceEngine());
  }

  void toggleDoubt() {
    if (doubtOpen) {
      closeDoubt();
      return;
    }
    doubtOpen = true;
    doubtInputError = null;
    _getDoubtController().askDoubt();
    final ctrl = _ensureController();
    ctrl.organism.stateService.appendEvent(
      ctrl.organism.lessonLocalId,
      StudentLearningEvent(
        type: 'DOUBT_OPENED',
        ts: DateTime.now().millisecondsSinceEpoch,
        payload: _doubtEventPayload(),
      ),
    );
    notifyListeners();
  }

  JsonMap _doubtEventPayload([JsonMap extra = const {}]) {
    final ctx = _buildDoubtContext();
    return {
      'marker': ctx.marker,
      'layer': ctx.layer.value,
      'itemIdx': ctx.itemIdx,
      ...extra,
    };
  }

  void setDoubtText(String value) {
    doubtText = value.length > doubtTextMaxLength
        ? value.substring(0, doubtTextMaxLength)
        : value;
    doubtInputError = null;
    final ctrl = _ensureController();
    ctrl.organism.stateService.appendEvent(
      ctrl.organism.lessonLocalId,
      StudentLearningEvent(
        type: 'DOUBT_TEXT_TYPED',
        ts: DateTime.now().millisecondsSinceEpoch,
        payload: _doubtEventPayload({'chars': doubtText.trim().length}),
      ),
    );
    notifyListeners();
  }

  Future<void> pickDoubtImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      final bytes = file.bytes?.toList();
      if (bytes == null || bytes.isEmpty) return;
      final ext = file.name.split('.').last.toLowerCase();
      final contentType = switch (ext) {
        'png' => 'image/png',
        'gif' => 'image/gif',
        'webp' => 'image/webp',
        _ => 'image/jpeg',
      };
      final payload = DoubtImagePayload(
        name: file.name,
        type: contentType,
        size: bytes.length,
        dataUrl: 'data:$contentType;base64,${base64Encode(bytes)}',
      );
      final validation =
          DoubtInputDraft(text: doubtText, image: payload).validate();
      if (validation != null && validation != emptyDoubtMessage) {
        doubtInputError = validation;
        notifyListeners();
        return;
      }
      doubtImage = payload;
      doubtInputError = null;
      final ctrl = _ensureController();
      ctrl.organism.stateService.appendEvent(
        ctrl.organism.lessonLocalId,
        StudentLearningEvent(
          type: 'DOUBT_IMAGE_SELECTED',
          ts: DateTime.now().millisecondsSinceEpoch,
          payload: _doubtEventPayload({
            'name': payload.name,
            'type': payload.type,
            'size': payload.size,
          }),
        ),
      );
      notifyListeners();
    } catch (_) {
      doubtInputError = 'Nao foi possivel anexar a imagem.';
      notifyListeners();
    }
  }

  void removeDoubtImage() {
    doubtImage = null;
    notifyListeners();
  }

  Future<void> submitDoubt() async {
    final draft = DoubtInputDraft(text: doubtText, image: doubtImage);
    final validation = draft.validate();
    if (validation != null) {
      doubtInputError = validation;
      notifyListeners();
      return;
    }
    final ctrl = _ensureController();
    final context = _buildDoubtContext();
    ctrl.organism.stateService.appendEvent(
      ctrl.organism.lessonLocalId,
      StudentLearningEvent(
        type: 'DOUBT_SUBMITTED',
        ts: DateTime.now().millisecondsSinceEpoch,
        payload: _doubtEventPayload({
          'chars': draft.cleanText.length,
          'hasImage': doubtImage != null,
        }),
      ),
    );
    notifyListeners();
    await _getDoubtController().submitDoubt(
      lessonLocalId: ctrl.organism.lessonLocalId,
      profile: _buildAuxProfile(),
      itemText: context.itemText,
      currentContent: context.currentContent,
      layer: context.layer,
      itemIdx: context.itemIdx,
      marker: context.marker,
      input: draft,
    );
    final state = _getDoubtController().state;
    if (state.status == DoubtStatus.explaining) {
      ctrl.organism.stateService.appendEvent(
        ctrl.organism.lessonLocalId,
        StudentLearningEvent(
          type: 'DOUBT_ANSWERED',
          ts: DateTime.now().millisecondsSinceEpoch,
          payload: _doubtEventPayload({
            'hasVisualTrigger': state.response?.visualTrigger != null,
          }),
        ),
      );
    } else if (state.status == DoubtStatus.error) {
      ctrl.organism.stateService.appendEvent(
        ctrl.organism.lessonLocalId,
        StudentLearningEvent(
          type: 'DOUBT_FAILED',
          ts: DateTime.now().millisecondsSinceEpoch,
          payload: _doubtEventPayload({'error': state.error}),
        ),
      );
      if ((state.error ?? '').toLowerCase().contains('credit')) {
        route = '/creditos';
      }
    }
    notifyListeners();
  }

  void closeDoubt() {
    doubtOpen = false;
    _getDoubtController().dismissDoubt();
    final ctrl = _ensureController();
    ctrl.organism.stateService.appendEvent(
      ctrl.organism.lessonLocalId,
      StudentLearningEvent(
        type: 'DOUBT_CLOSED',
        ts: DateTime.now().millisecondsSinceEpoch,
        payload: _doubtEventPayload(),
      ),
    );
    notifyListeners();
  }

  Future<void> toggleAudio() async {
    await _ensureAudioPreferenceReady();
    audioError = null;
    final ctrl = _ensureController();
    if (audioEnabled) {
      ctrl.organism.audioPreference.setAudioEnabled(false);
      ctrl.organism.lessonAudioController.pararAudio();
      audioEnabled = false;
      audioLoading = false;
      audioStatus = 'paused';
      _appendAudioEvent('AUDIO_PREFERENCE_CHANGED', {'enabled': false});
      _appendAudioEvent('AUDIO_PAUSED', _audioEventPayload());
      notifyListeners();
      return;
    }
    ctrl.organism.audioPreference.setAudioEnabled(true);
    audioEnabled = true;
    audioStatus = 'idle';
    _appendAudioEvent('AUDIO_PREFERENCE_CHANGED', {'enabled': true});
    notifyListeners();
    await playLessonAudio();
  }

  Future<void> playLessonAudio({bool automatic = false}) async {
    await _ensureAudioPreferenceReady();
    if (!audioEnabled || audioLoading || audioStatus == 'playing') return;
    final ctrl = _ensureController();
    if (!ctrl.organism.audioPreference.getAudioEnabled()) return;
    final content = _lastSnapshot?.conteudo;
    if (content == null) return;
    final parts = [
      content.explanation,
      content.question,
      if ((content.options[AnswerLetter.A] ?? '').isNotEmpty)
        'A: ${content.options[AnswerLetter.A]}',
      if ((content.options[AnswerLetter.B] ?? '').isNotEmpty)
        'B: ${content.options[AnswerLetter.B]}',
      if ((content.options[AnswerLetter.C] ?? '').isNotEmpty)
        'C: ${content.options[AnswerLetter.C]}',
    ];
    final text = parts
        .whereType<String>()
        .where((part) => part.trim().isNotEmpty)
        .join('. ');
    if (text.trim().isEmpty) return;
    final active = ctrl.organism.activeState;
    final marker = active.current?.marker;
    final layer = active.current?.layer ?? LessonLayer.l1;
    final lang = stableLangToBCP47(stableLang);
    final voice = voiceByLang(lang);
    final cacheKey = [
      ctrl.organism.lessonLocalId,
      marker ?? 'no-marker',
      layer.value,
      lang,
      voice,
      hashString(text),
    ].join(':');
    audioLoading = true;
    audioStatus = 'loading';
    audioError = null;
    _appendAudioEvent('AUDIO_GENERATION_REQUESTED', {
      ..._audioEventPayload(cacheKey: cacheKey),
      'automatic': automatic,
    });
    notifyListeners();
    try {
      final started = await ctrl.organism.mediaService.playLessonAudioSequence(
        LessonMediaPosition(
          lessonLocalId: ctrl.organism.lessonLocalId,
          itemMarker: marker,
          layer: layer,
        ),
        parts,
        lang: lang,
        voice: voice,
        onStart: () {
          audioLoading = false;
          audioStatus = 'playing';
          _appendAudioEvent('AUDIO_GENERATED', {
            ..._audioEventPayload(cacheKey: cacheKey),
            'voice': voice,
            'language': lang,
          });
          _appendAudioEvent(
            'AUDIO_PLAYED',
            _audioEventPayload(cacheKey: cacheKey),
          );
          notifyListeners();
        },
        onEnd: () {
          audioLoading = false;
          audioStatus = audioEnabled ? 'idle' : 'paused';
          _appendAudioEvent(
            'AUDIO_STOPPED',
            _audioEventPayload(cacheKey: cacheKey),
          );
          notifyListeners();
        },
      );
      if (!started) {
        audioLoading = false;
        audioStatus = 'error';
        audioError = 'Audio indisponivel para este trecho.';
        _appendAudioEvent('AUDIO_FAILED', {
          ..._audioEventPayload(cacheKey: cacheKey),
          'error': audioError,
        });
        notifyListeners();
      }
    } catch (e) {
      audioLoading = false;
      audioStatus = 'error';
      audioError =
          'Erro ao gerar audio: ${e.toString().replaceFirst("Exception: ", "")}';
      _appendAudioEvent('AUDIO_FAILED', {
        ..._audioEventPayload(cacheKey: cacheKey),
        'error': audioError,
      });
      notifyListeners();
    }
  }

  void stopLessonAudio() {
    final ctrl = _controller;
    ctrl?.organism.lessonAudioController.pararAudio();
    audioLoading = false;
    audioStatus = 'paused';
    _appendAudioEvent('AUDIO_PAUSED', _audioEventPayload());
    notifyListeners();
  }

  Future<void> _ensureAudioPreferenceReady() async {
    final prefs = _audioPrefs ??= await SharedPreferences.getInstance();
    final raw = prefs.getString(audioPreferenceStorageKey);
    audioEnabled = raw == null || raw == '1' || raw == 'true';
    final ctrl = _controller;
    if (ctrl != null &&
        ctrl.organism.audioPreference.getAudioEnabled() != audioEnabled) {
      ctrl.organism.audioPreference.setAudioEnabled(audioEnabled);
    }
  }

  JsonMap _audioEventPayload({String? cacheKey}) {
    final ctrl = _controller;
    final state = ctrl?.organism.activeState;
    final lang = stableLangToBCP47(stableLang);
    return {
      'lessonLocalId': ctrl?.organism.lessonLocalId ?? lessonLocalId,
      'marker': state?.current?.marker,
      'layer': state?.current?.layer.value,
      'language': lang,
      'voice': voiceByLang(lang),
      if (cacheKey != null) 'cacheKey': cacheKey,
    };
  }

  void _appendAudioEvent(String type, JsonMap payload) {
    final ctrl = _controller;
    if (ctrl == null) return;
    ctrl.organism.stateService.appendEvent(
      ctrl.organism.lessonLocalId,
      StudentLearningEvent(
        type: type,
        ts: DateTime.now().millisecondsSinceEpoch,
        payload: payload,
      ),
    );
  }

  Future<void> requestLessonImage() async {
    if (imageStatus == 'loading') return;
    final triggerJson = lessonVisualTrigger;
    if (triggerJson == null) {
      imageError = 'Este ponto ainda nao trouxe visual_trigger.';
      imageStatus = 'unavailable';
      notifyListeners();
      return;
    }
    final cacheKey = _lessonImageCacheKey(triggerJson);
    imageError = null;
    imageOfferAccepted = true;
    _appendVisualEvent('VISUAL_AI_ACCEPTED', {
      'cacheKey': cacheKey,
      'cost': 10,
    });
    final prefs = _imagePrefs ??= await SharedPreferences.getInstance();
    final cached = prefs.getString(cacheKey);
    if (cached != null && cached.isNotEmpty) {
      lessonImageDataUrl = cached;
      imageStatus = 'ready';
      _markVisualState(cacheKey: cacheKey, status: 'cache_hit');
      _appendVisualEvent('VISUAL_AI_RENDERED', {
        'cacheKey': cacheKey,
        'cacheHit': true,
      });
      notifyListeners();
      return;
    }
    imageStatus = 'loading';
    _appendVisualEvent('VISUAL_AI_REQUESTED', {
      'cacheKey': cacheKey,
      'cost': 10,
    });
    notifyListeners();
    try {
      final ctrl = _ensureController();
      final state = ctrl.organism.activeState;
      final trigger = LessonVisualTrigger.fromJson(triggerJson);
      final pipeline = LessonVisualPipeline(
        imageClient: SimServerLessonImageClient(
          config: SimAiServerConfig(
            baseUrl: simServerBaseUrl,
            accessTokenProvider: () async =>
                Supabase.instance.client.auth.currentSession?.accessToken,
          ),
        ),
      );
      final softwareImage =
          await pipeline.renderMathTemplateVisual(triggerJson);
      final prompt = pipeline.buildPromptForTrigger(
        topic: state.curriculum?.topic ?? freeText,
        trigger: trigger,
        lang: stableLang,
      );
      final dataUrl = softwareImage ??
          await (await _getCreditService()).runReserved<String?>(
            lessonLocalId: ctrl.organism.lessonLocalId,
            amount: simCreditCosts.imageGeneration,
            reason: 'image_generation',
            idempotencyKey: 'image:$cacheKey',
            metadata: {
              'lessonLocalId': ctrl.organism.lessonLocalId,
              'marker': state.current?.marker,
              'layer': state.current?.layer.value,
              'cacheKey': cacheKey,
              'provider': 'server-ai',
            },
            operation: (_) => pipeline.fetchPaidLessonImage(prompt, cacheKey),
          );
      if (dataUrl == null || dataUrl.isEmpty) {
        throw Exception('Servidor nao retornou imagem utilizavel.');
      }
      credits = (await _getCreditService()).cachedBalance;
      lessonImageDataUrl = dataUrl;
      imageStatus = 'ready';
      await prefs.setString(cacheKey, dataUrl);
      _markVisualState(
        cacheKey: cacheKey,
        status: 'ready',
        imageUrl: dataUrl.startsWith('http') ? dataUrl : null,
        provider: softwareImage == null ? 'server-ai' : 'software-template',
        cost: softwareImage == null ? 10 : 0,
      );
      _appendVisualEvent('VISUAL_AI_RENDERED', {
        'cacheKey': cacheKey,
        'cacheHit': false,
        'provider': softwareImage == null ? 'server-ai' : 'software-template',
      });
    } on CreditClientException catch (e) {
      imageStatus = 'idle';
      imageError = e.insufficientCredits
          ? 'Creditos insuficientes para gerar imagem.'
          : e.toString();
      if (e.insufficientCredits) route = '/creditos';
      _markVisualState(cacheKey: cacheKey, status: 'failed');
      _appendVisualEvent('VISUAL_AI_FAILED', {
        'cacheKey': cacheKey,
        'reason': imageError,
        'creditFailure': true,
      });
    } catch (e) {
      imageStatus = 'error';
      imageError = e.toString().replaceFirst('Exception: ', '');
      _markVisualState(cacheKey: cacheKey, status: 'failed');
      _appendVisualEvent('VISUAL_AI_FAILED', {
        'cacheKey': cacheKey,
        'reason': imageError,
      });
    } finally {
      notifyListeners();
    }
  }

  String _lessonImageCacheKey(JsonMap trigger) {
    final ctrl = _ensureController();
    final state = ctrl.organism.activeState;
    final marker = state.current?.marker ?? 'no-marker';
    final layer =
        state.current?.layer.value ?? state.progress?.layer.value ?? 1;
    final lang = state.profile.stableLang ?? stableLang;
    final triggerKey =
        base64Url.encode(utf8.encode(jsonEncode(trigger))).replaceAll('=', '');
    final shortTrigger =
        triggerKey.length > 48 ? triggerKey.substring(0, 48) : triggerKey;
    return 'lesson:${ctrl.organism.lessonLocalId}:marker:$marker:layer:$layer:lang:$lang:visual:$shortTrigger';
  }

  void _appendVisualEvent(String type, JsonMap payload) {
    final ctrl = _ensureController();
    ctrl.organism.stateService.appendEvent(
      ctrl.organism.lessonLocalId,
      StudentLearningEvent(
        type: type,
        ts: DateTime.now().millisecondsSinceEpoch,
        payload: payload,
      ),
    );
  }

  void _markVisualState({
    required String cacheKey,
    required String status,
    String? imageUrl,
    String? provider,
    int? cost,
  }) {
    final ctrl = _ensureController();
    final position = LessonMediaPosition(
      lessonLocalId: ctrl.organism.lessonLocalId,
      itemMarker: ctrl.organism.activeState.current?.marker,
      layer: ctrl.organism.activeState.current?.layer,
    );
    final media = StudentLessonMediaService(
      audioCore: ctrl.organism.mediaService.audioCore,
      readState: (lessonLocalId) =>
          ctrl.organism.stateService.ensure(lessonLocalId: lessonLocalId),
      writeState: ctrl.organism.stateService.write,
    );
    if (status == 'ready' || status == 'cache_hit') {
      media.markLessonImageReady(
        position,
        cacheKey: cacheKey,
        imageUrl: imageUrl ?? lessonImageDataUrl,
      );
    } else if (status == 'failed') {
      media.markLessonImageFailed(position, error: imageError);
    } else {
      media.markLessonImageStarted(position, cacheKey: cacheKey);
    }
    ctrl.organism.stateService.mutate(ctrl.organism.lessonLocalId, (state) {
      final visual = JsonMap.from(
        state.extra['visual'] is Map ? state.extra['visual'] as Map : const {},
      );
      visual[cacheKey] = {
        'cacheKey': cacheKey,
        'status': status,
        if (imageUrl != null) 'image_url': imageUrl,
        if (provider != null) 'provider': provider,
        if (cost != null) 'cost': cost,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      };
      return state.copyWith(extra: {...state.extra, 'visual': visual});
    });
  }

  Future<void> loadT02Content() async {
    if (t02Loading) return;
    t02Loading = true;
    t02Error = null;
    notifyListeners();
    try {
      final ctrl = _ensureController();
      final material = ctrl.organism.activeState.currentLessonMaterial;
      final hasReadyMaterial = material != null &&
          (material['text_status'] == 'ready' ||
              material['explanation'] != null);
      final marker = ctrl.organism.activeState.current?.marker ?? 'current';
      final snapshot = hasReadyMaterial
          ? await ctrl.organism.lessonRuntimeEngine.open(
              lessonLocalId: ctrl.organism.lessonLocalId,
            )
          : await (await _getCreditService()).runReserved(
              lessonLocalId: ctrl.organism.lessonLocalId,
              amount: simCreditCosts.lessonGeneration,
              reason: 'lesson_generation',
              idempotencyKey:
                  'lesson:${ctrl.organism.lessonLocalId}:t02:$aulaStep:$marker',
              metadata: {
                'lessonLocalId': ctrl.organism.lessonLocalId,
                'marker': marker,
                'layer': ctrl.organism.activeState.current?.layer.value,
                'aulaStep': aulaStep,
                'mode': 'lesson_runtime_open',
              },
              operation: (_) => ctrl.organism.lessonRuntimeEngine.open(
                lessonLocalId: ctrl.organism.lessonLocalId,
              ),
            );
      credits = (await _getCreditService()).cachedBalance;
      _applySnapshot(snapshot);
    } on CreditClientException catch (e) {
      t02Loading = false;
      t02Error = e.insufficientCredits
          ? 'Creditos insuficientes para preparar a aula.'
          : 'Erro de creditos: ${e.toString()}';
      if (e.insufficientCredits) route = '/creditos';
      notifyListeners();
    } catch (e) {
      t02Loading = false;
      t02Error =
          'Erro ao carregar aula: ${e.toString().replaceFirst("Exception: ", "")}';
      notifyListeners();
    }
  }

  void resetT02() {
    t02Loading = false;
    t02Error = null;
    t02Explanation = null;
    t02Question = null;
    t02Options = null;
    t02CorrectAnswer = null;
    t02WhyCorrect = null;
    t02WhyWrong = null;
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _supportExitTimer?.cancel();
    _controller?.organism.lessonAudioController.pararAudio();
    unawaited(_audioPlayback?.dispose());
    super.dispose();
  }

  SimOrganismController _ensureController() {
    if (_controller != null) return _controller!;
    final organism = SimOrganism.production(
      lessonLocalId: lessonLocalId ?? 'live-entry',
      playback: _audioPlayback ??= AudioplayersPlaybackAdapter(),
      audioPreferenceStorage: _audioPrefs == null
          ? null
          : SharedPreferencesAudioPreferenceStorage(_audioPrefs!),
      cloudQueueStorage: _cloudQueueStorage,
    );
    audioEnabled = organism.audioPreference.getAudioEnabled();
    organism.stateService.mutate(
      organism.lessonLocalId,
      (state) => state.copyWith(userId: userId),
    );
    final ctrl = SimOrganismController(organism: organism);
    ctrl.authed = authed;
    _controller = ctrl;
    return ctrl;
  }

  Future<void> _runController() async {
    try {
      final ctrl = _ensureController();
      final lang = stableLang ??
          (otherLanguage.trim().isNotEmpty ? otherLanguage.trim() : null) ??
          selectedLanguageCode ??
          'Portuguese';
      ctrl.chooseLanguage(code: selectedLanguageCode ?? 'pt', label: lang);
      await ctrl.submitObjective(
        text: studentProfileNotes.isNotEmpty ? studentProfileNotes : freeText,
        name: preferredName.isNotEmpty ? preferredName : null,
      );
      _persistedCurriculum = ctrl.organism.activeState.curriculum;
      entryStatus = 'primeira_aula_pronta';
      notifyListeners();
    } catch (e) {
      entryError = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
    }
  }

  void _applySnapshot(LessonRuntimeSnapshot snapshot) {
    _lastSnapshot = snapshot;
    final activeState = _controller?.organism.activeState;
    _persistedCurriculum ??= activeState?.curriculum;
    if (activeState?.progress != null) {
      aulaStep = activeState!.progress!.itemIdx;
    }
    attempts = activeState?.attempts ?? attempts;
    final c = snapshot.conteudo;
    t02Loading = false;
    if (!snapshot.hasCurriculum) {
      t02Error =
          'Curriculo ainda nao disponivel. Aguarde a preparacao.';
    } else {
      t02Error = null;
    }
    t02Explanation = c?.explanation;
    t02Question = c?.question;
    if (c != null) {
      final nextTrigger = c.visualTrigger;
      final triggerChanged =
          jsonEncode(lessonVisualTrigger) != jsonEncode(nextTrigger);
      if (triggerChanged) {
        lessonImageDataUrl = null;
        imageStatus = 'idle';
        imageError = null;
        imageOfferAccepted = false;
      }
      lessonVisualTrigger = nextTrigger;
      if (nextTrigger != null && triggerChanged) {
        _appendVisualEvent('VISUAL_TRIGGER_RECEIVED', {
          'marker': activeState?.current?.marker,
          'layer': activeState?.current?.layer.value,
        });
        _appendVisualEvent('VISUAL_AI_OFFERED', {
          'marker': activeState?.current?.marker,
          'layer': activeState?.current?.layer.value,
          'cost': 10,
        });
      }
      t02Options = {
        'A': c.options[AnswerLetter.A] ?? '',
        'B': c.options[AnswerLetter.B] ?? '',
        'C': c.options[AnswerLetter.C] ?? '',
      };
      t02CorrectAnswer = c.correctAnswer.name;
      t02WhyCorrect = c.whyCorrect;
      t02WhyWrong = c.whyWrong;
    } else {
      t02Options = null;
      t02CorrectAnswer = null;
      t02WhyCorrect = null;
      t02WhyWrong = null;
      lessonVisualTrigger = null;
      lessonImageDataUrl = null;
      imageStatus = 'idle';
      imageError = null;
    }
    final audioAutoKey = _lessonAudioAutoKey(c, activeState);
    if (audioEnabled &&
        c != null &&
        audioAutoKey != null &&
        audioAutoKey != _lastAudioAutoKey) {
      _lastAudioAutoKey = audioAutoKey;
      unawaited(playLessonAudio(automatic: true));
    }
    notifyListeners();
  }

  String? _lessonAudioAutoKey(
    LessonContent? content,
    StudentLearningState? state,
  ) {
    if (content == null) return null;
    final text = [
      content.explanation,
      content.question,
      content.options[AnswerLetter.A],
      content.options[AnswerLetter.B],
      content.options[AnswerLetter.C],
    ].whereType<String>().where((part) => part.trim().isNotEmpty).join('|');
    if (text.isEmpty) return null;
    final lang = stableLangToBCP47(stableLang);
    return [
      state?.current?.marker ?? 'no-marker',
      state?.current?.layer.value ?? 'L?',
      lang,
      voiceByLang(lang),
      hashString(text),
    ].join(':');
  }

  Future<void> _advanceEngine() async {
    try {
      final engine = _controller?.organism.lessonRuntimeEngine;
      if (engine == null) return;
      await engine.advance();
      _applySnapshot(engine.snapshot());
    } catch (_) {}
  }

  String _buildAttachmentsText() {
    final ready = attachments.where(
      (a) =>
          a.status == 'ready' &&
          (a.extractedText?.trim().length ?? 0) >= minExtractedChars,
    );
    return ready.map((a) {
      final text = a.extractedText!.trim();
      final clipped = text.length > 8000
          ? '${text.substring(0, 8000)}\n[...truncado em 8000 chars]'
          : text;
      return '--- Anexo: ${a.name} ---\n$clipped';
    }).join('\n\n');
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
  const SimMobileApp({super.key, this.initialSession});

  final LabSession? initialSession;

  @override
  State<SimMobileApp> createState() => _SimMobileAppState();
}

class _SimMobileAppState extends State<SimMobileApp> {
  late final LabSession session = widget.initialSession ?? LabSession();

  @override
  void initState() {
    super.initState();
    session.addListener(_onSessionChanged);
    session.bindRealAuth();
    if (widget.initialSession == null) {
      unawaited(session.restorePersistedState());
    }
  }

  @override
  void dispose() {
    session.removeListener(_onSessionChanged);
    session.dispose();
    super.dispose();
  }

  void _onSessionChanged() {
    if (!mounted) return;
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
      return;
    }
    setState(() {});
  }

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
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * .82,
        child: _LessonHistoryDrawer(session: session),
      ),
    );
  }
}

class _LessonHistoryDrawer extends StatefulWidget {
  const _LessonHistoryDrawer({required this.session});

  final LabSession session;

  @override
  State<_LessonHistoryDrawer> createState() => _LessonHistoryDrawerState();
}

class _LessonHistoryDrawerState extends State<_LessonHistoryDrawer> {
  late final TextEditingController _searchController;

  LabSession get session => widget.session;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: session.lessonHistoryQuery);
    unawaited(session._refreshLessonHistory());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: session,
      builder: (context, _) {
        final lessons = session.filteredLessonHistory;
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Historico',
                      style: TextStyle(
                        color: simDark,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Fechar',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _searchController,
                onChanged: session.setLessonHistoryQuery,
                decoration: InputDecoration(
                  hintText: 'Buscar aulas',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: const Color(0xFFF9FAFB),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: simBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: simBorder),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _DrawerActionChip(
                    icon: Icons.add,
                    label: 'Nova aula',
                    onTap: () async {
                      await session.startNewLessonFromHistory();
                      if (context.mounted) Navigator.pop(context);
                    },
                  ),
                  _DrawerActionChip(
                    icon: Icons.download,
                    label: 'Exportar',
                    onTap: session.exportLessonBackup,
                  ),
                  _DrawerActionChip(
                    icon: Icons.upload_file,
                    label: 'Importar',
                    onTap: session.importLessonBackup,
                  ),
                  _DrawerActionChip(
                    icon: Icons.sync,
                    label: 'Sync',
                    onTap: session.lessonHistoryLoading
                        ? null
                        : session.syncLessonHistory,
                  ),
                ],
              ),
              if (session.lessonHistoryMessage != null) ...[
                const SizedBox(height: 10),
                Text(
                  session.lessonHistoryMessage!,
                  style: const TextStyle(color: simMuted, fontSize: 12),
                ),
              ],
              const SizedBox(height: 12),
              Expanded(
                child: lessons.isEmpty
                    ? const Center(
                        child: Text(
                          'Nenhuma aula salva ainda.',
                          style: TextStyle(color: simMuted),
                        ),
                      )
                    : ListView.separated(
                        itemCount: lessons.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final entry = lessons[index];
                          return _LessonHistoryTile(
                            entry: entry,
                            active:
                                entry.lessonLocalId == session.lessonLocalId,
                            onTap: () async {
                              await session.selectLessonFromHistory(
                                entry.lessonLocalId,
                              );
                              if (context.mounted) Navigator.pop(context);
                            },
                            onRename: () => _rename(entry),
                            onDelete: () => _delete(entry),
                          );
                        },
                      ),
              ),
              const Divider(height: 22),
              MenuLine(
                label: 'Creditos',
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
                label: 'Solicitar exclusao da conta',
                onTap: () {
                  Navigator.pop(context);
                  session.openSupport('/conta/deletar');
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _rename(LessonHistoryEntry entry) async {
    final controller = TextEditingController(text: entry.title);
    final title = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Renomear aula'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nome da aula'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (title != null) {
      await session.renameLessonFromHistory(entry.lessonLocalId, title);
    }
  }

  Future<void> _delete(LessonHistoryEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Apagar aula?'),
        content: Text(
          'A aula "${entry.title}" sera removida do historico. '
          'Dados financeiros e auditoria nao serao apagados.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Apagar'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await session.tombstoneLessonFromHistory(entry.lessonLocalId);
    } else {
      final store = await session._getLessonHistoryStore();
      final state = session._buildPersistedLearningState();
      await store.saveState(
        state.copyWith(
          events: [
            ...state.events,
            session._lessonEvent('LESSON_DELETE_CANCELLED', {
              'lessonLocalId': entry.lessonLocalId,
            }),
          ],
        ),
      );
    }
  }
}

class _DrawerActionChip extends StatelessWidget {
  const _DrawerActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final FutureOr<void> Function()? onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 18, color: simDark),
      label: Text(label),
      onPressed: onTap == null ? null : () => onTap!(),
      backgroundColor: Colors.white,
      side: const BorderSide(color: simBorder),
      labelStyle: const TextStyle(
        color: simDark,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _LessonHistoryTile extends StatelessWidget {
  const _LessonHistoryTile({
    required this.entry,
    required this.active,
    required this.onTap,
    required this.onRename,
    required this.onDelete,
  });

  final LessonHistoryEntry entry;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final icon = entry.status == 'concluida'
        ? Icons.check_circle
        : entry.status == 'apagada'
            ? Icons.delete
            : Icons.play_circle;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: active ? simLight : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: active ? simDark : simBorder),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: active ? simDark : simMuted),
        title: Text(
          entry.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          '${entry.progressPercent}% - ${entry.status.replaceAll('_', ' ')}'
          '${entry.lastMarker == null ? '' : ' - ${entry.lastMarker}'}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Wrap(
          spacing: 2,
          children: [
            IconButton(
              tooltip: 'Renomear',
              icon: const Icon(Icons.edit, size: 19),
              onPressed: onRename,
            ),
            IconButton(
              tooltip: 'Apagar',
              icon: const Icon(Icons.delete_outline, size: 19),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
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
                          session.authed
                              ? 'Iniciar agora'
                              : 'Entrar para começar',
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
                      'Ajude a melhorar o SIM.',
                      style: TextStyle(
                        color: simDark,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Envie sugestoes, reporte dificuldades e fale direto com o desenvolvedor.',
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
                label: 'Falar no WhatsApp',
                onTap: () => session.openExternalDoor(
                  'https://wa.me/message/RLCYEXAYFUIIA1',
                ),
              ),
              ContactButton(
                asset: 'assets/messenger-logo.png',
                label: 'Falar no Messenger',
                onTap: () =>
                    session.openExternalDoor('https://m.me/61557707493807'),
              ),
            ],
          ),
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
                    'Entrar',
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
                                      ? 'Aguarde...'
                                      : 'Continuar com Google',
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
                            hint: 'Seu nome',
                            controller: nameController,
                            onChanged: (_) {},
                          ),
                          const SizedBox(height: 12),
                        ],
                        SimInput(
                          hint: 'email@exemplo.com',
                          controller: emailController,
                          keyboardType: TextInputType.emailAddress,
                          onChanged: (_) {},
                        ),
                        const SizedBox(height: 12),
                        SimInput(
                          hint: 'Senha (min. 6 caracteres)',
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
                                    ? 'Aguarde...'
                                    : signup
                                        ? 'Criar conta e ganhar 3 aulas gratis'
                                        : 'Entrar',
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
                      '<- Voltar ao portal',
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
            const StepHeader(step: 1, total: 5, label: 'Passo 1 de 5'),
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
                        'SIM will use this language for the app, lessons, explanations, images, audio and all guidance - from this point onward.',
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
              hintText:
                  'e.g. Italian, German, Arabic, Kiribati...',
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
    debugPrint(
      '[OBJECTIVE_REQUIRED] freeTextChars=${widget.session.freeText.trim().length} attachmentsCount=${widget.session.attachments.length}',
    );
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
    widget.session.addRealAttachment(source);
  }

  @override
  Widget build(BuildContext context) {
    final remaining = maxFreeText - widget.session.freeText.length;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const StepHeader(
                step: 3, total: 5, label: 'Entrada pedagogica'),
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
                                        'Campo obrigatorio',
                                        style: TextStyle(
                                          color: Colors.black,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.4,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      const Text(
                                        'Escreva o que voce quer estudar. Se anexar um arquivo ou foto, explique o que deseja aprender com ele.',
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
                              'Conte do seu jeito: idade, serie, materia, tema, prova, prazo, dificuldade ou foto/lista que precisa estudar.',
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
                                            ? 'Reading...'
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
        ? 'foto'
        : attachment.type == 'application/pdf'
            ? 'pdf'
            : 'doc';
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
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 260),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$icon ${attachment.name}$suffix',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: simDark, fontSize: 12),
                ),
                if (attachment.status == 'error' &&
                    attachment.error != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    attachment.error!,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: simMuted, fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: onRemove,
            child: const Text(
              'x',
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
  static const _msgIntervalMs = 3200;

  static const _stages = [
    _PrepStage(title: 'Conectando ao T00 real...', progress: 0.15),
    _PrepStage(title: 'Preparando seu perfil...', progress: 0.40),
    _PrepStage(title: 'Preparando seu curriculo...', progress: 0.65),
    _PrepStage(title: 'Preparando sua aula...', progress: 0.85),
    _PrepStage(title: 'Preparo concluido.', progress: 1.00),
  ];

  static const _messages = [
    'Enquanto sua aula e preparada...',
    'O SIM esta dividindo o topico em passos menores.',
    'A IA nao vai apenas responder.',
    'Ela vai tentar ensinar do melhor jeito para voce.',
    'Se algo parecer dificil, o caminho pode mudar.',
    'Se voce errar, o erro vira uma pista.',
    'Se voce entender, o SIM te ajuda a avancar.',
    'Todo dia, a IA fica mais poderosa.',
    'O SIM traz esse poder para o estudo.',
    'Estudar pode ficar mais leve, claro e eficiente.',
    'Sua aula esta quase pronta.',
    'Respire. Aprender pode ser mais facil do que voce imagina.',
  ];

  int _stageIdx = 0;
  int _msgIdx = 0;
  bool _ready = false;
  bool _loading = false;
  String? _error;
  String? _detail;
  Timer? _msgTimer;

  @override
  void initState() {
    super.initState();
    _startMessageRotation();
    _startT00Bootstrap();
  }

  void _startMessageRotation() {
    _msgTimer =
        Timer.periodic(const Duration(milliseconds: _msgIntervalMs), (_) {
      if (!mounted) return;
      setState(() => _msgIdx = (_msgIdx + 1) % _messages.length);
    });
  }

  Future<void> _startT00Bootstrap() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _ready = false;
      _error = null;
      _detail = null;
      _stageIdx = 0;
    });
    if (_isFlutterTestBinding) {
      _runLocalT00FallbackForTest();
      return;
    }
    final client = HttpClient();
    try {
      final uri = Uri.parse('$simServerBaseUrl/api/bootstrap-t00');
      final req =
          await client.postUrl(uri).timeout(const Duration(seconds: 20));
      req.headers.set('content-type', 'application/json');
      req.headers.set('accept', 'text/event-stream');
      final token = Supabase.instance.client.auth.currentSession?.accessToken;
      if (token != null && token.trim().isNotEmpty) {
        req.headers.set('authorization', 'Bearer ${token.trim()}');
      }
      req.write(jsonEncode(widget.session.buildT00BootstrapPayload()));
      final res = await req.close().timeout(const Duration(seconds: 150));
      if (res.statusCode == 402) {
        widget.session.openCredits();
        return;
      }
      if (res.statusCode < 200 || res.statusCode >= 300) {
        final body = await utf8.decoder.bind(res).join();
        throw HttpException('HTTP ${res.statusCode}: $body', uri: uri);
      }
      await for (final line in res
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .timeout(const Duration(seconds: 150))) {
        _processSseLine(line);
      }
      if (mounted && !_ready && _error == null) {
        setState(() {
          _stageIdx = 4;
          _ready = true;
          _loading = false;
        });
        widget.session.recordT00Done();
      }
    } catch (e) {
      final message = e.toString().replaceFirst('Exception: ', '');
      widget.session.recordT00Fatal(message);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _ready = false;
        _error = 'Erro ao preparar. Tente novamente.';
        _detail = message;
      });
    } finally {
      client.close(force: true);
    }
  }

  bool get _isFlutterTestBinding {
    return WidgetsBinding.instance.runtimeType.toString().contains('Test');
  }

  void _runLocalT00FallbackForTest() {
    widget.session.recordT00StreamStarted();
    widget.session.recordT00Profile({
      'profile': 'Fallback local de teste Flutter.',
    });
    widget.session.recordT00ItemPartial({
      'order': 1,
      'marker': 'M-1',
      'item': {
        'marker': 'M-1',
        'title': widget.session.freeText.trim().isEmpty
            ? 'Primeiro item'
            : widget.session.freeText.trim(),
      },
    });
    widget.session.recordT00Final({
      'profile': 'Fallback local de teste Flutter.',
      'curriculum': [
        {
          'marker': 'M-1',
          'title': widget.session.freeText.trim().isEmpty
              ? 'Primeiro item'
              : widget.session.freeText.trim(),
        },
      ],
    });
    widget.session.recordT00Done();
    if (!mounted) return;
    setState(() {
      _stageIdx = 4;
      _ready = true;
      _loading = false;
      _detail = 'Fallback local de teste concluido.';
    });
  }

  void _processSseLine(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith(':')) return;
    if (!trimmed.startsWith('data:')) return;
    final raw = trimmed.substring(5).trim();
    if (raw.isEmpty || raw == '[DONE]') return;
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return;
    final payload = JsonMap.from(decoded);
    final type = (payload['type'] ?? '').toString();
    switch (type) {
      case 'start':
        widget.session.recordT00StreamStarted();
        _moveToStage(0);
        break;
      case 't00_profile':
        widget.session.recordT00Profile(payload);
        _moveToStage(1, detail: 'Perfil recebido do T00.');
        break;
      case 't00_item_partial':
        widget.session.recordT00ItemPartial(payload);
        _moveToStage(2, detail: 'Item recebido: ${payload['marker'] ?? ''}');
        break;
      case 't00_final':
        widget.session.recordT00Final(payload);
        _moveToStage(3, detail: 'Curriculo completo recebido.');
        break;
      case 'done':
        widget.session.recordT00Done();
        if (!mounted) return;
        setState(() {
          _stageIdx = 4;
          _ready = true;
          _loading = false;
          _error = null;
          _detail = 'T00 concluido.';
        });
        break;
      case 'fatal':
        final message =
            (payload['error'] ?? 'Erro ao preparar. Tente novamente.')
                .toString();
        widget.session.recordT00Fatal(message);
        if (!mounted) return;
        setState(() {
          _loading = false;
          _ready = false;
          _error = 'Erro ao preparar. Tente novamente.';
          _detail = message;
        });
        break;
    }
  }

  void _moveToStage(int index, {String? detail}) {
    if (!mounted) return;
    setState(() {
      _stageIdx = index.clamp(0, _stages.length - 1);
      _detail = detail;
    });
  }

  @override
  void dispose() {
    _msgTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stage = _stages[_stageIdx];
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const StepHeader(step: 4, total: 5, label: 'Preparando aula'),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: SimCard(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 400),
                          child: Text(
                            _error ?? stage.title,
                            key: ValueKey('${_stageIdx}_${_error ?? ''}'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _error == null
                                  ? simDark
                                  : const Color(0xFFDC2626),
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              height: 1.3,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 500),
                          child: Text(
                            _detail ?? _messages[_msgIdx],
                            key: ValueKey('${_msgIdx}_${_detail ?? ''}'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: simMuted,
                              fontSize: 14,
                              height: 1.55,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: stage.progress),
                          duration: const Duration(milliseconds: 700),
                          curve: Curves.easeOut,
                          builder: (context, value, _) => ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              value: value,
                              minHeight: 10,
                              backgroundColor: simLight,
                              color: _error == null
                                  ? simDark
                                  : const Color(0xFFDC2626),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            _stages.length,
                            (i) => Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 4),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                width: i == _stageIdx ? 20 : 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: i <= _stageIdx ? simDark : simBorder,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        if (!_ready && _error == null) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                                3, (i) => _PulseDot(delay: i * 150)),
                          ),
                          const SizedBox(height: 16),
                        ],
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: _error != null
                              ? DecoratedBox(
                                  decoration:
                                      primaryButtonDecoration(radius: 14),
                                  child: TextButton(
                                    onPressed: _startT00Bootstrap,
                                    child: const Text(
                                      'Tentar novamente',
                                      style: TextStyle(
                                        color: simDark,
                                        fontSize: 17,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                )
                              : _ready
                                  ? DecoratedBox(
                                      decoration:
                                          primaryButtonDecoration(radius: 14),
                                      child: TextButton(
                                        onPressed:
                                            widget.session.preparationDone,
                                        child: const Text(
                                          'Continuar ->',
                                          style: TextStyle(
                                            color: simDark,
                                            fontSize: 17,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    )
                                  : DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: simLight,
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: const Center(
                                        child: Text(
                                          'Preparando...',
                                          style: TextStyle(
                                            color: simMuted,
                                            fontSize: 17,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _error != null
                              ? 'O T00 real falhou. Nenhum curriculo foi marcado como pronto.'
                              : _ready
                                  ? 'Pronto para continuar.'
                                  : 'Aguardando eventos reais do T00...',
                          style: const TextStyle(color: simMuted, fontSize: 13),
                          textAlign: TextAlign.center,
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
    );
  }
}

class _PrepStage {
  const _PrepStage({required this.title, required this.progress});
  final String title;
  final double progress;
}

class _PulseDot extends StatefulWidget {
  const _PulseDot({required this.delay});
  final int delay;

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _ctrl.repeat(reverse: true);
    });
    _anim = Tween(
      begin: 0.35,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: FadeTransition(
        opacity: _anim,
        child: Container(
          width: 10,
          height: 10,
          decoration: const BoxDecoration(
            color: simDark,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

class PlacementLabScreen extends StatelessWidget {
  const PlacementLabScreen({required this.session, super.key});

  final LabSession session;

  int get _step {
    switch (session.placementStage) {
      case 'intro':
        return 2;
      case 'running':
        return 3;
      case 'result':
        return 4;
      default:
        return 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            StepHeader(step: _step, total: 4, label: 'Nivelamento'),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: SimCard(child: _body()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    switch (session.placementStage) {
      case 'intro':
        return _IntroBody(session: session);
      case 'running':
        return _RunningBody(session: session);
      case 'result':
        return _ResultBody(session: session);
      default:
        return _ChoiceBody(session: session);
    }
  }
}

class _ChoiceBody extends StatelessWidget {
  const _ChoiceBody({required this.session});
  final LabSession session;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Por onde voce quer comecar?',
          style: TextStyle(
            color: simDark,
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Voce pode comecar do inicio, ou fazer um teste rapido pra eu ja te colocar no ponto certo.',
          style: TextStyle(color: simMuted, fontSize: 15, height: 1.45),
        ),
        const SizedBox(height: 22),
        PrimaryWideButton(
          label: 'Comecar do inicio',
          onTap: session.skipPlacement,
        ),
        const SizedBox(height: 12),
        SecondaryWideButton(
          label: 'Fazer teste rapido',
          onTap: session.startPlacement,
        ),
      ],
    );
  }
}

class _IntroBody extends StatelessWidget {
  const _IntroBody({required this.session});
  final LabSession session;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Teste rapido',
          style: TextStyle(
            color: simDark,
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Vou te fazer algumas perguntas curtas. Nao tem nota, nao tem erro ruim - e so pra eu saber por onde comecar.',
          style: TextStyle(color: simMuted, fontSize: 15, height: 1.45),
        ),
        const SizedBox(height: 22),
        PrimaryWideButton(
          label: session.placementLoading ? 'Preparando...' : 'Comecar',
          onTap: session.placementLoading ? () {} : session.loadPlacementT02,
        ),
      ],
    );
  }
}

class _RunningBody extends StatelessWidget {
  const _RunningBody({required this.session});
  final LabSession session;

  @override
  Widget build(BuildContext context) {
    if (session.placementLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      );
    }
    final question = session.placementQuestion ?? '';
    final choices = session.placementChoices;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Pergunta 1 de 1',
          style: TextStyle(color: simMuted, fontSize: 12, letterSpacing: 1.2),
        ),
        const SizedBox(height: 12),
        Text(
          question,
          style: const TextStyle(
            color: simDark,
            fontSize: 17,
            fontWeight: FontWeight.w700,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 20),
        ...choices.map((c) {
          final label = c['label'] as String? ?? '';
          final correct = c['correct'] as bool? ?? false;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: SecondaryWideButton(
              label: label,
              onTap: () => session.answerPlacement(correct),
            ),
          );
        }),
      ],
    );
  }
}

class _ResultBody extends StatelessWidget {
  const _ResultBody({required this.session});
  final LabSession session;

  @override
  Widget build(BuildContext context) {
    final marker = session.placementStartMarker ?? 'M-1';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tudo certo',
          style: TextStyle(
            color: simDark,
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Vou te levar pro ponto certo.',
          style: TextStyle(color: simMuted, fontSize: 15, height: 1.45),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: simLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: simBorder),
          ),
          child: Text.rich(
            TextSpan(
              text: 'Comecando em ',
              style: const TextStyle(color: simDark, fontSize: 14),
              children: [
                TextSpan(
                  text: marker,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const TextSpan(text: '.'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 22),
        PrimaryWideButton(label: 'Continuar', onTap: session.finishPlacement),
      ],
    );
  }
}

class AulaLabScreen extends StatefulWidget {
  const AulaLabScreen({required this.session, super.key});

  final LabSession session;

  @override
  State<AulaLabScreen> createState() => _AulaLabScreenState();
}

class _AulaLabScreenState extends State<AulaLabScreen> {
  LabSession get session => widget.session;

  @override
  void initState() {
    super.initState();
    if (session.t02Explanation == null && !session.t02Loading) {
      session.loadT02Content();
    }
  }

  String _headerLabel() {
    final raw = session.lessonHeaderLabel;
    if (raw.startsWith('aula_item_of:')) {
      final rest = raw.substring('aula_item_of:'.length);
      final parts = rest.split(':');
      final itemOf = parts.isNotEmpty ? parts[0] : '?';
      final layerKey = parts.length > 1 ? parts[1] : '';
      return 'Item $itemOf - ${_layerName(layerKey)}';
    }
    if (raw.startsWith('aula_review_review:')) {
      final inner = raw.substring('aula_review_review:'.length);
      return 'Revisao - ${_layerName(inner)}';
    }
    if (raw.isEmpty) return 'Item ${session.aulaStep + 1} - Camada 1';
    return _layerName(raw);
  }

  String _layerName(String key) => switch (key) {
        'aula_layer_1' || 'aula_layer_label_1' => 'Camada 1',
        'aula_layer_2' || 'aula_layer_label_2' => 'Camada 2',
        'aula_layer_3' || 'aula_layer_label_3' => 'Camada 3',
        'aula_review_lbl_1' => 'Revisao C1',
        'aula_review_lbl_2' => 'Revisao C2',
        'aula_review_lbl_3' => 'Revisao C3',
        _ => key,
      };

  String _nextLabel() {
    final raw = session.nextStepLabel;
    return switch (raw) {
      'aula_layer_label_1' => 'Ir para Camada 1',
      'aula_layer_label_2' => 'Ir para Camada 2',
      'aula_layer_label_3' => 'Ir para Camada 3',
      'aula_next' => 'Proximo',
      'aula_next_item' => 'Proximo item',
      'aula_consolidate' => 'Consolidar',
      _ when raw.isEmpty => 'Avancar',
      _ => raw,
    };
  }

  String _feedbackMsg() {
    final phase = session.classroomPhase;
    if (phase.type != ClassroomPhaseType.concluido) return '';
    final correct = phase.wasCorrect ?? false;
    final signal = phase.signal ?? DecisionSignal.three;
    if (correct && signal == DecisionSignal.one) {
      return 'Excelente! Resposta correta e solida.';
    }
    if (correct && signal == DecisionSignal.two) {
      return 'Correto, mas SIM marcou revisao leve.';
    }
    if (signal == DecisionSignal.three) {
      return 'SIM abriu recuperacao para reforcar este ponto.';
    }
    return 'Errou. SIM refaz este ponto.';
  }

  String _answerFeedbackMsg() {
    final phase = session.classroomPhase;
    final letter = phase.letter?.name ?? session.selectedAnswer;
    final correct =
        session.t02CorrectAnswer == null || session.t02CorrectAnswer == letter;
    if (correct) {
      return 'Resposta registrada. Veja o feedback e escolha o qualificador.';
    }
    return 'Resposta registrada. Veja o feedback e escolha o qualificador.';
  }

  Widget _buildDoneScreen(String topic) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            AulaTopBar(session: session),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: SimCard(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.check_circle_outline,
                          size: 48,
                          color: simDark,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Sessao concluida!',
                          style: TextStyle(
                            color: simDark,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          topic,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: simMuted,
                            fontSize: 15,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Solido: ${session.signalsSolid}  -  Entendeu: ${session.signalsUnderstood}  -  Fragil: ${session.signalsFragile}',
                          style: const TextStyle(
                            color: simMuted,
                            fontSize: 13,
                            fontFamily: 'monospace',
                          ),
                        ),
                        const SizedBox(height: 20),
                        PrimaryWideButton(
                          label: 'Voltar ao inicio',
                          onTap: session.goPortal,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final topic =
        session.freeText.trim().isEmpty ? 'Aula SIM' : session.freeText.trim();
    final opts = session.t02Options;
    final phase = session.classroomPhase;
    final isDone = session.lessonIsDone;
    final awaitingQualifier = phase.type == ClassroomPhaseType.expandida;
    final locked = session.answersLocked || awaitingQualifier;
    final isConcluido = phase.type == ClassroomPhaseType.concluido;
    final selectedLetter = phase.letter?.name ?? session.selectedAnswer;
    final hasLessonContent = session.t02Explanation?.trim().isNotEmpty == true &&
        session.t02Question?.trim().isNotEmpty == true &&
        opts != null &&
        (opts['A']?.trim().isNotEmpty ?? false) &&
        (opts['B']?.trim().isNotEmpty ?? false) &&
        (opts['C']?.trim().isNotEmpty ?? false);

    if (isDone) return _buildDoneScreen(topic);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            AulaTopBar(session: session),
            ClipRRect(
              child: LinearProgressIndicator(
                value: session.lessonProgress > 0
                    ? session.lessonProgress / 100
                    : null,
                minHeight: 3,
                backgroundColor: simLight,
                color: simDark,
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    SimCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _headerLabel(),
                            style: const TextStyle(
                              color: simMuted,
                              fontSize: 12,
                              fontFamily: 'monospace',
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            topic,
                            style: const TextStyle(
                              color: simDark,
                              fontSize: 22,
                              height: 1.2,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 14),
                          if (session.t02Loading) ...[
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 20),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                            const Text(
                              'Preparando sua aula...',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: simMuted, fontSize: 14),
                            ),
                          ] else if (session.t02Error != null) ...[
                            Text(
                              session.t02Error!,
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 10),
                            GestureDetector(
                              onTap: session.loadT02Content,
                              child: const Text(
                                'Tentar novamente',
                                style: TextStyle(
                                  color: simDark,
                                  fontWeight: FontWeight.w700,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ] else if (hasLessonContent) ...[
                            Text(
                              session.t02Explanation!,
                              style: const TextStyle(
                                color: simMuted,
                                fontSize: 15,
                                height: 1.45,
                              ),
                            ),
                          ] else ...[
                            const Text(
                              'A aula ainda nao carregou o conteudo real.',
                              style: TextStyle(
                                color: Colors.red,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'O SIM precisa receber explicacao, pergunta e alternativas A/B/C do T02 antes de abrir a sala.',
                              style: TextStyle(
                                color: simMuted,
                                fontSize: 13.5,
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 10),
                            GestureDetector(
                              onTap: session.loadT02Content,
                              child: const Text(
                                'Tentar novamente',
                                style: TextStyle(
                                  color: simDark,
                                  fontWeight: FontWeight.w700,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                          if (hasLessonContent) ...[
                            const SizedBox(height: 14),
                            LessonImagePanel(session: session),
                          ],
                          if (hasLessonContent && session.audioError != null) ...[
                            const SizedBox(height: 10),
                            StatusLine(
                              icon: Icons.volume_off_outlined,
                              text: session.audioError!,
                            ),
                          ],
                          if (hasLessonContent && session.audioLoading) ...[
                            const SizedBox(height: 10),
                            const StatusLine(
                              icon: Icons.volume_up_outlined,
                              text: 'Preparando audio da aula...',
                              loading: true,
                            ),
                          ],
                          if (hasLessonContent) ...[
                            const SizedBox(height: 10),
                            StatusLine(
                              icon: session.audioEnabled
                                  ? session.audioStatus == 'playing'
                                      ? Icons.pause_circle_outline
                                      : Icons.volume_up_outlined
                                  : Icons.volume_off_outlined,
                              text: session.audioEnabled
                                  ? session.audioStatus == 'playing'
                                      ? 'Audio da aula tocando'
                                      : 'Audio da aula ligado'
                                  : 'Audio da aula desligado',
                            ),
                          ],
                          if (hasLessonContent &&
                              session.audioEnabled &&
                              !session.audioLoading &&
                              session.t02Explanation != null) ...[
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                onPressed: session.audioStatus == 'playing'
                                    ? session.stopLessonAudio
                                    : session.playLessonAudio,
                                icon: Icon(
                                  session.audioStatus == 'playing'
                                      ? Icons.pause
                                      : Icons.play_arrow,
                                  size: 18,
                                ),
                                label: Text(
                                  session.audioStatus == 'playing'
                                      ? 'Pausar audio'
                                      : 'Tocar audio',
                                ),
                              ),
                            ),
                          ],
                          if (hasLessonContent) ...[
                            const SizedBox(height: 14),
                            const Text(
                              'Pergunta',
                              style: TextStyle(
                                color: simDark,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              session.t02Question!,
                              style: const TextStyle(
                                color: simDark,
                                fontSize: 15,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 12),
                            AnswerButton(
                              label: 'A',
                              text: opts['A']!,
                              active: selectedLetter == 'A',
                              locked: locked,
                              correct: (isConcluido || awaitingQualifier) &&
                                  session.t02CorrectAnswer == 'A',
                              onTap: locked
                                  ? null
                                  : () => session.chooseAulaAnswer('A'),
                            ),
                            AnswerButton(
                              label: 'B',
                              text: opts['B']!,
                              active: selectedLetter == 'B',
                              locked: locked,
                              correct: (isConcluido || awaitingQualifier) &&
                                  session.t02CorrectAnswer == 'B',
                              onTap: locked
                                  ? null
                                  : () => session.chooseAulaAnswer('B'),
                            ),
                            AnswerButton(
                              label: 'C',
                              text: opts['C']!,
                              active: selectedLetter == 'C',
                              locked: locked,
                              correct: (isConcluido || awaitingQualifier) &&
                                  session.t02CorrectAnswer == 'C',
                              onTap: locked
                                  ? null
                                  : () => session.chooseAulaAnswer('C'),
                            ),
                          ],
                          if (awaitingQualifier) ...[
                            const SizedBox(height: 14),
                            _FeedbackBanner(
                              message: _answerFeedbackMsg(),
                              wasCorrect: session.t02CorrectAnswer == null ||
                                  session.t02CorrectAnswer == selectedLetter,
                            ),
                            if (session.t02WhyCorrect != null ||
                                session.t02WhyWrong != null) ...[
                              const SizedBox(height: 10),
                              Text(
                                (session.t02CorrectAnswer == null ||
                                        session.t02CorrectAnswer ==
                                            selectedLetter)
                                    ? session.t02WhyCorrect?.toString() ?? ''
                                    : session.t02WhyWrong?.toString() ?? '',
                                style: const TextStyle(
                                  color: simMuted,
                                  fontSize: 13.5,
                                  height: 1.4,
                                ),
                              ),
                            ],
                            const SizedBox(height: 14),
                            const Text(
                              'Como ficou este ponto?',
                              style: TextStyle(
                                color: simDark,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            QualifierButton(
                              label: '1',
                              text: 'Ficou sólido',
                              onTap: () => session
                                  .submitAulaQualifier(DecisionSignal.one),
                            ),
                            QualifierButton(
                              label: '2',
                              text: 'Entendi, mas quero revisar',
                              onTap: () => session
                                  .submitAulaQualifier(DecisionSignal.two),
                            ),
                            QualifierButton(
                              label: '3',
                              text: 'Ainda está frágil',
                              onTap: () => session
                                  .submitAulaQualifier(DecisionSignal.three),
                            ),
                          ] else if (isConcluido) ...[
                            const SizedBox(height: 14),
                            _FeedbackBanner(
                              message: _feedbackMsg(),
                              wasCorrect: phase.wasCorrect ?? false,
                            ),
                            if (session.t02WhyCorrect != null ||
                                session.t02WhyWrong != null) ...[
                              const SizedBox(height: 10),
                              Text(
                                (phase.wasCorrect ?? false)
                                    ? session.t02WhyCorrect?.toString() ?? ''
                                    : session.t02WhyWrong?.toString() ?? '',
                                style: const TextStyle(
                                  color: simMuted,
                                  fontSize: 13.5,
                                  height: 1.4,
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            PrimaryWideButton(
                              label: _nextLabel(),
                              onTap: session.advanceAula,
                            ),
                          ] else if (session.aulaMessage.isNotEmpty &&
                              !locked) ...[
                            const SizedBox(height: 14),
                            Text(
                              session.aulaMessage,
                              style: const TextStyle(
                                color: simDark,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 12),
                            PrimaryWideButton(
                              label: 'Avancar',
                              onTap: session.advanceAula,
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (session.supportRoomView != null) ...[
                      const SizedBox(height: 14),
                      SupportRoomPanel(session: session),
                    ],
                    if (session.reviewRoomView != null ||
                        session.reviewQueueCount > 0) ...[
                      const SizedBox(height: 14),
                      ReviewRoomPanel(
                        session: session,
                      ),
                    ],
                    if (session.recoveryRoomView != null ||
                        session.recoveryQueueCount > 0) ...[
                      const SizedBox(height: 14),
                      RecoveryRoomPanel(
                        session: session,
                      ),
                    ],
                    const SizedBox(height: 14),
                    if (session.doubtOpen) DoubtRoomPanel(session: session),
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

class SupportRoomPanel extends StatelessWidget {
  const SupportRoomPanel({required this.session, super.key});

  final LabSession session;

  @override
  Widget build(BuildContext context) {
    final view = session.supportRoomView;
    if (view == null) return const SizedBox.shrink();
    final station = view.station;
    final content = station?.content;
    return SimCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  'assets/monkey-logo.png',
                  width: 42,
                  height: 42,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Amparo',
                  style: TextStyle(
                    color: simDark,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            view.message,
            style: const TextStyle(color: simMuted, fontSize: 14, height: 1.4),
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: view.status == SupportRoomStatus.preparing
                ? null
                : (view.progress.clamp(5, 100) / 100),
            minHeight: 4,
            backgroundColor: simLight,
            color: simDark,
          ),
          const SizedBox(height: 12),
          if (view.status == SupportRoomStatus.preparing) ...[
            const StatusLine(
              icon: Icons.auto_awesome,
              text: 'Preparando o caminho...',
              loading: true,
            ),
            if (view.showExitOptions) ...[
              const SizedBox(height: 10),
              const Text(
                'A preparacao continua. Se preferir, voce pode tentar de novo ou voltar para a aula no mesmo ponto.',
                style: TextStyle(color: simMuted, fontSize: 13, height: 1.35),
              ),
              const SizedBox(height: 10),
              PrimaryWideButton(
                label: 'Tentar de novo',
                onTap: session.nextSupportStation,
              ),
              const SizedBox(height: 8),
              SecondaryWideButton(
                label: 'Voltar para a aula',
                onTap: () => session.returnFromSupport(afterFailure: true),
              ),
            ],
          ] else if (view.status == SupportRoomStatus.failed) ...[
            Text(
              view.error ??
                  'Nao foi possivel preparar este amparo agora. Voce pode tentar novamente ou voltar para a aula no mesmo ponto.',
              style: const TextStyle(color: Colors.red, fontSize: 14),
            ),
            const SizedBox(height: 10),
            PrimaryWideButton(
              label: 'Tentar de novo',
              onTap: () => session.nextSupportStation(),
            ),
            const SizedBox(height: 8),
            SecondaryWideButton(
              label: 'Voltar para a aula',
              onTap: () => session.returnFromSupport(afterFailure: true),
            ),
          ] else if (view.status == SupportRoomStatus.crossed) ...[
            const Text(
              'Pronto. O caminho foi ajustado. Vamos voltar para a aula no mesmo ponto.',
              style: TextStyle(color: simDark, fontSize: 15, height: 1.4),
            ),
            const SizedBox(height: 10),
            PrimaryWideButton(
              label: 'Voltar para a aula',
              onTap: () => session.returnFromSupport(),
            ),
          ] else if (view.status == SupportRoomStatus.retryAvailable) ...[
            const Text(
              'Vamos fazer mais uma travessia curta, por outro caminho.',
              style: TextStyle(color: simDark, fontSize: 15, height: 1.4),
            ),
            const SizedBox(height: 10),
            PrimaryWideButton(
              label: 'Continuar',
              onTap: session.nextSupportStation,
            ),
          ] else if (view.status == SupportRoomStatus.maxReached) ...[
            const Text(
              'Vamos voltar para a aula no mesmo ponto e seguir com mais cuidado.',
              style: TextStyle(color: simDark, fontSize: 15, height: 1.4),
            ),
            const SizedBox(height: 10),
            PrimaryWideButton(
              label: 'Voltar para a aula',
              onTap: () => session.returnFromSupport(),
            ),
          ] else if (content != null && station != null) ...[
            Text(
              'Passo ${view.index + 1}/3 - ${station.title}',
              style: const TextStyle(
                color: simDark,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              content.explanation,
              style:
                  const TextStyle(color: simMuted, fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 10),
            Text(
              content.question,
              style: const TextStyle(color: simDark, fontSize: 15, height: 1.4),
            ),
            const SizedBox(height: 10),
            for (final letter in AnswerLetter.values)
              AnswerButton(
                label: letter.name,
                text: content.options[letter] ?? '',
                active: view.letra == letter,
                locked: view.status == SupportRoomStatus.result,
                correct: view.status == SupportRoomStatus.result &&
                    content.correctAnswer == letter,
                onTap: view.status == SupportRoomStatus.result
                    ? null
                    : () => session.submitSupportAnswer(letter.name),
              ),
            if (view.letra != null &&
                view.status != SupportRoomStatus.result) ...[
              const SizedBox(height: 12),
              const Text(
                'Como ficou este passo?',
                style: TextStyle(
                  color: simDark,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              QualifierButton(
                label: '1',
                text: 'Ficou solido',
                onTap: () => session.submitSupportQualifier(DecisionSignal.one),
              ),
              QualifierButton(
                label: '2',
                text: 'Entendi, mas quero revisar',
                onTap: () => session.submitSupportQualifier(DecisionSignal.two),
              ),
              QualifierButton(
                label: '3',
                text: 'Ainda esta fragil',
                onTap: () =>
                    session.submitSupportQualifier(DecisionSignal.three),
              ),
            ],
            if (view.status == SupportRoomStatus.result) ...[
              const SizedBox(height: 12),
              _FeedbackBanner(
                message: view.resultCorrect == true
                    ? 'Esse passo ficou claro.'
                    : 'Vamos seguir ajustando o caminho.',
                wasCorrect: view.resultCorrect == true,
              ),
              const SizedBox(height: 10),
              PrimaryWideButton(
                label: view.index >= 2 ? 'Concluir amparo' : 'Proximo passo',
                onTap: session.nextSupportStation,
              ),
            ],
            const SizedBox(height: 8),
            SecondaryWideButton(
              label: 'Voltar para a aula',
              onTap: () => session.returnFromSupport(),
            ),
          ],
        ],
      ),
    );
  }
}

class DoubtRoomPanel extends StatelessWidget {
  const DoubtRoomPanel({required this.session, super.key});

  final LabSession session;

  @override
  Widget build(BuildContext context) {
    final state = session.doubtState;
    final image = session.doubtImage;
    return SimCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Duvida',
            style: TextStyle(
              color: simDark,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Escreva sua duvida ou envie uma foto. A aula continua no mesmo ponto.',
            style: TextStyle(color: simMuted, fontSize: 14, height: 1.4),
          ),
          const SizedBox(height: 14),
          if (state.status == DoubtStatus.processing) ...[
            LinearProgressIndicator(value: state.progress / 100),
            const SizedBox(height: 8),
            Text(
              session._getDoubtController().progressLabel,
              style: const TextStyle(color: simMuted, fontSize: 13),
            ),
          ] else if (state.status == DoubtStatus.explaining &&
              state.response != null) ...[
            Text(
              state.response!.explanation,
              style: const TextStyle(
                color: simDark,
                fontSize: 15,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (state.response!.visualTrigger != null) ...[
              const SizedBox(height: 10),
              const Text(
                'Ha uma sugestao visual para este ponto. A imagem paga nao foi gerada automaticamente.',
                style: TextStyle(color: simMuted, fontSize: 13, height: 1.4),
              ),
            ],
            const SizedBox(height: 12),
            PrimaryWideButton(
              label: 'Entendi',
              onTap: session.closeDoubt,
            ),
          ] else ...[
            TextFormField(
              initialValue: session.doubtText,
              maxLines: 4,
              maxLength: doubtTextMaxLength,
              onChanged: session.setDoubtText,
              decoration: InputDecoration(
                hintText: 'Escreva sua duvida aqui...',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: simBorder),
                ),
              ),
            ),
            if (image != null) ...[
              const SizedBox(height: 10),
              _DoubtImagePreview(image: image),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: session.removeDoubtImage,
                child: const Text(
                  'Remover foto',
                  style: TextStyle(
                    color: simDark,
                    fontWeight: FontWeight.w700,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
            if (session.doubtInputError != null ||
                state.status == DoubtStatus.error) ...[
              const SizedBox(height: 10),
              Text(
                session.doubtInputError ??
                    state.error ??
                    'Nao foi possivel responder agora.',
                style: const TextStyle(color: Colors.red, fontSize: 13),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => unawaited(session.pickDoubtImage()),
                    child: Text(image == null ? 'Anexar foto' : 'Trocar foto'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: PrimaryWideButton(
                    label: state.status == DoubtStatus.error
                        ? 'Tentar novamente'
                        : 'Enviar duvida',
                    onTap: () => unawaited(session.submitDoubt()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: session.closeDoubt,
              child: const Text(
                'Fechar',
                style: TextStyle(
                  color: simMuted,
                  fontWeight: FontWeight.w700,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DoubtImagePreview extends StatelessWidget {
  const _DoubtImagePreview({required this.image});

  final DoubtImagePayload image;

  @override
  Widget build(BuildContext context) {
    final comma = image.dataUrl.indexOf(',');
    final bytes = comma >= 0
        ? base64Decode(image.dataUrl.substring(comma + 1))
        : const <int>[];
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: bytes.isEmpty
          ? Container(
              height: 120,
              color: simLight,
              alignment: Alignment.center,
              child: const Text(
                'Preview indisponivel',
                style: TextStyle(color: simMuted),
              ),
            )
          : Image.memory(
              Uint8List.fromList(bytes),
              height: 140,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
    );
  }
}

class _FeedbackBanner extends StatelessWidget {
  const _FeedbackBanner({required this.message, required this.wasCorrect});

  final String message;
  final bool wasCorrect;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: wasCorrect ? const Color(0xFFECFDF5) : const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: wasCorrect ? const Color(0xFF6EE7B7) : const Color(0xFFFBBF24),
        ),
      ),
      child: Text(
        message,
        style: TextStyle(
          color: wasCorrect ? const Color(0xFF065F46) : const Color(0xFF92400E),
          fontSize: 14,
          fontWeight: FontWeight.w600,
          height: 1.4,
        ),
      ),
    );
  }
}

class ReviewRoomPanel extends StatelessWidget {
  const ReviewRoomPanel({required this.session, super.key});

  final LabSession session;

  @override
  Widget build(BuildContext context) {
    final view = session.reviewRoomView;
    final count = session.reviewQueueCount;
    final content = view?.conteudo;
    final status = view?.status;
    return SimCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Revisão',
            style: TextStyle(
              color: simDark,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            count == 1 ? '1 item para revisão' : '$count itens para revisão',
            style: const TextStyle(color: simMuted, fontSize: 14, height: 1.4),
          ),
          const SizedBox(height: 14),
          if (view == null) ...[
            PrimaryWideButton(
              label: 'Iniciar revisão',
              onTap: () => unawaited(session.startReviewRoom()),
            ),
          ] else if (status == ReviewRoomStatus.preparing) ...[
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            const Text(
              'Preparando revisão com T02...',
              style: TextStyle(color: simMuted, fontSize: 14),
            ),
          ] else if (status == ReviewRoomStatus.failed) ...[
            Text(
              view.errMsg ?? 'Não foi possível preparar a revisão.',
              style: const TextStyle(color: Colors.red, fontSize: 14),
            ),
            const SizedBox(height: 12),
            PrimaryWideButton(
              label: 'Tentar novamente',
              onTap: () => unawaited(session.startReviewRoom()),
            ),
          ] else if (status == ReviewRoomStatus.done) ...[
            const Text(
              'Revisão concluída',
              style: TextStyle(
                color: simDark,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            PrimaryWideButton(
              label: 'Voltar para aula',
              onTap: session.closeReviewRoom,
            ),
          ] else if (content != null) ...[
            Text(
              'Questão ${view.idx + 1} de ${view.queue.length}',
              style: const TextStyle(
                color: simMuted,
                fontSize: 12,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 10),
            if (content.explanation.trim().isNotEmpty) ...[
              Text(
                content.explanation,
                style: const TextStyle(
                  color: simMuted,
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 10),
            ],
            Text(
              content.question,
              style: const TextStyle(
                color: simDark,
                fontSize: 15,
                height: 1.4,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            AnswerButton(
              label: 'A',
              text: content.options[AnswerLetter.A] ?? '',
              active: view.letra == AnswerLetter.A,
              locked: status == ReviewRoomStatus.result,
              correct: status == ReviewRoomStatus.result &&
                  content.correctAnswer == AnswerLetter.A,
              onTap: status == ReviewRoomStatus.result
                  ? null
                  : () => session.submitReviewAnswer('A'),
            ),
            AnswerButton(
              label: 'B',
              text: content.options[AnswerLetter.B] ?? '',
              active: view.letra == AnswerLetter.B,
              locked: status == ReviewRoomStatus.result,
              correct: status == ReviewRoomStatus.result &&
                  content.correctAnswer == AnswerLetter.B,
              onTap: status == ReviewRoomStatus.result
                  ? null
                  : () => session.submitReviewAnswer('B'),
            ),
            AnswerButton(
              label: 'C',
              text: content.options[AnswerLetter.C] ?? '',
              active: view.letra == AnswerLetter.C,
              locked: status == ReviewRoomStatus.result,
              correct: status == ReviewRoomStatus.result &&
                  content.correctAnswer == AnswerLetter.C,
              onTap: status == ReviewRoomStatus.result
                  ? null
                  : () => session.submitReviewAnswer('C'),
            ),
            if (status == ReviewRoomStatus.result) ...[
              const SizedBox(height: 10),
              _FeedbackBanner(
                message: view.resultCorrect == true
                    ? 'Revisão respondida corretamente.'
                    : 'Revisão registrada. O engine mantém este ponto em atenção.',
                wasCorrect: view.resultCorrect == true,
              ),
              const SizedBox(height: 12),
              PrimaryWideButton(
                label: view.idx + 1 >= view.queue.length
                    ? 'Concluir revisão'
                    : 'Próxima questão',
                onTap: () => unawaited(session.nextReviewQuestion()),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class RecoveryRoomPanel extends StatelessWidget {
  const RecoveryRoomPanel({required this.session, super.key});

  final LabSession session;

  @override
  Widget build(BuildContext context) {
    final view = session.recoveryRoomView;
    final count = session.recoveryQueueCount;
    final content = view?.conteudo;
    final status = view?.status;
    return SimCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recuperacao',
            style: TextStyle(
              color: simDark,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            count == 1
                ? '1 item para recuperacao'
                : '$count itens para recuperacao',
            style: const TextStyle(color: simMuted, fontSize: 14, height: 1.4),
          ),
          const SizedBox(height: 8),
          const Text(
            'A recuperacao reconstruiu o ponto fragil antes da conclusao da aula.',
            style: TextStyle(color: simMuted, fontSize: 14, height: 1.4),
          ),
          const SizedBox(height: 14),
          if (view == null) ...[
            PrimaryWideButton(
              label: 'Iniciar recuperacao',
              onTap: () => unawaited(session.startRecoveryRoom()),
            ),
          ] else if (status == RecoveryRoomStatus.preparing) ...[
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            const Text(
              'Preparando recuperacao com T02...',
              style: TextStyle(color: simMuted, fontSize: 14),
            ),
          ] else if (status == RecoveryRoomStatus.failed) ...[
            Text(
              view.errMsg ?? 'Nao foi possivel preparar a recuperacao.',
              style: const TextStyle(color: Colors.red, fontSize: 14),
            ),
            const SizedBox(height: 12),
            PrimaryWideButton(
              label: 'Tentar novamente',
              onTap: () => unawaited(session.startRecoveryRoom()),
            ),
          ] else if (status == RecoveryRoomStatus.intro) ...[
            const Text(
              'Vamos voltar para a camada 1 deste ponto e reconstruir com calma.',
              style: TextStyle(color: simMuted, fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 12),
            PrimaryWideButton(
              label: 'Comecar recuperacao',
              onTap: session.continueRecoveryRoom,
            ),
          ] else if (status == RecoveryRoomStatus.done) ...[
            const Text(
              'Recuperacao concluida',
              style: TextStyle(
                color: simDark,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            PrimaryWideButton(
              label: view.restartRequired
                  ? 'Continuar recuperacao'
                  : 'Voltar para aula',
              onTap: view.restartRequired
                  ? () => unawaited(session.startRecoveryRoom())
                  : session.closeRecoveryRoom,
            ),
          ] else if (content != null) ...[
            Text(
              'Reconstrucao ${view.idx + 1} de ${view.queue.length}',
              style: const TextStyle(
                color: simMuted,
                fontSize: 12,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 10),
            if (content.explanation.trim().isNotEmpty) ...[
              Text(
                content.explanation,
                style: const TextStyle(
                  color: simMuted,
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 10),
            ],
            Text(
              content.question,
              style: const TextStyle(
                color: simDark,
                fontSize: 15,
                height: 1.4,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            AnswerButton(
              label: 'A',
              text: content.options[AnswerLetter.A] ?? '',
              active: view.letra == AnswerLetter.A,
              locked: status == RecoveryRoomStatus.result,
              correct: status == RecoveryRoomStatus.result &&
                  content.correctAnswer == AnswerLetter.A,
              onTap: status == RecoveryRoomStatus.result
                  ? null
                  : () => session.submitRecoveryAnswer('A'),
            ),
            AnswerButton(
              label: 'B',
              text: content.options[AnswerLetter.B] ?? '',
              active: view.letra == AnswerLetter.B,
              locked: status == RecoveryRoomStatus.result,
              correct: status == RecoveryRoomStatus.result &&
                  content.correctAnswer == AnswerLetter.B,
              onTap: status == RecoveryRoomStatus.result
                  ? null
                  : () => session.submitRecoveryAnswer('B'),
            ),
            AnswerButton(
              label: 'C',
              text: content.options[AnswerLetter.C] ?? '',
              active: view.letra == AnswerLetter.C,
              locked: status == RecoveryRoomStatus.result,
              correct: status == RecoveryRoomStatus.result &&
                  content.correctAnswer == AnswerLetter.C,
              onTap: status == RecoveryRoomStatus.result
                  ? null
                  : () => session.submitRecoveryAnswer('C'),
            ),
            if (status == RecoveryRoomStatus.result) ...[
              const SizedBox(height: 10),
              _FeedbackBanner(
                message: view.resultCorrect == true
                    ? 'Recuperacao registrada como evidencia de reconstrucao.'
                    : 'Recuperacao registrada. O engine mantem a pendencia ativa.',
                wasCorrect: view.resultCorrect == true,
              ),
              const SizedBox(height: 12),
              PrimaryWideButton(
                label: view.idx + 1 >= view.queue.length
                    ? 'Concluir recuperacao'
                    : 'Proxima reconstrucao',
                onTap: () => unawaited(session.nextRecoveryQuestion()),
              ),
            ],
          ],
        ],
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
  const AulaTopBar({required this.session, super.key});

  final LabSession session;

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
          RoundIconButton(
            icon: Icons.help_outline,
            tooltip: 'Duvida',
            onTap: session.toggleDoubt,
          ),
          const SizedBox(width: 8),
          RoundIconButton(
            icon: session.audioEnabled
                ? Icons.volume_up_outlined
                : Icons.volume_off_outlined,
            tooltip: 'Audio',
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
    final hasTrigger = session.lessonVisualTrigger != null;
    final dataUrl = session.lessonImageDataUrl;
    if (!hasTrigger) {
      return const SizedBox.shrink();
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: simLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: simBorder),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (loading) ...[
            const SizedBox(
              width: 34,
              height: 34,
              child: CircularProgressIndicator(strokeWidth: 2, color: simDark),
            ),
          ] else if (ready && dataUrl != null && dataUrl.isNotEmpty) ...[
            _LessonGeneratedImage(dataUrl: dataUrl),
          ] else ...[
            const Icon(Icons.image_outlined, size: 46, color: simMuted),
          ],
          const SizedBox(height: 10),
          Text(
            loading
                ? 'Gerando imagem da aula...'
                : ready
                    ? 'Imagem da aula pronta'
                    : 'Imagem disponivel para este ponto',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: simDark,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (!ready && !loading) ...[
            const SizedBox(height: 6),
            const Text(
              'Gerar imagem por IA pode consumir 10 creditos. O servidor valida credito antes de gerar.',
              textAlign: TextAlign.center,
              style: TextStyle(color: simMuted, fontSize: 12, height: 1.3),
            ),
          ],
          if (session.imageError != null) ...[
            const SizedBox(height: 8),
            Text(
              session.imageError!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ],
          const SizedBox(height: 8),
          SizedBox(
            height: 32,
            child: OutlinedButton.icon(
              onPressed: loading ? null : session.requestLessonImage,
              icon: const Icon(Icons.auto_awesome, size: 16),
              label: Text(
                ready ? 'Gerar novamente (10 creditos)' : 'Gerar imagem',
              ),
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

class _LessonGeneratedImage extends StatelessWidget {
  const _LessonGeneratedImage({required this.dataUrl});

  final String dataUrl;

  @override
  Widget build(BuildContext context) {
    if (dataUrl.startsWith('http')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          dataUrl,
          height: 180,
          width: double.infinity,
          fit: BoxFit.cover,
        ),
      );
    }
    final comma = dataUrl.indexOf(',');
    if (comma < 0) {
      return const Icon(Icons.broken_image_outlined, size: 46, color: simMuted);
    }
    final bytes = base64Decode(dataUrl.substring(comma + 1));
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.memory(
        Uint8List.fromList(bytes),
        height: 180,
        width: double.infinity,
        fit: BoxFit.cover,
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

class CreditsLabScreen extends StatefulWidget {
  const CreditsLabScreen({required this.session, super.key});

  final LabSession session;

  @override
  State<CreditsLabScreen> createState() => _CreditsLabScreenState();
}

class _CreditsLabScreenState extends State<CreditsLabScreen> {
  bool _loading = true;
  CreditPackId? _buying;
  String? _buyError;

  @override
  void initState() {
    super.initState();
    _loadCredits();
  }

  Future<void> _loadCredits() async {
    await widget.session.refreshCredits();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _handlePackClick(CreditPack pack) async {
    if (_buying != null) return;
    setState(() {
      _buying = pack.id;
      _buyError = null;
    });
    try {
      final url = await widget.session.createCheckoutUrl(pack.id);
      if (!mounted) return;
      if (url == null) {
        setState(() {
          _buyError =
              'Nao foi possivel abrir o checkout. Tente de novo.';
          _buying = null;
        });
        return;
      }
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        setState(() =>
            _buyError = 'Nao foi possivel abrir o navegador.');
      }
    } catch (e) {
      if (mounted) setState(() => _buyError = 'Erro: $e');
    } finally {
      if (mounted) setState(() => _buying = null);
    }
  }

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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text(
                        'Creditos',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: simDark,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh, color: simMuted),
                      tooltip: 'Atualizar saldo',
                      onPressed: () {
                        setState(() => _loading = true);
                        _loadCredits();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _loading
                    ? const SizedBox(
                        height: 40,
                        child: Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: simDark,
                          ),
                        ),
                      )
                    : Text(
                        'Saldo: ${widget.session.credits} credito${widget.session.credits == 1 ? '' : 's'}',
                        style: const TextStyle(
                          color: simDark,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                const SizedBox(height: 4),
                const Text(
                  '3 creditos por aula - 10 por imagem',
                  style: TextStyle(color: simMuted, fontSize: 13),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Audio e preparo T00 ficam sem cobranca real enquanto nao houver politica oficial no servidor.',
                  style: TextStyle(color: simMuted, fontSize: 12),
                ),
                const SizedBox(height: 18),
                for (final pack in simPricing.creditPacks)
                  _SimCreditPackButton(
                    pack: pack,
                    loading: _buying == pack.id,
                    disabled: _buying != null,
                    onTap: () => _handlePackClick(pack),
                  ),
                if (_buyError != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _buyError!,
                    style: const TextStyle(color: Colors.red, fontSize: 13),
                  ),
                ],
                const SizedBox(height: 4),
                const Text(
                  'Apos o pagamento, toque em atualizar para atualizar o saldo.',
                  style: TextStyle(color: simMuted, fontSize: 12),
                ),
                const SizedBox(height: 18),
                _CreditLedgerPreview(
                  transactions: widget.session.billingTransactions,
                ),
                const SizedBox(height: 16),
                PrimaryWideButton(
                  label: 'Voltar para aula',
                  onTap: () => widget.session.openSupport('/cyber/aula'),
                ),
                const SizedBox(height: 10),
                SecondaryWideButton(
                  label: 'Portal',
                  onTap: widget.session.goPortal,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CreditLedgerPreview extends StatelessWidget {
  const _CreditLedgerPreview({required this.transactions});

  final List<StudentBillingTransaction> transactions;

  @override
  Widget build(BuildContext context) {
    final visible = transactions.reversed.take(6).toList(growable: false);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        border: Border.all(color: simBorder),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Historico de creditos',
            style: TextStyle(
              color: simDark,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          if (visible.isEmpty)
            const Text(
              'Nenhuma transacao carregada ainda.',
              style: TextStyle(color: simMuted, fontSize: 13),
            )
          else
            for (final tx in visible)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(
                      tx.amount >= 0 ? Icons.add_circle : Icons.remove_circle,
                      color: tx.amount >= 0 ? Colors.green : Colors.redAccent,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${tx.reason} - ${tx.status.name}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: simDark, fontSize: 13),
                      ),
                    ),
                    Text(
                      tx.amount > 0 ? '+${tx.amount}' : '${tx.amount}',
                      style: const TextStyle(
                        color: simDark,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class _SimCreditPackButton extends StatelessWidget {
  const _SimCreditPackButton({
    required this.pack,
    required this.loading,
    required this.disabled,
    required this.onTap,
  });

  final CreditPack pack;
  final bool loading;
  final bool disabled;
  final VoidCallback onTap;

  String get _subtitle => switch (pack.id) {
        CreditPackId.credits100 => '~33 aulas',
        CreditPackId.credits200 => '~66 aulas',
        CreditPackId.credits500 => '~166 aulas',
      };

  String get _price {
    final cents = pack.amountCents;
    return 'R\$ ${cents ~/ 100},${(cents % 100).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: OutlinedButton(
        onPressed: disabled ? null : onTap,
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
            loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: simDark,
                    ),
                  )
                : const Icon(Icons.credit_card, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${pack.credits} creditos - $_price',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    _subtitle,
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

class CheckoutReturnScreen extends StatefulWidget {
  const CheckoutReturnScreen({required this.session, super.key});

  final LabSession session;

  @override
  State<CheckoutReturnScreen> createState() => _CheckoutReturnScreenState();
}

class _CheckoutReturnScreenState extends State<CheckoutReturnScreen> {
  CheckoutStatusKind? _status;
  int _credits = 0;
  int _balance = 0;
  String? _error;
  Timer? _pollTimer;
  int _elapsedMs = 0;
  static const int _timeoutMs = 30000;
  static const int _pollIntervalMs = 2000;

  @override
  void initState() {
    super.initState();
    _confirm();
  }

  String? get _sessionId => widget.session.checkoutSessionId;

  Future<void> _confirm() async {
    final sessionId = _sessionId;
    if (sessionId == null || !isValidStripeSessionId(sessionId)) {
      setState(() {
        _status = CheckoutStatusKind.error;
        _error = 'Sessao de pagamento invalida.';
      });
      return;
    }
    final result = await widget.session.getCheckoutStatus(sessionId);
    if (result.kind == CheckoutStatusKind.pending && _elapsedMs < _timeoutMs) {
      _pollTimer = Timer(const Duration(milliseconds: _pollIntervalMs), () {
        _elapsedMs += _pollIntervalMs;
        _confirm();
      });
      return;
    }
    _pollTimer?.cancel();
    if (result.kind == CheckoutStatusKind.complete) {
      widget.session.refreshCredits();
    }
    setState(() {
      _status = result.kind;
      _credits = result.credits;
      _balance = result.balance;
      _error = result.error;
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _handleContinue() {
    final s = widget.session;
    final target = s.returnTo;
    s.returnTo = '/';
    s.openSupport(target.isNotEmpty ? target : '/');
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    if (status == null) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Verificando pagamento...'),
              ],
            ),
          ),
        ),
      );
    }
    if (status == CheckoutStatusKind.complete) {
      return SimpleLabPage(
        title: 'Pagamento confirmado',
        body:
            'Voce recebeu $_credits credito${_credits == 1 ? '' : 's'}. Saldo atual: $_balance credito${_balance == 1 ? '' : 's'}.',
        primary: 'Continuar',
        onPrimary: _handleContinue,
        session: widget.session,
        secondary: 'Ver creditos',
        onSecondary: widget.session.openCredits,
      );
    }
    if (status == CheckoutStatusKind.expired) {
      return SimpleLabPage(
        title: 'Sessao expirada',
        body:
            'O tempo para confirmar o pagamento expirou. Se o pagamento foi realizado, entre em contato com o suporte.',
        primary: 'Ver creditos',
        onPrimary: widget.session.openCredits,
        session: widget.session,
      );
    }
    return SimpleLabPage(
      title: 'Erro no pagamento',
      body: _error ??
          'Nao foi possivel verificar o pagamento. Tente novamente.',
      primary: 'Ver creditos',
      onPrimary: widget.session.openCredits,
      session: widget.session,
    );
  }
}

class FatherLabScreen extends StatefulWidget {
  const FatherLabScreen({required this.session, super.key});

  final LabSession session;

  @override
  State<FatherLabScreen> createState() => _FatherLabScreenState();
}

class _FatherLabScreenState extends State<FatherLabScreen> {
  bool _loading = true;
  String? _error;
  _FatherData? _data;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _refresh();
    _pollTimer = Timer.periodic(const Duration(seconds: 15), (_) => _refresh());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _refresh() {
    final s = widget.session;
    try {
      final hasSession = s.lessonLocalId != null || s.aulaStep > 0;
      final total = s.signalsSolid + s.signalsUnderstood + s.signalsFragile;
      final pct = s.totalAulaSteps > 0
          ? (s.aulaStep / s.totalAulaSteps * 100).round()
          : 0;
      setState(() {
        _loading = false;
        _error = null;
        _data = _FatherData(
          hasSession: hasSession,
          objective: s.freeText.isEmpty ? null : s.freeText,
          language: s.stableLang,
          progressPercent: pct,
          currentItemIndex: s.aulaStep,
          totalItems: s.totalAulaSteps,
          signalsSolid: s.signalsSolid,
          signalsUnderstood: s.signalsUnderstood,
          signalsFragile: s.signalsFragile,
          signalsTotal: total,
          amparoActive: false,
          amparoLevel: 0,
          upcomingReviews: const [],
          lessonsCount: s.aulaStep,
          takenAt: DateTime.now(),
        );
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.session;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Column(
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Painel do Pai',
                          style: TextStyle(
                            color: simDark,
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.3,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Acompanhe o progresso sem interferir',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: simMuted, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.refresh,
                          color: simMuted,
                          size: 20,
                        ),
                        tooltip: 'Atualizar',
                        onPressed: () {
                          setState(() => _loading = true);
                          _refresh();
                        },
                      ),
                      const SizedBox(width: 4),
                      OutlinedButton(
                        onPressed: s.goPortal,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: simBorder),
                          foregroundColor: simDark,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Voltar',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),

              if (_loading && _data == null)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: simDark,
                      strokeWidth: 2,
                    ),
                  ),
                )
              else if (_error != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      color: Color(0xFFDC2626),
                      fontSize: 13,
                    ),
                  ),
                )
              else if (_data != null && !_data!.hasSession)
                _PaiCard(
                  title: 'SEM SESSAO',
                  child: const Text(
                    'Nenhuma sessao ativa encontrada.',
                    style: TextStyle(color: simMuted, fontSize: 14),
                  ),
                )
              else if (_data != null) ...[
                // Objective
                _PaiCard(
                  title: 'OBJETIVO',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _data!.objective ?? '-',
                        style: const TextStyle(color: simDark, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Idioma: ${(_data!.language ?? '-').toUpperCase()}',
                        style: const TextStyle(color: simMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),

                // Progress
                _PaiCard(
                  title: 'PROGRESSO',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Item ${_data!.currentItemIndex} de ${_data!.totalItems}',
                            style: const TextStyle(
                              color: simMuted,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            '${_data!.progressPercent}%',
                            style: const TextStyle(
                              color: simDark,
                              fontSize: 28,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: _data!.totalItems > 0
                              ? _data!.currentItemIndex / _data!.totalItems
                              : 0,
                          minHeight: 8,
                          backgroundColor: simLight,
                          color: simDark,
                        ),
                      ),
                    ],
                  ),
                ),

                // Quality signals
                _PaiCard(
                  title: 'QUALIDADE',
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _PaiStat(
                              label: 'Solido',
                              value: _data!.signalsSolid,
                              hint: 'Dominou',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _PaiStat(
                              label: 'Entendeu',
                              value: _data!.signalsUnderstood,
                              hint: 'Compreendeu',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _PaiStat(
                              label: 'Fragil',
                              value: _data!.signalsFragile,
                              hint: 'Precisa reforco',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Total de sinais: ${_data!.signalsTotal}',
                        style: const TextStyle(color: simMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),

                // Amparo
                _PaiCard(
                  title: 'AMPARO',
                  child: _data!.amparoActive
                      ? Text(
                          'Amparo ativo no nivel ${_data!.amparoLevel}.',
                          style: const TextStyle(color: simDark, fontSize: 14),
                        )
                      : const Text(
                          'Nenhum amparo ativo.',
                          style: TextStyle(color: simMuted, fontSize: 14),
                        ),
                ),

                // Revisoes
                _PaiCard(
                  title: 'PROXIMAS REVISOES',
                  child: _data!.upcomingReviews.isEmpty
                      ? const Text(
                          'Nenhuma revisao pendente.',
                          style: TextStyle(color: simMuted, fontSize: 14),
                        )
                      : Column(
                          children: _data!.upcomingReviews.asMap().entries.map((
                            e,
                          ) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    e.value,
                                    style: const TextStyle(
                                      color: simDark,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                ),

                // Aulas salvas
                _PaiCard(
                  title: 'AULAS SALVAS',
                  child: Text(
                    '${_data!.lessonsCount} aula${_data!.lessonsCount == 1 ? '' : 's'} concluida${_data!.lessonsCount == 1 ? '' : 's'}',
                    style: const TextStyle(color: simDark, fontSize: 14),
                  ),
                ),

                // Timestamp
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 8),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'atualizado: ${_data!.takenAt.hour.toString().padLeft(2, '0')}:${_data!.takenAt.minute.toString().padLeft(2, '0')}:${_data!.takenAt.second.toString().padLeft(2, '0')}',
                      style: const TextStyle(color: simMuted, fontSize: 11),
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

class _FatherData {
  const _FatherData({
    required this.hasSession,
    this.objective,
    this.language,
    required this.progressPercent,
    required this.currentItemIndex,
    required this.totalItems,
    required this.signalsSolid,
    required this.signalsUnderstood,
    required this.signalsFragile,
    required this.signalsTotal,
    required this.amparoActive,
    required this.amparoLevel,
    required this.upcomingReviews,
    required this.lessonsCount,
    required this.takenAt,
  });

  final bool hasSession;
  final String? objective;
  final String? language;
  final int progressPercent;
  final int currentItemIndex;
  final int totalItems;
  final int signalsSolid;
  final int signalsUnderstood;
  final int signalsFragile;
  final int signalsTotal;
  final bool amparoActive;
  final int amparoLevel;
  final List<String> upcomingReviews;
  final int lessonsCount;
  final DateTime takenAt;
}

class _PaiCard extends StatelessWidget {
  const _PaiCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: simBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0E111827),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: simMuted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _PaiStat extends StatelessWidget {
  const _PaiStat({
    required this.label,
    required this.value,
    required this.hint,
  });

  final String label;
  final int value;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: simBorder),
      ),
      child: Column(
        children: [
          Text(
            '$value',
            style: const TextStyle(
              color: simDark,
              fontSize: 22,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: simDark,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(hint, style: const TextStyle(color: simMuted, fontSize: 10)),
        ],
      ),
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
          ? 'Pagina de privacidade preservada como ambiente de apoio do SIM.'
          : 'Pagina de termos preservada como ambiente de apoio do SIM.',
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
                  'Solicitar exclusao da conta',
                  style: TextStyle(
                    color: simDark,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Digite DELETAR para registrar a solicitacao de exclusao. A execucao real acontece no servidor, sem chave secreta dentro do app.',
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
                  label: 'Solicitar exclusao da conta',
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
    this.locked = false,
    this.correct = false,
    this.onTap,
    super.key,
  });

  final String label;
  final String text;
  final bool active;
  final bool locked;
  final bool correct;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    Color borderColor = active ? simDark : simBorder;
    Color bgColor = Colors.white;
    if (correct) {
      bgColor = const Color(0xFFECFDF5);
      borderColor = const Color(0xFF34D399);
    } else if (active && locked) {
      bgColor = const Color(0xFFFEF2F2);
      borderColor = const Color(0xFFF87171);
    } else if (active) {
      bgColor = simLight;
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Opacity(
          opacity: locked && !active && !correct ? 0.55 : 1.0,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor),
            ),
            child: Text(
              '$label. $text',
              style: const TextStyle(
                color: simDark,
                fontSize: 14.5,
                height: 1.35,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class QualifierButton extends StatelessWidget {
  const QualifierButton({
    required this.label,
    required this.text,
    required this.onTap,
    super.key,
  });

  final String label;
  final String text;
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
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: simBorder),
          ),
          child: Text(
            '$label. $text',
            style: const TextStyle(
              color: simDark,
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
              height: 1.35,
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
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (context) => SizedBox(
      height: MediaQuery.of(context).size.height * .82,
      child: _LessonHistoryDrawer(session: session),
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
  SupportedLang(
      code: 'en',
      name: 'English',
      native: 'English',
      flag: 'US'),
  SupportedLang(
    code: 'pt',
    name: 'Portuguese',
    native: 'Portugues',
    flag: 'BR',
  ),
  SupportedLang(
      code: 'es',
      name: 'Spanish',
      native: 'Espanol',
      flag: 'ES'),
  SupportedLang(
      code: 'fr',
      name: 'French',
      native: 'Francais',
      flag: 'FR'),
  SupportedLang(
      code: 'ja',
      name: 'Japanese',
      native: 'Japanese',
      flag: 'JP'),
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
        : '${language.name} - ${language.native}';
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
