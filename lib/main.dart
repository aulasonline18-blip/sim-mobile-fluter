import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const simSupabaseUrl = 'https://qgdlmxobfexoyllvdlee.supabase.co';
const simSupabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFnZGxteG9iZmV4b3lsbHZkbGVlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzkxODgzNzAsImV4cCI6MjA5NDc2NDM3MH0.szSCxlrkftrovIElV4nbgArJqSsfKOpGy1xvUs4rnL0';
const simAuthRedirectUrl = 'sim-mobile://login-callback';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: simSupabaseUrl,
    publishableKey: simSupabaseAnonKey,
  );
  runApp(const SimMobileApp());
}

const simDark = Color(0xFF111827);
const simMid = Color(0xFF374151);
const simLight = Color(0xFFF3F4F6);
const simMuted = Color(0xFF6B7280);
const simBorder = Color(0xFFD1D5DB);
const maxFreeText = 1500;
const maxAttachments = 3;
const maxAttachmentBytes = 10 * 1024 * 1024;
const minExtractedChars = 20;
const audioNotSupportedMessage =
    'Áudio ainda não está disponível. Envie texto, foto ou arquivo.';
const videoNotSupportedMessage =
    'Vídeo ainda não está disponível. Envie texto, foto ou arquivo.';
const objectiveRequiredMessage =
    'Campo obrigatório. Escreva o que você quer estudar.';
const objectiveRequiredWithAttachmentMessage =
    'Você anexou um arquivo. Agora escreva o que deseja estudar com ele.';

class AttachmentDraft {
  AttachmentDraft({
    required this.id,
    required this.name,
    required this.type,
    required this.size,
    required this.status,
    this.extractedText,
    this.method,
    this.error,
  });

  final String id;
  final String name;
  final String type;
  final int size;
  final String status;
  final String? extractedText;
  final String? method;
  final String? error;
}

class LabSession extends ChangeNotifier {
  bool authed = false;
  bool authReady = false;
  int credits = 0;
  String route = '/';
  String returnTo = '/';
  String? userId;
  String? userEmail;
  String? userName;
  String? authError;
  StreamSubscription<AuthState>? _authSub;
  String? selectedLanguageCode;
  String? stableLang;
  String otherLanguage = '';
  String freeText = '';
  String preferredName = '';
  bool allowPaidImages = false;
  List<AttachmentDraft> attachments = [];
  String attachmentsText = '';
  String studentProfileNotes = '';
  String? lessonLocalId;
  String entryStatus = 'idle';
  String? entryError;
  bool placementStarted = false;
  bool placementDone = false;
  int aulaStep = 0;
  String selectedAnswer = '';
  String aulaMessage = '';
  bool doubtOpen = false;
  bool audioEnabled = true;
  bool audioLoading = false;
  String? audioError;
  String imageStatus = 'idle';
  String? imageError;
  String? externalDoorOpened;
  String deleteConfirmation = '';
  String? accountDeletionMessage;

  void goPortal() {
    route = '/';
    notifyListeners();
  }

  void goLogin({String target = '/'}) {
    returnTo = safeReturnTo(target);
    route = '/login';
    notifyListeners();
  }

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
      if (route == '/login') route = safeReturnTo(returnTo);
    } else {
      credits = 0;
    }
    notifyListeners();
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
        redirectTo: simAuthRedirectUrl,
        queryParams: const {'prompt': 'select_account'},
      );
      if (!launched) {
        authError = 'Não foi possível abrir o login do Google.';
      }
    } catch (error) {
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
        emailRedirectTo: simAuthRedirectUrl,
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
    route = '/';
    notifyListeners();
  }

  void start() {
    if (!authed) {
      goLogin(target: '/');
      return;
    }
    if (credits <= 0) return;
    selectedLanguageCode = null;
    stableLang = null;
    otherLanguage = '';
    route = '/cyber/idioma';
    notifyListeners();
  }

  void chooseLanguage(String code, String name) {
    selectedLanguageCode = code;
    final cleanName = name.trim();
    stableLang = cleanName.isEmpty ? null : cleanName;
    if (code != 'other' || cleanName.isNotEmpty) {
      route = '/cyber/objeto';
    }
    notifyListeners();
  }

  void setOtherLanguage(String value) {
    otherLanguage = value;
    notifyListeners();
  }

  void setFreeText(String value) {
    freeText = value.length > maxFreeText
        ? value.substring(0, maxFreeText)
        : value;
    notifyListeners();
  }

  void setPreferredName(String value) {
    preferredName = value;
    notifyListeners();
  }

  void addLabAttachment(String source) {
    if (attachments.length >= maxAttachments) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final isImage = source != 'document';
    attachments = [
      ...attachments,
      AttachmentDraft(
        id: 'att-$now-${attachments.length + 1}',
        name: isImage
            ? 'imagem-${attachments.length + 1}.jpg'
            : 'arquivo-${attachments.length + 1}.pdf',
        type: isImage ? 'image/jpeg' : 'application/pdf',
        size: isImage ? 842000 : 1240000,
        status: 'ready',
        method: isImage ? 'vision' : 'pdf-text',
        extractedText:
            'LABORATORY MOCK: texto extraído do anexo para preservar o contrato visual e funcional da Fase 2.',
      ),
    ];
    notifyListeners();
  }

  void removeAttachment(int index) {
    attachments = [
      for (int i = 0; i < attachments.length; i++)
        if (i != index) attachments[i],
    ];
    notifyListeners();
  }

  bool saveObjectiveEntry() {
    final freeTrim = freeText.trim();
    if (freeTrim.length < 10) return false;
    final clipped = freeTrim.length > maxFreeText
        ? freeTrim.substring(0, maxFreeText)
        : freeTrim;
    attachmentsText = _buildAttachmentsText();
    final language = stableLang ?? 'English';
    lessonLocalId = _deriveLessonLocalId(
      clipped,
      selectedLanguageCode ?? language,
    );
    studentProfileNotes = attachmentsText.isEmpty
        ? clipped
        : '$clipped\n\n$attachmentsText';
    freeText = clipped;
    entryStatus = 'pedido_recebido';
    entryError = null;
    route = '/cyber/curriculo';
    notifyListeners();
    return true;
  }

  void openCredits() {
    if (!authed) {
      goLogin(target: '/creditos');
      return;
    }
    route = '/creditos';
    notifyListeners();
  }

  void openSupport(String path) {
    route = path;
    notifyListeners();
  }

  void openExternalDoor(String url) {
    externalDoorOpened = url;
    notifyListeners();
  }

  void openCheckoutReturn() {
    route = '/checkout/return';
    notifyListeners();
  }

  void preparationDone() {
    entryStatus = 'primeira_aula_pronta';
    route = '/cyber/placement';
    notifyListeners();
  }

  void skipPlacement() {
    placementDone = true;
    route = '/cyber/aula';
    notifyListeners();
  }

  void startPlacement() {
    placementStarted = true;
    notifyListeners();
  }

  void finishPlacement() {
    placementDone = true;
    route = '/cyber/aula';
    notifyListeners();
  }

  void chooseAulaAnswer(String letter) {
    selectedAnswer = letter;
    aulaMessage = letter == 'A'
        ? 'Resposta registrada. SIM preparou o próximo passo.'
        : letter == 'B'
        ? 'Resposta registrada. SIM marcou revisão.'
        : 'Resposta registrada. SIM abriu caminho de recuperação.';
    notifyListeners();
  }

  void setDeleteConfirmation(String value) {
    deleteConfirmation = value;
    accountDeletionMessage = null;
    notifyListeners();
  }

  void requestAccountDeletion() {
    accountDeletionMessage = deleteConfirmation.trim() == 'DELETAR'
        ? 'Solicitação de exclusão registrada para envio seguro ao servidor.'
        : 'Digite DELETAR para confirmar a solicitação.';
    notifyListeners();
  }

  void advanceAula() {
    aulaStep += 1;
    selectedAnswer = '';
    aulaMessage = '';
    doubtOpen = false;
    imageStatus = 'idle';
    imageError = null;
    notifyListeners();
  }

  void toggleDoubt() {
    doubtOpen = !doubtOpen;
    notifyListeners();
  }

  Future<void> toggleAudio() async {
    if (audioLoading) return;
    audioError = null;
    if (!audioEnabled) {
      audioEnabled = true;
      notifyListeners();
      return;
    }
    audioLoading = true;
    notifyListeners();
    await Future<void>.delayed(const Duration(milliseconds: 180));
    audioLoading = false;
    audioEnabled = false;
    audioError = 'Áudio pausado.';
    notifyListeners();
  }

  Future<void> requestLessonImage() async {
    if (imageStatus == 'loading') return;
    imageError = null;
    imageStatus = 'loading';
    notifyListeners();
    await Future<void>.delayed(const Duration(milliseconds: 180));
    imageStatus = 'ready';
    notifyListeners();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  String _buildAttachmentsText() {
    final ready = attachments.where(
      (a) =>
          a.status == 'ready' &&
          (a.extractedText?.trim().length ?? 0) >= minExtractedChars,
    );
    return ready
        .map((a) {
          final text = a.extractedText!.trim();
          final clipped = text.length > 8000
              ? '${text.substring(0, 8000)}\n[...truncado em 8000 chars]'
              : text;
          return '--- Anexo: ${a.name} ---\n$clipped';
        })
        .join('\n\n');
  }
}

String safeReturnTo(String raw) {
  if (!raw.startsWith('/')) return '/';
  if (raw.startsWith('//')) return '/';
  return raw;
}

String _deriveLessonLocalId(String objetivo, String idioma) {
  final obj = objetivo.trim().toLowerCase();
  final idi = idioma.trim().toLowerCase();
  final input = idi.isEmpty ? obj : '$idi|$obj';
  var h = 5381;
  for (final unit in input.codeUnits) {
    h = ((h << 5) + h) ^ unit;
  }
  final unsigned = h & 0xFFFFFFFF;
  return 'cyber-${unsigned.toRadixString(36)}';
}

class SimMobileApp extends StatefulWidget {
  const SimMobileApp({super.key, this.initialSession});

  final LabSession? initialSession;

  @override
  State<SimMobileApp> createState() => _SimMobileAppState();
}

class _SimMobileAppState extends State<SimMobileApp> {
  late final LabSession session = widget.initialSession ?? LabSession();

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
        fontFamily: 'Roboto',
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

class SimFrame extends StatelessWidget {
  const SimFrame({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: simDark,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: child,
        ),
      ),
    );
  }
}

class PortalScreen extends StatelessWidget {
  const PortalScreen({required this.session, super.key});

  final LabSession session;

  @override
  Widget build(BuildContext context) {
    final displayBalance = session.authed ? session.credits : 0;
    return Scaffold(
      body: Stack(
        children: [
          const BackgroundDecor(),
          SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        session.authed
                            ? RoundIconButton(
                                icon: Icons.menu,
                                tooltip: 'Open lessons menu',
                                onTap: () => _showLabDrawer(context),
                              )
                            : const SizedBox(width: 48, height: 48),
                        CreditsPill(
                          value: displayBalance,
                          onTap: session.openCredits,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    PortalHeroCard(session: session),
                    const SizedBox(height: 16),
                    const Text(
                      'SIM v1  •  Cyber-Premium',
                      style: TextStyle(
                        color: simMuted,
                        fontSize: 12,
                        fontFamily: 'monospace',
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                    HelpCard(session: session),
                    const SizedBox(height: 24),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: pillDecoration(),
                        child: const Text(
                          '1/5',
                          style: TextStyle(
                            color: simMuted,
                            fontSize: 12,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showLabDrawer(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Menu',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: simDark,
              ),
            ),
            const SizedBox(height: 10),
            _PortalDrawerBody(session: session),
          ],
        ),
      ),
    );
  }
}

class _PortalDrawerBody extends StatelessWidget {
  const _PortalDrawerBody({required this.session});

  final LabSession session;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        MenuLine(
          label: 'Abrir aula',
          onTap: () {
            Navigator.pop(context);
            session.openSupport('/cyber/aula');
          },
        ),
        MenuLine(
          label: 'Créditos',
          onTap: () {
            Navigator.pop(context);
            session.openCredits();
          },
        ),
        MenuLine(
          label: 'Painel do Pai',
          onTap: () {
            Navigator.pop(context);
            session.openSupport('/pai');
          },
        ),
        MenuLine(
          label: 'Privacidade',
          onTap: () {
            Navigator.pop(context);
            session.openSupport('/privacidade');
          },
        ),
        MenuLine(
          label: 'Termos',
          onTap: () {
            Navigator.pop(context);
            session.openSupport('/termos');
          },
        ),
        MenuLine(
          label: 'Solicitar exclusão da conta',
          onTap: () {
            Navigator.pop(context);
            session.openSupport('/conta/deletar');
          },
        ),
      ],
    );
  }
}

class PortalHeroCard extends StatelessWidget {
  const PortalHeroCard({required this.session, super.key});

  final LabSession session;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
      decoration: glassDecoration(radius: 28),
      child: Column(
        children: [
          SizedBox(
            width: 132,
            height: 132,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 152,
                  height: 152,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(color: simDark.withAlpha(31)),
                  ),
                ),
                Container(
                  width: 132,
                  height: 132,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: simBorder),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x33111827),
                        blurRadius: 30,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Image.asset(
                    'assets/monkey-logo.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'SIM',
            style: TextStyle(
              color: simDark,
              fontSize: 68,
              height: 1,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(width: 32, child: Divider(color: simMid, thickness: 1)),
              SizedBox(width: 12),
              Flexible(
                child: Text(
                  'Smart Intelligence Mentor',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: simDark,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              SizedBox(width: 12),
              SizedBox(width: 32, child: Divider(color: simMid, thickness: 1)),
            ],
          ),
          const SizedBox(height: 24),
          const Text.rich(
            TextSpan(
              children: [
                TextSpan(text: 'Guided artificial intelligence for '),
                TextSpan(
                  text: 'real learning',
                  style: TextStyle(color: simDark, fontWeight: FontWeight.w700),
                ),
                TextSpan(text: ' - '),
                TextSpan(
                  text: 'adapted to the learner',
                  style: TextStyle(color: simDark, fontWeight: FontWeight.w700),
                ),
                TextSpan(
                  text:
                      ', supervised by the system, and built to turn effort into ',
                ),
                TextSpan(
                  text: 'real progress',
                  style: TextStyle(color: simDark, fontWeight: FontWeight.w700),
                ),
                TextSpan(text: '.'),
              ],
            ),
            textAlign: TextAlign.center,
            style: TextStyle(color: simMuted, fontSize: 15.5, height: 1.55),
          ),
          const SizedBox(height: 30),
          SizedBox(
            width: double.infinity,
            height: 64,
            child: DecoratedBox(
              decoration: primaryButtonDecoration(radius: 16),
              child: TextButton(
                onPressed: session.start,
                style: TextButton.styleFrom(
                  foregroundColor: simDark,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Positioned(
                      left: 14,
                      child: Icon(Icons.play_arrow, size: 22, color: simDark),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 44),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          session.authed ? 'Start' : 'Sign in to start',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: simDark,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class HelpCard extends StatelessWidget {
  const HelpCard({required this.session, super.key});

  final LabSession session;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: glassDecoration(radius: 24),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: simLight,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: simBorder),
                ),
                child: const Icon(
                  Icons.favorite_border,
                  color: simDark,
                  size: 22,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Help improve SIM.',
                      style: TextStyle(
                        color: simDark,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Send suggestions, report difficulties, and talk directly to the developer.',
                      style: TextStyle(
                        color: simMuted,
                        fontSize: 13.5,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 20,
            runSpacing: 12,
            children: [
              ContactButton(
                asset: 'assets/whatsapp-logo.png',
                label: 'Contact us on WhatsApp',
                onTap: () => session.openExternalDoor(
                  'https://wa.me/message/RLCYEXAYFUIIA1',
                ),
              ),
              ContactButton(
                asset: 'assets/messenger-logo.png',
                label: 'Contact us on Messenger',
                onTap: () =>
                    session.openExternalDoor('https://m.me/61557707493807'),
              ),
            ],
          ),
          if (session.externalDoorOpened != null) ...[
            const SizedBox(height: 10),
            Text(
              'Porta externa: ${session.externalDoorOpened}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: simMuted,
                fontSize: 11,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class ContactButton extends StatelessWidget {
  const ContactButton({
    required this.asset,
    required this.label,
    required this.onTap,
    super.key,
  });

  final String asset;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      button: true,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 56,
          height: 56,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: simBorder),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33243447),
                blurRadius: 20,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: ColorFiltered(
            colorFilter: const ColorFilter.matrix(<double>[
              0.2126,
              0.7152,
              0.0722,
              0,
              0,
              0.2126,
              0.7152,
              0.0722,
              0,
              0,
              0.2126,
              0.7152,
              0.0722,
              0,
              0,
              0,
              0,
              0,
              1,
              0,
            ]),
            child: Image.asset(asset, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({required this.session, super.key});

  final LabSession session;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool loading = false;
  String? error;
  bool signup = false;
  late final TextEditingController emailController = TextEditingController();
  late final TextEditingController passwordController = TextEditingController();
  late final TextEditingController nameController = TextEditingController();

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    nameController.dispose();
    super.dispose();
  }

  Future<void> google() async {
    if (loading) return;
    setState(() {
      loading = true;
      error = null;
    });
    await widget.session.signInWithGoogle();
    if (!mounted) return;
    setState(() {
      loading = false;
      error = widget.session.authError;
    });
  }

  Future<void> emailSubmit() async {
    if (loading) return;
    setState(() {
      loading = true;
      error = null;
    });
    final email = emailController.text.trim();
    final password = passwordController.text;
    if (signup) {
      await widget.session.signUpWithEmailPassword(
        email: email,
        password: password,
        name: nameController.text,
      );
    } else {
      await widget.session.signInWithEmailPassword(
        email: email,
        password: password,
      );
    }
    if (!mounted) return;
    setState(() {
      loading = false;
      error = widget.session.authError;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 448),
              child: Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: simBorder),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'S',
                      style: TextStyle(
                        color: simDark,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'SIM',
                    style: TextStyle(
                      color: simMid,
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Sign in',
                    style: TextStyle(
                      color: simMuted,
                      fontSize: 12,
                      fontFamily: 'monospace',
                      letterSpacing: 3,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: glassDecoration(radius: 18),
                    child: Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: OutlinedButton(
                            onPressed: loading ? null : google,
                            style: OutlinedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF1A1A1A),
                              side: const BorderSide(color: simBorder),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const GoogleMark(),
                                const SizedBox(width: 10),
                                Text(
                                  loading
                                      ? 'Please wait...'
                                      : 'Continue with Google',
                                  style: const TextStyle(
                                    color: Color(0xFF1A1A1A),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Row(
                          children: [
                            Expanded(child: Divider(color: simBorder)),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              child: Text(
                                'or',
                                style: TextStyle(
                                  color: simMuted,
                                  fontSize: 12,
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Expanded(child: Divider(color: simBorder)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (signup) ...[
                          SimInput(
                            hint: 'Your name',
                            controller: nameController,
                            onChanged: (_) {},
                          ),
                          const SizedBox(height: 12),
                        ],
                        SimInput(
                          hint: 'email@example.com',
                          controller: emailController,
                          keyboardType: TextInputType.emailAddress,
                          onChanged: (_) {},
                        ),
                        const SizedBox(height: 12),
                        SimInput(
                          hint: 'Password (min. 6 characters)',
                          controller: passwordController,
                          obscureText: true,
                          onChanged: (_) {},
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: DecoratedBox(
                            decoration: primaryButtonDecoration(radius: 12),
                            child: TextButton(
                              onPressed: loading ? null : emailSubmit,
                              child: Text(
                                loading
                                    ? 'Please wait...'
                                    : signup
                                    ? 'Create account and get 3 free lessons'
                                    : 'Sign in',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: simDark,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextButton(
                          onPressed: loading
                              ? null
                              : () {
                                  setState(() {
                                    error = null;
                                    signup = !signup;
                                  });
                                },
                          child: Text(
                            signup
                                ? 'Already have an account? Sign in'
                                : 'No account? Create one now',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: simMuted,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                        if (error != null) ...[
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              error!,
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextButton(
                    onPressed: widget.session.goPortal,
                    child: const Text(
                      '← Back to portal',
                      style: TextStyle(
                        color: simMuted,
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton(
                        onPressed: () =>
                            widget.session.openSupport('/privacidade'),
                        child: const Text(
                          'Privacidade',
                          style: TextStyle(
                            color: simMuted,
                            fontSize: 12,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () => widget.session.openSupport('/termos'),
                        child: const Text(
                          'Termos',
                          style: TextStyle(
                            color: simMuted,
                            fontSize: 12,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'GOOGLE AUTH VIA SUPABASE',
                    style: TextStyle(
                      color: simMuted,
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class GoogleMark extends StatelessWidget {
  const GoogleMark({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 20,
      height: 20,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            'G',
            style: TextStyle(
              color: Color(0xFF4285F4),
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class IdiomaScreen extends StatelessWidget {
  const IdiomaScreen({required this.session, super.key});

  final LabSession session;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const StepHeader(step: 1, total: 5, label: 'Step 1 of 5'),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 32, 20, 32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 576),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Choose your language',
                        style: TextStyle(
                          color: simDark,
                          fontSize: 30,
                          height: 1.1,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'SIM will use this language for the app, lessons, explanations, images, audio and all guidance — from this point onward.',
                        style: TextStyle(
                          color: simMuted,
                          fontSize: 18,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 28),
                      for (final language in supportedLangs) ...[
                        LanguageButton(
                          language: language,
                          active: session.selectedLanguageCode == language.code,
                          onTap: () => session.chooseLanguage(
                            language.code,
                            language.name,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      LanguageButton(
                        language: const SupportedLang(
                          code: 'other',
                          name: 'Other language',
                          native: '',
                          flag: '🌐',
                        ),
                        active: session.selectedLanguageCode == 'other',
                        onTap: () => session.chooseLanguage(
                          'other',
                          session.otherLanguage.trim(),
                        ),
                      ),
                      if (session.selectedLanguageCode == 'other') ...[
                        const SizedBox(height: 20),
                        OtherLanguageBox(session: session),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OtherLanguageBox extends StatefulWidget {
  const OtherLanguageBox({required this.session, super.key});

  final LabSession session;

  @override
  State<OtherLanguageBox> createState() => _OtherLanguageBoxState();
}

class _OtherLanguageBoxState extends State<OtherLanguageBox> {
  late final TextEditingController controller = TextEditingController(
    text: widget.session.otherLanguage,
  );

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final value = controller.text.trim();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: simBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Type your language',
            style: TextStyle(
              color: simMuted,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'e.g. Italian, German, Arabic, Kiribati…',
              border: InputBorder.none,
            ),
            style: const TextStyle(color: simDark, fontSize: 18),
            onChanged: (v) {
              widget.session.setOtherLanguage(v);
              setState(() {});
            },
          ),
          Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              height: 56,
              child: DecoratedBox(
                decoration: primaryButtonDecoration(radius: 12),
                child: TextButton(
                  onPressed: value.isEmpty
                      ? null
                      : () => widget.session.chooseLanguage('other', value),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'Continue',
                      style: TextStyle(
                        color: simDark,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ObjetoScreen extends StatefulWidget {
  const ObjetoScreen({required this.session, super.key});

  final LabSession session;

  @override
  State<ObjetoScreen> createState() => _ObjetoScreenState();
}

class _ObjetoScreenState extends State<ObjetoScreen> {
  bool attachmentMenuOpen = false;
  bool sending = false;
  String? error;
  late final TextEditingController objectiveController = TextEditingController(
    text: widget.session.freeText,
  );
  late final TextEditingController nameController = TextEditingController(
    text: widget.session.preferredName,
  );

  bool get waitingAttachment => widget.session.attachments.any(
    (a) => a.status == 'uploading' || a.status == 'processing',
  );
  bool get objectiveTooShort => widget.session.freeText.trim().length < 10;
  bool get canContinue => !sending && !waitingAttachment && !objectiveTooShort;

  @override
  void dispose() {
    objectiveController.dispose();
    nameController.dispose();
    super.dispose();
  }

  void showObjectiveRequired() {
    setState(() {
      error = widget.session.attachments.isNotEmpty
          ? objectiveRequiredWithAttachmentMessage
          : objectiveRequiredMessage;
    });
  }

  Future<void> saveAndContinue() async {
    if (waitingAttachment) return;
    if (objectiveTooShort) {
      showObjectiveRequired();
      return;
    }
    if (!canContinue) return;
    setState(() {
      error = null;
      sending = true;
    });
    await Future<void>.delayed(const Duration(milliseconds: 160));
    widget.session.saveObjectiveEntry();
  }

  void addAttachment(String source) {
    if (widget.session.attachments.length >= maxAttachments) {
      setState(() => error = 'Limite de 3 anexos por envio.');
      return;
    }
    setState(() {
      error = null;
      attachmentMenuOpen = false;
    });
    widget.session.addLabAttachment(source);
  }

  @override
  Widget build(BuildContext context) {
    final remaining = maxFreeText - widget.session.freeText.length;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const StepHeader(step: 3, total: 5, label: 'Entrada pedagógica'),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 576),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Tell us about who is going to study',
                        style: TextStyle(
                          color: simDark,
                          fontSize: 28,
                          height: 1.12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 24),
                      SimCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const CardTitle(
                              icon: Icons.chat_bubble_outline,
                              title: 'What should SIM help with?',
                            ),
                            AttachmentPreviewList(
                              attachments: widget.session.attachments,
                              onRemove: (index) => setState(
                                () => widget.session.removeAttachment(index),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: simBorder),
                              ),
                              child: Stack(
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Campo obrigatório',
                                        style: TextStyle(
                                          color: Colors.black,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.4,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      const Text(
                                        'Escreva o que você quer estudar. Se anexar um arquivo ou foto, explique o que deseja aprender com ele.',
                                        style: TextStyle(
                                          color: simMuted,
                                          fontSize: 13,
                                          height: 1.35,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      TextField(
                                        controller: objectiveController,
                                        minLines: 6,
                                        maxLines: 8,
                                        maxLength: maxFreeText,
                                        decoration: const InputDecoration(
                                          hintText:
                                              'Ex: Quero estudar essa lista para a prova.',
                                          border: InputBorder.none,
                                          counterText: '',
                                          contentPadding: EdgeInsets.only(
                                            bottom: 48,
                                          ),
                                        ),
                                        style: const TextStyle(
                                          color: simDark,
                                          fontSize: 16,
                                          height: 1.4,
                                        ),
                                        onChanged: (value) {
                                          widget.session.setFreeText(value);
                                          if (error ==
                                                  objectiveRequiredMessage ||
                                              error ==
                                                  objectiveRequiredWithAttachmentMessage) {
                                            setState(() => error = null);
                                          } else {
                                            setState(() {});
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                  Positioned(
                                    left: 0,
                                    bottom: 0,
                                    child: IconButton(
                                      tooltip: 'Abrir menu de anexos',
                                      onPressed: () => setState(
                                        () => attachmentMenuOpen =
                                            !attachmentMenuOpen,
                                      ),
                                      icon: const Icon(
                                        Icons.attach_file,
                                        color: simDark,
                                        size: 24,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    right: 4,
                                    bottom: 12,
                                    child: Text(
                                      '${widget.session.freeText.length}/$maxFreeText',
                                      style: const TextStyle(
                                        color: simMuted,
                                        fontSize: 12,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                  ),
                                  if (attachmentMenuOpen)
                                    Positioned(
                                      left: 4,
                                      bottom: 46,
                                      child: AttachmentMenu(
                                        onPick: addAttachment,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Conte do seu jeito: idade, série, matéria, tema, prova, prazo, dificuldade ou foto/lista que precisa estudar.',
                              style: TextStyle(
                                color: simMuted,
                                fontSize: 13,
                                height: 1.35,
                              ),
                            ),
                            if (widget.session.attachments.isNotEmpty &&
                                objectiveTooShort) ...[
                              const SizedBox(height: 8),
                              const Text(
                                objectiveRequiredWithAttachmentMessage,
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                            if (remaining < 0) ...[
                              const SizedBox(height: 6),
                              const Text(
                                'Texto muito longo.',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      SimCard(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const CircleIcon(
                              icon: Icons.person_outline,
                              top: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Preferred name',
                                    style: TextStyle(
                                      color: simDark,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  SimInput(
                                    hint: 'What should SIM call the student?',
                                    controller: nameController,
                                    onChanged: widget.session.setPreferredName,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (error != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          error!,
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 14,
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      GestureDetector(
                        onTap: () {
                          if (!canContinue && !waitingAttachment) {
                            showObjectiveRequired();
                          }
                        },
                        child: SizedBox(
                          width: double.infinity,
                          height: 64,
                          child: DecoratedBox(
                            decoration: primaryButtonDecoration(radius: 16),
                            child: TextButton(
                              onPressed: canContinue ? saveAndContinue : null,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  if (sending)
                                    const Positioned(
                                      left: 16,
                                      child: SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: simDark,
                                        ),
                                      ),
                                    ),
                                  if (!sending &&
                                      !waitingAttachment &&
                                      !objectiveTooShort)
                                    const Positioned(
                                      right: 16,
                                      child: Icon(
                                        Icons.arrow_forward,
                                        color: simDark,
                                      ),
                                    ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 42,
                                    ),
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        sending
                                            ? 'Reading…'
                                            : waitingAttachment
                                            ? 'Aguardando leitura do anexo...'
                                            : objectiveTooShort
                                            ? 'Escreva o objetivo primeiro'
                                            : 'Save and continue',
                                        style: const TextStyle(
                                          color: simDark,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'LABORATORY MOCK: upload/extraction is simulated; validation and saved fields follow the SIM contract for Fase 2.',
                        style: TextStyle(
                          color: simMuted,
                          fontSize: 11,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AttachmentPreviewList extends StatelessWidget {
  const AttachmentPreviewList({
    required this.attachments,
    required this.onRemove,
    super.key,
  });

  final List<AttachmentDraft> attachments;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    if (attachments.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (int i = 0; i < attachments.length; i++)
            AttachmentChip(
              attachment: attachments[i],
              onRemove: () => onRemove(i),
            ),
        ],
      ),
    );
  }
}

class AttachmentChip extends StatelessWidget {
  const AttachmentChip({
    required this.attachment,
    required this.onRemove,
    super.key,
  });

  final AttachmentDraft attachment;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final icon = attachment.type.startsWith('image/')
        ? '📷'
        : attachment.type == 'application/pdf'
        ? '📄'
        : '📝';
    final suffix =
        attachment.status == 'uploading' || attachment.status == 'processing'
        ? ' lendo...'
        : attachment.status == 'error'
        ? ' erro'
        : '';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: simBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$icon ${attachment.name}$suffix',
            style: const TextStyle(color: simDark, fontSize: 12),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: onRemove,
            child: const Text(
              '✕',
              style: TextStyle(color: simMuted, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class AttachmentMenu extends StatelessWidget {
  const AttachmentMenu({required this.onPick, super.key});

  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 220,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: simBorder),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33111827),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MenuLine(label: 'Anexar arquivo', onTap: () => onPick('document')),
            MenuLine(label: 'Tirar foto', onTap: () => onPick('camera')),
            MenuLine(label: 'Escolher imagem', onTap: () => onPick('image')),
          ],
        ),
      ),
    );
  }
}

class MenuLine extends StatelessWidget {
  const MenuLine({required this.label, required this.onTap, super.key});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        width: double.infinity,
        height: 44,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              label,
              style: const TextStyle(color: simDark, fontSize: 14),
            ),
          ),
        ),
      ),
    );
  }
}

class PhaseBoundaryScreen extends StatelessWidget {
  const PhaseBoundaryScreen({required this.session, super.key});

  final LabSession session;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const StepHeader(step: 4, total: 5, label: 'Preparando aula'),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: SimCard(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '/cyber/curriculo',
                          style: TextStyle(
                            color: simDark,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'SIM recebeu a ficha, interpreta o objetivo, monta o currículo e prepara a primeira aula.',
                          style: TextStyle(
                            color: simMuted,
                            fontSize: 15,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 18),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: session.entryStatus == 'primeira_aula_pronta'
                                ? 1
                                : 0.72,
                            minHeight: 10,
                            backgroundColor: simLight,
                            color: simDark,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'lessonLocalId: ${session.lessonLocalId ?? ''}',
                          style: const TextStyle(
                            color: simDark,
                            fontSize: 12,
                            fontFamily: 'monospace',
                          ),
                        ),
                        Text(
                          'entry.status: ${session.entryStatus}',
                          style: const TextStyle(
                            color: simDark,
                            fontSize: 12,
                            fontFamily: 'monospace',
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: DecoratedBox(
                            decoration: primaryButtonDecoration(radius: 14),
                            child: TextButton(
                              onPressed: session.preparationDone,
                              child: const Text(
                                'Continuar para nivelamento',
                                style: TextStyle(
                                  color: simDark,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PlacementLabScreen extends StatelessWidget {
  const PlacementLabScreen({required this.session, super.key});

  final LabSession session;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const StepHeader(step: 5, total: 5, label: 'Nivelamento'),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: SimCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Você já conhece esse assunto?',
                        style: TextStyle(
                          color: simDark,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        session.placementStarted
                            ? 'Pergunta de nivelamento: escolha a opção que melhor representa seu ponto de partida.'
                            : 'SIM pode começar do zero ou fazer uma pergunta rápida para sugerir o ponto certo.',
                        style: const TextStyle(
                          color: simMuted,
                          fontSize: 15,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 22),
                      if (!session.placementStarted) ...[
                        PrimaryWideButton(
                          label: 'Começar do zero',
                          onTap: session.skipPlacement,
                        ),
                        const SizedBox(height: 12),
                        SecondaryWideButton(
                          label: 'Fazer nivelamento',
                          onTap: session.startPlacement,
                        ),
                      ] else ...[
                        const Text(
                          'Qual alternativa descreve melhor seu conhecimento?',
                          style: TextStyle(
                            color: simDark,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SecondaryWideButton(
                          label: 'A. Domino bem',
                          onTap: session.finishPlacement,
                        ),
                        const SizedBox(height: 8),
                        SecondaryWideButton(
                          label: 'B. Sei uma parte',
                          onTap: session.finishPlacement,
                        ),
                        const SizedBox(height: 8),
                        SecondaryWideButton(
                          label: 'C. Preciso começar guiado',
                          onTap: session.finishPlacement,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AulaLabScreen extends StatelessWidget {
  const AulaLabScreen({required this.session, super.key});

  final LabSession session;

  @override
  Widget build(BuildContext context) {
    final topic = session.freeText.trim().isEmpty
        ? 'Aula SIM'
        : session.freeText.trim();
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            AulaTopBar(session: session),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    SimCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Item ${session.aulaStep + 1} · Camada 1',
                            style: const TextStyle(
                              color: simMuted,
                              fontSize: 12,
                              fontFamily: 'monospace',
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            topic,
                            style: const TextStyle(
                              color: simDark,
                              fontSize: 22,
                              height: 1.2,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'Explicação da aula mínima em laboratório. Aqui entra o conteúdo T02 real quando o servidor estiver conectado.',
                            style: TextStyle(
                              color: simMuted,
                              fontSize: 15,
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 14),
                          LessonImagePanel(session: session),
                          if (session.audioError != null) ...[
                            const SizedBox(height: 10),
                            StatusLine(
                              icon: Icons.volume_off_outlined,
                              text: session.audioError!,
                            ),
                          ],
                          if (session.audioLoading) ...[
                            const SizedBox(height: 10),
                            const StatusLine(
                              icon: Icons.volume_up_outlined,
                              text: 'Preparando áudio da aula...',
                              loading: true,
                            ),
                          ],
                          const SizedBox(height: 10),
                          StatusLine(
                            icon: session.audioEnabled
                                ? Icons.volume_up_outlined
                                : Icons.volume_off_outlined,
                            text: session.audioEnabled
                                ? 'Áudio da aula ligado'
                                : 'Áudio da aula pausado',
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'Pergunta',
                            style: TextStyle(
                              color: simDark,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Qual alternativa mostra que você entendeu este primeiro ponto?',
                            style: TextStyle(
                              color: simDark,
                              fontSize: 15,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 12),
                          AnswerButton(
                            label: 'A',
                            text: 'Consigo explicar com minhas palavras.',
                            active: session.selectedAnswer == 'A',
                            onTap: () => session.chooseAulaAnswer('A'),
                          ),
                          AnswerButton(
                            label: 'B',
                            text: 'Entendi uma parte, mas preciso revisar.',
                            active: session.selectedAnswer == 'B',
                            onTap: () => session.chooseAulaAnswer('B'),
                          ),
                          AnswerButton(
                            label: 'C',
                            text:
                                'Ainda estou perdido e preciso de recuperação.',
                            active: session.selectedAnswer == 'C',
                            onTap: () => session.chooseAulaAnswer('C'),
                          ),
                          if (session.aulaMessage.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            Text(
                              session.aulaMessage,
                              style: const TextStyle(
                                color: simDark,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 12),
                            PrimaryWideButton(
                              label: 'Avançar',
                              onTap: session.advanceAula,
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (session.selectedAnswer == 'B') ...[
                      const SizedBox(height: 14),
                      const AuxRoomCard(
                        title: 'Revisão',
                        body:
                            'SIM marcou este ponto para revisão antes de seguir. A revisão nasce da verdade pedagógica registrada no estado.',
                      ),
                    ],
                    if (session.selectedAnswer == 'C') ...[
                      const SizedBox(height: 14),
                      const AuxRoomCard(
                        title: 'Recuperação',
                        body:
                            'SIM abriu recuperação para reconstruir o ponto que ainda travou. A recuperação preserva o caminho do aluno.',
                      ),
                    ],
                    const SizedBox(height: 14),
                    if (session.doubtOpen)
                      SimCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Dúvida',
                              style: TextStyle(
                                color: simDark,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Sala de dúvida aberta. No app real, esta pergunta chama o T02 com o adendo de dúvida no servidor.',
                              style: TextStyle(
                                color: simMuted,
                                fontSize: 14,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AuxRoomCard extends StatelessWidget {
  const AuxRoomCard({required this.title, required this.body, super.key});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return SimCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: simDark,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: const TextStyle(color: simMuted, fontSize: 14, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class AulaTopBar extends StatelessWidget {
  const AulaTopBar({required this.session, super.key});

  final LabSession session;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: simBorder)),
      ),
      child: Row(
        children: [
          RoundIconButton(
            icon: Icons.menu,
            tooltip: 'Menu',
            onTap: () => showAulaMenu(context, session),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              session.stableLang ?? 'SIM',
              style: const TextStyle(
                color: simDark,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          RoundIconButton(
            icon: Icons.help_outline,
            tooltip: 'Dúvida',
            onTap: session.toggleDoubt,
          ),
          const SizedBox(width: 8),
          RoundIconButton(
            icon: session.audioEnabled
                ? Icons.volume_up_outlined
                : Icons.volume_off_outlined,
            tooltip: 'Áudio',
            onTap: session.toggleAudio,
          ),
        ],
      ),
    );
  }
}

class LessonImagePanel extends StatelessWidget {
  const LessonImagePanel({required this.session, super.key});

  final LabSession session;

  @override
  Widget build(BuildContext context) {
    final loading = session.imageStatus == 'loading';
    final ready = session.imageStatus == 'ready';
    return Container(
      height: 168,
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: simLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: simBorder),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (loading)
            const SizedBox(
              width: 34,
              height: 34,
              child: CircularProgressIndicator(strokeWidth: 2, color: simDark),
            )
          else if (ready)
            const Icon(Icons.image, size: 46, color: simDark)
          else
            const Icon(Icons.image_outlined, size: 46, color: simMuted),
          const SizedBox(height: 10),
          Text(
            loading
                ? 'Gerando imagem da aula...'
                : ready
                ? 'Imagem da aula pronta'
                : 'Imagem da aula',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: simDark,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 32,
            child: OutlinedButton.icon(
              onPressed: loading ? null : session.requestLessonImage,
              icon: const Icon(Icons.auto_awesome, size: 16),
              label: Text(ready ? 'Gerar novamente' : 'Gerar imagem'),
              style: OutlinedButton.styleFrom(
                foregroundColor: simDark,
                side: const BorderSide(color: simBorder),
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class StatusLine extends StatelessWidget {
  const StatusLine({
    required this.icon,
    required this.text,
    this.loading = false,
    super.key,
  });

  final IconData icon;
  final String text;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (loading)
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: simDark),
          )
        else
          Icon(icon, size: 16, color: simMuted),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: simMuted, fontSize: 13, height: 1.35),
          ),
        ),
      ],
    );
  }
}

class CreditsLabScreen extends StatelessWidget {
  const CreditsLabScreen({required this.session, super.key});

  final LabSession session;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: SimCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Créditos',
                  style: TextStyle(
                    color: simDark,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Saldo atual: ${session.credits}',
                  style: const TextStyle(color: simMuted, fontSize: 15),
                ),
                const SizedBox(height: 18),
                CreditPackButton(
                  title: '100 créditos',
                  subtitle: 'Aulas e uso básico',
                  onTap: session.openCheckoutReturn,
                ),
                CreditPackButton(
                  title: '200 créditos',
                  subtitle: 'Mais aulas e imagem quando disponível',
                  onTap: session.openCheckoutReturn,
                ),
                CreditPackButton(
                  title: '500 créditos',
                  subtitle: 'Uso prolongado do SIM',
                  onTap: session.openCheckoutReturn,
                ),
                const SizedBox(height: 16),
                PrimaryWideButton(
                  label: 'Voltar para aula',
                  onTap: () => session.openSupport('/cyber/aula'),
                ),
                const SizedBox(height: 10),
                SecondaryWideButton(label: 'Portal', onTap: session.goPortal),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CreditPackButton extends StatelessWidget {
  const CreditPackButton({
    required this.title,
    required this.subtitle,
    required this.onTap,
    super.key,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: simDark,
          side: const BorderSide(color: simBorder),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.all(14),
        ),
        child: Row(
          children: [
            const Icon(Icons.credit_card, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(color: simMuted, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CheckoutReturnScreen extends StatelessWidget {
  const CheckoutReturnScreen({required this.session, super.key});

  final LabSession session;

  @override
  Widget build(BuildContext context) {
    return SimpleLabPage(
      title: 'Retorno do pagamento',
      body:
          'O pagamento volta para o SIM, valida a sessão do checkout e devolve o aluno para a aula ou para tentar novamente.',
      primary: 'Continuar aula',
      onPrimary: () => session.openSupport('/cyber/aula'),
      session: session,
      secondary: 'Tentar de novo',
      onSecondary: session.openCredits,
    );
  }
}

class FatherLabScreen extends StatelessWidget {
  const FatherLabScreen({required this.session, super.key});

  final LabSession session;

  @override
  Widget build(BuildContext context) {
    return SimpleLabPage(
      title: 'Painel do Pai',
      body:
          'Resumo vivo: idioma ${session.stableLang ?? '-'}, objetivo ${session.freeText.isEmpty ? '-' : session.freeText}, avanço ${session.aulaStep}.',
      primary: 'Voltar',
      onPrimary: () => session.openSupport('/cyber/aula'),
      session: session,
    );
  }
}

class LegalLabScreen extends StatelessWidget {
  const LegalLabScreen({required this.session, required this.title, super.key});

  final LabSession session;
  final String title;

  @override
  Widget build(BuildContext context) {
    return SimpleLabPage(
      title: title,
      body: title == 'Privacidade'
          ? 'Página de privacidade preservada como ambiente de apoio do SIM.'
          : 'Página de termos preservada como ambiente de apoio do SIM.',
      primary: 'Voltar',
      onPrimary: () => session.openSupport('/cyber/aula'),
      session: session,
    );
  }
}

class DeleteAccountLabScreen extends StatelessWidget {
  const DeleteAccountLabScreen({required this.session, super.key});

  final LabSession session;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: SimCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Solicitar exclusão da conta',
                  style: TextStyle(
                    color: simDark,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Digite DELETAR para registrar a solicitação de exclusão. A execução real acontece no servidor, sem chave secreta dentro do app.',
                  style: TextStyle(color: simMuted, fontSize: 15, height: 1.45),
                ),
                const SizedBox(height: 16),
                SimInput(
                  hint: 'DELETAR',
                  onChanged: session.setDeleteConfirmation,
                ),
                if (session.accountDeletionMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    session.accountDeletionMessage!,
                    style: const TextStyle(
                      color: simDark,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                PrimaryWideButton(
                  label: 'Solicitar exclusão da conta',
                  onTap: session.requestAccountDeletion,
                ),
                const SizedBox(height: 10),
                SecondaryWideButton(
                  label: 'Voltar',
                  onTap: () => session.openSupport('/cyber/aula'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SimpleLabPage extends StatelessWidget {
  const SimpleLabPage({
    required this.title,
    required this.body,
    required this.primary,
    required this.onPrimary,
    required this.session,
    this.secondary,
    this.onSecondary,
    super.key,
  });

  final String title;
  final String body;
  final String primary;
  final VoidCallback onPrimary;
  final LabSession session;
  final String? secondary;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SimCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: simDark,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    body,
                    style: const TextStyle(
                      color: simMuted,
                      fontSize: 15,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 20),
                  PrimaryWideButton(label: primary, onTap: onPrimary),
                  const SizedBox(height: 10),
                  if (secondary != null && onSecondary != null) ...[
                    SecondaryWideButton(label: secondary!, onTap: onSecondary!),
                    const SizedBox(height: 10),
                  ],
                  SecondaryWideButton(label: 'Portal', onTap: session.goPortal),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PrimaryWideButton extends StatelessWidget {
  const PrimaryWideButton({
    required this.label,
    required this.onTap,
    super.key,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: DecoratedBox(
        decoration: primaryButtonDecoration(radius: 14),
        child: TextButton(
          onPressed: onTap,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: simDark,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class SecondaryWideButton extends StatelessWidget {
  const SecondaryWideButton({
    required this.label,
    required this.onTap,
    super.key,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: simDark,
          side: const BorderSide(color: simBorder),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class AnswerButton extends StatelessWidget {
  const AnswerButton({
    required this.label,
    required this.text,
    required this.active,
    required this.onTap,
    super.key,
  });

  final String label;
  final String text;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: active ? simLight : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: active ? simDark : simBorder),
          ),
          child: Text(
            '$label. $text',
            style: const TextStyle(
              color: simDark,
              fontSize: 14.5,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

void showAulaMenu(BuildContext context, LabSession session) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (context) => Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          MenuLine(
            label: 'Recarregar créditos',
            onTap: () {
              Navigator.pop(context);
              session.openCredits();
            },
          ),
          MenuLine(
            label: 'Painel do Pai',
            onTap: () {
              Navigator.pop(context);
              session.openSupport('/pai');
            },
          ),
          MenuLine(
            label: 'Privacidade',
            onTap: () {
              Navigator.pop(context);
              session.openSupport('/privacidade');
            },
          ),
          MenuLine(
            label: 'Termos',
            onTap: () {
              Navigator.pop(context);
              session.openSupport('/termos');
            },
          ),
          MenuLine(
            label: 'Solicitar exclusão da conta',
            onTap: () {
              Navigator.pop(context);
              session.openSupport('/conta/deletar');
            },
          ),
        ],
      ),
    ),
  );
}

class SupportedLang {
  const SupportedLang({
    required this.code,
    required this.name,
    required this.native,
    required this.flag,
  });
  final String code;
  final String name;
  final String native;
  final String flag;
}

const supportedLangs = <SupportedLang>[
  SupportedLang(code: 'en', name: 'English', native: 'English', flag: '🇺🇸'),
  SupportedLang(
    code: 'pt',
    name: 'Portuguese',
    native: 'Português',
    flag: '🇧🇷',
  ),
  SupportedLang(code: 'es', name: 'Spanish', native: 'Español', flag: '🇪🇸'),
  SupportedLang(code: 'fr', name: 'French', native: 'Français', flag: '🇫🇷'),
  SupportedLang(code: 'ja', name: 'Japanese', native: '日本語', flag: '🇯🇵'),
];

class LanguageButton extends StatelessWidget {
  const LanguageButton({
    required this.language,
    required this.active,
    required this.onTap,
    super.key,
  });

  final SupportedLang language;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = language.native.isEmpty
        ? language.name
        : '${language.name} · ${language.native}';
    return SizedBox(
      width: double.infinity,
      height: 64,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: active ? simLight : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: simBorder),
          boxShadow: active
              ? const [
                  BoxShadow(
                    color: Color(0x22111827),
                    blurRadius: 18,
                    offset: Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(
            foregroundColor: simDark,
            alignment: Alignment.centerLeft,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: Row(
            children: [
              Text(language.flag, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StepHeader extends StatelessWidget {
  const StepHeader({
    required this.step,
    required this.total,
    required this.label,
    super.key,
  });

  final int step;
  final int total;
  final String label;

  @override
  Widget build(BuildContext context) {
    final pct = step / total;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 8,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: simBorder),
              ),
              clipBehavior: Clip.antiAlias,
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: pct,
                  child: Container(color: simLight),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(
              color: simMuted,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class SimInput extends StatelessWidget {
  const SimInput({
    required this.hint,
    required this.onChanged,
    this.controller,
    this.obscureText = false,
    this.keyboardType,
    super.key,
  });

  final String hint;
  final TextEditingController? controller;
  final bool obscureText;
  final TextInputType? keyboardType;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: simBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: simDark),
        ),
      ),
    );
  }
}

class SimCard extends StatelessWidget {
  const SimCard({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: simBorder),
      ),
      child: child,
    );
  }
}

class CardTitle extends StatelessWidget {
  const CardTitle({required this.icon, required this.title, super.key});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          CircleIcon(icon: icon),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: simDark,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CircleIcon extends StatelessWidget {
  const CircleIcon({required this.icon, this.top = 0, super.key});

  final IconData icon;
  final double top;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: top),
      child: Container(
        width: 32,
        height: 32,
        decoration: const BoxDecoration(
          color: simLight,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: simDark, size: 18),
      ),
    );
  }
}

class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: simBorder),
          ),
          child: Icon(icon, color: simDark, size: 22),
        ),
      ),
    );
  }
}

class CreditsPill extends StatelessWidget {
  const CreditsPill({required this.value, required this.onTap, super.key});

  final int value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: pillDecoration(),
        child: Row(
          children: [
            const Icon(Icons.link, color: simDark, size: 17),
            const SizedBox(width: 8),
            Text(
              '$value',
              style: const TextStyle(
                color: simDark,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BackgroundDecor extends StatelessWidget {
  const BackgroundDecor({super.key});

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white, simLight, Colors.white],
          stops: [0, 0.6, 1],
        ),
      ),
      child: SizedBox.expand(),
    );
  }
}

BoxDecoration glassDecoration({required double radius}) {
  return BoxDecoration(
    color: Colors.white.withAlpha(217),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: Colors.white),
    boxShadow: const [
      BoxShadow(
        color: Color(0x2E111827),
        blurRadius: 60,
        offset: Offset(0, 30),
      ),
      BoxShadow(
        color: Color(0x2E243447),
        blurRadius: 30,
        offset: Offset(0, 10),
      ),
    ],
  );
}

BoxDecoration pillDecoration() {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(999),
    border: Border.all(color: simBorder),
    boxShadow: const [
      BoxShadow(color: Color(0x2E243447), blurRadius: 14, offset: Offset(0, 4)),
    ],
  );
}

BoxDecoration primaryButtonDecoration({required double radius}) {
  return BoxDecoration(
    gradient: const LinearGradient(
      colors: [Colors.white, simLight],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: simBorder),
    boxShadow: const [
      BoxShadow(
        color: Color(0x33111827),
        blurRadius: 28,
        offset: Offset(0, 12),
      ),
    ],
  );
}
