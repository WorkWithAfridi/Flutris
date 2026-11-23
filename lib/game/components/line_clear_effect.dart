import 'dart:ui' show Paint;

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/animation.dart' show Curves;

import '../palette.dart';
import 'board_component.dart';

/// Flame effect overlay: flashes cleared rows and fades them out using
/// Flame's effect/controller system, then removes itself from the tree.
class LineClearEffect extends PositionComponent {
  LineClearEffect({
    required this.rows,
    required this.board,
    this.palette = lcdPalette,
    super.priority,
  }) : super(
          position: board.position.clone(),
          size: board.size.clone(),
        );

  final List<int> rows;
  final BoardComponent board;
  final BoardPalette palette;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    final cell = board.cellSize;

    for (final row in rows) {
      final band = RectangleComponent(
        position: Vector2(size.x / 2, (row + 0.5) * cell),
        size: Vector2(size.x, cell),
        anchor: Anchor.center,
        paint: Paint()..color = palette.flash,
      );
      await add(band);

      band.add(
        OpacityEffect.to(
          0,
          EffectController(duration: 0.3, curve: Curves.easeOut),
        ),
      );
      band.add(
        ScaleEffect.to(
          Vector2(1, 0.05),
          EffectController(duration: 0.3, curve: Curves.easeOut),
        ),
      );
      band.add(RemoveEffect(delay: 0.32));
    }
  }
}
