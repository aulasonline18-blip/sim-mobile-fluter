import 'package:flutter/foundation.dart';

class LessonUiState extends ChangeNotifier {
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
  bool audioPlaying = false;
  bool audioLoading = false;
  String? audioError;
  String imageStatus = 'idle';
  String? imageError;
  String deleteConfirmation = '';
  String? accountDeletionMessage;

  void markPreparationDone() {
    entryStatus = 'primeira_aula_pronta';
    notifyListeners();
  }

  void skipPlacement() {
    placementDone = true;
    notifyListeners();
  }

  void startPlacement() {
    placementStarted = true;
    notifyListeners();
  }

  void finishPlacement() {
    placementDone = true;
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

  void advanceAulaVisual() {
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
}
