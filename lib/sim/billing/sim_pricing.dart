enum CreditPackId { credits100, credits200, credits500 }

extension CreditPackIdWire on CreditPackId {
  String get wire => switch (this) {
        CreditPackId.credits100 => 'credits_100',
        CreditPackId.credits200 => 'credits_200',
        CreditPackId.credits500 => 'credits_500',
      };

  static CreditPackId fromWire(String value) {
    return switch (value) {
      'credits_100' => CreditPackId.credits100,
      'credits_200' => CreditPackId.credits200,
      'credits_500' => CreditPackId.credits500,
      _ => throw ArgumentError('Invalid packId: $value'),
    };
  }
}

class CreditPack {
  const CreditPack({
    required this.id,
    required this.credits,
    required this.amountCents,
  });

  final CreditPackId id;
  final int credits;
  final int amountCents;
}

class SimPricing {
  const SimPricing();

  String get currency => 'brl';
  int get lessonCostCredits => 3;
  int get imageCostCredits => 10;
  int get signupBonusCredits => 9;

  List<CreditPack> get creditPacks => const [
        CreditPack(
          id: CreditPackId.credits100,
          credits: 100,
          amountCents: 790,
        ),
        CreditPack(
          id: CreditPackId.credits200,
          credits: 200,
          amountCents: 1580,
        ),
        CreditPack(
          id: CreditPackId.credits500,
          credits: 500,
          amountCents: 3950,
        ),
      ];

  CreditPack getPackOrThrow(String packId) {
    final id = CreditPackIdWire.fromWire(packId);
    return creditPacks.firstWhere((pack) => pack.id == id);
  }
}

const simPricing = SimPricing();
