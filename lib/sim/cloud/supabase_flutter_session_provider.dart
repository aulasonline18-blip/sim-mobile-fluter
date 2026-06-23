import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import 'supabase_client_contract.dart';

class SupabaseFlutterSessionProvider implements SupabaseSessionProvider {
  const SupabaseFlutterSessionProvider({supabase.SupabaseClient? client})
    : this._withClient(client);

  const SupabaseFlutterSessionProvider._withClient(this._client);

  final supabase.SupabaseClient? _client;

  supabase.SupabaseClient get _resolved =>
      _client ?? supabase.Supabase.instance.client;

  @override
  Future<SupabaseSession?> currentSession() async {
    final session = _resolved.auth.currentSession;
    final token = session?.accessToken;
    final userId = session?.user.id;
    if (token == null || token.trim().isEmpty || userId == null) return null;
    return SupabaseSession(accessToken: token, userId: userId);
  }
}
