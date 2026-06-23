import 'sim_pricing.dart';

enum StripeEnvironment { sandbox, live }

extension StripeEnvironmentWire on StripeEnvironment {
  String get wire => switch (this) {
        StripeEnvironment.sandbox => 'sandbox',
        StripeEnvironment.live => 'live',
      };

  static StripeEnvironment fromWire(String value) {
    return switch (value) {
      'sandbox' => StripeEnvironment.sandbox,
      'live' => StripeEnvironment.live,
      _ => throw ArgumentError('Invalid Stripe environment'),
    };
  }
}

enum CheckoutMode { hosted, embedded }

class CreateCreditsCheckoutHostedInput {
  const CreateCreditsCheckoutHostedInput({
    required this.packId,
    required this.successUrl,
    required this.cancelUrl,
    required this.environment,
  });

  final String packId;
  final String successUrl;
  final String cancelUrl;
  final StripeEnvironment environment;

  CreateCreditsCheckoutHostedInput validate() {
    simPricing.getPackOrThrow(packId);
    if (!RegExp(r'^https?://').hasMatch(successUrl)) {
      throw ArgumentError('Invalid successUrl');
    }
    if (!RegExp(r'^https?://').hasMatch(cancelUrl)) {
      throw ArgumentError('Invalid cancelUrl');
    }
    return this;
  }
}

class CreateCreditsCheckoutEmbeddedInput {
  const CreateCreditsCheckoutEmbeddedInput({
    required this.packId,
    required this.returnUrl,
    required this.environment,
  });

  final String packId;
  final String returnUrl;
  final StripeEnvironment environment;

  CreateCreditsCheckoutEmbeddedInput validate() {
    simPricing.getPackOrThrow(packId);
    if (!RegExp(r'^https?://').hasMatch(returnUrl)) {
      throw ArgumentError('Invalid returnUrl');
    }
    return this;
  }
}

class HostedCheckoutResult {
  const HostedCheckoutResult.success({
    required this.url,
    required this.sessionId,
  }) : error = null;

  const HostedCheckoutResult.failure(this.error)
      : url = null,
        sessionId = null;

  final String? url;
  final String? sessionId;
  final String? error;

  bool get ok => error == null;
}

class EmbeddedCheckoutResult {
  const EmbeddedCheckoutResult.success(this.clientSecret) : error = null;
  const EmbeddedCheckoutResult.failure(this.error) : clientSecret = null;

  final String? clientSecret;
  final String? error;
}

enum CheckoutStatusKind { complete, pending, expired, error }

class CheckoutStatus {
  const CheckoutStatus.complete({
    required this.credits,
    required this.balance,
  })  : kind = CheckoutStatusKind.complete,
        error = null;

  const CheckoutStatus.pending()
      : kind = CheckoutStatusKind.pending,
        credits = 0,
        balance = 0,
        error = null;

  const CheckoutStatus.expired()
      : kind = CheckoutStatusKind.expired,
        credits = 0,
        balance = 0,
        error = null;

  const CheckoutStatus.failure(this.error)
      : kind = CheckoutStatusKind.error,
        credits = 0,
        balance = 0;

  final CheckoutStatusKind kind;
  final int credits;
  final int balance;
  final String? error;
}

abstract interface class PaymentsFunctions {
  Future<HostedCheckoutResult> createCreditsCheckoutHosted(
    CreateCreditsCheckoutHostedInput input,
  );

  Future<EmbeddedCheckoutResult> createCreditsCheckoutEmbedded(
    CreateCreditsCheckoutEmbeddedInput input,
  );

  Future<CheckoutStatus> getCheckoutStatus({
    required String sessionId,
    required StripeEnvironment environment,
  });
}

bool isValidStripeSessionId(String value) {
  return RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(value);
}

bool isValidStripeCheckoutUrl(String? value) {
  return value != null && value.startsWith('https://checkout.stripe.com/');
}
