import 'payment_return_store.dart';
import 'payments_functions.dart';

class CheckoutReturnState {
  const CheckoutReturnState({
    required this.status,
    this.credits = 0,
    this.balance = 0,
    this.error,
    this.returnTo,
  });

  final CheckoutStatusKind status;
  final int credits;
  final int balance;
  final String? error;
  final String? returnTo;
}

class CheckoutReturnController {
  CheckoutReturnController({
    required this.paymentsFunctions,
    required this.returnStore,
    this.environment = StripeEnvironment.live,
    this.confirmTimeoutMs = 30000,
  });

  final PaymentsFunctions paymentsFunctions;
  final PaymentReturnStore returnStore;
  final StripeEnvironment environment;
  final int confirmTimeoutMs;

  Future<CheckoutReturnState> confirm(String? sessionId) async {
    if (sessionId == null || !isValidStripeSessionId(sessionId)) {
      return CheckoutReturnState(
        status: CheckoutStatusKind.error,
        error: 'Invalid sessionId',
        returnTo: returnStore.readReturnTo(),
      );
    }
    final result = await paymentsFunctions.getCheckoutStatus(
      sessionId: sessionId,
      environment: environment,
    );
    return CheckoutReturnState(
      status: result.kind,
      credits: result.credits,
      balance: result.balance,
      error: result.error,
      returnTo: returnStore.readReturnTo(),
    );
  }

  String continueTarget() {
    final target = returnStore.readReturnTo();
    returnStore.clearReturnTo();
    return target ?? '/';
  }
}
