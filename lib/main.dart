import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/utils/sim_constants.dart';
import 'features/auth/login_screen.dart';
import 'features/billing/billing_and_simple_pages.dart';
import 'features/classroom/aula_screen.dart';
import 'features/onboarding/onboarding_screens.dart';
import 'features/onboarding/preparation_and_placement.dart';
import 'features/portal/portal_flow.dart';
import 'features/session/lab_session.dart';
import 'sim/cloud/sim_server_cloud_functions.dart';
import 'sim/cloud/supabase_flutter_session_provider.dart';
import 'sim/cloud/supabase_student_state_cloud_storage.dart';
import 'sim/external_ai/sim_ai_server_config.dart';
import 'sim/state/shared_prefs_state_storage.dart';
import 'sim/state/student_state_store.dart';

export 'features/session/lab_session.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: simSupabaseUrl,
    publishableKey: simSupabaseAnonKey,
  );
  final prefs = await SharedPreferences.getInstance();
  final stateStorage = SharedPrefsStudentStateLocalStorage(prefs);
  const sessionProvider = SupabaseFlutterSessionProvider();
  final cloudStorage = SupabaseStudentStateCloudStorage(
    cloudFunctions: SimServerCloudFunctions(
      config: const SimAiServerConfig(baseUrl: simApiBaseUrl),
    ),
    sessionProvider: sessionProvider,
  );
  final canonicalStore = StudentStateStore(
    local: stateStorage,
    cloud: cloudStorage,
  );
  runApp(SimApp(canonicalStore: canonicalStore, prefs: prefs));
}

class SimApp extends StatefulWidget {
  const SimApp({
    super.key,
    this.canonicalStore,
    this.initialSession,
    this.prefs,
  });

  final StudentStateStore? canonicalStore;
  final LabSession? initialSession;
  final SharedPreferences? prefs;

  @override
  State<SimApp> createState() => _SimAppState();
}

typedef SimMobileApp = SimApp;

class _SimAppState extends State<SimApp> {
  late final LabSession session =
      widget.initialSession ??
      LabSession(canonicalStore: widget.canonicalStore, prefs: widget.prefs);

  @override
  void initState() {
    super.initState();
    session.addListener(_onSessionChanged);
    session.bindRealAuth();
  }

  @override
  void dispose() {
    session.removeListener(_onSessionChanged);
    session.dispose();
    super.dispose();
  }

  void _onSessionChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    Widget screen;
    switch (session.route) {
      case '/login':
        screen = LoginScreen(session: session);
      case '/cyber/idioma':
        screen = IdiomaScreen(session: session);
      case '/cyber/objeto':
        screen = ObjetoScreen(session: session);
      case '/cyber/curriculo':
        screen = PhaseBoundaryScreen(session: session);
      case '/cyber/placement':
        screen = PlacementLabScreen(session: session);
      case '/cyber/aula':
        screen = AulaLabScreen(session: session);
      case '/creditos':
        screen = CreditsLabScreen(session: session);
      case '/checkout/return':
        screen = CheckoutReturnScreen(session: session);
      case '/pai':
        screen = FatherLabScreen(session: session);
      case '/privacidade':
        screen = LegalLabScreen(session: session, title: 'Privacidade');
      case '/termos':
        screen = LegalLabScreen(session: session, title: 'Termos');
      case '/conta/deletar':
        screen = DeleteAccountLabScreen(session: session);
      default:
        screen = PortalScreen(session: session);
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SIM',
      theme: ThemeData(
        useMaterial3: true,
        textTheme: GoogleFonts.interTextTheme(),
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(
          seedColor: simDark,
          brightness: Brightness.light,
          surface: Colors.white,
        ),
      ),
      home: SimFrame(child: screen),
    );
  }
}


