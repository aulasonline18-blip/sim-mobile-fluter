// MIRROR OF: src/cyber/PaidImageService.ts (Web, source of truth)
// Serviço de imagem paga (Blueprint AI). Cobre ciclo offer→accept→consume.
// ATENÇÃO: Este serviço debita créditos do aluno. Chamar PaidImageService.offer()
// exibe confirmação de cobrança na UI (lesson_paid_image_offer.dart) ANTES de qualquer
// débito. Consume só é chamado após aceite explícito.
import 'dart:async';

import '../state/student_learning_state.dart';
import '../state/student_learning_state_service.dart';
import 's12_visual_pipeline.dart';

enum PaidImageOfferStatus { pending, accepted, declined, consumed, failed }

class PaidImageOffer {
  PaidImageOffer({
    required this.offerId,
    required this.lessonKey,
    required this.prompt,
    required this.creditCost,
  });

  final String offerId;
  final String lessonKey;
  final String prompt;
  final int creditCost;
  PaidImageOfferStatus status = PaidImageOfferStatus.pending;
  String? resultUrl;
  String? error;
}

typedef PaidImageFetcher =
    Future<String> Function({
      required String prompt,
      required String lessonKey,
      required String acceptedOfferId,
      required String idempotencyKey,
    });

class PaidImageService {
  PaidImageService({
    required StudentLearningStateService stateService,
    required PaidImageFetcher fetcher,
    int creditCostPerImage = 1,
  }) : this._(stateService, fetcher, creditCostPerImage);

  PaidImageService._(this._stateService, this._fetcher, this._creditCost);

  final StudentLearningStateService _stateService;
  final PaidImageFetcher _fetcher;
  final int _creditCost;

  final Map<String, PaidImageOffer> _offers = {};
  final _offerController = StreamController<PaidImageOffer>.broadcast();

  /// Stream de ofertas — UI escuta para mostrar lesson_paid_image_offer.dart.
  Stream<PaidImageOffer> get offerStream => _offerController.stream;

  /// Emite oferta de imagem paga. Não debita crédito.
  /// Chamado pelo orchestrator quando S12 retorna generate:true + allowPaid:false.
  PaidImageOffer offer({
    required String lessonKey,
    required String lessonLocalId,
    required Map<String, dynamic>? visualTrigger,
  }) {
    final conteudo = visualTrigger == null
        ? null
        : visualTrigger['visual_trigger'] is Map
        ? visualTrigger
        : {'visual_trigger': visualTrigger};
    final decision = decideVisualGeneration(
      conteudo,
      const VisualDecisionContext(allowPaidImages: true, priority: 'active'),
    );

    if (!decision.generate || decision.prompt == null) {
      return PaidImageOffer(
        offerId: 'noop_${DateTime.now().millisecondsSinceEpoch}',
        lessonKey: lessonKey,
        prompt: '',
        creditCost: 0,
      )..status = PaidImageOfferStatus.declined;
    }

    final offerId = 'img_offer_${DateTime.now().millisecondsSinceEpoch}';
    final o = PaidImageOffer(
      offerId: offerId,
      lessonKey: lessonKey,
      prompt: decision.prompt!,
      creditCost: _creditCost,
    );
    _offers[offerId] = o;
    _stateService.appendEvent(
      lessonLocalId,
      StudentLearningEvent(
        type: 'PAID_IMAGE_OFFERED',
        ts: DateTime.now().millisecondsSinceEpoch,
        payload: {
          'offerId': offerId,
          'lessonKey': lessonKey,
          'creditCost': _creditCost,
          'reason': decision.reason,
        },
      ),
    );
    _offerController.add(o);
    return o;
  }

  /// Aceita a oferta: debita crédito e inicia geração. Retorna URL da imagem.
  Future<String?> consume({
    required String offerId,
    required String lessonLocalId,
  }) async {
    final o = _offers[offerId];
    if (o == null || o.status != PaidImageOfferStatus.pending) return null;
    o.status = PaidImageOfferStatus.accepted;
    _offerController.add(o);

    try {
      final url = await _fetcher(
        prompt: o.prompt,
        lessonKey: o.lessonKey,
        acceptedOfferId: offerId,
        idempotencyKey: offerId,
      );
      o.resultUrl = url;
      o.status = PaidImageOfferStatus.consumed;
      _stateService.appendEvent(
        lessonLocalId,
        StudentLearningEvent(
          type: 'PAID_IMAGE_CONSUMED',
          ts: DateTime.now().millisecondsSinceEpoch,
          payload: {
            'offerId': offerId,
            'lessonKey': o.lessonKey,
            'creditCost': o.creditCost,
          },
        ),
      );
      _offerController.add(o);
      return url;
    } catch (e) {
      o.error = e.toString();
      o.status = PaidImageOfferStatus.failed;
      _stateService.appendEvent(
        lessonLocalId,
        StudentLearningEvent(
          type: 'PAID_IMAGE_FAILED',
          ts: DateTime.now().millisecondsSinceEpoch,
          payload: {
            'offerId': offerId,
            'lessonKey': o.lessonKey,
            'error': e.toString(),
          },
        ),
      );
      _offerController.add(o);
      return null;
    }
  }

  /// Recusa a oferta. Não debita crédito.
  void decline({required String offerId, required String lessonLocalId}) {
    final o = _offers[offerId];
    if (o == null) return;
    o.status = PaidImageOfferStatus.declined;
    _stateService.appendEvent(
      lessonLocalId,
      StudentLearningEvent(
        type: 'PAID_IMAGE_DECLINED',
        ts: DateTime.now().millisecondsSinceEpoch,
        payload: {'offerId': offerId, 'lessonKey': o.lessonKey},
      ),
    );
    _offerController.add(o);
  }

  /// Consulta status de uma oferta.
  PaidImageOffer? getOffer(String offerId) => _offers[offerId];

  void dispose() {
    _offerController.close();
  }
}
