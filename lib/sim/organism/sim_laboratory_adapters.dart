import '../billing/account_deletion.dart';
import '../billing/credits_functions.dart';
import '../billing/payments_functions.dart';
import '../cloud/cloud_functions.dart';
import '../cloud/supabase_client_contract.dart';
import '../media/audio_core.dart';
import '../media/lesson_visual_pipeline.dart';
import '../modules/pedagogical_module_contracts.dart';
import '../state/student_learning_state.dart';

class LaboratoryT00Client implements T00BootstrapClient {
  const LaboratoryT00Client();

  @override
  Stream<T00BootstrapChunk> runBootstrap(T00BootstrapRequest request) async* {
    final topic = (request.onboarding['objetivo'] ?? 'Aula SIM').toString();
    yield T00BootstrapChunk(
      type: 't00_profile',
      payload: {
        'profile': 'Perfil pedagogico de laboratorio para $topic',
        'ficha_for_next': {
          'stable_lang': request.lang,
          'target_topic': topic,
        },
      },
    );
    yield T00BootstrapChunk(
      type: 't00_item_partial',
      payload: {
        'item': {
          'marker': 'T00:1',
          'text': topic,
          'title': topic,
        },
      },
    );
  }
}

class LaboratoryT02Client implements T02LessonClient {
  const LaboratoryT02Client();

  @override
  Future<T02LessonMaterial> auxiliaryRoom(T02LessonRequest request) {
    return _material(request, 'Recuperar e revisar');
  }

  @override
  Future<T02LessonMaterial> completeLesson(T02LessonRequest request) {
    return _material(request, request.item);
  }

  @override
  Future<T02LessonMaterial> doubt(T02LessonRequest request) {
    return _material(request, 'Duvida sobre ${request.item}');
  }

  @override
  Future<T02LessonMaterial> placement(T02LessonRequest request) {
    return _material(request, 'Nivelamento de ${request.item}');
  }

  Future<T02LessonMaterial> _material(T02LessonRequest request, String topic) async {
    return T02LessonMaterial(
      explanation: 'LABORATORIO: explicacao temporaria para $topic.',
      question: 'Qual opcao combina melhor com $topic?',
      options: const {
        AnswerLetter.A: 'Entendi e consigo explicar.',
        AnswerLetter.B: 'Entendi uma parte.',
        AnswerLetter.C: 'Ainda preciso de ajuda.',
      },
      correctAnswer: AnswerLetter.A,
      whyCorrect: 'A resposta mostra dominio do ponto.',
      whyWrong: {'B': 'precisa reforco', 'C': 'precisa recuperacao'},
      generatedAt: DateTime.now(),
      source: 'laboratory_t02_contract',
    );
  }
}

class LaboratorySessionProvider implements SupabaseSessionProvider {
  const LaboratorySessionProvider({this.session});

  final SupabaseSession? session;

  @override
  Future<SupabaseSession?> currentSession() async => session;
}

class LaboratoryStudentStateCloudFunctions implements StudentStateCloudFunctions {
  final Map<String, StudentStateRow> rows = {};

  @override
  Future<void> deleteStudentStateByLesson(String lessonLocalId, SupabaseSession session) async {
    rows.remove(lessonLocalId);
  }

  @override
  Future<StudentStateRow?> getStudentStateByLesson(String lessonLocalId, SupabaseSession session) async {
    return rows[lessonLocalId];
  }

  @override
  Future<List<StudentStateRow>> listStudentStates(SupabaseSession session) async {
    return rows.values.toList(growable: false);
  }

  @override
  Future<List<StudentStateSummaryRow>> listStudentStateSummaries(SupabaseSession session) async {
    return rows.values
        .map(summarizeStudentStateRow)
        .whereType<StudentStateSummaryRow>()
        .toList(growable: false);
  }

  @override
  Future<PersistStudentStateResult> persistStudentState(
    PersistStudentStateInput input,
    SupabaseSession session,
  ) async {
    rows[input.lessonLocalId] = StudentStateRow(
      lessonLocalId: input.lessonLocalId,
      state: input.state,
      highWaterMark: input.clientScore,
      schemaVersion: input.schemaVersion,
      updatedAt: DateTime.now().toIso8601String(),
    );
    return PersistStudentStateResult.accepted(
      lessonLocalId: input.lessonLocalId,
      highWaterMark: input.clientScore,
      schemaVersion: input.schemaVersion,
      updatedAt: DateTime.now().toIso8601String(),
    );
  }
}

class LaboratoryCreditsFunctions implements CreditsFunctions {
  int balance;

  LaboratoryCreditsFunctions({this.balance = 3});

  @override
  Future<CreditsSnapshot> getMyCredits() async {
    return CreditsSnapshot(balance: balance, lifetimeEarned: balance, lifetimeSpent: 0);
  }

  @override
  Future<int> chargeLessonGeneration(ChargeLessonGenerationInput input) async {
    input.normalized();
    balance -= 3;
    return balance;
  }
}

class LaboratoryPaymentsFunctions implements PaymentsFunctions {
  const LaboratoryPaymentsFunctions();

  @override
  Future<HostedCheckoutResult> createCreditsCheckoutHosted(
    CreateCreditsCheckoutHostedInput input,
  ) async {
    return const HostedCheckoutResult.success(
      url: 'https://checkout.stripe.com/c/pay/cs_test_lab',
      sessionId: 'cs_test_lab',
    );
  }

  @override
  Future<EmbeddedCheckoutResult> createCreditsCheckoutEmbedded(
    CreateCreditsCheckoutEmbeddedInput input,
  ) async {
    return const EmbeddedCheckoutResult.success('client_secret_lab');
  }

  @override
  Future<CheckoutStatus> getCheckoutStatus({
    required String sessionId,
    required StripeEnvironment environment,
  }) async {
    return const CheckoutStatus.complete(credits: 30, balance: 33);
  }
}

class LaboratoryAccountDeletionGateway implements AccountDeletionGateway {
  bool requested = false;

  @override
  Future<void> requestAccountDeletion(AccountDeletionRequest request) async {
    requested = true;
  }
}

class LaboratoryGeneratedAudioClient implements GeneratedAudioClient {
  const LaboratoryGeneratedAudioClient();

  @override
  Future<String?> generateAudio({
    required String text,
    required String lang,
    required String voice,
    required String lessonKey,
  }) async {
    return 'data:audio/wav;base64,';
  }
}

class LaboratoryLessonImageClient implements LessonImageClient {
  const LaboratoryLessonImageClient();

  @override
  Future<String?> generateLessonImage({
    required String prompt,
    required String lessonKey,
    String aspectRatio = '1:1',
  }) async {
    return 'data:image/png;base64,';
  }
}
