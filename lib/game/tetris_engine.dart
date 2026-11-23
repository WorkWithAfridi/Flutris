import 'dart:math' show Random;

import 'game_mode.dart';
import 'level_system.dart';
import 'piece_bag.dart';
import 'tetromino.dart';

/// Discrete game events, useful for sound effects and UI feedback.
enum TetrisEvent {
  start,
  pause,
  resume,
  reset,
  move,
  rotate,
  softDrop,
  hardDrop,
  lock,
  lineClear,
  levelUp,
  combo,
  perfectClear,
  hold,
  victory,
  timeUp,
  gameOver,
}

/// Lifecycle state of a [TetrisEngine].
enum TetrisStatus { ready, playing, paused, gameOver, victory, timeUp }

/// Immutable view of the engine state, convenient for HUD widgets.
class TetrisSnapshot {
  const TetrisSnapshot({
    required this.status,
    required this.score,
    required this.level,
    required this.lines,
    required this.best,
    required this.elapsed,
    required this.nextPiece,
    required this.upcoming,
    required this.activeType,
    required this.activeCells,
    required this.ghostCells,
    required this.lastClearedRows,
    required this.mode,
    required this.holdPiece,
    required this.combo,
    required this.remainingTime,
    required this.goalProgress,
    required this.levelProgress,
    required this.linesToNextLevel,
  });

  final TetrisStatus status;
  final int score;
  final int level;
  final int lines;
  final int best;
  final Duration elapsed;
  final PieceType? nextPiece;
  final List<PieceType> upcoming;
  final PieceType? activeType;
  final List<Cell> activeCells;
  final List<Cell> ghostCells;
  final List<int> lastClearedRows;
  final ModeConfig mode;
  final PieceType? holdPiece;
  final int combo;
  final Duration remainingTime;
  final double goalProgress;
  final double levelProgress;
  final int linesToNextLevel;

  bool get isPlaying => status == TetrisStatus.playing;
  bool get isPaused => status == TetrisStatus.paused;
  bool get isGameOver => status == TetrisStatus.gameOver;
  bool get isVictory => status == TetrisStatus.victory;
  bool get isFinished => isGameOver || isVictory || status == TetrisStatus.timeUp;
}

/// Pure-Dart Tetris game engine: board state, movement, SRS rotation,
/// gravity, lock delay, line clearing, scoring and level progression.
///
/// It deliberately has no Flutter/Flame dependency. A renderer (for example
/// the Flame `FlameGame`) simply reads the getters each frame, and a UI layer
/// forwards button presses to the input methods. Set [onChanged] to be
/// notified whenever state changes (useful for HUD widgets).
class TetrisEngine {
  TetrisEngine({
    Random? random,
    int? startingLevel,
    int? best,
    List<PieceType>? seededPieces,
    int? previewCount,
    ModeConfig? mode,
  })  : mode = mode ?? modeConfigs[GameMode.marathon]!,
        startingLevel = startingLevel ??
            (mode ?? modeConfigs[GameMode.marathon]!).startingLevel,
        previewCount =
            previewCount ?? (mode ?? modeConfigs[GameMode.marathon]!).previewCount,
        levels = LevelSystem(mode ?? modeConfigs[GameMode.marathon]!),
        _bag = PieceBag(random),
        _best = best ?? 0 {
    if (seededPieces != null) _queue.addAll(seededPieces);
    _remainingTime = this.mode.timeLimit ?? Duration.zero;
  }

  static const int columns = 10;
  static const int rows = 20;
  static const int lockDelayMillis = 500;
  static const int maxLockResets = 15;
  static const int linesPerLevel = 10;
  static const int defaultPreviewCount = 5;

  /// Rules of the selected game mode.
  final ModeConfig mode;
  final LevelSystem levels;
  final int startingLevel;
  final int previewCount;
  final PieceBag _bag;

  final List<List<PieceType?>> _board = List.generate(
    rows,
    (_) => List<PieceType?>.filled(columns, null),
  );
  final List<PieceType> _queue = <PieceType>[];

  TetrisStatus _status = TetrisStatus.ready;
  ActivePiece? _active;
  int _score = 0;
  int _lines = 0;
  int _level = 1;
  int _best;
  Duration _elapsed = Duration.zero;
  Duration _gravityAccumulator = Duration.zero;
  Duration? _lockTimer;
  int _lockResets = 0;
  List<int> _lastClearedRows = const <int>[];
  Duration _remainingTime = Duration.zero;
  PieceType? _holdPiece;
  bool _holdUsed = false;
  int _combo = -1;
  bool _backToBack = false;

  /// Called after any state change. Optional: the render loop can instead
  /// poll the getters on every frame.
  void Function()? onChanged;

  /// Called with the row indices that were just cleared, so renderers can
  /// spawn line-clear effects.
  void Function(List<int> rows)? onLinesCleared;

  /// Called for discrete gameplay events (sound effects, haptics, etc.).
  void Function(TetrisEvent event)? onEvent;

  // ---------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------

  TetrisStatus get status => _status;
  bool get isPlaying => _status == TetrisStatus.playing;
  bool get isPaused => _status == TetrisStatus.paused;
  bool get isGameOver => _status == TetrisStatus.gameOver;
  bool get isVictory => _status == TetrisStatus.victory;
  bool get isTimeUp => _status == TetrisStatus.timeUp;

  int get score => _score;
  int get lines => _lines;
  int get level => _level;
  int get best => _best;
  Duration get elapsed => _elapsed;

  /// Remaining time in time-limited modes, otherwise zero.
  Duration get remainingTime => _remainingTime;

  /// Current combo count (0 = no combo, 1 = first consecutive clear).
  int get combo => _combo < 0 ? 0 : _combo;
  bool get isBackToBack => _backToBack;

  /// Held piece, if the mode allows hold and one has been stored.
  PieceType? get holdPiece => _holdPiece;
  bool get canHold =>
      mode.allowHold && _status == TetrisStatus.playing && !_holdUsed;

  int get linesToNextLevel => levels.linesToNext(_lines, startingLevel: startingLevel);
  double get levelProgress => levels.levelProgress(_lines, startingLevel: startingLevel);
  double get goalProgress => levels.goalProgress(_lines);

  /// Piece currently falling, or `null` between spawn/game over.
  ActivePiece? get activePiece => _active;

  /// Head of the preview queue (the piece that will spawn next).
  PieceType? get nextPiece => _queue.isEmpty ? null : _queue.first;

  /// Upcoming pieces after [nextPiece], for a NEXT preview.
  List<PieceType> get upcoming => List<PieceType>.unmodifiable(_queue.skip(1));

  /// Settled cell at `(x, y)`, or `null` for empty/out-of-bounds.
  /// Does not include the currently falling piece.
  PieceType? cellAt(int x, int y) {
    if (x < 0 || x >= columns || y < 0 || y >= rows) return null;
    return _board[y][x];
  }

  /// Absolute coordinates of the falling piece's cells (may include `y < 0`).
  List<Cell> get activeCells => _active?.cells ?? const <Cell>[];

  /// Absolute coordinates where the falling piece would land.
  List<Cell> get ghostCells {
    final piece = _active;
    if (piece == null) return const <Cell>[];
    return ActivePiece(
      piece.type,
      x: piece.x,
      y: _ghostY(piece),
      rotation: piece.rotation,
    ).cells;
  }

  /// Rows cleared by the most recent lock (empty if none).
  List<int> get lastClearedRows => List<int>.unmodifiable(_lastClearedRows);

  /// Immutable view for HUD widgets.
  TetrisSnapshot get snapshot => TetrisSnapshot(
    status: _status,
    score: _score,
    level: _level,
    lines: _lines,
    best: _best,
    elapsed: _elapsed,
    nextPiece: nextPiece,
    upcoming: upcoming,
    activeType: _active?.type,
    activeCells: activeCells,
    ghostCells: ghostCells,
    lastClearedRows: lastClearedRows,
    mode: mode,
    holdPiece: _holdPiece,
    combo: combo,
    remainingTime: _remainingTime,
    goalProgress: goalProgress,
    levelProgress: levelProgress,
    linesToNextLevel: linesToNextLevel,
  );

  // ---------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------

  /// Starts a new game. If paused, resumes instead.
  ///
  /// Pass `clearBoard: false` to start on an existing board, e.g. one loaded
  /// with [loadBoard] for a replay or a restored game.
  void start({bool clearBoard = true}) {
    if (_status == TetrisStatus.playing) return;
    if (_status == TetrisStatus.paused) {
      resume();
      return;
    }
    if (clearBoard) _clearBoard();
    _resetStats();
    _status = TetrisStatus.playing;
    _fillQueue();
    _spawn();
    _emit(TetrisEvent.start);
    _notify();
  }

  /// Resets to the initial ready state (best score is kept).
  void reset() {
    _clearBoard();
    _active = null;
    _queue.clear();
    _resetStats();
    _status = TetrisStatus.ready;
    _emit(TetrisEvent.reset);
    _notify();
  }

  void pause() {
    if (_status != TetrisStatus.playing) return;
    _status = TetrisStatus.paused;
    _emit(TetrisEvent.pause);
    _notify();
  }

  void resume() {
    if (_status != TetrisStatus.paused) return;
    _status = TetrisStatus.playing;
    _emit(TetrisEvent.resume);
    _notify();
  }

  void togglePause() {
    if (_status == TetrisStatus.playing) {
      pause();
    } else if (_status == TetrisStatus.paused) {
      resume();
    }
  }

  // ---------------------------------------------------------------------
  // Player input
  // ---------------------------------------------------------------------

  bool moveLeft() => _translate(-1, 0, resetLock: true);

  bool moveRight() => _translate(1, 0, resetLock: true);

  /// Moves the piece down one row and awards 1 soft-drop point.
  bool softDrop() {
    final moved = _translate(0, 1, resetLock: false);
    if (moved) {
      _emit(TetrisEvent.softDrop);
      _addScore(1);
      _notify();
    }
    return moved;
  }

  /// Drops the piece to its ghost position, awards 2 points per cell and
  /// locks it immediately.
  bool hardDrop() {
    if (_status != TetrisStatus.playing || _active == null) return false;
    final targetY = _ghostY(_active!);
    _addScore((targetY - _active!.y) * 2);
    _emit(TetrisEvent.hardDrop);
    _active = ActivePiece(
      _active!.type,
      x: _active!.x,
      y: targetY,
      rotation: _active!.rotation,
    );
    _lockPiece();
    _notify();
    return true;
  }

  bool rotateClockwise() => _rotate(1);

  bool rotateCounterClockwise() => _rotate(-1);

  /// Swaps the falling piece with the held piece. Only once per drop, and
  /// only in modes that enable hold.
  bool hold() {
    if (!canHold) return false;
    final current = _active!.type;
    final previous = _holdPiece;
    if (previous == null) {
      _holdPiece = current;
      _spawnFromQueue();
    } else {
      _holdPiece = current;
      if (!_tryActivate(ActivePiece(previous))) return true;
    }
    _holdUsed = true;
    _emit(TetrisEvent.hold);
    _notify();
    return true;
  }

  // ---------------------------------------------------------------------
  // Time
  // ---------------------------------------------------------------------

  /// Advances the game clock. Call from a render/update loop with the frame
  /// delta. Gravity and the lock delay are driven by this method.
  void tick(Duration delta) {
    if (_status != TetrisStatus.playing || delta.inMicroseconds <= 0) return;
    _elapsed += delta;

    if (mode.timeLimit != null) {
      final left = _remainingTime - delta;
      _remainingTime = left > Duration.zero ? left : Duration.zero;
      if (_remainingTime == Duration.zero) {
        _status = TetrisStatus.timeUp;
        _emit(TetrisEvent.timeUp);
        _notify();
        return;
      }
    }

    if (_active != null) {
      final interval = levels.gravity(_level);
      if (!mode.instantGravity && interval > Duration.zero) {
        _gravityAccumulator += delta;
        while (_gravityAccumulator >= interval) {
          _gravityAccumulator -= interval;
          // A failed downward step starts the lock timer; stop looping so we
          // don't spin while the piece is resting on the stack.
          if (!_translate(0, 1, resetLock: false)) break;
        }
      }

      final lockTimer = _lockTimer;
      if (lockTimer != null) {
        final updated = lockTimer + delta;
        if (updated >= levels.lockDelay(_level)) {
          _lockPiece();
        } else {
          _lockTimer = updated;
        }
      }
    }
  }

  // ---------------------------------------------------------------------
  // Helpers for tests / replays / saved games
  // ---------------------------------------------------------------------

  /// Replaces the settled board contents. Does not alter stats or the active
  /// piece. Intended for tests, replays and saved-game restore.
  void loadBoard(List<List<PieceType?>> cells) {
    if (cells.length != rows || cells.any((row) => row.length != columns)) {
      throw ArgumentError.value(
        cells,
        'cells',
        'Expected a $rows x $columns grid.',
      );
    }
    for (var y = 0; y < rows; y++) {
      for (var x = 0; x < columns; x++) {
        _board[y][x] = cells[y][x];
      }
    }
    _notify();
  }

  /// Replaces the falling piece. Intended for tests, replays and scripted
  /// demos (for example setting up a wall-kick scenario).
  void placeActivePiece(ActivePiece piece) {
    if (_status != TetrisStatus.playing) return;
    _active = piece;
    _lockTimer = null;
    _lockResets = 0;
    _notify();
  }

  // ---------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------

  void _notify() => onChanged?.call();

  void _emit(TetrisEvent event) => onEvent?.call(event);

  void _addScore(int points) {
    _score += points;
    if (_score > _best) _best = _score;
  }

  void _resetStats() {
    _score = 0;
    _lines = 0;
    _level = startingLevel;
    _elapsed = Duration.zero;
    _remainingTime = mode.timeLimit ?? Duration.zero;
    _gravityAccumulator = Duration.zero;
    _lockTimer = null;
    _lockResets = 0;
    _holdPiece = null;
    _holdUsed = false;
    _combo = -1;
    _backToBack = false;
    _lastClearedRows = const <int>[];
  }

  void _clearBoard() {
    for (final row in _board) {
      for (var x = 0; x < columns; x++) {
        row[x] = null;
      }
    }
  }

  void _fillQueue() {
    while (_queue.length < previewCount) {
      _queue.add(_bag.next());
    }
  }

  void _spawn() {
    _fillQueue();
    final type = _queue.removeAt(0);
    _fillQueue();
    _tryActivate(ActivePiece(type));
  }

  void _spawnFromQueue() => _spawn();

  /// Activates [piece], handling top-out and instant-gravity modes.
  /// Returns false when the game ended.
  bool _tryActivate(ActivePiece piece) {
    if (_collides(piece) && !mode.topOutEndsGame) {
      // Zen mode: topping out clears the board and gives the piece a fresh
      // well instead of ending the game.
      _clearBoard();
    }
    if (_collides(piece)) {
      _active = null;
      _status = TetrisStatus.gameOver;
      _emit(TetrisEvent.gameOver);
      _notify();
      return false;
    }

    var landing = piece;
    if (mode.instantGravity) {
      landing = ActivePiece(
        piece.type,
        x: piece.x,
        y: _ghostY(piece),
        rotation: piece.rotation,
      );
    }
    _active = landing;
    _holdUsed = false;
    _gravityAccumulator = Duration.zero;
    _lockTimer = null;
    _lockResets = 0;
    _startLockTimerIfGrounded();
    _notify();
    return true;
  }

  bool _collides(ActivePiece piece) {
    for (final cell in piece.cells) {
      if (cell.x < 0 || cell.x >= columns || cell.y >= rows) return true;
      if (cell.y >= 0 && _board[cell.y][cell.x] != null) return true;
    }
    return false;
  }

  int _ghostY(ActivePiece piece) {
    var y = piece.y;
    while (true) {
      final next = ActivePiece(
        piece.type,
        x: piece.x,
        y: y + 1,
        rotation: piece.rotation,
      );
      if (_collides(next)) return y;
      y++;
    }
  }

  bool _isGrounded() {
    final piece = _active;
    if (piece == null) return false;
    return _collides(
      ActivePiece(
        piece.type,
        x: piece.x,
        y: piece.y + 1,
        rotation: piece.rotation,
      ),
    );
  }

  void _startLockTimerIfGrounded() {
    if (_isGrounded()) _lockTimer ??= Duration.zero;
  }

  bool _translate(int dx, int dy, {required bool resetLock}) {
    if (_status != TetrisStatus.playing || _active == null) return false;
    final candidate = _active!.copy()
      ..x += dx
      ..y += dy;
    if (_collides(candidate)) {
      if (dy > 0) _startLockTimerIfGrounded();
      return false;
    }
    _active = candidate;
    if (dx != 0) _emit(TetrisEvent.move);
    if (resetLock && _lockTimer != null && _lockResets < maxLockResets) {
      _lockTimer = Duration.zero;
      _lockResets++;
    }
    _startLockTimerIfGrounded();
    _notify();
    return true;
  }

  bool _rotate(int direction) {
    if (_status != TetrisStatus.playing || _active == null) return false;
    final piece = _active!;
    final to =
        (piece.rotation + direction + Tetromino.rotationCount) %
        Tetromino.rotationCount;
    for (final kick in Tetromino.kicks(piece.type, piece.rotation, to)) {
      final candidate = ActivePiece(
        piece.type,
        x: piece.x + kick.x,
        y: piece.y + kick.y,
        rotation: to,
      );
      if (!_collides(candidate)) {
        _active = candidate;
        _emit(TetrisEvent.rotate);
        if (_lockTimer != null && _lockResets < maxLockResets) {
          _lockTimer = Duration.zero;
          _lockResets++;
        }
        _startLockTimerIfGrounded();
        _notify();
        return true;
      }
    }
    return false;
  }

  void _lockPiece() {
    final piece = _active;
    if (piece == null) return;

    var lockedAboveBoard = false;
    for (final cell in piece.cells) {
      if (cell.y < 0) {
        lockedAboveBoard = true;
      } else if (cell.y < rows && cell.x >= 0 && cell.x < columns) {
        _board[cell.y][cell.x] = piece.type;
      }
    }

    _active = null;
    _lockTimer = null;
    _lockResets = 0;
    _gravityAccumulator = Duration.zero;
    _emit(TetrisEvent.lock);

    if (lockedAboveBoard) {
      _status = TetrisStatus.gameOver;
      _emit(TetrisEvent.gameOver);
      _notify();
      return;
    }

    final fullRows = <int>[];
    for (var y = 0; y < rows; y++) {
      if (_board[y].every((cell) => cell != null)) fullRows.add(y);
    }
    _lastClearedRows = List<int>.unmodifiable(fullRows);
    _removeRows(fullRows);

    if (fullRows.isNotEmpty) {
      final cleared = fullRows.length;
      var points = switch (cleared) {
        1 => 100,
        2 => 300,
        3 => 500,
        _ => 800,
      };

      final perfectClear = _board.every((row) => row.every((cell) => cell == null));
      final b2bTrigger = cleared == 4 || perfectClear;
      if (mode.comboScoring) {
        _combo++;
        if (_combo > 0) {
          points += 50 * _combo;
          _emit(TetrisEvent.combo);
        }
        if (_backToBack && b2bTrigger) {
          points = (points * 1.5).round();
        }
        _backToBack = b2bTrigger;
      }
      if (perfectClear) {
        points += 1000;
        _emit(TetrisEvent.perfectClear);
      }
      _addScore((points * _level * mode.scoreMultiplier).round());

      _lines += cleared;
      final nextLevel = levels.levelFor(_lines, startingLevel: startingLevel);
      if (nextLevel > _level) {
        _level = nextLevel;
        _emit(TetrisEvent.levelUp);
      }
      _emit(TetrisEvent.lineClear);
      onLinesCleared?.call(List<int>.unmodifiable(fullRows));
      _checkGoal();
    } else {
      _combo = -1;
      _backToBack = false;
    }
    if (_status == TetrisStatus.playing) _spawn();
  }

  void _checkGoal() {
    if (mode.goalType == GoalType.lines &&
        mode.goalValue != null &&
        _lines >= mode.goalValue!) {
      _status = TetrisStatus.victory;
      _emit(TetrisEvent.victory);
      _notify();
    }
  }

  /// Removes [fullRows] and shifts all rows above them down.
  void _removeRows(List<int> fullRows) {
    if (fullRows.isEmpty) return;
    final remaining = <List<PieceType?>>[
      for (var y = 0; y < rows; y++)
        if (!fullRows.contains(y)) List<PieceType?>.from(_board[y]),
    ];
    final empty = List<PieceType?>.filled(columns, null);
    for (var y = 0; y < rows; y++) {
      final sourceIndex = y - (rows - remaining.length);
      _board[y] = sourceIndex >= 0
          ? List<PieceType?>.from(remaining[sourceIndex])
          : List<PieceType?>.from(empty);
    }
  }
}
