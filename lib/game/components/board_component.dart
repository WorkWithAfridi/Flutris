import 'dart:math' as math;
import 'dart:ui' show Canvas, Color, Offset, Paint, PaintingStyle, Rect;

import 'package:flame/components.dart';

import '../tetris.dart';

/// Flame component that draws the settled stack, ghost piece and active piece.
///
/// It keeps a centered 10:20 playfield inside whatever canvas the game gets,
/// so it works with both the handheld LCD slot and a full-screen layout.
class BoardComponent extends PositionComponent {
  BoardComponent({
    required this.engine,
    this.palette = lcdPalette,
    super.priority,
  });

  /// Mutable so the game can swap engines when a mode is selected.
  TetrisEngine engine;
  final BoardPalette palette;

  double get cellSize => size.x / TetrisEngine.columns;

  /// Screen-space rect of a board cell (may be above/below the playfield).
  Rect cellRect(int x, int y) =>
      Rect.fromLTWH(x * cellSize, y * cellSize, cellSize, cellSize);

  /// Screen-space rect of a whole row, used by line-clear effects.
  Rect rowRect(int row) => Rect.fromLTWH(0, row * cellSize, size.x, cellSize);

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    final canvas = size.clone();
    final cell = math.min(
      canvas.x / TetrisEngine.columns,
      canvas.y / TetrisEngine.rows,
    );
    final width = cell * TetrisEngine.columns;
    final height = cell * TetrisEngine.rows;
    this.size = Vector2(width, height);
    position = Vector2((canvas.x - width) / 2, (canvas.y - height) / 2);
  }

  @override
  void render(Canvas canvas) {
    canvas.drawRect(
      Offset.zero & size.toSize(),
      Paint()..color = palette.field,
    );

    final grid = Paint()
      ..color = palette.grid
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;
    for (var y = 0; y < TetrisEngine.rows; y++) {
      for (var x = 0; x < TetrisEngine.columns; x++) {
        canvas.drawRect(cellRect(x, y).deflate(1), grid);
      }
    }

    for (var y = 0; y < TetrisEngine.rows; y++) {
      for (var x = 0; x < TetrisEngine.columns; x++) {
        final type = engine.cellAt(x, y);
        if (type != null) _drawCell(canvas, cellRect(x, y), type);
      }
    }

    final ghost = Paint()
      ..color = palette.ghost
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (final cell in engine.ghostCells) {
      if (cell.y < 0 || cell.y >= TetrisEngine.rows) continue;
      canvas.drawRect(cellRect(cell.x, cell.y).deflate(1), ghost);
    }

    final active = engine.activePiece;
    if (active != null) {
      for (final cell in active.cells) {
        if (cell.y < 0 || cell.y >= TetrisEngine.rows) continue;
        _drawCell(canvas, cellRect(cell.x, cell.y), active.type);
      }
    }

    canvas.drawRect(
      Rect.fromLTWH(1, 1, size.x - 2, size.y - 2),
      Paint()
        ..color = palette.ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  void _drawCell(Canvas canvas, Rect rect, PieceType type) {
    final outer = rect.deflate(1);
    final base = palette.coloredPieces
        ? Color.lerp(palette.ink, Color(Tetromino.color(type)), 0.7)!
        : palette.ink;

    if (palette.coloredPieces) {
      canvas.drawRect(outer, Paint()..color = base);
      canvas.drawRect(
        outer.deflate(2),
        Paint()..color = palette.highlight.withValues(alpha: 0.35),
      );
    } else {
      // Three-layer LCD block: dark border, light bevel, dark core.
      canvas.drawRect(outer, Paint()..color = base);
      canvas.drawRect(outer.deflate(2), Paint()..color = palette.highlight);
      canvas.drawRect(outer.deflate(3), Paint()..color = base);
    }
  }
}
