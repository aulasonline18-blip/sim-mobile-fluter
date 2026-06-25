import 'dart:io' show Platform;

import 'payments_functions.dart';
import 'sim_pricing.dart';

enum PurchaseProviderKind { webStripe, androidPlayBilling, iosStoreKit }

enum TargetPurchasePlatform { current, web, android, ios }

class CreditPurchaseRequest {
  const CreditPurchaseRequest({
    required this.packId,
    required this.returnUrl,
    required this.origin,
  });

  final CreditPackId packId;
  final String returnUrl;
  final String origin;
}

class CreditPurchaseResult {
  const CreditPurchaseResult.redirect(this.url)
      : started = true,
        providerKind = PurchaseProviderKind.webStripe,
        error = null;

  const CreditPurchaseResult.pendingProvider(this.providerKind)
      : started = false,
        url = null,
        error = null;

  const CreditPurchaseResult.failure(this.error)
      : started = false,
        url = null,
        providerKind = null;

  final bool started;
  final String? url;
  final PurchaseProviderKind? providerKind;
  final String? error;
}

abstract interface class PurchaseProvider {
  PurchaseProviderKind get kind;
  Future<CreditPurchaseResult> startPurchase(CreditPurchaseRequest request);
}

class WebStripePurchaseProvider implements PurchaseProvider {
  WebStripePurchaseProvider({
    required this.payments,
    this.environment = StripeEnvironment.live,
  });

  final PaymentsFunctions payments;
  final StripeEnvironment environment;

  @override
  PurchaseProviderKind get kind => PurchaseProviderKind.webStripe;

  @override
  Future<CreditPurchaseResult> startPurchase(
      CreditPurchaseRequest request) async {
    final result = await payments.createCreditsCheckoutHosted(
      CreateCreditsCheckoutHostedInput(
        packId: request.packId.wire,
        successUrl: request.returnUrl,
        cancelUrl: '${request.origin}/creditos?canceled=1',
        environment: environment,
      ).validate(),
    );
    if (!result.ok) return CreditPurchaseResult.failure(result.error);
    if (!isValidStripeCheckoutUrl(result.url)) {
      return const CreditPurchaseResult.failure('pay_checkout_invalid');
    }
    return CreditPurchaseResult.redirect(result.url);
  }
}

class AndroidPlayBillingProvider implements PurchaseProvider {
  const AndroidPlayBillingProvider();

  @override
  PurchaseProviderKind get kind => PurchaseProviderKind.androidPlayBilling;

  @override
  Future<CreditPurchaseResult> startPurchase(
      CreditPurchaseRequest request) async {
    return const CreditPurchaseResult.pendingProvider(
      PurchaseProviderKind.androidPlayBilling,
    );
  }
}

class IosStoreKitProvider implements PurchaseProvider {
  const IosStoreKitProvider();

  @override
  PurchaseProviderKind get kind => PurchaseProviderKind.iosStoreKit;

  @override
  Future<CreditPurchaseResult> startPurchase(
      CreditPurchaseRequest request) async {
    return const CreditPurchaseResult.pendingProvider(
      PurchaseProviderKind.iosStoreKit,
    );
  }
}

class CreditPurchaseService {
  CreditPurchaseService({
    required this.webStripeProvider,
    this.androidProvider = const AndroidPlayBillingProvider(),
    this.iosProvider = const IosStoreKitProvider(),
  });

  final PurchaseProvider webStripeProvider;
  final PurchaseProvider androidProvider;
  final PurchaseProvider iosProvider;

  PurchaseProvider providerForCurrentPlatform({
    bool laboratoryStripe = true,
    TargetPurchasePlatform platform = TargetPurchasePlatform.current,
  }) {
    final isAndroid =
        platform == TargetPurchasePlatform.android || Platform.isAndroid;
    final isIos = platform == TargetPurchasePlatform.ios || Platform.isIOS;
    if (platform == TargetPurchasePlatform.web) return webStripeProvider;
    if (isAndroid && platform != TargetPurchasePlatform.ios) {
      return laboratoryStripe ? webStripeProvider : androidProvider;
    }
    if (isIos) {
      return laboratoryStripe ? webStripeProvider : iosProvider;
    }
    return webStripeProvider;
  }

  Future<CreditPurchaseResult> startPurchase(
    CreditPurchaseRequest request, {
    bool laboratoryStripe = true,
    TargetPurchasePlatform platform = TargetPurchasePlatform.current,
  }) {
    return providerForCurrentPlatform(
      laboratoryStripe: laboratoryStripe,
      platform: platform,
    ).startPurchase(request);
  }
}
