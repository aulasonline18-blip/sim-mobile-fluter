class SimEnvironment {
  const SimEnvironment._();

  static const apiBaseUrl = String.fromEnvironment(
    'SIM_SERVER_URL',
    defaultValue: 'http://167.179.109.137:3000',
  );

  static const t00Path = '/api/bootstrap-t00';
  static const t02Path = '/api/complete-lesson';
  static const imagePath = '/api/generate-lesson-image';
  static const audioPath = '/api/generate-lesson-audio';
}
