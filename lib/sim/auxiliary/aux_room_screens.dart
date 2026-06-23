import 'aux_room_models.dart';

class DoubtInputSheetModel {
  const DoubtInputSheetModel({
    required this.title,
    required this.description,
    required this.placeholder,
    required this.submitLabel,
    required this.busyLabel,
    required this.cameraLabel,
    required this.galleryLabel,
    required this.removeLabel,
  });

  final String title;
  final String description;
  final String placeholder;
  final String submitLabel;
  final String busyLabel;
  final String cameraLabel;
  final String galleryLabel;
  final String removeLabel;
}

const doubtInputSheetModel = DoubtInputSheetModel(
  title: 'Enviar dúvida',
  description:
      'Escreva sua dúvida ou envie uma foto do exercício, resolução, fórmula, gráfico ou tabela.',
  placeholder: 'Escreva sua dúvida aqui...',
  submitLabel: 'Enviar dúvida',
  busyLabel: 'Enviando...',
  cameraLabel: 'Tirar foto',
  galleryLabel: 'Escolher imagem',
  removeLabel: 'Remover',
);

class AuxRoomScreenState {
  const AuxRoomScreenState({
    this.review,
    this.recovery,
  });

  final ReviewRoomView? review;
  final RecoveryRoomView? recovery;

  bool get showingReview => review != null;
  bool get showingRecovery => recovery != null;
}
