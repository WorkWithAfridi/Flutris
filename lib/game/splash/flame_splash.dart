import 'dart:math' as math;
import 'dart:ui' show Color, Paint, Rect;

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/game.dart';
import 'package:flutter/animation.dart' show Curves;
import 'package:flutter/painting.dart'
    show Alignment, FontWeight, LinearGradient, TextStyle;

/// Virtual design size of the splash scene. The scene is scaled and centered
/// inside whatever canvas the game is given.
const double _virtualSize = 288;

/// Animated Flame splash shown before the handheld UI.
///
/// Motion uses Flame's effect/controller system: staggered dot reveals, logo
/// scale-in, an infinite scanline, a filling progress bar and boot text.
/// [onFinished] fires once when [duration] elapses.
class FlameSplash extends FlameGame {
  FlameSplash({
    this.duration = const Duration(milliseconds: 2600),
    this.onFinished,
  });

  final Duration duration;
  final void Function()? onFinished;

  _SplashScene? _scene;
  bool _completed = false;

  /// Matches the handheld shell's dark purple surround.
  @override
  Color backgroundColor() => const Color(0xFF382D46);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _scene = _SplashScene(
      duration: duration,
      onFinished: _complete,
      // The first resize may have happened before the scene existed, so the
      // scene must lay itself out with the size we already have.
      initialSize: size.clone(),
    );
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
    _scene?.layoutScene(size.clone());
  }

  void _complete() {
    if (_completed) return;
    _completed = true;
    onFinished?.call();
  }
}

class _SplashScene extends PositionComponent {
  _SplashScene({
    required this.duration,
    required this.onFinished,
    required Vector2 initialSize,
  }) : _initialSize = initialSize.clone();

  final Duration duration;
  final void Function() onFinished;
  final Vector2 _initialSize;

  static const _ink = Color(0xFF354839);

  /// Centers and scales the fixed virtual frame inside [canvas].
  void layoutScene(Vector2 canvas) {
    final scale = math.min(canvas.x / _virtualSize, canvas.y / _virtualSize);
    this.scale = Vector2.all(scale);
    position = Vector2(
      (canvas.x - _virtualSize * scale) / 2,
      (canvas.y - _virtualSize * scale) / 2,
    );
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    size = Vector2.all(_virtualSize);
    layoutScene(_initialSize);

    // Deep purple edge gives the panel the same layered feel as the shell.
    await add(
      RectangleComponent(
        position: Vector2(12, 12),
        size: Vector2(264, 264),
        paint: Paint()..color = const Color(0xFF6E5A86),
      ),
    );
    await add(
      RectangleComponent(
        position: Vector2(16, 16),
        size: Vector2(256, 256),
        paint: Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFD1C2E9), Color(0xFF9980B8)],
          ).createShader(Rect.fromLTWH(0, 0, 256, 256)),
      ),
    );

    await _addDisplay();
    await _addLogo();
    await _addScanline();
    await _addProgressBar();
    await _addBootText();
  }

  Future<void> _addDisplay() async {
    // LCD bezel and screen.
    await add(
      RectangleComponent(
        position: Vector2(26, 46),
        size: Vector2(236, 128),
        paint: Paint()..color = const Color(0xFF2E2740),
      ),
    );
    await add(
      RectangleComponent(
        position: Vector2(30, 50),
        size: Vector2(228, 120),
        paint: Paint()..color = const Color(0xFFB5C49D),
      ),
    );

    // Three rows of dots in the upper part of the LCD, well clear of the logo.
    for (var row = 0; row < 3; row++) {
      for (var col = 0; col < 14; col++) {
        final dot = RectangleComponent(
          position: Vector2(44 + col * 15.3, 62 + row * 18),
          size: Vector2(8, 8),
          anchor: Anchor.center,
          paint: Paint()..color = _ink,
        );
        dot.scale = Vector2.all(0.01);
        await add(dot);
        dot.add(
          ScaleEffect.to(
            Vector2.all(1),
            EffectController(
              duration: 0.28,
              startDelay: 0.04 + (row * 14 + col) * 0.012,
              curve: Curves.easeOutBack,
            ),
          ),
        );
      }
    }
  }

  Future<void> _addLogo() async {
    final logo = TextComponent(
      text: 'FLUTRIS',
      textRenderer: TextPaint(
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: _ink,
          letterSpacing: 2,
        ),
      ),
      position: Vector2(_virtualSize / 2, 130),
      anchor: Anchor.center,
    );
    logo.scale = Vector2.all(0.6);
    await add(logo);
    logo.add(
      ScaleEffect.to(
        Vector2.all(1),
        EffectController(
          duration: 0.5,
          startDelay: 0.3,
          curve: Curves.easeOutBack,
        ),
      ),
    );

    final subtitle = TextComponent(
      text: 'POCKET EDITION',
      textRenderer: TextPaint(
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 9,
          color: _ink,
          letterSpacing: 2,
        ),
      ),
      position: Vector2(_virtualSize / 2, 158),
      anchor: Anchor.center,
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

  Future<void> _addScanline() async {
    final scanline = RectangleComponent(
      position: Vector2(30, 50),
      size: Vector2(228, 2),
      paint: Paint()..color = const Color(0x55354839),
    );
    await add(scanline);
    scanline.add(
      MoveEffect.by(
        Vector2(0, 118),
        InfiniteEffectController(LinearEffectController(1.6)),
      ),
    );
  }

  Future<void> _addProgressBar() async {
    await add(
      RectangleComponent(
        position: Vector2(54, 184),
        size: Vector2(180, 8),
        paint: Paint()..color = const Color(0x77354839),
      ),
    );
    final fill = RectangleComponent(
      position: Vector2(54, 184),
      size: Vector2(0, 8),
      paint: Paint()..color = _ink,
    );
    await add(fill);
    final seconds = (duration.inMilliseconds / 1000 - 0.3).clamp(0.5, 6.0);
    fill.add(
      SizeEffect.to(
        Vector2(180, 8),
        EffectController(duration: seconds.toDouble(), curve: Curves.easeInOut),
      ),
    );
  }

  Future<void> _addBootText() async {
    // Fixed positions keep the lines and the skip hint from colliding.
    final lines = [
      (0.95, 210.0, 'BOOTING FLAME CORE'),
      (1.30, 227.0, 'GENERATING TETROMINOES'),
      (1.65, 244.0, 'READY'),
    ];
    for (final (delay, y, text) in lines) {
      final label = TextComponent(
        text: text,
        textRenderer: TextPaint(
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 8.5,
            color: _ink,
            letterSpacing: 1,
          ),
        ),
        position: Vector2(28, y),
      );
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
      TextComponent(
        text: 'TAP TO SKIP',
        textRenderer: TextPaint(
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 7,
            color: Color(0xAA354839),
            letterSpacing: 2,
          ),
        ),
        position: Vector2(_virtualSize / 2, 262),
        anchor: Anchor.center,
      ),
    );
  }
}
