import 'game_mode.dart';
import 'tetris_engine.dart';

/// Screens of the game shell. Pure state, no widgets.
enum FlowState { menu, playing, paused, gameOver, victory, timeUp }

/// Navigation state machine shared by the Flame renderer and the handheld
/// buttons. The UI only calls the public methods; the engine handles rules.
class GameFlow {
  GameFlow({
    List<ModeConfig>? modes,
    Map<GameMode, int>? bestScores,
    this.onStart,
    this.onBestChanged,
  }) : modes = modes ?? allModes,
       bestScores = bestScores ?? <GameMode, int>{};

  final List<ModeConfig> modes;
  final Map<GameMode, int> bestScores;
  final void Function(ModeConfig mode)? onStart;
  final void Function(GameMode mode, int score)? onBestChanged;

  FlowState state = FlowState.menu;
  int selected = 0;

  ModeConfig get selectedMode => modes[selected];

  bool get isMenu => state == FlowState.menu;
  bool get isPlaying => state == FlowState.playing;
  bool get isPaused => state == FlowState.paused;
  bool get isEndScreen =>
      state == FlowState.gameOver ||
      state == FlowState.victory ||
      state == FlowState.timeUp;

  /// Moves the menu cursor with wrapping.
  void move(int delta) {
    if (!isMenu) return;
    selected = (selected + delta).mod(modes.length);
  }

  /// Confirms the highlighted mode, or leaves an end screen back to the menu.
  void confirm() {
    if (isMenu) {
      onStart?.call(selectedMode);
    } else if (isEndScreen) {
      toMenu();
    }
  }

  void toMenu() {
    state = FlowState.menu;
  }

  /// Keeps the flow synced with engine lifecycle events.
  void sync(TetrisEngine engine) {
    if (isMenu) return;
    switch (engine.status) {
      case TetrisStatus.playing:
        state = FlowState.playing;
      case TetrisStatus.paused:
        state = FlowState.paused;
      case TetrisStatus.gameOver:
        state = FlowState.gameOver;
      case TetrisStatus.victory:
        state = FlowState.victory;
      case TetrisStatus.timeUp:
        state = FlowState.timeUp;
      case TetrisStatus.ready:
        break;
    }
  }

  void recordBest(TetrisEngine engine) {
    final previous = bestScores[engine.mode.mode] ?? 0;
    final score = engine.score;
    if (previous == 0 || score > previous) {
      bestScores[engine.mode.mode] = score;
      onBestChanged?.call(engine.mode.mode, score);
    }
  }
}

/// Extension providing positive modulo for menu wrapping.
extension _Mod on int {
  int mod(int value) => ((this % value) + value) % value;
}
