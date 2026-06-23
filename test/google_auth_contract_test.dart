import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('android app uses real Google auth through Supabase OAuth', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final main = File('lib/main.dart').readAsStringSync();
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    expect(pubspec, contains('supabase_flutter'));
    expect(main, contains('Supabase.initialize'));
    expect(main, contains('OAuthProvider.google'));
    expect(main, contains("'prompt': 'select_account'"));
    expect(main, contains('signInWithPassword'));
    expect(main, contains('signUpWithEmailPassword'));
    expect(main, contains('No account? Create one now'));
    expect(main, contains('sim-mobile://login-callback'));
    expect(main, isNot(contains('LABORATORY MOCK AUTH')));
    expect(manifest, contains('android.permission.INTERNET'));
    expect(manifest, contains('android.intent.action.VIEW'));
    expect(manifest, contains('android.intent.category.BROWSABLE'));
    expect(manifest, contains('android:scheme="sim-mobile"'));
    expect(manifest, contains('android:host="login-callback"'));
  });
}
