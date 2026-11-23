import 'dart:ui' show Color;

import 'package:flame/game.dart';
import 'package:flame/input.dart';
import 'package:flutter/services.dart'
    show KeyDownEvent, KeyEvent, KeyRepeatEvent, LogicalKeyboardKey;
import 'package:flutter/widgets.dart' show KeyEventResult;

import 'components/board_component.dart';
import 'components/flow_overlay.dart';
import 'components/line_clear_effect.dart';
import '../persistence/best_score_store.dart';
import '../feedback/feedback_cue.dart';
import '../feedback/feedback_service.dart';
import 'tetris.dart';

/// Flame game that hosts the mode menu, the rules engine and the render tree.
///
/// Flame responsibilities: the update loop (gravity/lock timing), the render
/// tree ([BoardComponent], [FlowOverlayComponent], line-clear effects),
/// keyboard input and the game canvas. Rules live in the pure-Dart
/// [TetrisEngine]; navigation lives in [GameFlow].
///
/// The handheld shell forwards touch input through the public methods and can
/// subscribe to [onStateChanged] to mirror engine state in Flutter widgets.
class FlutrisGame extends FlameGame with KeyboardEvents {
  FlutrisGame({
    TetrisEngine? engine,
    this.palette = lcdPalette,
    this.startInMenu = true,
    this.renderHud = true,
    this.compactMenu = false,
  }) : _engine = engine ?? TetrisEngine() {
    flow = GameFlow(
      onStart: _startMode,
      onBestChanged: (mode, score) => BestScoreStore.instance.save(mode, score),
    );
  }

  static const int columns = TetrisEngine.columns;
  static const int rows = TetrisEngine.rows;

  final BoardPalette palette;
  final bool startInMenu;

  /// Whether the Flame overlay draws its compact in-canvas HUD.
  ///
  /// Set this to false when a surrounding Flutter layout presents the same
  /// engine state in a dedicated panel.
  final bool renderHud;

  /// Whether the Flame menu leaves mode details to an external Flutter panel.
  final bool compactMenu;

  /// Notifies a Flutter shell about menu and engine state changes.
  void Function()? onStateChanged;

  TetrisEngine _engine;
  TetrisEngine get engine => _engine;

  bool get isHintVisible => isLoaded && _overlay.showHint;

  /// Latest placement suggestion, rendered by the Flutter side panel.
  Placement? get placementHint => isLoaded ? _overlay.hint : null;

  /// Compact signature used to avoid unnecessary UI rebuilds.
  String get hintSummary {
    final hint = placementHint;
    if (hint == null) return '';
    return '${hint.rotation}/${hint.x}/${hint.features.lines}/'
        '${hint.features.holes}/${hint.score.toStringAsFixed(1)}';
  }

  late final GameFlow flow;
  late final BoardComponent _board;
  late final FlowOverlayComponent _overlay;

  final Set<LogicalKeyboardKey> _heldKeys = <LogicalKeyboardKey>{};

  double _horizontalRepeat = _initialDelay;
  double _verticalRepeat = 0;

  static const double _initialDelay = 0.17;
  static const double _repeatInterval = 0.055;
  static const double _softDropInterval = 0.045;

  @override
  Color backgroundColor() => palette.background;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await BestScoreStore.instance.load();
    flow.bestScores.addAll(BestScoreStore.instance.scores);
    onStateChanged?.call();
    _board = BoardComponent(engine: _engine, palette: palette, priority: 1);
    _overlay = FlowOverlayComponent(
      flow: flow,
      palette: palette,
      engine: _engine,
      renderHud: renderHud,
      compactMenu: compactMenu,
      priority: 3,
    );
    await add(_board);
    await add(_overlay);
    // Fire-and-forget: audio setup must never block the game from loading.
    FeedbackService.instance.preload().then(
      (_) => FeedbackService.instance.syncMenuMusic(inMenu: flow.isMenu),
    );
    _overlay.onHintChanged = (_) => onStateChanged?.call();
    _wireEngine(_engine);

    if (startInMenu) {
      flow.toMenu();
    } else {
      flow.state = FlowState.playing;
      _engine.start();
    }
  }

  void _wireEngine(TetrisEngine engine) {
    engine.onLinesCleared = _spawnLineClearEffect;
    final previousOnChanged = engine.onChanged;
    engine.onChanged = () {
      previousOnChanged?.call();
      flow.sync(engine);
      onStateChanged?.call();
    };
    engine.onEvent = (event) {
      final cue = FeedbackCue.forEvent(
        event,
        clearedLines: engine.lastClearedRows.length,
      );
      if (cue != null) FeedbackService.instance.play(cue);
      if (event == TetrisEvent.victory ||
          event == TetrisEvent.gameOver ||
          event == TetrisEvent.timeUp) {
        flow.recordBest(engine);
      }
      flow.sync(engine);
    };
  }

  void _startMode(ModeConfig mode) {
    FeedbackService.instance.stopMenuMusic();
    _engine = TetrisEngine(mode: mode, best: flow.bestScores[mode.mode]);
    _board.engine = _engine;
    _overlay.engine = _engine;
    _wireEngine(_engine);
    flow.state = FlowState.playing;
    _engine.start();
  }

  void _spawnLineClearEffect(List<int> rows) {
    add(
      LineClearEffect(rows: rows, board: _board, palette: palette, priority: 2),
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (dt <= 0) return;
    if (flow.isPlaying) {
      _engine.tick(Duration(microseconds: (dt * 1e6).round()));
    }
    _handleHeldKeys(dt);
  }

  void _handleHeldKeys(double dt) {
    if (!flow.isPlaying) return;
    final left = _heldKeys.contains(LogicalKeyboardKey.arrowLeft);
    final right = _heldKeys.contains(LogicalKeyboardKey.arrowRight);
    final down = _heldKeys.contains(LogicalKeyboardKey.arrowDown);

    if (left != right) {
      _horizontalRepeat += dt;
      final threshold = _horizontalRepeat <= _initialDelay
          ? _initialDelay
          : _repeatInterval;
      if (_horizontalRepeat >= threshold) {
        _horizontalRepeat = 0;
        if (left) {
          _engine.moveLeft();
        } else {
          _engine.moveRight();
        }
      }
    } else {
      _horizontalRepeat = _initialDelay;
    }

    if (down) {
      _verticalRepeat += dt;
      if (_verticalRepeat >= _softDropInterval) {
        _verticalRepeat = 0;
        _engine.softDrop();
      }
    } else {
      _verticalRepeat = 0;
    }
  }

  @override
  KeyEventResult onKeyEvent(
    KeyEvent event,
    Set<LogicalKeyboardKey> keysPressed,
  ) {
    _heldKeys
      ..clear()
      ..addAll(keysPressed);
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    final key = event.logicalKey;
    if (flow.isMenu) {
      if (key == LogicalKeyboardKey.arrowUp) {
        menuUp();
      } else if (key == LogicalKeyboardKey.arrowDown) {
        menuDown();
      } else if (key == LogicalKeyboardKey.enter ||
          key == LogicalKeyboardKey.space ||
          key == LogicalKeyboardKey.keyZ) {
        confirm();
      } else {
        return KeyEventResult.ignored;
      }
      return KeyEventResult.handled;
    }

    if (flow.isEndScreen) {
      if (key == LogicalKeyboardKey.enter ||
          key == LogicalKeyboardKey.space ||
          key == LogicalKeyboardKey.keyZ) {
        confirm();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    // In-game controls.
    if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.keyA) {
      return KeyEventResult.handled; // held movement handled in update()
    }
    if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.keyD) {
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp || key == LogicalKeyboardKey.keyX) {
      hardDrop();
    } else if (key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.keyZ) {
      rotate();
    } else if (key == LogicalKeyboardKey.keyQ) {
      rotateCounterClockwise();
    } else if (key == LogicalKeyboardKey.keyC ||
        key == LogicalKeyboardKey.shiftLeft) {
      hold();
    } else if (key == LogicalKeyboardKey.keyH) {
      toggleHint();
    } else if (key == LogicalKeyboardKey.keyP) {
      togglePause();
    } else if (key == LogicalKeyboardKey.escape) {
      quitToMenu();
    } else if (key == LogicalKeyboardKey.keyM) {
      FeedbackService.instance.toggleSound();
      FeedbackService.instance.syncMenuMusic(inMenu: flow.isMenu);
      FeedbackService.instance.press();
    } else if (key == LogicalKeyboardKey.keyR) {
      restart();
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  // ---------------------------------------------------------------------
  // Input API for the on-screen handheld controls
  // ---------------------------------------------------------------------

  void moveLeft() => _engine.moveLeft();

  void moveRight() => _engine.moveRight();

  void moveDown() => _engine.softDrop();

  void hardDrop() => _engine.hardDrop();

  void rotate() => _engine.rotateClockwise();

  void rotateCounterClockwise() => _engine.rotateCounterClockwise();

  void hold() => _engine.hold();

  void togglePause() {
    _engine.togglePause();
    flow.sync(_engine);
  }

  void restart() => _engine.start();

  // Menu navigation (forward D-pad / A / B while flow.isMenu).
  void menuUp() {
    flow.move(-1);
    onStateChanged?.call();
  }

  void menuDown() {
    flow.move(1);
    onStateChanged?.call();
  }

  void confirm() {
    flow.confirm();
    onStateChanged?.call();
  }

  /// Leaves the current game and returns to the mode menu, keeping records.
  void quitToMenu() {
    if (flow.isMenu) return;
    flow.recordBest(_engine);
    _overlay.showHint = false;
    _overlay.hint = null;
    _engine.reset();
    flow.toMenu();
    FeedbackService.instance.syncMenuMusic(inMenu: true);
    onStateChanged?.call();
  }

  void back() => quitToMenu();

  void toggleHint() {
    if (!isLoaded || !_engine.mode.allowHints) return;
    _overlay.showHint = !_overlay.showHint;
    onStateChanged?.call();
  }
}
