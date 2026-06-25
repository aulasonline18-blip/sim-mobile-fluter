import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/sim/billing/account_deletion.dart';
import 'package:sim_mobile/sim/billing/checkout_return_controller.dart';
import 'package:sim_mobile/sim/billing/credit_client.dart';
import 'package:sim_mobile/sim/billing/credit_purchase_service.dart';
import 'package:sim_mobile/sim/billing/credit_service.dart';
import 'package:sim_mobile/sim/billing/credits_functions.dart';
import 'package:sim_mobile/sim/billing/credits_route_controller.dart';
import 'package:sim_mobile/sim/billing/payment_return_store.dart';
import 'package:sim_mobile/sim/billing/payment_webhook_contract.dart';
import 'package:sim_mobile/sim/billing/payments_functions.dart';
import 'package:sim_mobile/sim/billing/sim_pricing.dart';
import 'package:sim_mobile/sim/billing/student_billing_ledger.dart';
import 'package:sim_mobile/sim/state/student_learning_state.dart';
import 'package:sim_mobile/sim/state/student_learning_state_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeCreditsFunctions implements CreditsFunctions {
  @override
  Future<int> chargeLessonGeneration(ChargeLessonGenerationInput input) async {
    return 7;
  }

  @override
  Future<CreditsSnapshot> getMyCredits() async {
    return const CreditsSnapshot(
      balance: 12,
      lifetimeEarned: 20,
      lifetimeSpent: 8,
    );
  }
}

class FakePaymentsFunctions implements PaymentsFunctions {
  HostedCheckoutResult hostedResult = const HostedCheckoutResult.success(
    url: 'https://checkout.stripe.com/c/pay/cs_test_123',
    sessionId: 'cs_test_123',
  );
  CheckoutStatus checkoutStatus = const CheckoutStatus.complete(
    credits: 100,
    balance: 112,
  );

  @override
  Future<EmbeddedCheckoutResult> createCreditsCheckoutEmbedded(
    CreateCreditsCheckoutEmbeddedInput input,
  ) async {
    return const EmbeddedCheckoutResult.success('secret');
  }

  @override
  Future<HostedCheckoutResult> createCreditsCheckoutHosted(
    CreateCreditsCheckoutHostedInput input,
  ) async {
    return hostedResult;
  }

  @override
  Future<CheckoutStatus> getCheckoutStatus({
    required String sessionId,
    required StripeEnvironment environment,
  }) async {
    return checkoutStatus;
  }
}

class FakeDeletionGateway implements AccountDeletionGateway {
  AccountDeletionRequest? request;

  @override
  Future<void> requestAccountDeletion(AccountDeletionRequest request) async {
    this.request = request;
  }
}

class FakeCreditClient implements CreditClient {
  int balance = 20;
  int reserveCalls = 0;
  int captureCalls = 0;
  int refundCalls = 0;
  bool insufficient = false;
  final transactions = <StudentBillingTransaction>[];

  @override
  Future<CreditsSnapshot> getBalance() async {
    return CreditsSnapshot(
      balance: balance,
      lifetimeEarned: balance,
      lifetimeSpent: 0,
    );
  }

  @override
  Future<CreditReservation> reserveCredits({
    required int amount,
    required String reason,
    required String idempotencyKey,
    required JsonMap metadata,
  }) async {
    reserveCalls++;
    if (insufficient || balance < amount) {
      throw const CreditClientException('insufficient credits',
          statusCode: 402);
    }
    return CreditReservation(
      reservationId: 'reservation-$reserveCalls',
      amount: amount,
      reason: reason,
      status: 'pending',
      balance: balance,
      idempotencyKey: idempotencyKey,
    );
  }

  @override
  Future<CreditCaptureResult> captureCredits({
    required String reservationId,
    required String idempotencyKey,
    required JsonMap metadata,
  }) async {
    captureCalls++;
    balance -= 3;
    final tx = StudentBillingTransaction(
      id: 'tx-$captureCalls',
      userId: 'u1',
      type: StudentBillingTransactionType.charge,
      amount: -3,
      reason: 'lesson_generation',
      status: StudentBillingTransactionStatus.completed,
      createdAt: 1,
      updatedAt: 1,
      reservationId: reservationId,
      idempotencyKey: idempotencyKey,
      metadata: metadata,
    );
    transactions.add(tx);
    return CreditCaptureResult(balance: balance, transaction: tx);
  }

  @override
  Future<CreditCaptureResult> refundCredits({
    required String reservationId,
    required String idempotencyKey,
    required JsonMap metadata,
  }) async {
    refundCalls++;
    return CreditCaptureResult(balance: balance, transaction: null);
  }

  @override
  Future<List<StudentBillingTransaction>> getTransactionHistory() async {
    return transactions;
  }
}

void main() {
  test('official pricing preserves live packs and costs', () {
    expect(simPricing.currency, 'brl');
    expect(simPricing.lessonCostCredits, 3);
    expect(simPricing.imageCostCredits, 10);
    expect(simPricing.signupBonusCredits, 9);
    expect(simPricing.getPackOrThrow('credits_100').amountCents, 790);
    expect(simPricing.getPackOrThrow('credits_200').credits, 200);
    expect(simPricing.getPackOrThrow('credits_500').amountCents, 3950);
  });

  test('payment return store accepts only safe internal paths', () {
    final store = PaymentReturnStore();

    store.saveReturnTo('/cyber/aula');
    expect(store.readReturnTo(), '/cyber/aula');
    store.saveReturnTo('//evil.com');
    expect(store.readReturnTo(), '/cyber/aula');
    store.saveReturnTo('/creditos');
    expect(store.readReturnTo(), '/cyber/aula');
    store.clearReturnTo();
    expect(store.readReturnTo(), isNull);
  });

  test('credits route opens hosted Stripe checkout from pack id only',
      () async {
    final controller = CreditsRouteController(
      creditsFunctions: FakeCreditsFunctions(),
      paymentsFunctions: FakePaymentsFunctions(),
      returnStore: PaymentReturnStore(),
    );

    controller.preserveReturnTo('/cyber/aula');
    await controller.loadCredits();
    await controller.handlePackClick(
      packId: CreditPackId.credits100,
      origin: 'https://gemini-aid-pal.lovable.app',
    );

    expect(controller.state.balance, 12);
    expect(controller.state.redirectUrl,
        startsWith('https://checkout.stripe.com/'));
  });

  test('credits route preserves embedded rollback mode', () async {
    final controller = CreditsRouteController(
      creditsFunctions: FakeCreditsFunctions(),
      paymentsFunctions: FakePaymentsFunctions(),
      returnStore: PaymentReturnStore(),
      checkoutMode: CheckoutMode.embedded,
    );

    await controller.handlePackClick(
      packId: CreditPackId.credits200,
      origin: 'https://app.test',
    );

    expect(controller.state.checkoutPack, CreditPackId.credits200);
  });

  test('checkout return validates session and restores saved return target',
      () async {
    final store = PaymentReturnStore()..saveReturnTo('/cyber/aula');
    final controller = CheckoutReturnController(
      paymentsFunctions: FakePaymentsFunctions(),
      returnStore: store,
    );

    final state = await controller.confirm('cs_test_123');
    expect(state.status, CheckoutStatusKind.complete);
    expect(state.credits, 100);
    expect(controller.continueTarget(), '/cyber/aula');
    expect(store.readReturnTo(), isNull);
  });

  test('webhook grant uses official pack credits and ignores unpaid sessions',
      () {
    final grant = grantFromCheckoutCompleted(
      const StripeWebhookSession(
        id: 'cs_1',
        paymentStatus: 'paid',
        metadata: {'userId': 'u1', 'packId': 'credits_500', 'credits': '999'},
      ),
    );

    expect(grant?.credits, 500);
    expect(parseWebhookEnvironment('live'), StripeEnvironment.live);
    expect(
      grantFromCheckoutCompleted(
        const StripeWebhookSession(
          id: 'cs_2',
          paymentStatus: 'unpaid',
          metadata: {'userId': 'u1', 'packId': 'credits_100'},
        ),
      ),
      isNull,
    );
  });

  test('account deletion requires DELETAR and records request', () async {
    final gateway = FakeDeletionGateway();
    final controller = AccountDeletionController(gateway: gateway);

    await controller.submit(
        confirm: 'deletar', userId: 'u1', email: 'a@test.com');
    expect(gateway.request, isNull);
    await controller.submit(
        confirm: 'DELETAR', userId: 'u1', email: 'a@test.com');
    expect(controller.done, true);
    expect(gateway.request?.reason, 'user_requested_account_deletion');
    expect(
        const DeleteAccountTexts().submitLabel, 'Solicitar exclusao da conta');
  });

  test('charge lesson input normalizes ids like server validator', () {
    final input = ChargeLessonGenerationInput(
      lessonLocalId: 'x' * 200,
      legacyLessonLocalIds: [' ', 'a', 'b' * 200],
    ).normalized();

    expect(input.lessonLocalId.length, 160);
    expect(input.legacyLessonLocalIds.length, 2);
    expect(input.legacyLessonLocalIds.last.length, 160);
  });

  test('credit service reserves then captures successful content generation',
      () async {
    SharedPreferences.setMockInitialValues({});
    final client = FakeCreditClient();
    final prefs = await SharedPreferences.getInstance();
    final stateService = StudentLearningStateService();
    final service = CreditService(
      client: client,
      stateService: stateService,
      preferences: prefs,
    );

    final result = await service.runReserved(
      lessonLocalId: 'lesson-1',
      amount: simCreditCosts.lessonGeneration,
      reason: 'lesson_generation',
      idempotencyKey: 'lesson-1:t02:1',
      metadata: const {'marker': 'm1'},
      operation: (_) async => 'generated',
    );

    expect(result, 'generated');
    expect(client.reserveCalls, 1);
    expect(client.captureCalls, 1);
    expect(client.refundCalls, 0);
    expect(service.cachedBalance, 17);
    final state = stateService.read('lesson-1')!;
    expect(
        state.events.map((event) => event.type), contains('CREDIT_CAPTURED'));
  });

  test('credit service refunds reservation when generation fails', () async {
    SharedPreferences.setMockInitialValues({});
    final client = FakeCreditClient();
    final prefs = await SharedPreferences.getInstance();
    final service = CreditService(
      client: client,
      stateService: StudentLearningStateService(),
      preferences: prefs,
    );

    expect(
      () => service.runReserved(
        lessonLocalId: 'lesson-1',
        amount: simCreditCosts.imageGeneration,
        reason: 'image_generation',
        idempotencyKey: 'lesson-1:image:m1',
        metadata: const {'marker': 'm1'},
        operation: (_) async => throw Exception('provider failed'),
      ),
      throwsException,
    );
    await Future<void>.delayed(Duration.zero);

    expect(client.reserveCalls, 1);
    expect(client.captureCalls, 0);
    expect(client.refundCalls, 1);
  });

  test('credit service records insufficient credit without capture', () async {
    SharedPreferences.setMockInitialValues({});
    final client = FakeCreditClient()..insufficient = true;
    final prefs = await SharedPreferences.getInstance();
    final stateService = StudentLearningStateService();
    final service = CreditService(
      client: client,
      stateService: stateService,
      preferences: prefs,
    );

    await expectLater(
      service.runReserved(
        lessonLocalId: 'lesson-1',
        amount: simCreditCosts.imageGeneration,
        reason: 'image_generation',
        idempotencyKey: 'lesson-1:image:m1',
        metadata: const {'marker': 'm1'},
        operation: (_) async => 'image',
      ),
      throwsA(isA<CreditClientException>()),
    );

    expect(client.captureCalls, 0);
    expect(client.refundCalls, 0);
    final state = stateService.read('lesson-1')!;
    expect(
      state.events.map((event) => event.type),
      contains('CREDIT_INSUFFICIENT'),
    );
  });

  test('purchase service keeps Android behind provider abstraction', () async {
    final purchase = CreditPurchaseService(
      webStripeProvider: WebStripePurchaseProvider(
        payments: FakePaymentsFunctions(),
      ),
    );

    final androidResult = await purchase.startPurchase(
      const CreditPurchaseRequest(
        packId: CreditPackId.credits100,
        returnUrl: 'sim-mobile://checkout/return',
        origin: 'https://gemini-aid-pal.lovable.app',
      ),
      platform: TargetPurchasePlatform.android,
      laboratoryStripe: false,
    );

    expect(androidResult.started, false);
    expect(androidResult.providerKind, PurchaseProviderKind.androidPlayBilling);
  });
}
