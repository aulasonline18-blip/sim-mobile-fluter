class PaidImageOffer {
  const PaidImageOffer({
    required this.prompt,
    required this.lessonKey,
    this.message,
    this.costCredits = 10,
  });

  final String prompt;
  final String lessonKey;
  final String? message;
  final int costCredits;
}

abstract interface class LessonPaidImageOrchestrator {
  Future<void> acceptPaidImageOffer(String offerKey);
  void declinePaidImageOffer(String offerKey);
}

abstract interface class CreditsGateway {
  Future<int> getMyCredits();
}

class LessonPaidImageOfferController {
  LessonPaidImageOfferController({
    required this.orchestrator,
    required this.creditsGateway,
  });

  final LessonPaidImageOrchestrator orchestrator;
  final CreditsGateway creditsGateway;

  PaidImageOffer? paidOffer;
  String? offerKey;
  bool offerLoading = false;
  int? creditBalance;
  String? navigationTarget;

  Future<void> refreshBalance() async {
    creditBalance = await creditsGateway.getMyCredits();
  }

  void registerPaidOffer(String key, PaidImageOffer offer) {
    offerKey = key;
    paidOffer = offer;
  }

  void clearPaidOffer() {
    offerKey = null;
    paidOffer = null;
  }

  Future<void> acceptPaidImage() async {
    final key = offerKey;
    if (key == null) return;
    offerLoading = true;
    try {
      await orchestrator.acceptPaidImageOffer(key);
      await refreshBalance();
    } finally {
      offerLoading = false;
    }
  }

  void declinePaidImage() {
    final key = offerKey;
    if (key == null) return;
    orchestrator.declinePaidImageOffer(key);
    paidOffer = null;
  }

  void handleInsufficientCredits({String? kind}) {
    if (kind == 'image') {
      creditBalance = 0;
      offerLoading = false;
      return;
    }
    buyCredits();
  }

  void buyCredits() {
    navigationTarget = '/creditos?returnTo=/cyber/aula';
  }
}
