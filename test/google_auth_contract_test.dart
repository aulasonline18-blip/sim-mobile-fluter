import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('android app uses real Google auth through Supabase OAuth', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final appSource = [
      File('lib/main.dart'),
      ...Directory('lib/app_shell').listSync().whereType<File>(),
    ].map((file) => file.readAsStringSync()).join('\n');
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    expect(pubspec, contains('supabase_flutter'));
    expect(appSource, contains('Supabase.initialize'));
    expect(appSource, contains('OAuthProvider.google'));
    expect(appSource, contains("'prompt': 'select_account'"));
    expect(appSource, contains('signInWithPassword'));
    expect(appSource, contains('signUpWithEmailPassword'));
    expect(appSource, contains('No account? Create one now'));
    expect(appSource, contains('sim-mobile://login-callback'));
    expect(appSource, isNot(contains('LABORATORY MOCK AUTH')));
    expect(manifest, contains('android.permission.INTERNET'));
    expect(manifest, contains('android.intent.action.VIEW'));
    expect(manifest, contains('android.intent.category.BROWSABLE'));
    expect(manifest, contains('android:scheme="sim-mobile"'));
    expect(manifest, contains('android:host="login-callback"'));
  });
}
