import 'tetris.dart';

/// Measured properties of a candidate landing board.
class BoardFeatures {
  const BoardFeatures({
    required this.landingHeight,
    required this.lines,
    required this.holes,
    required this.bumpiness,
    required this.aggregateHeight,
    required this.rowTransitions,
    required this.columnTransitions,
    required this.wells,
  });

  final double landingHeight;
  final int lines;
  final int holes;
  final int bumpiness;
  final int aggregateHeight;
  final int rowTransitions;
  final int columnTransitions;
  final int wells;
}

/// A concrete suggested landing for the current piece.
class Placement {
  const Placement({
    required this.type,
    required this.rotation,
    required this.x,
    required this.y,
    required this.score,
    required this.features,
  });

  final PieceType type;
  final int rotation;
  final int x;
  final int y;
  final double score;
  final BoardFeatures features;

  int get linesCleared => features.lines;

  /// Short human-readable reason for the suggestion.
  String get rationale {
    final parts = <String>[];
    if (features.lines >= 4) {
      parts.add('Tetris (+${features.lines} lines)');
    } else if (features.lines > 0) {
      parts.add('clears ${features.lines} ${features.lines == 1 ? 'line' : 'lines'}');
    } else {
      parts.add('no immediate clear');
    }
    if (features.holes == 0) {
      parts.add('no holes');
    } else {
      parts.add('${features.holes} ${features.holes == 1 ? 'hole' : 'holes'}');
    }
    parts.add(features.bumpiness <= 3 ? 'flat surface' : 'rough surface');
    return parts.join(' · ');
  }

  @override
  String toString() =>
      'Placement(${type.name} r$rotation @ $x,$y; score ${score.toStringAsFixed(2)})';
}

/// Weights for the linear evaluator. Defaults follow the well-known
/// El-Tetris / Dellacherie feature set (negative weights are penalties).
class AdvisorWeights {
  const AdvisorWeights({
    this.landingHeight = -4.5,
    this.lines = 3.42,
    this.rowTransitions = -3.22,
    this.columnTransitions = -9.35,
    this.holes = -7.9,
    this.wells = -3.39,
    this.bumpiness = -0.18,
  });

  final double landingHeight;
  final double lines;
  final double rowTransitions;
  final double columnTransitions;
  final double holes;
  final double wells;
  final double bumpiness;
}

const AdvisorWeights elTetrisWeights = AdvisorWeights();

/// Exhaustively evaluates every legal rotation × column landing of the
/// current piece and ranks the results.
///
/// This is deliberately a one-piece planner (like El-Tetris): it simulates
/// straight drops and scores the resulting board before lines are removed.
/// It powers the in-game hint display for planning-focused modes.
class PlacementAdvisor {
  const PlacementAdvisor({this.weights = elTetrisWeights});

  final AdvisorWeights weights;

  /// Best landing for [engine]'s current piece, or `null` if idle.
  Placement? suggest(TetrisEngine engine) {
    final ranked = rank(engine, limit: 1);
    return ranked.isEmpty ? null : ranked.first;
  }

  /// Up to [limit] landings, best first.
  List<Placement> rank(TetrisEngine engine, {int limit = 5}) {
    final active = engine.activePiece;
    if (active == null || !engine.isPlaying) return const <Placement>[];

    final board = List.generate(
      TetrisEngine.rows,
      (y) => List<bool>.generate(
        TetrisEngine.columns,
        (x) => engine.cellAt(x, y) != null,
      ),
    );

    final results = <Placement>[];
    final rotations = active.type == PieceType.o ? 1 : 4;
    for (var rotation = 0; rotation < rotations; rotation++) {
      final local = Tetromino.cells(active.type, rotation);
      final minX = local.map((c) => c.x).reduce((a, b) => a < b ? a : b);
      final maxX = local.map((c) => c.x).reduce((a, b) => a > b ? a : b);
      final maxY = local.map((c) => c.y).reduce((a, b) => a > b ? a : b);

      for (var x = -minX; x <= TetrisEngine.columns - 1 - maxX; x++) {
        var y = -maxY;
        if (!_fits(board, local, x, y)) continue;
        while (_fits(board, local, x, y + 1)) {
          y++;
        }

        // Build the post-landing board (before line removal).
        final candidate = board.map((row) => List<bool>.from(row)).toList();
        for (final cell in local) {
          candidate[y + cell.y][x + cell.x] = true;
        }

        final features = _features(candidate, local, x, y);
        final score = weights.landingHeight * features.landingHeight +
            weights.lines * features.lines +
            weights.rowTransitions * features.rowTransitions +
            weights.columnTransitions * features.columnTransitions +
            weights.holes * features.holes +
            weights.wells * features.wells +
            weights.bumpiness * features.bumpiness;

        results.add(
          Placement(
            type: active.type,
            rotation: rotation,
            x: x,
            y: y,
            score: score,
            features: features,
          ),
        );
      }
    }

    results.sort((a, b) => b.score.compareTo(a.score));
    return limit <= 0
        ? results
        : results.sublist(0, limit.clamp(0, results.length));
  }

  bool _fits(
    List<List<bool>> board,
    List<Cell> cells,
    int offsetX,
    int offsetY,
  ) {
    for (final cell in cells) {
      final x = offsetX + cell.x;
      final y = offsetY + cell.y;
      if (x < 0 || x >= TetrisEngine.columns) return false;
      if (y >= TetrisEngine.rows) return false;
      if (y >= 0 && board[y][x]) return false;
    }
    return true;
  }

  BoardFeatures _features(
    List<List<bool>> board,
    List<Cell> piece,
    int offsetX,
    int offsetY,
  ) {
    final heights = List<int>.filled(TetrisEngine.columns, 0);
    var holes = 0;
    for (var x = 0; x < TetrisEngine.columns; x++) {
      var top = TetrisEngine.rows;
      for (var y = 0; y < TetrisEngine.rows; y++) {
        if (board[y][x]) {
          if (top == TetrisEngine.rows) top = y;
        } else if (top != TetrisEngine.rows) {
          holes++;
        }
      }
      heights[x] = TetrisEngine.rows - top;
    }

    var aggregateHeight = 0;
    var bumpiness = 0;
    for (var x = 0; x < TetrisEngine.columns; x++) {
      aggregateHeight += heights[x];
      if (x > 0) bumpiness += (heights[x] - heights[x - 1]).abs();
    }

    var lines = 0;
    for (var y = 0; y < TetrisEngine.rows; y++) {
      if (board[y].every((cell) => cell)) lines++;
    }

    var rowTransitions = 0;
    for (var y = 0; y < TetrisEngine.rows; y++) {
      var previous = true; // left wall counts as filled
      for (var x = 0; x < TetrisEngine.columns; x++) {
        if (board[y][x] != previous) rowTransitions++;
        previous = board[y][x];
      }
      if (!previous) rowTransitions++; // right wall
    }

    var columnTransitions = 0;
    for (var x = 0; x < TetrisEngine.columns; x++) {
      var previous = false; // top is open
      for (var y = 0; y < TetrisEngine.rows; y++) {
        if (board[y][x] != previous) columnTransitions++;
        previous = board[y][x];
      }
      if (!previous) columnTransitions++; // bottom wall is filled
    }

    var wells = 0;
    for (var x = 0; x < TetrisEngine.columns; x++) {
      var depth = 0;
      for (var y = 0; y < TetrisEngine.rows; y++) {
        if (board[y][x]) {
          depth = 0;
          continue;
        }
        final leftFilled = x == 0 || board[y][x - 1];
        final rightFilled =
            x == TetrisEngine.columns - 1 || board[y][x + 1];
        if (leftFilled && rightFilled) {
          depth++;
          wells += depth;
        } else {
          depth = 0;
        }
      }
    }

    var minPieceY = TetrisEngine.rows;
    for (final cell in piece) {
      final y = offsetY + cell.y;
      if (y < minPieceY) minPieceY = y;
    }
    final landingHeight = (TetrisEngine.rows - minPieceY).toDouble();

    return BoardFeatures(
      landingHeight: landingHeight,
      lines: lines,
      holes: holes,
      bumpiness: bumpiness,
      aggregateHeight: aggregateHeight,
      rowTransitions: rowTransitions,
      columnTransitions: columnTransitions,
      wells: wells,
    );
  }
}
