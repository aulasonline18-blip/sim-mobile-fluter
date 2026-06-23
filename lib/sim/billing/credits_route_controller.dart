import 'credits_functions.dart';
import 'payment_return_store.dart';
import 'payments_functions.dart';
import 'sim_pricing.dart';

class CreditsRouteState {
  const CreditsRouteState({
    this.authChecked = false,
    this.balance = 0,
    this.lifetimeEarned = 0,
    this.lifetimeSpent = 0,
    this.checkoutPack,
    this.hostedLoading,
    this.hostedError,
    this.redirectUrl,
  });

  final bool authChecked;
  final int balance;
  final int lifetimeEarned;
  final int lifetimeSpent;
  final CreditPackId? checkoutPack;
  final CreditPackId? hostedLoading;
  final String? hostedError;
  final String? redirectUrl;

  CreditsRouteState copyWith({
    bool? authChecked,
    int? balance,
    int? lifetimeEarned,
    int? lifetimeSpent,
    CreditPackId? checkoutPack,
    CreditPackId? hostedLoading,
    String? hostedError,
    String? redirectUrl,
    bool clearHostedLoading = false,
    bool clearHostedError = false,
    bool clearCheckoutPack = false,
  }) {
    return CreditsRouteState(
      authChecked: authChecked ?? this.authChecked,
      balance: balance ?? this.balance,
      lifetimeEarned: lifetimeEarned ?? this.lifetimeEarned,
      lifetimeSpent: lifetimeSpent ?? this.lifetimeSpent,
      checkoutPack:
          clearCheckoutPack ? null : checkoutPack ?? this.checkoutPack,
      hostedLoading:
          clearHostedLoading ? null : hostedLoading ?? this.hostedLoading,
      hostedError: clearHostedError ? null : hostedError ?? this.hostedError,
      redirectUrl: redirectUrl ?? this.redirectUrl,
    );
  }
}

class CreditsRouteController {
  CreditsRouteController({
    required this.creditsFunctions,
    required this.paymentsFunctions,
    required this.returnStore,
    this.checkoutMode = CheckoutMode.hosted,
    this.environment = StripeEnvironment.live,
    this.checkoutOpenTimeoutMs = 20000,
  });

  final CreditsFunctions creditsFunctions;
  final PaymentsFunctions paymentsFunctions;
  final PaymentReturnStore returnStore;
  final CheckoutMode checkoutMode;
  final StripeEnvironment environment;
  final int checkoutOpenTimeoutMs;

  CreditsRouteState state = const CreditsRouteState();

  void preserveReturnTo(String? returnTo) {
    returnStore.saveReturnTo(returnTo);
  }

  Future<void> loadCredits() async {
    final snapshot = await creditsFunctions.getMyCredits();
    state = state.copyWith(
      authChecked: true,
      balance: snapshot.balance,
      lifetimeEarned: snapshot.lifetimeEarned,
      lifetimeSpent: snapshot.lifetimeSpent,
    );
  }

  Future<void> handlePackClick({
    required CreditPackId packId,
    required String origin,
  }) async {
    if (checkoutMode == CheckoutMode.embedded) {
      state = state.copyWith(checkoutPack: packId);
      return;
    }
    state = state.copyWith(
      hostedLoading: packId,
      clearHostedError: true,
    );
    final result = await paymentsFunctions.createCreditsCheckoutHosted(
      CreateCreditsCheckoutHostedInput(
        packId: packId.wire,
        successUrl: '$origin/checkout/return?session_id={CHECKOUT_SESSION_ID}',
        cancelUrl: '$origin/creditos?canceled=1',
        environment: environment,
      ).validate(),
    );
    if (!result.ok) {
      state = state.copyWith(
        hostedError: result.error,
        clearHostedLoading: true,
      );
      return;
    }
    if (!isValidStripeCheckoutUrl(result.url)) {
      state = state.copyWith(
        hostedError: 'pay_checkout_invalid',
        clearHostedLoading: true,
      );
      return;
    }
    state = state.copyWith(redirectUrl: result.url);
  }
}
