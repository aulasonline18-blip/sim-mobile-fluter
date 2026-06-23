import 'student_experience_types.dart';

StudentExperienceErrorInfo classifyStudentExperienceError(Object error) {
  final message = error.toString();
  final lower = message.toLowerCase();
  if (message.contains('HTTP 402') ||
      lower.contains('credit') ||
      lower.contains('credito') ||
      lower.contains('saldo') ||
      lower.contains('insufficient_credits')) {
    return const StudentExperienceErrorInfo(
      kind: StudentExperienceErrorKind.credits,
      message:
          'Seus creditos acabaram. Compre creditos para continuar estudando.',
    );
  }
  if (lower.contains('timeout') ||
      lower.contains('tempo') ||
      lower.contains('abort')) {
    return const StudentExperienceErrorInfo(
      kind: StudentExperienceErrorKind.timeout,
      message: 'A preparacao demorou demais. Toque para tentar novamente.',
    );
  }
  return const StudentExperienceErrorInfo(
    kind: StudentExperienceErrorKind.generic,
    message:
        'Nao consegui preparar a entrada da aula agora. Toque para tentar novamente.',
  );
}
