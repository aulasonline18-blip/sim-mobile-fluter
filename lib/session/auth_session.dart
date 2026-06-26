import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'navigation_state.dart';

class AuthSession extends ChangeNotifier {
  AuthSession({required this.navigation, this.onAuthenticated});

  final NavigationState navigation;
  final VoidCallback? onAuthenticated;

  bool authed = false;
  bool authReady = false;
  int credits = 0;
  String? userId;
  String? userEmail;
  String? userName;
  String? authError;
  StreamSubscription<AuthState>? _authSub;

  void bindRealAuth() {
    final client = _supabaseClientOrNull();
    if (client == null) {
      authReady = true;
      authError = 'Supabase nao foi inicializado.';
      notifyListeners();
      return;
    }
    _authSub ??= client.auth.onAuthStateChange.listen((data) {
      applySupabaseSession(data.session);
    });
    applySupabaseSession(client.auth.currentSession);
  }

  SupabaseClient? _supabaseClientOrNull() {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  void applySupabaseSession(Session? session) {
    final user = session?.user;
    authReady = true;
    authError = null;
    authed = user != null;
    userId = user?.id;
    userEmail = user?.email;
    userName =
        user?.userMetadata?['full_name']?.toString() ??
        user?.userMetadata?['name']?.toString();
    if (authed) {
      credits = credits <= 0 ? 3 : credits;
      if (navigation.route == '/login') {
        navigation.route = safeNavigationReturnTo(navigation.returnTo);
      }
      onAuthenticated?.call();
    } else {
      credits = 0;
    }
    notifyListeners();
    navigation.notifyListeners();
  }

  Future<void> signInWithGoogle() async {
    authError = null;
    notifyListeners();
    final client = _supabaseClientOrNull();
    if (client == null) {
      authError = 'Supabase nao foi inicializado.';
      notifyListeners();
      return;
    }
    try {
      final launched = await client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'sim-mobile://login-callback',
        queryParams: const {'prompt': 'select_account'},
      );
      if (!launched) {
        authError = 'Não foi possível abrir o login do Google.';
      }
    } catch (_) {
      authError = 'Não foi possível abrir o login do Google.';
    }
    notifyListeners();
  }

  Future<void> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    authError = null;
    notifyListeners();
    final client = _supabaseClientOrNull();
    if (client == null) {
      authError = 'Supabase nao foi inicializado.';
      notifyListeners();
      return;
    }
    try {
      await client.auth.signInWithPassword(email: email, password: password);
    } on AuthException catch (error) {
      authError = error.message;
    } catch (_) {
      authError = 'Unexpected error';
    }
    notifyListeners();
  }

  Future<void> signUpWithEmailPassword({
    required String email,
    required String password,
    required String name,
  }) async {
    authError = null;
    notifyListeners();
    final client = _supabaseClientOrNull();
    if (client == null) {
      authError = 'Supabase nao foi inicializado.';
      notifyListeners();
      return;
    }
    try {
      await client.auth.signUp(
        email: email,
        password: password,
        emailRedirectTo: 'sim-mobile://login-callback',
        data: {
          'full_name': name.trim().isEmpty
              ? email.split('@').first
              : name.trim(),
        },
      );
    } on AuthException catch (error) {
      authError = error.message;
    } catch (_) {
      authError = 'Unexpected error';
    }
    notifyListeners();
  }

  Future<void> signOutReal() async {
    final client = _supabaseClientOrNull();
    await client?.auth.signOut();
    applySupabaseSession(null);
    navigation.goPortal();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}
