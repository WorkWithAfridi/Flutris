import 'dart:ui' show Canvas, Color, Offset, Paint, Rect;

import 'package:flame/components.dart';
import 'package:flutter/painting.dart' show FontWeight, TextStyle;

import '../tetris.dart';

/// Flame-rendered start menu, HUD, hint panel and end screens.
///
/// It lives inside the game canvas (the handheld LCD slot), so the Flutter UI
/// does not need to change: the existing buttons forward input to the game and
/// this component reflects the resulting state.
class FlowOverlayComponent extends PositionComponent {
  FlowOverlayComponent({
    required this.flow,
    required this.palette,
    required this.engine,
    this.renderHud = true,
    this.advisor = const PlacementAdvisor(),
    super.priority,
  });

  final GameFlow flow;
  final BoardPalette palette;

  /// Mutable: replaced when a different mode is started.
  TetrisEngine engine;
  final bool renderHud;
  final PlacementAdvisor advisor;

  /// Whether the planning hint panel is visible.
  bool showHint = false;
  Placement? hint;
  double _hintRefresh = 0;

  late final TextPaint _title;
  late final TextPaint _body;
  late final TextPaint _small;
  late final TextPaint _accent;
  late final TextPaint _inverse;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    const font = 'monospace';
    _title = TextPaint(
      style: TextStyle(
        fontFamily: font,
        fontSize: 15,
        fontWeight: FontWeight.bold,
        color: Color(0xFF354839),
        letterSpacing: 1.5,
      ),
    );
    _body = TextPaint(
      style: TextStyle(
        fontFamily: font,
        fontSize: 9,
        fontWeight: FontWeight.w600,
        color: Color(0xFF354839),
      ),
    );
    _small = TextPaint(
      style: TextStyle(
        fontFamily: font,
        fontSize: 7,
        color: Color(0xFF354839),
      ),
    );
    _accent = TextPaint(
      style: TextStyle(
        fontFamily: font,
        fontSize: 10,
        fontWeight: FontWeight.bold,
        color: Color(0xFF354839),
      ),
    );
    _inverse = TextPaint(
      style: TextStyle(
        fontFamily: font,
        fontSize: 9,
        fontWeight: FontWeight.bold,
        color: Color(0xFFB5C49D),
      ),
    );
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    this.size = size.clone();
    position = Vector2.zero();
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!showHint || !flow.isPlaying) return;
    _hintRefresh += dt;
    if (_hintRefresh < 0.25) return;
    _hintRefresh = 0;
    hint = advisor.suggest(engine);
  }

  @override
  void render(Canvas canvas) {
    if (flow.isMenu) {
      _renderMenu(canvas);
      return;
    }

    if (renderHud) _renderHud(canvas);
    if (showHint) _renderHint(canvas);
    if (flow.isPaused || flow.isEndScreen) _renderEndOverlay(canvas);
  }

  void _text(Canvas canvas, String text, double x, double y, TextPaint paint) {
    paint.toTextPainter(text).paint(canvas, Offset(x, y));
  }

  void _renderMenu(Canvas canvas) {
    final w = size.x;
    canvas.drawRect(Offset.zero & size.toSize(), Paint()..color = palette.field);

    _text(canvas, 'FLUTRIS', 10, 10, _title);
    _text(canvas, 'SELECT MODE', 10, 30, _small);

    var y = 48.0;
    for (var i = 0; i < flow.modes.length; i++) {
      final mode = flow.modes[i];
      final selected = i == flow.selected;
      if (selected) {
        canvas.drawRect(
          Rect.fromLTWH(4, y - 2, w - 8, 24),
          Paint()..color = palette.ink,
        );
      }
      final best = flow.bestScores[mode.mode];
      final name = selected ? '>${mode.name}' : ' ${mode.name}';
      _text(
        canvas,
        name,
        9,
        y,
        selected ? _inverse : _accent,
      );
      _text(
        canvas,
        '${mode.goalLabel.padRight(9)} BEST ${best ?? 0}',
        22,
        y + 14,
        selected ? _inverse : _small,
      );
      y += 26;
    }

    final mode = flow.selectedMode;
    _text(canvas, mode.tagline, 8, y + 4, _accent);
    _wrapText(canvas, mode.description, 8, y + 18, w - 16, 9, _small);
    _text(canvas, 'UP/DOWN SELECT  ENTER CONFIRM', 8, size.y - 14, _small);
  }

  void _renderHud(Canvas canvas) {
    final w = size.x;
    final bar = Paint()..color = palette.ink.withValues(alpha: 0.12);
    canvas.drawRect(Rect.fromLTWH(0, 0, w, 22), bar);

    _text(canvas, engine.mode.name, 5, 3, _accent);
    _text(canvas, 'LV ${engine.level}', 5, 13, _small);
    _text(canvas, '${engine.lines}/${engine.mode.goalValue ?? '--'}', w / 2 - 12, 13, _small);

    final time = engine.mode.timeLimit == null
        ? _formatDuration(engine.elapsed)
        : _formatDuration(engine.remainingTime);
    _text(canvas, time, w - 40, 3, _small);
    if (engine.combo > 1) _text(canvas, 'x${engine.combo} COMBO', w - 55, 13, _small);
  }

  void _renderHint(Canvas canvas) {
    final w = size.x;
    final h = 58.0;
    final top = size.y - h;
    canvas.drawRect(
      Rect.fromLTWH(0, top, w, h),
      Paint()..color = palette.field.withValues(alpha: 0.94),
    );
    canvas.drawRect(
      Rect.fromLTWH(0, top, w, 1),
      Paint()..color = palette.ink.withValues(alpha: 0.5),
    );
    final placement = hint ?? advisor.suggest(engine);
    if (placement == null) {
      _text(canvas, 'HINT: ...', 6, top + 6, _accent);
      return;
    }
    _text(
      canvas,
      'HINT  R${placement.rotation} -> COL ${placement.x + 1}',
      6,
      top + 6,
      _accent,
    );
    _wrapText(canvas, placement.rationale, 6, top + 20, w - 12, 9, _small);
  }

  void _renderEndOverlay(Canvas canvas) {
    final h = size.y;
    canvas.drawRect(
      Offset.zero & size.toSize(),
      Paint()..color = const Color(0xCC17211C),
    );
    final title = switch (flow.state) {
      FlowState.victory => 'GOAL CLEAR',
      FlowState.timeUp => 'TIME UP',
      FlowState.gameOver => 'TOP OUT',
      FlowState.paused => 'PAUSED',
      FlowState.menu => '',
      FlowState.playing => '',
    };
    _text(canvas, title, 10, h / 2 - 60, _inverse);
    _text(canvas, 'SCORE ${engine.score}', 10, h / 2 - 34, _body);
    _text(canvas, 'LINES ${engine.lines}  LEVEL ${engine.level}', 10, h / 2 - 18, _body);
    _text(canvas, 'TIME ${_formatDuration(engine.elapsed)}', 10, h / 2 - 2, _body);
    _text(canvas, 'A / ENTER = MENU', 10, h / 2 + 30, _body);
  }

  void _wrapText(
    Canvas canvas,
    String text,
    double x,
    double y,
    double maxWidth,
    double lineHeight,
    TextPaint paint,
  ) {
    final words = text.split(' ');
    final buffer = StringBuffer();
    var lineY = y;
    for (final word in words) {
      final candidate = buffer.isEmpty ? word : '$buffer $word';
      if (paint.toTextPainter(candidate).width > maxWidth && buffer.isNotEmpty) {
        _text(canvas, buffer.toString(), x, lineY, paint);
        buffer
          ..clear()
          ..write(word);
        lineY += lineHeight;
      } else {
        if (buffer.isNotEmpty) buffer.write(' ');
        buffer.write(word);
      }
    }
    if (buffer.isNotEmpty) _text(canvas, buffer.toString(), x, lineY, paint);
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
