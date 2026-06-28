import 'dart:async';
import 'dart:io';

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
  if (error is TimeoutException ||
      lower.contains('timeout') ||
      lower.contains('timeoutexception') ||
      lower.contains('tempo') ||
      lower.contains('abort') ||
      lower.contains('t02 nao devolveu') ||
      lower.contains('aula minima')) {
    return const StudentExperienceErrorInfo(
      kind: StudentExperienceErrorKind.timeout,
      message: 'A preparacao demorou demais. Toque para tentar novamente.',
    );
  }
  if (error is SocketException ||
      lower.contains('socketexception') ||
      lower.contains('connection refused') ||
      lower.contains('connection reset') ||
      lower.contains('network is unreachable') ||
      lower.contains('failed host lookup') ||
      lower.contains('os error') ||
      lower.contains('cleartext') ||
      lower.contains('http 401') ||
      lower.contains('http 403') ||
      lower.contains('http 5')) {
    return const StudentExperienceErrorInfo(
      kind: StudentExperienceErrorKind.generic,
      message:
          'Erro de conexao com o servidor. Verifique sua internet e tente novamente.',
    );
  }
  return const StudentExperienceErrorInfo(
    kind: StudentExperienceErrorKind.generic,
    message:
        'Nao consegui preparar a entrada da aula agora. Toque para tentar novamente.',
  );
}
