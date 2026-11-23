/// Selectable game modes. Each mode maps to a [ModeConfig] with its own goal,
/// speed curve and enabled features.
enum GameMode { marathon, sprint, ultra, master, zen, tactics }

/// What ends a [GameMode].
enum GoalType { lines, time, none }

/// Static rules for one game mode. Pure data, no game state.
class ModeConfig {
  const ModeConfig({
    required this.mode,
    required this.name,
    required this.tagline,
    required this.description,
    required this.startingLevel,
    required this.maxLevel,
    required this.linesPerLevel,
    required this.goalType,
    this.goalValue,
    this.timeLimit,
    this.gravityScale = 1.0,
    this.instantGravity = false,
    this.startingLockDelayMillis = 500,
    this.minimumLockDelayMillis = 500,
    this.allowHold = true,
    this.allowHints = false,
    this.comboScoring = false,
    this.topOutEndsGame = true,
    this.scoreMultiplier = 1.0,
    this.previewCount = 5,
  });

  final GameMode mode;
  final String name;
  final String tagline;
  final String description;
  final int startingLevel;
  final int maxLevel;
  final int linesPerLevel;
  final GoalType goalType;
  final int? goalValue;
  final Duration? timeLimit;
  final double gravityScale;
  final bool instantGravity;
  final int startingLockDelayMillis;
  final int minimumLockDelayMillis;
  final bool allowHold;
  final bool allowHints;
  final bool comboScoring;
  final bool topOutEndsGame;
  final double scoreMultiplier;
  final int previewCount;

  /// Classic accelerating gravity curve, scaled per mode.
  Duration gravityForLevel(int level) {
    if (instantGravity) return Duration.zero;
    final base = (0.8 - ((level - 1) * 0.007)).clamp(0.2, 1.0).toDouble();
    var seconds = 1.0;
    for (var i = 1; i < level; i++) {
      seconds *= base;
    }
    seconds *= gravityScale;
    if (seconds < 0.04) seconds = 0.04;
    return Duration(milliseconds: (seconds * 1000).round());
  }

  /// Lock delay shortens at high Master levels; fixed otherwise.
  Duration lockDelayForLevel(int level, int maxLevel) {
    if (maxLevel <= startingLevel ||
        startingLockDelayMillis == minimumLockDelayMillis) {
      return Duration(milliseconds: startingLockDelayMillis);
    }
    final span = (maxLevel - startingLevel).clamp(1, 1000);
    final progress = ((level - startingLevel) / span).clamp(0.0, 1.0);
    final millis = startingLockDelayMillis +
        (minimumLockDelayMillis - startingLockDelayMillis) * progress;
    return Duration(milliseconds: millis.round());
  }

  /// Short label for HUD and menu.
  String get goalLabel => switch (goalType) {
        GoalType.lines => '$goalValue LINES',
        GoalType.time => '${timeLimit?.inMinutes ?? 0}:00',
        GoalType.none => 'ENDLESS',
      };
}

const Map<GameMode, ModeConfig> modeConfigs = <GameMode, ModeConfig>{
  GameMode.marathon: ModeConfig(
    mode: GameMode.marathon,
    name: 'MARATHON',
    tagline: 'THE CLASSIC CLIMB',
    description: '150 lines across 15 levels. Gravity rises every 10 lines.',
    startingLevel: 1,
    maxLevel: 15,
    linesPerLevel: 10,
    goalType: GoalType.lines,
    goalValue: 150,
    allowHints: true,
    comboScoring: true,
  ),
  GameMode.sprint: ModeConfig(
    mode: GameMode.sprint,
    name: 'SPRINT 40',
    tagline: 'RACE THE CLOCK',
    description: 'Clear 40 lines as fast as you can. Level stays fixed.',
    startingLevel: 5,
    maxLevel: 5,
    linesPerLevel: 10,
    goalType: GoalType.lines,
    goalValue: 40,
    allowHints: true,
    scoreMultiplier: 0.5,
  ),
  GameMode.ultra: ModeConfig(
    mode: GameMode.ultra,
    name: 'ULTRA 2:00',
    tagline: 'SCORE ATTACK',
    description: 'Two minutes. Bank the biggest score you can.',
    startingLevel: 5,
    maxLevel: 5,
    linesPerLevel: 10,
    goalType: GoalType.time,
    timeLimit: Duration(minutes: 2),
    allowHints: true,
    scoreMultiplier: 1.5,
    comboScoring: true,
  ),
  GameMode.master: ModeConfig(
    mode: GameMode.master,
    name: 'MASTER',
    tagline: '20G EXPERT',
    description: 'Pieces slam down instantly. Survive 300 lines from M1.',
    startingLevel: 15,
    maxLevel: 30,
    linesPerLevel: 10,
    goalType: GoalType.lines,
    goalValue: 300,
    instantGravity: true,
    startingLockDelayMillis: 500,
    minimumLockDelayMillis: 80,
    allowHints: true,
    scoreMultiplier: 2.0,
    comboScoring: true,
  ),
  GameMode.zen: ModeConfig(
    mode: GameMode.zen,
    name: 'ZEN',
    tagline: 'NO PRESSURE',
    description: 'Relaxed gravity, unlimited time. Topping out just resets.',
    startingLevel: 1,
    maxLevel: 10,
    linesPerLevel: 10,
    goalType: GoalType.none,
    gravityScale: 1.8,
    allowHints: true,
    topOutEndsGame: false,
    scoreMultiplier: 0.75,
  ),
  GameMode.tactics: ModeConfig(
    mode: GameMode.tactics,
    name: 'TACTICS',
    tagline: 'PLAN YOUR STACK',
    description: 'Hints, combo bonuses and a deep preview. Think ahead.',
    startingLevel: 3,
    maxLevel: 15,
    linesPerLevel: 10,
    goalType: GoalType.lines,
    goalValue: 100,
    allowHints: true,
    comboScoring: true,
    scoreMultiplier: 1.2,
    previewCount: 6,
  ),
};

/// Ordered list for menus and cycling.
final List<ModeConfig> allModes = <ModeConfig>[
  modeConfigs[GameMode.marathon]!,
  modeConfigs[GameMode.sprint]!,
  modeConfigs[GameMode.ultra]!,
  modeConfigs[GameMode.master]!,
  modeConfigs[GameMode.zen]!,
  modeConfigs[GameMode.tactics]!,
];
