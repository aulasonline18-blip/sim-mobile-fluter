class ClassroomTextScale {
  const ClassroomTextScale._();

  static const prefsKey = 'sim.classroom.text_scale.level';
  static const defaultLevel = 2;
  static const minLevel = 1;
  static const maxLevel = 5;
  static const levels = <int, double>{
    1: 0.84,
    2: 0.92,
    3: 1.0,
    4: 1.1,
    5: 1.22,
  };

  static int normalize(int value) => value.clamp(minLevel, maxLevel);

  static double scaleFor(int level) => levels[normalize(level)]!;

  static int next(int current) {
    final normalized = normalize(current);
    return normalized >= maxLevel ? minLevel : normalized + 1;
  }
}
