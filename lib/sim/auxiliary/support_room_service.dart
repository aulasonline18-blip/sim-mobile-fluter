import 'dart:async';

import '../modules/pedagogical_module_contracts.dart';
import '../state/student_learning_state.dart';
import '../state/student_learning_state_service.dart';
import 'aux_room_models.dart';

const supportNeutralMessage =
    'Vamos adaptar o caminho agora. Vou preparar tres passos curtos e depois voce volta para a aula no mesmo ponto.';

enum SupportRoomStatus {
  idle,
  preparing,
  ready,
  answering,
  result,
  crossed,
  retryAvailable,
  maxReached,
  failed,
}

class SupportStation {
  const SupportStation({
    required this.marker,
    required this.title,
    required this.purpose,
    required this.layer,
    required this.type,
    required this.level,
    this.content,
  });

  final String marker;
  final String title;
  final String purpose;
  final LessonLayer layer;
  final String type;
  final int level;
  final AuxRoomContent? content;

  JsonMap toJson() => {
        'marker': marker,
        'title': title,
        'purpose': purpose,
        'layer': layer.value,
        'amparo_type': type,
        'amparo_level': level,
        if (content != null)
          'conteudo': {
            'explanation': content!.explanation,
            'question': content!.question,
            'options': {
              'A': content!.options[AnswerLetter.A],
              'B': content!.options[AnswerLetter.B],
              'C': content!.options[AnswerLetter.C],
            },
            'correct_answer': content!.correctAnswer.name,
          },
      };

  factory SupportStation.fromJson(JsonMap json) {
    final content = json['conteudo'] is Map
        ? _contentFromJson(JsonMap.from(json['conteudo'] as Map))
        : null;
    return SupportStation(
      marker: (json['marker'] ?? 'AMPARO').toString(),
      title: (json['title'] ?? 'Travessia').toString(),
      purpose: (json['purpose'] ?? '').toString(),
      layer: LessonLayerValue.fromValue(json['layer']),
      type: (json['amparo_type'] ?? 'support').toString(),
      level: (json['amparo_level'] as num?)?.toInt() ?? 1,
      content: content,
    );
  }

  SupportStation copyWith({AuxRoomContent? content}) => SupportStation(
        marker: marker,
        title: title,
        purpose: purpose,
        layer: layer,
        type: type,
        level: level,
        content: content ?? this.content,
      );
}

class SupportStationResult {
  const SupportStationResult({
    required this.marker,
    required this.letra,
    required this.sinal,
    required this.correct,
    required this.ts,
  });

  final String marker;
  final AnswerLetter letra;
  final DecisionSignal sinal;
  final bool correct;
  final int ts;

  bool get aggravant => !correct || sinal == DecisionSignal.three;

  JsonMap toJson() => {
        'marker': marker,
        'letra': letra.name,
        'sinal': sinal.value,
        'correct': correct,
        'ts': ts,
      };

  factory SupportStationResult.fromJson(JsonMap json) => SupportStationResult(
        marker: (json['marker'] ?? '').toString(),
        letra: AnswerLetter.values.firstWhere(
          (letter) => letter.name == json['letra'],
          orElse: () => AnswerLetter.A,
        ),
        sinal: DecisionSignalValue.fromValue(json['sinal']),
        correct: json['correct'] == true,
        ts: (json['ts'] as num?)?.toInt() ?? 0,
      );
}

class SupportRoomView {
  const SupportRoomView({
    required this.status,
    required this.stations,
    required this.index,
    required this.attemptCount,
    this.progress = 0,
    this.message = supportNeutralMessage,
    this.conductionMessage,
    this.letra,
    this.sinal,
    this.resultCorrect,
    this.error,
    this.showExitOptions = false,
  });

  final SupportRoomStatus status;
  final List<SupportStation> stations;
  final int index;
  final int attemptCount;
  final int progress;
  final String message;
  final String? conductionMessage;
  final AnswerLetter? letra;
  final DecisionSignal? sinal;
  final bool? resultCorrect;
  final String? error;
  final bool showExitOptions;

  SupportStation? get station =>
      index >= 0 && index < stations.length ? stations[index] : null;

  SupportRoomView copyWith({
    SupportRoomStatus? status,
    List<SupportStation>? stations,
    int? index,
    int? attemptCount,
    int? progress,
    String? message,
    String? conductionMessage,
    AnswerLetter? letra,
    DecisionSignal? sinal,
    bool? resultCorrect,
    String? error,
    bool? showExitOptions,
  }) {
    return SupportRoomView(
      status: status ?? this.status,
      stations: stations ?? this.stations,
      index: index ?? this.index,
      attemptCount: attemptCount ?? this.attemptCount,
      progress: progress ?? this.progress,
      message: message ?? this.message,
      conductionMessage: conductionMessage ?? this.conductionMessage,
      letra: letra ?? this.letra,
      sinal: sinal ?? this.sinal,
      resultCorrect: resultCorrect ?? this.resultCorrect,
      error: error,
      showExitOptions: showExitOptions ?? this.showExitOptions,
    );
  }
}

class SupportRoomContext {
  const SupportRoomContext({
    required this.lessonLocalId,
    required this.objective,
    required this.currentItem,
    required this.marker,
    required this.layer,
    required this.profile,
    required this.currentMaterial,
    required this.recentAttempts,
  });

  final String lessonLocalId;
  final String objective;
  final String currentItem;
  final String? marker;
  final LessonLayer layer;
  final AuxRoomProfile profile;
  final JsonMap currentMaterial;
  final List<LessonAttempt> recentAttempts;
}

class SupportRoomService {
  const SupportRoomService({
    required this.stateService,
    required this.t00Client,
    required this.t02Client,
    this.preparationTimeout = const Duration(seconds: 60),
  });

  final StudentLearningStateService stateService;
  final T00BootstrapClient t00Client;
  final T02LessonClient t02Client;
  final Duration preparationTimeout;

  SupportRoomView preparingView(String lessonLocalId) {
    final support = _supportFor(lessonLocalId);
    return SupportRoomView(
      status: SupportRoomStatus.preparing,
      stations: const [],
      index: 0,
      attemptCount: _attemptCount(support),
      progress: 5,
    );
  }

  Future<SupportRoomView> start(SupportRoomContext context) async {
    _append(context.lessonLocalId, 'SUPPORT_ROBOT_SHOWN', {
      'message': supportNeutralMessage,
    });
    _append(context.lessonLocalId, 'SUPPORT_PREPARATION_STARTED', const {});
    _append(context.lessonLocalId, 'SUPPORT_CURRICULUM_REQUESTED', {
      'marker': context.marker,
      'layer': context.layer.value,
    });
    try {
      final stations = await _loadStations(context);
      if (stations.length != 3) {
        throw Exception('T00 amparo deve retornar exatamente 3 estacoes.');
      }
      final ready = await _ensureStationContent(context, stations, 0);
      _writeSupport(context.lessonLocalId, {
        'active': true,
        'status': 'ready',
        'stations': ready.map((station) => station.toJson()).toList(),
        'current_index': 0,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });
      _append(context.lessonLocalId, 'SUPPORT_CURRICULUM_READY', {
        'count': ready.length,
      });
      _append(context.lessonLocalId, 'SUPPORT_STATION_SHOWN', {
        'index': 0,
        'marker': ready.first.marker,
      });
      return SupportRoomView(
        status: SupportRoomStatus.ready,
        stations: ready,
        index: 0,
        attemptCount: _attemptCount(_supportFor(context.lessonLocalId)),
        progress: 33,
      );
    } on TimeoutException {
      _append(context.lessonLocalId, 'SUPPORT_PREPARATION_TIMEOUT', const {});
      return _failed(context.lessonLocalId);
    } catch (error) {
      _append(context.lessonLocalId, 'SUPPORT_PREPARATION_FAILED', {
        'error': error.toString(),
      });
      return _failed(context.lessonLocalId, error: error.toString());
    }
  }

  SupportRoomView selectAnswer(SupportRoomView view, AnswerLetter letra) {
    return view.copyWith(status: SupportRoomStatus.answering, letra: letra);
  }

  SupportRoomView submitQualifier(
    SupportRoomContext context,
    SupportRoomView view,
    DecisionSignal signal,
  ) {
    final station = view.station;
    final content = station?.content;
    final letra = view.letra;
    if (station == null || content == null || letra == null) {
      return view.copyWith(
        status: SupportRoomStatus.failed,
        error: 'Passo de amparo incompleto.',
      );
    }
    final correct = letra == content.correctAnswer;
    final result = SupportStationResult(
      marker: station.marker,
      letra: letra,
      sinal: signal,
      correct: correct,
      ts: DateTime.now().millisecondsSinceEpoch,
    );
    final support = _supportFor(context.lessonLocalId);
    final results = _resultList(support['results'])..add(result.toJson());
    _writeSupport(context.lessonLocalId, {
      'results': results,
      'updatedAt': result.ts,
    });
    _append(context.lessonLocalId, 'SUPPORT_ANSWER_SUBMITTED', result.toJson());
    return view.copyWith(
      status: SupportRoomStatus.result,
      sinal: signal,
      resultCorrect: correct,
    );
  }

  Future<SupportRoomView> next(
      SupportRoomContext context, SupportRoomView view) async {
    final nextIndex = view.index + 1;
    if (nextIndex >= view.stations.length) return _finish(context, view);
    final stations =
        await _ensureStationContent(context, view.stations, nextIndex);
    _writeSupport(context.lessonLocalId, {
      'stations': stations.map((station) => station.toJson()).toList(),
      'current_index': nextIndex,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    });
    _append(context.lessonLocalId, 'SUPPORT_STATION_SHOWN', {
      'index': nextIndex,
      'marker': stations[nextIndex].marker,
    });
    return view.copyWith(
      status: SupportRoomStatus.ready,
      stations: stations,
      index: nextIndex,
      progress: ((nextIndex + 1) / 3 * 100).round(),
      letra: null,
      sinal: null,
      resultCorrect: null,
    );
  }

  SupportRoomView returnToLesson(String lessonLocalId,
      {bool afterFailure = false}) {
    stateService.mutate(lessonLocalId, (state) {
      final existing = state.extra['support'];
      final support = JsonMap.from(existing is Map ? existing : const {});
      final snapshot = support['return_snapshot'];
      final snapshotMap = snapshot is Map ? JsonMap.from(snapshot) : const {};
      final progress = snapshotMap['progress'] is Map
          ? LessonProgress.fromJson(
              JsonMap.from(snapshotMap['progress'] as Map))
          : state.progress;
      final current = snapshotMap['current'] is Map
          ? LessonCurrent.fromJson(JsonMap.from(snapshotMap['current'] as Map))
          : state.current;
      final extra = JsonMap.from(state.extra);
      extra['support'] = {
        ...support,
        'active': false,
        'return_to_lesson': true,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      };
      return state.copyWith(
        progress: progress,
        current: current,
        auxRooms: snapshotMap['auxRooms'] is Map
            ? JsonMap.from(snapshotMap['auxRooms'] as Map)
            : state.auxRooms,
        currentLessonMaterial: snapshotMap['currentLessonMaterial'] is Map
            ? JsonMap.from(snapshotMap['currentLessonMaterial'] as Map)
            : state.currentLessonMaterial,
        extra: extra,
      );
    });
    _append(
      lessonLocalId,
      afterFailure
          ? 'SUPPORT_RETURNED_AFTER_FAILURE'
          : 'SUPPORT_RETURNED_TO_LESSON',
      const {},
    );
    return const SupportRoomView(
      status: SupportRoomStatus.idle,
      stations: [],
      index: 0,
      attemptCount: 0,
    );
  }

  SupportRoomView retryRequested(String lessonLocalId) {
    _append(lessonLocalId, 'SUPPORT_RETRY_REQUESTED', const {});
    _append(lessonLocalId, 'SUPPORT_RETRY', const {});
    _writeSupport(lessonLocalId, {
      'status': 'preparing',
      'stations': const [],
      'current_index': 0,
      'results': const [],
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    });
    return preparingView(lessonLocalId);
  }

  Future<List<SupportStation>> _loadStations(SupportRoomContext context) async {
    final payload = <JsonMap>[];
    await for (final chunk in t00Client
        .runBootstrap(
          T00BootstrapRequest(
            lessonLocalId: context.lessonLocalId,
            onboarding: {
              'modo': 'amparo',
              'dados': _supportPayload(context),
            },
            lang: context.profile.stableLang ?? 'pt',
            academic: context.profile.academicLevel ?? '',
          ),
        )
        .timeout(preparationTimeout)) {
      _append(context.lessonLocalId, 'SUPPORT_PREPARATION_PROGRESS', {
        'type': chunk.type,
      });
      payload.add(chunk.payload);
    }
    final stations = _extractStations(payload);
    return stations.take(3).toList(growable: false);
  }

  Future<List<SupportStation>> _ensureStationContent(
    SupportRoomContext context,
    List<SupportStation> stations,
    int index,
  ) async {
    final station = stations[index];
    if (station.content != null) return stations;
    try {
      final material = await t02Client.auxiliaryRoom(
        T02LessonRequest(
          lessonLocalId: context.lessonLocalId,
          item: station.purpose.isNotEmpty ? station.purpose : station.title,
          lang: context.profile.stableLang ?? 'pt',
          academic: context.profile.academicLevel ?? '',
          layer: LessonLayer.l1,
          mode: 'amparo',
          errCount: 0,
          history: const [],
          marker: station.marker,
          profile: {
            'modo': 'amparo',
            'item': station.toJson(),
            'perfil': context.profile.toJson(),
            'idioma': context.profile.stableLang ?? 'pt',
          },
        ),
      );
      final next = [...stations];
      next[index] = station.copyWith(
        content: AuxRoomContent(
          explanation: material.explanation,
          question: material.question,
          options: material.options,
          correctAnswer: material.correctAnswer,
        ),
      );
      return next;
    } catch (error) {
      _append(context.lessonLocalId, 'SUPPORT_PREPARATION_FAILED', {
        'station': station.marker,
        'error': error.toString(),
      });
      rethrow;
    }
  }

  SupportRoomView _finish(SupportRoomContext context, SupportRoomView view) {
    final results = _resultList(_supportFor(context.lessonLocalId)['results'])
        .map(SupportStationResult.fromJson)
        .toList(growable: false);
    final aggravants = results.where((result) => result.aggravant).length;
    final attemptCount = _attemptCount(_supportFor(context.lessonLocalId));
    if (aggravants < 2) {
      _writeSupport(context.lessonLocalId, {
        'active': false,
        'crossed': true,
        'status': 'crossed',
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });
      _append(context.lessonLocalId, 'SUPPORT_CROSSED', {
        'aggravants': aggravants,
      });
      _append(context.lessonLocalId, 'SUPPORT_COMPLETED', const {});
      return view.copyWith(status: SupportRoomStatus.crossed, progress: 100);
    }
    _append(context.lessonLocalId, 'SUPPORT_NOT_CROSSED', {
      'aggravants': aggravants,
      'attemptCount': attemptCount,
    });
    if (attemptCount < 2) {
      _append(context.lessonLocalId, 'SUPPORT_RETRY', {
        'attemptCount': attemptCount,
      });
      return view.copyWith(status: SupportRoomStatus.retryAvailable);
    }
    _writeSupport(context.lessonLocalId, {
      'active': false,
      'status': 'max_reached',
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    });
    _append(context.lessonLocalId, 'SUPPORT_MAX_ATTEMPTS_REACHED', {
      'attemptCount': attemptCount,
    });
    _append(context.lessonLocalId, 'SUPPORT_COMPLETED', const {});
    return view.copyWith(status: SupportRoomStatus.maxReached);
  }

  SupportRoomView _failed(String lessonLocalId, {String? error}) {
    _writeSupport(lessonLocalId, {
      'status': 'failed',
      'error': error,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    });
    return SupportRoomView(
      status: SupportRoomStatus.failed,
      stations: const [],
      index: 0,
      attemptCount: _attemptCount(_supportFor(lessonLocalId)),
      progress: 100,
      error: 'Nao foi possivel preparar este amparo agora.',
      showExitOptions: true,
    );
  }

  JsonMap _supportPayload(SupportRoomContext context) => {
        'objetivo': context.objective,
        'materia': context.objective,
        'item_atual': context.currentItem,
        'marker': context.marker,
        'layer': context.layer.value,
        'explicacao_atual': context.currentMaterial['explanation'],
        'pergunta_atual': context.currentMaterial['question'],
        'resposta_correta': context.currentMaterial['correct_answer'] ??
            context.currentMaterial['correctAnswer'],
        'ultimas_respostas_erradas': context.recentAttempts
            .where((attempt) => !attempt.correct)
            .map((attempt) => attempt.toJson())
            .toList(),
        'ultimos_qualificadores': context.recentAttempts
            .map((attempt) => attempt.sinal.value)
            .toList(),
        'historico_recente':
            context.recentAttempts.map((attempt) => attempt.toJson()).toList(),
        'perfil': context.profile.toJson(),
        'idioma': context.profile.stableLang ?? 'pt',
        'ponto_de_travamento': context.marker ?? context.currentItem,
      };

  List<SupportStation> _extractStations(List<JsonMap> chunks) {
    for (final chunk in chunks.reversed) {
      final raw = chunk['passos'] ??
          chunk['stations'] ??
          (chunk['support'] is Map
              ? (chunk['support'] as Map)['passos']
              : null) ??
          (chunk['curriculum'] is Map
              ? (chunk['curriculum'] as Map)['items']
              : null);
      if (raw is List) {
        return raw
            .whereType<Map>()
            .map((entry) => SupportStation.fromJson(JsonMap.from(entry)))
            .toList(growable: false);
      }
    }
    return const [];
  }

  JsonMap _supportFor(String lessonLocalId) {
    final support = stateService.read(lessonLocalId)?.extra['support'];
    return JsonMap.from(support is Map ? support : const {});
  }

  int _attemptCount(JsonMap support) =>
      (support['support_attempt_count'] as num?)?.toInt() ??
      (support['attempt_count'] as num?)?.toInt() ??
      1;

  void _writeSupport(String lessonLocalId, JsonMap patch) {
    stateService.mutate(lessonLocalId, (state) {
      final existing = state.extra['support'];
      final support = JsonMap.from(existing is Map ? existing : const {});
      return state.copyWith(extra: {
        ...state.extra,
        'support': {...support, ...patch},
      });
    });
  }

  void _append(String lessonLocalId, String type, JsonMap payload) {
    stateService.appendEvent(
      lessonLocalId,
      StudentLearningEvent(
        type: type,
        ts: DateTime.now().millisecondsSinceEpoch,
        payload: payload,
      ),
    );
  }
}

AuxRoomContent _contentFromJson(JsonMap json) {
  final options = json['options'];
  final correct =
      (json['correct_answer'] ?? json['correctAnswer'] ?? 'A').toString();
  return AuxRoomContent(
    explanation: (json['explanation'] ?? '').toString(),
    question: (json['question'] ?? '').toString(),
    options: {
      AnswerLetter.A: options is Map ? (options['A'] ?? '').toString() : '',
      AnswerLetter.B: options is Map ? (options['B'] ?? '').toString() : '',
      AnswerLetter.C: options is Map ? (options['C'] ?? '').toString() : '',
    },
    correctAnswer: AnswerLetter.values.firstWhere(
      (letter) => letter.name == correct,
      orElse: () => AnswerLetter.A,
    ),
  );
}

List<JsonMap> _resultList(Object? raw) => (raw as List? ?? const [])
    .whereType<Map>()
    .map((entry) => JsonMap.from(entry))
    .toList();
