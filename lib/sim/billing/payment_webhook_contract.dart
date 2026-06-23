import 'payments_functions.dart';
import 'sim_pricing.dart';

class StripeWebhookSession {
  const StripeWebhookSession({
    required this.id,
    required this.paymentStatus,
    required this.metadata,
  });

  final String id;
  final String paymentStatus;
  final Map<String, String> metadata;
}

class WebhookCreditGrant {
  const WebhookCreditGrant({
    required this.userId,
    required this.credits,
    required this.note,
  });

  final String userId;
  final int credits;
  final String note;
}

StripeEnvironment? parseWebhookEnvironment(String? raw) {
  if (raw == 'sandbox') return StripeEnvironment.sandbox;
  if (raw == 'live') return StripeEnvironment.live;
  return null;
}

WebhookCreditGrant? grantFromCheckoutCompleted(StripeWebhookSession session) {
  final userId = session.metadata['userId'];
  if (userId == null || userId.isEmpty) return null;
  if (session.paymentStatus != 'paid') return null;
  final packId = session.metadata['packId'];
  var credits = 0;
  if (packId != null && packId.isNotEmpty) {
    try {
      credits = simPricing.getPackOrThrow(packId).credits;
    } catch (_) {
      credits = int.tryParse(session.metadata['credits'] ?? '') ?? 0;
    }
  } else {
    credits = int.tryParse(session.metadata['credits'] ?? '') ?? 0;
  }
  if (credits <= 0) return null;
  return WebhookCreditGrant(
    userId: userId,
    credits: credits,
    note: 'Compra ${session.metadata['priceId'] ?? ''}'.trim(),
  );
}
