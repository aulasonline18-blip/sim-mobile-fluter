import 'aux_room_models.dart';

const String imageOnlyMessage = 'Na dúvida, envie apenas foto ou imagem.';
const String emptyDoubtMessage = 'Escreva sua dúvida ou envie uma foto.';
const String imageTooLargeMessage =
    'A imagem ficou grande demais. Tente uma foto mais leve.';
const int doubtTextMaxLength = 1200;
const int doubtImageMaxDataUrlLength = 8 * 1024 * 1024;

class DoubtInputDraft {
  const DoubtInputDraft({this.text = '', this.image});

  final String text;
  final DoubtImagePayload? image;

  String get cleanText {
    final trimmed = text.trim();
    if (trimmed.length <= doubtTextMaxLength) return trimmed;
    return trimmed.substring(0, doubtTextMaxLength);
  }

  String? validate() {
    if (cleanText.isEmpty && image == null) return emptyDoubtMessage;
    if (image == null) return null;
    if (!image!.type.startsWith('image/')) return imageOnlyMessage;
    if (!image!.dataUrl.startsWith('data:image/')) return imageOnlyMessage;
    if (image!.dataUrl.length > doubtImageMaxDataUrlLength) {
      return imageTooLargeMessage;
    }
    return null;
  }
}
