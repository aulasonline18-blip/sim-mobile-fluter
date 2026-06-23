import '../state/student_learning_state.dart';
import 'aux_room_models.dart';
import 'doubt_input_sheet.dart';
import 'doubt_progress_bar.dart';
import 'doubt_t02_caller.dart';

const String defaultDoubtError =
    'Nao consegui carregar a explicacao, tente novamente.';

class LessonDoubtController {
  LessonDoubtController({required this.caller}) : state = DoubtState.idle;

  final DoubtT02Caller caller;
  DoubtState state;

  String get progressLabel => doubtProgressLabel(state.progress);

  void askDoubt() {
    if (state.status == DoubtStatus.processing) return;
    state = state.copyWith(sheetOpen: true, error: null);
  }

  void dismissDoubt() {
    state = state.copyWith(sheetOpen: false);
  }

  void reset() {
    state = DoubtState.idle;
  }

  Future<void> submitDoubt({
    required String lessonLocalId,
    required AuxRoomProfile profile,
    required String itemText,
    required String currentContent,
    required LessonLayer layer,
    required int itemIdx,
    String? marker,
    required DoubtInputDraft input,
  }) async {
    final validation = input.validate();
    if (validation != null) {
      state = state.copyWith(
        status: DoubtStatus.error,
        progress: 0,
        sheetOpen: true,
        error: validation,
      );
      return;
    }
    state = const DoubtState(
      status: DoubtStatus.processing,
      progress: 15,
      sheetOpen: false,
    );
    try {
      state = state.copyWith(progress: 60);
      final response = await caller.call(
        lessonLocalId: lessonLocalId,
        profile: profile,
        itemText: itemText,
        currentContent: currentContent,
        layer: layer,
        itemIdx: itemIdx,
        marker: marker,
        studentDoubt: input.cleanText,
        doubtImage: input.image,
      );
      state = DoubtState(
        status: DoubtStatus.explaining,
        progress: 100,
        response: response,
      );
    } catch (_) {
      state = const DoubtState(
        status: DoubtStatus.error,
        progress: 0,
        error: defaultDoubtError,
      );
    }
  }
}
