import '../state/student_learning_state.dart';
import 'aux_room_models.dart';
import 'student_aux_room_service.dart';

class ReviewRoomService {
  const ReviewRoomService(this.service);

  final StudentAuxRoomService service;

  ReviewRoomView createReviewChoiceView() => const ReviewRoomView(
        status: ReviewRoomStatus.choose,
        count: 5,
        queue: [],
        idx: 0,
      );

  Future<ReviewRoomView> startReviewRoom(
    ReviewRoomContext context,
    int count,
  ) async {
    final boundedCount = count == 10 ? 10 : 5;
    final queue = service.buildReviewQueueForLesson(
      lessonLocalId: context.lessonLocalId,
      topic: context.topic,
      items: context.items,
      count: boundedCount,
      fallbackStartIdx: context.fallbackStartIdx,
    );
    if (queue.isEmpty) {
      return ReviewRoomView(
        status: ReviewRoomStatus.failed,
        count: boundedCount,
        queue: const [],
        idx: 0,
        errMsg: 'Sem itens para revisar.',
      );
    }
    return prepareReviewRoomQuestion(
      context: context,
      queue: queue,
      idx: 0,
      count: boundedCount,
    );
  }

  Future<ReviewRoomView> prepareReviewRoomQuestion({
    required ReviewRoomContext context,
    required List<String> queue,
    required int idx,
    required int count,
  }) async {
    final prepared = await service.prepareAuxRoomQuestion(
      lessonLocalId: context.lessonLocalId,
      mode: AuxRoomMode.review,
      profile: context.profile,
      items: context.items,
      marker: idx < queue.length ? queue[idx] : null,
      signal: DecisionSignal.two,
    );
    if (!prepared.ok) {
      return ReviewRoomView(
        status: ReviewRoomStatus.failed,
        count: count,
        queue: queue,
        idx: idx,
        errMsg: prepared.error,
      );
    }
    return ReviewRoomView(
      status: ReviewRoomStatus.ready,
      count: count,
      queue: queue,
      idx: idx,
      conteudo: prepared.conteudo,
    );
  }

  ReviewRoomView selectLetter(ReviewRoomView view, AnswerLetter letra) {
    return view.copyWith(status: ReviewRoomStatus.answering, letra: letra);
  }

  ReviewRoomView answerReviewRoom(
    ReviewRoomContext context,
    ReviewRoomView view,
    DecisionSignal sinal,
  ) {
    final conteudo = view.conteudo;
    final letra = view.letra;
    final marker = view.idx < view.queue.length ? view.queue[view.idx] : null;
    if (conteudo == null || letra == null || marker == null) {
      return view.copyWith(
        status: ReviewRoomStatus.failed,
        errMsg: 'review answer missing data',
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
      status: ReviewRoomStatus.result,
      sinal: sinal,
      resultCorrect: letra == conteudo.correctAnswer,
    );
  }

  Future<ReviewRoomView> nextReviewRoom(
    ReviewRoomContext context,
    ReviewRoomView view,
  ) async {
    final nextIdx = view.idx + 1;
    if (nextIdx >= view.queue.length || nextIdx >= view.count) {
      service.completeReviewSession(context.lessonLocalId);
      return view.copyWith(status: ReviewRoomStatus.done, idx: nextIdx);
    }
    return prepareReviewRoomQuestion(
      context: context,
      queue: view.queue,
      idx: nextIdx,
      count: view.count,
    );
  }
}
