import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'sim/billing/sim_server_billing_clients.dart';
import 'sim/cloud/sim_server_cloud_functions.dart';
import 'sim/cloud/supabase_flutter_session_provider.dart';
import 'sim/cloud/supabase_student_state_cloud_storage.dart';
import 'sim/config/sim_environment.dart';
import 'sim/external_ai/sim_ai_server_config.dart';
import 'sim/external_ai/sim_server_ai_clients.dart';
import 'sim/external_ai/sim_server_attachment_client.dart';
import 'sim/classroom/classroom_models.dart';
import 'sim/classroom/lesson_runtime_engine.dart';
import 'sim/classroom/lesson_main_view_model.dart';
import 'sim/experience/student_experience_types.dart';
import 'sim/organism/sim_organism.dart';
import 'sim/organism/sim_organism_provider.dart';
import 'session/auth_session.dart';
import 'session/entry_form_state.dart';
import 'session/lesson_ui_state.dart';
import 'session/navigation_state.dart';
import 'sim/lesson/lesson_models.dart';
import 'sim/media/audio_core.dart';
import 'sim/media/audio_preference.dart';
import 'sim/media/lesson_audio_controller.dart';
import 'sim/media/student_lesson_media_service.dart';
import 'sim/state/shared_prefs_state_storage.dart';
import 'sim/state/student_learning_state.dart';
import 'sim/state/student_state_store.dart';
import 'sim/ui/sim_i18n.dart';
import 'sim/ui/widgets/cyber_step_shell.dart';
import 'sim/ui/widgets/sim_preparation_experience.dart';
import 'sim/ui/widgets/sim_typewriter.dart';
import 'sim/auxiliary/aux_room_models.dart';
import 'sim/ui/widgets/doubt_progress_bar.dart';

part 'app_shell/sim_constants.dart';
part 'app_shell/lab_session.dart';
part 'app_shell/portal_flow.dart';
part 'app_shell/login_screen.dart';
part 'app_shell/onboarding_screens.dart';
part 'app_shell/preparation_and_placement.dart';
part 'app_shell/aula_screen.dart';
part 'app_shell/aux_room_screens.dart';
part 'app_shell/aula_widgets.dart';
part 'app_shell/billing_and_simple_pages.dart';
part 'app_shell/shared_widgets.dart';

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
