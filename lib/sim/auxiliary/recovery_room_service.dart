import '../state/student_learning_state.dart';
import 'aux_room_models.dart';
import 'student_aux_room_service.dart';

class RecoveryRoomService {
  const RecoveryRoomService(this.service);

  final StudentAuxRoomService service;

  bool shouldStartRecoveryRoom(String lessonLocalId) {
    return service.shouldLessonBlockFinalCompletion(lessonLocalId);
  }

  Future<RecoveryRoomView> startRecoveryRoom(
    RecoveryRoomContext context,
  ) async {
    final built = service.buildRecoveryQueueForLesson(
      lessonLocalId: context.lessonLocalId,
      topic: context.topic,
      items: context.items,
    );
    if (built.queue.isEmpty) {
      service.registerRecoveryCompleted(context.lessonLocalId);
      return const RecoveryRoomView(
        status: RecoveryRoomStatus.done,
        queue: [],
        idx: 0,
      );
    }
    service.registerRecoveryStarted(context.lessonLocalId, built.queue);
    final signal = built.signalByMarker[built.queue.first] ?? DecisionSignal.three;
    final prepared = await _prepare(
      context: context,
      queue: built.queue,
      idx: 0,
      signal: signal,
    );
    if (prepared.status == RecoveryRoomStatus.ready) {
      return prepared.copyWith(status: RecoveryRoomStatus.intro);
    }
    return prepared;
  }

  Future<RecoveryRoomView> _prepare({
    required RecoveryRoomContext context,
    required List<String> queue,
    required int idx,
    required DecisionSignal signal,
  }) async {
    final prepared = await service.prepareAuxRoomQuestion(
      lessonLocalId: context.lessonLocalId,
      mode: AuxRoomMode.recovery,
      profile: context.profile,
      items: context.items,
      marker: idx < queue.length ? queue[idx] : null,
      signal: signal,
    );
    if (!prepared.ok) {
      return RecoveryRoomView(
        status: RecoveryRoomStatus.failed,
        queue: queue,
        idx: idx,
        errMsg: prepared.error,
      );
    }
    return RecoveryRoomView(
      status: RecoveryRoomStatus.ready,
      queue: queue,
      idx: idx,
      conteudo: prepared.conteudo,
    );
  }

  RecoveryRoomView continueRecovery(RecoveryRoomView view) {
    return view.status == RecoveryRoomStatus.intro
        ? view.copyWith(status: RecoveryRoomStatus.ready)
        : view;
  }

  RecoveryRoomView selectLetter(RecoveryRoomView view, AnswerLetter letra) {
    return view.copyWith(status: RecoveryRoomStatus.answering, letra: letra);
  }

  RecoveryRoomView answerRecoveryRoom(
    RecoveryRoomContext context,
    RecoveryRoomView view,
    DecisionSignal sinal,
  ) {
    final conteudo = view.conteudo;
    final letra = view.letra;
    final marker = view.idx < view.queue.length ? view.queue[view.idx] : null;
    if (conteudo == null || letra == null || marker == null) {
      return view.copyWith(
        status: RecoveryRoomStatus.failed,
        errMsg: 'recovery answer missing data',
      );
    }
    service.recordAuxRoomAnswer(
      lessonLocalId: context.lessonLocalId,
      marker: marker,
      layer: context.layer,
      items: context.items,
      conteudo: conteudo,
      letra: letra,
      sinal: sinal,
      source: 'cyber.aula',
    );
    return view.copyWith(
      status: RecoveryRoomStatus.result,
      sinal: sinal,
      resultCorrect: letra == conteudo.correctAnswer,
    );
  }

  Future<RecoveryRoomView> nextRecoveryRoom(
    RecoveryRoomContext context,
    RecoveryRoomView view,
  ) async {
    final built = service.buildRecoveryQueueForLesson(
      lessonLocalId: context.lessonLocalId,
      topic: context.topic,
      items: context.items,
    );
    if (built.queue.isEmpty) {
      service.registerRecoveryCompleted(context.lessonLocalId);
      return view.copyWith(status: RecoveryRoomStatus.done);
    }
    final signal = built.signalByMarker[built.queue.first] ?? DecisionSignal.three;
    return _prepare(context: context, queue: built.queue, idx: 0, signal: signal);
  }

  RecoveryRoomView finishRecoveryRoom(
    String lessonLocalId,
    RecoveryRoomView view,
  ) {
    if (service.shouldLessonBlockFinalCompletion(lessonLocalId)) {
      return view.copyWith(restartRequired: true);
    }
    service.registerFinalCompletionAllowed(lessonLocalId);
    return view.copyWith(status: RecoveryRoomStatus.done);
  }
}
