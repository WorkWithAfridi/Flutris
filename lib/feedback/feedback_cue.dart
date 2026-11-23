import '../game/tetris_engine.dart' show TetrisEvent;

/// Which system haptic to use for a cue.
enum FeedbackHaptic { selection, light, medium, heavy, success, warning }

/// One feedback cue: sound asset, haptic style and anti-spam throttle.
class FeedbackCue {
  const FeedbackCue(
    this.asset, {
    required this.haptic,
    this.throttle = Duration.zero,
    this.volume = 1.0,
  });

  final String asset;
  final FeedbackHaptic haptic;
  final Duration throttle;
  final double volume;

  static const tap = FeedbackCue(
    'tap.wav',
    haptic: FeedbackHaptic.selection,
    throttle: Duration(milliseconds: 40),
    volume: .55,
  );
  static const navigate = FeedbackCue(
    'navigate.wav',
    haptic: FeedbackHaptic.light,
    throttle: Duration(milliseconds: 45),
    volume: .6,
  );
  static const move = FeedbackCue(
    'move.wav',
    haptic: FeedbackHaptic.light,
    throttle: Duration(milliseconds: 45),
    volume: .45,
  );
  static const rotate = FeedbackCue(
    'rotate.wav',
    haptic: FeedbackHaptic.selection,
    throttle: Duration(milliseconds: 35),
    volume: .6,
  );
  static const softDrop = FeedbackCue(
    'soft_drop.wav',
    haptic: FeedbackHaptic.light,
    throttle: Duration(milliseconds: 55),
    volume: .35,
  );
  static const hardDrop = FeedbackCue(
    'hard_drop.wav',
    haptic: FeedbackHaptic.medium,
    volume: .8,
  );
  static const lock = FeedbackCue(
    'lock.wav',
    haptic: FeedbackHaptic.light,
    volume: .45,
  );
  static const lineClear = FeedbackCue(
    'line_clear.wav',
    haptic: FeedbackHaptic.heavy,
    volume: .85,
  );
  static const tetris = FeedbackCue(
    'tetris.wav',
    haptic: FeedbackHaptic.heavy,
    volume: .95,
  );
  static const levelUp = FeedbackCue(
    'level_up.wav',
    haptic: FeedbackHaptic.success,
    volume: .9,
  );
  static const combo = FeedbackCue(
    'combo.wav',
    haptic: FeedbackHaptic.medium,
    volume: .7,
  );
  static const hold = FeedbackCue(
    'hold.wav',
    haptic: FeedbackHaptic.selection,
    volume: .6,
  );
  static const victory = FeedbackCue(
    'victory.wav',
    haptic: FeedbackHaptic.success,
    volume: .95,
  );
  static const gameOver = FeedbackCue(
    'game_over.wav',
    haptic: FeedbackHaptic.warning,
    volume: .9,
  );
  static const pause = FeedbackCue(
    'pause.wav',
    haptic: FeedbackHaptic.selection,
    volume: .6,
  );

  static const all = <FeedbackCue>[
    tap,
    navigate,
    move,
    rotate,
    softDrop,
    hardDrop,
    lock,
    lineClear,
    tetris,
    levelUp,
    combo,
    hold,
    victory,
    gameOver,
    pause,
  ];

  static const allAssets = <String>[
    'tap.wav',
    'navigate.wav',
    'move.wav',
    'rotate.wav',
    'soft_drop.wav',
    'hard_drop.wav',
    'lock.wav',
    'line_clear.wav',
    'tetris.wav',
    'level_up.wav',
    'combo.wav',
    'hold.wav',
    'victory.wav',
    'game_over.wav',
    'pause.wav',
  ];

  /// Maps a gameplay event to its cue. Returns null for silent events.
  static FeedbackCue? forEvent(
    TetrisEvent event, {
    int clearedLines = 0,
  }) =>
      switch (event) {
        TetrisEvent.move => move,
        TetrisEvent.softDrop => softDrop,
        TetrisEvent.hardDrop => hardDrop,
        TetrisEvent.rotate => rotate,
        TetrisEvent.lock => lock,
        TetrisEvent.hold => hold,
        TetrisEvent.lineClear =>
          clearedLines >= 4 ? tetris : lineClear,
        TetrisEvent.levelUp => levelUp,
        TetrisEvent.combo => combo,
        TetrisEvent.perfectClear => tetris,
        TetrisEvent.victory => victory,
        TetrisEvent.timeUp || TetrisEvent.gameOver => gameOver,
        TetrisEvent.pause || TetrisEvent.resume || TetrisEvent.reset => pause,
        TetrisEvent.start => null,
      };
}
