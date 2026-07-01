// MIRROR OF: src/cyber/lesson-event-bus.ts (Web, source of truth)
import 'lesson_models.dart';

typedef LessonListener = void Function(CompleteLesson lesson);
typedef LessonPaidImageOfferListener =
    void Function(LessonPaidImageOffer? offer);

class LessonPaidImageOffer {
  const LessonPaidImageOffer({
    required this.offerId,
    required this.lessonKey,
    required this.prompt,
    required this.creditCost,
    required this.source,
  });

  final String offerId;
  final String lessonKey;
  final String prompt;
  final int creditCost;
  final String source;
}

class LessonEventBus {
  final Map<String, Set<LessonListener>> _subscribers = {};
  final Map<String, Set<LessonPaidImageOfferListener>> _offerSubscribers = {};
  final Map<String, LessonPaidImageOffer> _pendingOffers = {};

  void Function() subscribe(String key, LessonListener listener) {
    final set = _subscribers.putIfAbsent(key, () => <LessonListener>{});
    set.add(listener);
    return () {
      set.remove(listener);
      if (set.isEmpty) _subscribers.remove(key);
    };
  }

  void notify(String key, CompleteLesson lesson) {
    final set = _subscribers[key];
    if (set == null) return;
    for (final listener in List<LessonListener>.from(set)) {
      try {
        listener(lesson);
      } catch (_) {
        // isolate listener failures so other subscribers still receive the event
      }
    }
  }

  void Function() subscribePaidImageOffer(
    String key,
    LessonPaidImageOfferListener listener,
  ) {
    final set = _offerSubscribers.putIfAbsent(
      key,
      () => <LessonPaidImageOfferListener>{},
    );
    set.add(listener);
    if (_pendingOffers.containsKey(key)) {
      try {
        listener(_pendingOffers[key]);
      } catch (_) {
        // isolate listener failures so other subscribers still receive offers
      }
    }
    return () {
      set.remove(listener);
      if (set.isEmpty) _offerSubscribers.remove(key);
    };
  }

  void notifyPaidImageOffer(String key, LessonPaidImageOffer offer) {
    _pendingOffers[key] = offer;
    final set = _offerSubscribers[key];
    if (set == null) return;
    for (final listener in List<LessonPaidImageOfferListener>.from(set)) {
      try {
        listener(offer);
      } catch (_) {
        // offer listeners must never block lesson text
      }
    }
  }

  void clearPaidImageOffer(String key) {
    _pendingOffers.remove(key);
    final set = _offerSubscribers[key];
    if (set == null) return;
    for (final listener in List<LessonPaidImageOfferListener>.from(set)) {
      try {
        listener(null);
      } catch (_) {
        // offer listeners must never block lesson text
      }
    }
  }
}
