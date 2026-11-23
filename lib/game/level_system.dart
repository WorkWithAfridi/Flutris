import 'game_mode.dart';

/// Stateless helpers for level progression, speed and goal progress.
///
/// The engine owns the current level/line counts; this class derives
/// everything else from the mode configuration.
class LevelSystem {
  const LevelSystem(this.config);

  final ModeConfig config;

  /// Level reached after clearing [lines] total lines.
  int levelFor(int lines, {int? startingLevel}) {
    final start = startingLevel ?? config.startingLevel;
    if (config.linesPerLevel <= 0) return start;
    final gained = lines ~/ config.linesPerLevel;
    return (start + gained).clamp(start, config.maxLevel);
  }

  /// Lines cleared towards the current level.
  int linesIntoLevel(int lines, {int? startingLevel}) {
    final start = startingLevel ?? config.startingLevel;
    if (config.linesPerLevel <= 0) return 0;
    final gained = lines ~/ config.linesPerLevel;
    if (start + gained >= config.maxLevel) return 0;
    return lines % config.linesPerLevel;
  }

  /// Lines remaining before the next level (0 once capped).
  int linesToNext(int lines, {int? startingLevel}) {
    final start = startingLevel ?? config.startingLevel;
    if (start + lines ~/ config.linesPerLevel >= config.maxLevel) return 0;
    final into = linesIntoLevel(lines, startingLevel: start);
    return config.linesPerLevel - into;
  }

  /// 0..1 progress bar value for the current level.
  double levelProgress(int lines, {int? startingLevel}) {
    if (config.linesPerLevel <= 0 || linesToNext(lines, startingLevel: startingLevel) == 0) {
      return 1;
    }
    return linesIntoLevel(lines, startingLevel: startingLevel) /
        config.linesPerLevel;
  }

  /// 0..1 progress towards the mode's win goal.
  double goalProgress(int lines) {
    if (config.goalType == GoalType.none || config.goalValue == null) return 0;
    return (lines / config.goalValue!).clamp(0.0, 1.0);
  }

  Duration gravity(int level) => config.gravityForLevel(level);

  Duration lockDelay(int level) => config.lockDelayForLevel(level, config.maxLevel);
}
