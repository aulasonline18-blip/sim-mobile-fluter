abstract interface class PaymentReturnStorage {
  String? read(String key);
  void write(String key, String value);
  void remove(String key);
}

class MemoryPaymentReturnStorage implements PaymentReturnStorage {
  final Map<String, String> _values = {};

  @override
  String? read(String key) => _values[key];

  @override
  void remove(String key) {
    _values.remove(key);
  }

  @override
  void write(String key, String value) {
    _values[key] = value;
  }
}

class PaymentReturnStore {
  PaymentReturnStore({PaymentReturnStorage? storage})
      : storage = storage ?? MemoryPaymentReturnStorage();

  static const key = 'sim-payment-returnto-v0';

  final PaymentReturnStorage storage;

  bool isSafeInternalPath(String? path) {
    if (path == null || path.isEmpty) return false;
    if (!path.startsWith('/')) return false;
    if (path.startsWith('//')) return false;
    if (path.startsWith('/creditos')) return false;
    if (path.startsWith('/checkout')) return false;
    return true;
  }

  void saveReturnTo(String? path) {
    if (isSafeInternalPath(path)) storage.write(key, path!);
  }

  String? readReturnTo() {
    final value = storage.read(key);
    return isSafeInternalPath(value) ? value : null;
  }

  void clearReturnTo() {
    storage.remove(key);
  }
}
