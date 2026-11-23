import 'package:shared_preferences/shared_preferences.dart';

import '../game/game_mode.dart';

/// Persistent per-mode high scores, backed by `shared_preferences`.
///
/// All failures are swallowed: a missing plugin or storage error must never
/// break the game, it just means scores are not remembered on that device.
class BestScoreStore {
  BestScoreStore._();

  static final BestScoreStore instance = BestScoreStore._();

  static const _prefix = 'flutris.best.';

  final Map<GameMode, int> _scores = <GameMode, int>{};

  /// Loaded values, safe to copy into `GameFlow.bestScores`.
  Map<GameMode, int> get scores => Map<GameMode, int>.unmodifiable(_scores);

  /// Reads all stored values once. Safe to call again (refreshes the cache).
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final mode in GameMode.values) {
        final value = prefs.getInt(_key(mode));
        if (value != null) _scores[mode] = value;
      }
    } catch (_) {
      // Storage unavailable; keep whatever was already cached in memory.
    }
  }

  /// Clears the in-memory cache and reads again from disk.
  Future<void> reload() async {
    _scores.clear();
    await load();
  }

  /// Writes a new record for [mode].
  Future<void> save(GameMode mode, int score) async {
    _scores[mode] = score;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_key(mode), score);
    } catch (_) {
      // Best-effort persistence.
    }
  }

  static String _key(GameMode mode) => '$_prefix${mode.name}';
}
