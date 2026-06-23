import '../experience/student_experience_types.dart';
import '../state/student_learning_state.dart';
import 'sim_organism.dart';

class SimOrganismController {
  SimOrganismController({required this.organism});

  final SimOrganism organism;
  bool authed = false;
  String route = '/';
  String selectedLanguage = '';
  String selectedLanguageCode = '';
  String objective = '';
  String preferredName = '';
  StudentExperienceResult? lastExperienceResult;

  bool get hasLanguage => selectedLanguage.trim().isNotEmpty;
  bool get hasObjective => objective.trim().isNotEmpty;

  void go(String path) {
    final decision = organism.router.resolve(
      path: path,
      authed: authed,
      hasLanguage: hasLanguage,
      hasObjective: hasObjective,
    );
    route = decision.destination;
  }

  void signInLaboratory() {
    authed = true;
    go('/cyber/idioma');
  }

  void chooseLanguage({
    required String code,
    required String label,
  }) {
    selectedLanguageCode = code;
    selectedLanguage = label;
    organism.stateService.mutate(organism.lessonLocalId, (state) {
      return state.copyWith(
        profile: state.profile.copyWith(
          language: label,
          stableLang: label,
          extra: {
            ...state.profile.extra,
            'language_code': code,
          },
        ),
      );
    });
    go('/cyber/objeto');
  }

  Future<void> submitObjective({
    required String text,
    String? name,
  }) async {
    objective = text.trim();
    preferredName = name?.trim() ?? preferredName;
    final onboarding = <String, dynamic>{
      'objetivo': objective,
      'idioma': selectedLanguage,
      'stableLang': selectedLanguage,
      'preferred_name': preferredName,
      'lessonLocalId': organism.lessonLocalId,
    };
    organism.stateService.mutate(organism.lessonLocalId, (state) {
      return state.copyWith(
        profile: state.profile.copyWith(
          objetivo: objective,
          preferredName: preferredName.isEmpty ? null : preferredName,
          language: selectedLanguage,
          stableLang: selectedLanguage,
          extra: {
            ...state.profile.extra,
            'onboarding': onboarding,
          },
        ),
      );
    });
    route = '/cyber/curriculo';
    lastExperienceResult = await organism.experienceEngine.prepareStudentExperienceEntry(
      StudentExperienceArgs(
        academic: 'unknown',
        idioma: selectedLanguage,
        lessonLocalId: organism.lessonLocalId,
        onboarding: onboarding,
      ),
    );
    route = lastExperienceResult?.destination ?? '/cyber/aula';
  }

  Future<void> openClassroom() async {
    await organism.lessonRuntimeEngine.open(lessonLocalId: organism.lessonLocalId);
    go('/cyber/aula');
  }

  void enqueueSync() {
    organism.sync.enqueuePatch(organism.lessonLocalId);
  }

  StudentLearningState get state => organism.activeState;
}
