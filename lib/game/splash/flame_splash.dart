import 'dart:math' as math;
import 'dart:ui'
    show Canvas, Color, Offset, PaintingStyle, Paint, Radius, Rect, RRect;

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/game.dart';
import 'package:flutter/animation.dart' show Curves;

import '../../feedback/feedback_service.dart';
import 'package:flutter/painting.dart'
    show Alignment, FontStyle, FontWeight, LinearGradient, TextStyle;

/// Virtual design size of the splash device. Scaled and centered on canvas.
const double _virtualWidth = 300;
const double _virtualHeight = 340;

/// Palette mirrored from `lib/ui/handheld_screen.dart` so the splash and the
/// handheld shell read as the same object.
abstract final class _ShellColors {
  static const base = Color(0xFF382D46);
  static const bezel = Color(0xFF302D3E);
  static const bezelBorder = Color(0xFF493E53);
  static const shadow = Color(0x40816A9B);
  static const ink = Color(0xFF302449);
  static const muted = Color(0xFFADA6BC);
  static const lcd = Color(0xFFB5C49D);
  static const lcdEdge = Color(0xFF171E20);
  static const lcdInk = Color(0xFF354839);
  static const led = Color(0xFF9ACD7E);
}

/// Splash that presents the handheld device booting up, using the same visual
/// language as the in-game shell. Motion uses Flame effects/controllers.
class FlameSplash extends FlameGame {
  FlameSplash({
    this.duration = const Duration(milliseconds: 2600),
    this.onFinished,
  });

  final Duration duration;
  final void Function()? onFinished;

  _ShellBackdrop? _backdrop;
  _SplashScene? _scene;
  bool _completed = false;

  @override
  Color backgroundColor() => _ShellColors.base;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    // Audio is ready by the time the splash hands over to the game.
    FeedbackService.instance.preload();
    _backdrop = _ShellBackdrop();
    _scene = _SplashScene(
      duration: duration,
      onFinished: _complete,
      initialSize: size.clone(),
    );
    await add(_backdrop!);
    await add(_scene!);
    await add(
      TimerComponent(
        period: duration.inMilliseconds / 1000,
        onTick: _complete,
        removeOnFinish: true,
      ),
    );
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    final canvas = size.clone();
    _backdrop?.size = canvas;
    _scene?.layoutScene(canvas);
  }

  void _complete() {
    if (_completed) return;
    _completed = true;
    onFinished?.call();
  }
}

/// The shell gradient and glass sheen, covering the whole viewport.
class _ShellBackdrop extends PositionComponent {
  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    // Components receive their first resize on mount, so this also covers the
    // case where the game resized before onLoad created this component.
    this.size = size.clone();
  }

  @override
  void render(Canvas canvas) {
    final rect = Offset.zero & size.toSize();
    canvas.drawRect(rect, Paint()..color = _ShellColors.base);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xBFDCCAF0),
            Color(0xA67F659E),
            Color(0xB27A6196),
          ],
          stops: const [0, .48, 1],
        ).createShader(rect),
    );
    // Subtle diagonal glass highlight like the shell's sheen painter.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment(0.4, 1),
          colors: [Color(0x18FFFFFF), Color(0x00FFFFFF)],
          stops: const [0, 0.55],
        ).createShader(rect),
    );
  }
}

/// The scaled/centered device illustration and its boot animation.
class _SplashScene extends PositionComponent {
  _SplashScene({
    required this.duration,
    required this.onFinished,
    required Vector2 initialSize,
  }) : _initialSize = initialSize.clone();

  final Duration duration;
  final void Function() onFinished;
  final Vector2 _initialSize;

  void layoutScene(Vector2 canvas) {
    final scale = math.min(
      canvas.x / _virtualWidth,
      canvas.y / _virtualHeight,
    );
    this.scale = Vector2.all(scale);
    position = Vector2(
      (canvas.x - _virtualWidth * scale) / 2,
      (canvas.y - _virtualHeight * scale) / 2,
    );
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    size = Vector2(_virtualWidth, _virtualHeight);
    layoutScene(_initialSize);

    await add(_Wordmark());
    await add(_DeviceBezel());
    await _addStatusRow();
    await _addLcd();
    await _addProgressAndBootText();
  }

  Future<void> _addStatusRow() async {
    final led = CircleComponent(
      position: Vector2(42, 74),
      radius: 3.5,
      anchor: Anchor.center,
      paint: Paint()..color = _ShellColors.led,
    );
    await add(led);
    led.add(
      ScaleEffect.by(
        Vector2.all(1.25),
        EffectController(
          duration: 0.5,
          infinite: true,
          alternate: true,
          curve: Curves.easeInOut,
        ),
      ),
    );
    await add(_label('BOOTING', 52, 69, size: 6.5, spacing: 1.2));
    await add(_label('DOT MATRIX DISPLAY', 250, 69, size: 5.5, spacing: .8, anchoredEnd: true));
  }

  Future<void> _addLcd() async {
    // Hard dark edge, matching the 3px LCD border in the shell.
    await add(
      RectangleComponent(
        position: Vector2(40, 86),
        size: Vector2(220, 128),
        paint: Paint()..color = _ShellColors.lcdEdge,
      ),
    );
    await add(
      RectangleComponent(
        position: Vector2(43, 89),
        size: Vector2(214, 122),
        paint: Paint()..color = _ShellColors.lcd,
      ),
    );

    for (var row = 0; row < 3; row++) {
      for (var col = 0; col < 14; col++) {
        final dot = RectangleComponent(
          position: Vector2(54 + col * 14.4, 100 + row * 16),
          size: Vector2(8, 8),
          anchor: Anchor.center,
          paint: Paint()..color = _ShellColors.lcdInk,
        );
        dot.scale = Vector2.all(0.01);
        await add(dot);
        dot.add(
          ScaleEffect.to(
            Vector2.all(1),
            EffectController(
              duration: 0.28,
              startDelay: 0.04 + (row * 14 + col) * 0.011,
              curve: Curves.easeOutBack,
            ),
          ),
        );
      }
    }

    final wordmark = TextComponent(
      text: 'flutris',
      textRenderer: TextPaint(
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 26,
          fontWeight: FontWeight.w900,
          fontStyle: FontStyle.italic,
          letterSpacing: -1.2,
          color: _ShellColors.ink,
        ),
      ),
      position: Vector2(150, 159),
      anchor: Anchor.center,
    );
    wordmark.scale = Vector2.all(0.6);
    await add(wordmark);
    wordmark.add(
      ScaleEffect.to(
        Vector2.all(1),
        EffectController(
          duration: 0.5,
          startDelay: 0.3,
          curve: Curves.easeOutBack,
        ),
      ),
    );

    final subtitle = _label(
      'POCKET EDITION',
      150,
      190,
      size: 6,
      spacing: 1.6,
      color: _ShellColors.ink,
      anchoredCenter: true,
    );
    subtitle.scale = Vector2.all(0.01);
    await add(subtitle);
    subtitle.add(
      ScaleEffect.to(
        Vector2.all(1),
        EffectController(duration: 0.3, startDelay: 0.85, curve: Curves.easeOut),
      ),
    );
  }

  Future<void> _addProgressAndBootText() async {
    await add(
      RectangleComponent(
        position: Vector2(52, 226),
        size: Vector2(196, 7),
        paint: Paint()..color = Color(0x772E2740),
      ),
    );
    final fill = RectangleComponent(
      position: Vector2(52, 226),
      size: Vector2(0, 7),
      paint: Paint()..color = _ShellColors.ink,
    );
    await add(fill);
    final seconds = (duration.inMilliseconds / 1000 - 0.3).clamp(0.5, 6.0);
    fill.add(
      SizeEffect.to(
        Vector2(196, 7),
        EffectController(duration: seconds.toDouble(), curve: Curves.easeInOut),
      ),
    );

    final lines = [
      (0.95, 244.0, 'BOOTING FLAME CORE'),
      (1.30, 257.0, 'GENERATING TETROMINOES'),
      (1.65, 270.0, 'READY'),
    ];
    for (final (delay, y, text) in lines) {
      final label = _label(text, 42, y, size: 6, spacing: .6);
      label.scale = Vector2.all(0.01);
      await add(label);
      label.add(
        ScaleEffect.to(
          Vector2.all(1),
          EffectController(duration: 0.25, startDelay: delay, curve: Curves.easeOut),
        ),
      );
    }

    await add(
      _label(
        'TAP TO SKIP',
        150,
        291,
        size: 5.5,
        spacing: 1.2,
        anchoredCenter: true,
      ),
    );
  }

  TextComponent _label(
    String text,
    double x,
    double y, {
    double size = 6.5,
    double spacing = 1,
    Color color = _ShellColors.muted,
    bool anchoredCenter = false,
    bool anchoredEnd = false,
  }) =>
      TextComponent(
        text: text,
        textRenderer: TextPaint(
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: size,
            fontWeight: FontWeight.w700,
            letterSpacing: spacing,
            color: color,
          ),
        ),
        position: Vector2(x, y),
        anchor: anchoredCenter
            ? Anchor.center
            : anchoredEnd
                ? Anchor.centerRight
                : Anchor.topLeft,
      );
}

/// Lowercase italic wordmark above the device, matching the app header.
class _Wordmark extends PositionComponent {
  @override
  Future<void> onLoad() async {
    await super.onLoad();
    final text = TextComponent(
      text: 'flutris',
      textRenderer: TextPaint(
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 32,
          fontWeight: FontWeight.w900,
          fontStyle: FontStyle.italic,
          letterSpacing: -1.2,
          color: _ShellColors.ink,
        ),
      ),
      position: Vector2(150, 32),
      anchor: Anchor.center,
    );
    text.scale = Vector2.all(0.6);
    await add(text);
    text.add(
      ScaleEffect.to(
        Vector2.all(1),
        EffectController(duration: 0.55, curve: Curves.easeOutBack),
      ),
    );
  }
}

/// Bezel with the shell's asymmetric corner, border and hard offset shadow.
class _DeviceBezel extends PositionComponent {
  _DeviceBezel();

  static const _rect = Rect.fromLTWH(26, 58, 248, 246);

  RRect get _shape => RRect.fromRectAndCorners(
        _rect,
        topLeft: const Radius.circular(15),
        topRight: const Radius.circular(15),
        bottomLeft: const Radius.circular(15),
        bottomRight: const Radius.circular(43),
      );

  @override
  void render(Canvas canvas) {
    final shadowShape = RRect.fromRectAndCorners(
      _rect.shift(const Offset(0, 4)),
      topLeft: const Radius.circular(15),
      topRight: const Radius.circular(15),
      bottomLeft: const Radius.circular(15),
      bottomRight: const Radius.circular(43),
    );
    canvas.drawRRect(shadowShape, Paint()..color = _ShellColors.shadow);
    canvas.drawRRect(_shape, Paint()..color = _ShellColors.bezel);
    canvas.drawRRect(
      _shape,
      Paint()
        ..color = _ShellColors.bezelBorder
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }
}
