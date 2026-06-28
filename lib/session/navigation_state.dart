import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

String safeNavigationReturnTo(String raw) {
  if (!raw.startsWith('/')) return '/';
  if (raw.startsWith('//')) return '/';
  return raw;
}

class NavigationState extends ChangeNotifier {
  String route = '/';
  String returnTo = '/';
  String? externalDoorOpened;

  void goPortal() {
    route = '/';
    notifyListeners();
  }

  void goLogin({String target = '/'}) {
    returnTo = safeNavigationReturnTo(target);
    route = '/login';
    notifyListeners();
  }

  void goAula() {
    route = '/cyber/aula';
    notifyListeners();
  }

  void openRoute(String path) {
    route = path;
    notifyListeners();
  }

  void openExternalDoor(String url) {
    externalDoorOpened = url;
    notifyListeners();
    final uri = Uri.tryParse(url);
    if (uri != null) {
      launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
