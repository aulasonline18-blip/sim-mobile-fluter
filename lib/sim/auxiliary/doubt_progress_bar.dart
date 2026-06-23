class DoubtProgressSnapshot {
  const DoubtProgressSnapshot({required this.progress, required this.label});

  final int progress;
  final String label;

  int get percent => progress.clamp(0, 100);
}

String doubtProgressLabel(int progress) {
  if (progress < 30) return 'Enviando sua dúvida...';
  if (progress < 60) return 'Professor esta analisando...';
  if (progress < 90) return 'Preparando explicacao...';
  return 'Quase pronto...';
}
