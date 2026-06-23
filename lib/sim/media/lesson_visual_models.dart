class FixedBubbleModel {
  const FixedBubbleModel({
    this.visible = true,
    this.size = 40,
    this.bottom = 24,
    this.pulsing = true,
  });

  final bool visible;
  final double size;
  final double bottom;
  final bool pulsing;
}

class LessonAvatarModel {
  const LessonAvatarModel({required this.speaking});

  final bool speaking;
  double get width => 96;
  double get height => 116;
  double get circleSize => 80;
  double get barProgress => speaking ? 1 : 0.28;
}

bool isUsableImageDataUrl(Object? value) {
  if (value is! String) return false;
  return RegExp(
    r'^data:image/(png|jpeg|jpg|webp|svg\+xml);base64,',
    caseSensitive: false,
  ).hasMatch(value);
}
