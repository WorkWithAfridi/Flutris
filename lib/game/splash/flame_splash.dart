import 'dart:ui' show Color, Paint;

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/game.dart';
import 'package:flutter/animation.dart' show Curves;
import 'package:flutter/painting.dart' show FontWeight, TextStyle;

/// Virtual design size of the splash scene. The game scales it to any canvas.
const double _virtualSize = 288;

/// Animated Flame splash shown before the handheld UI.
///
/// All motion uses Flame's effect/controller system: staggered dot reveals,
/// logo scale-in, a moving scanline, a filling progress bar and boot text.
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

  @override
  Color backgroundColor() => const Color(0xFF2B2438);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _scene = _SplashScene(
      duration: duration,
      onFinished: _complete,
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
    final scene = _scene;
    if (scene == null) return;
    final canvas = size.clone();
    final scale =
        canvas.x < canvas.y ? canvas.x / _virtualSize : canvas.y / _virtualSize;
    scene.scale = Vector2.all(scale);
    scene.position = Vector2(
      (canvas.x - _virtualSize * scale) / 2,
      (canvas.y - _virtualSize * scale) / 2,
    );
  }

  void _complete() {
    if (_completed) return;
    _completed = true;
    onFinished?.call();
  }
}

class _SplashScene extends PositionComponent {
  _SplashScene({required this.duration, required this.onFinished});

  final Duration duration;
  final void Function() onFinished;

  static const _ink = Color(0xFF354839);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    size = Vector2.all(_virtualSize);

    // Console-colored panel and LCD well.
    await add(
      RectangleComponent(
        position: Vector2(16, 16),
        size: Vector2(256, 256),
        paint: Paint()..color = const Color(0xFFD8CBEC),
      ),
    );
    await add(
      RectangleComponent(
        position: Vector2(28, 72),
        size: Vector2(232, 116),
        paint: Paint()..color = const Color(0xFFB5C49D),
      ),
    );

    await _addDotMatrix();
    await _addLogo();
    await _addScanline();
    await _addProgressBar();
    await _addBootText();
  }

  Future<void> _addDotMatrix() async {
    for (var row = 0; row < 5; row++) {
      for (var col = 0; col < 14; col++) {
        final dot = RectangleComponent(
          position: Vector2(40 + col * 15.5, 84 + row * 20),
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
              startDelay: 0.04 + (row * 14 + col) * 0.011,
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
          fontSize: 38,
          fontWeight: FontWeight.bold,
          color: _ink,
          letterSpacing: 3,
        ),
      ),
      position: Vector2(_virtualSize / 2, 148),
      anchor: Anchor.center,
    );
    logo.scale = Vector2.all(0.6);
    await add(logo);
    logo.add(
      ScaleEffect.to(
        Vector2.all(1),
        EffectController(
          duration: 0.55,
          startDelay: 0.32,
          curve: Curves.easeOutBack,
        ),
      ),
    );

    final subtitle = TextComponent(
      text: 'POCKET EDITION',
      textRenderer: TextPaint(
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 10,
          color: _ink,
          letterSpacing: 2,
        ),
      ),
      position: Vector2(_virtualSize / 2, 172),
      anchor: Anchor.center,
    );
    subtitle.scale = Vector2.all(0.01);
    await add(subtitle);
    subtitle.add(
      ScaleEffect.to(
        Vector2.all(1),
        EffectController(duration: 0.3, startDelay: 0.95, curve: Curves.easeOut),
      ),
    );
  }

  Future<void> _addScanline() async {
    final scanline = RectangleComponent(
      position: Vector2(28, 72),
      size: Vector2(232, 2),
      paint: Paint()..color = const Color(0x55354839),
    );
    await add(scanline);
    scanline.add(
      MoveEffect.by(
        Vector2(0, 114),
        InfiniteEffectController(LinearEffectController(1.6)),
      ),
    );
  }

  Future<void> _addProgressBar() async {
    await add(
      RectangleComponent(
        position: Vector2(54, 210),
        size: Vector2(180, 9),
        paint: Paint()..color = const Color(0x77354839),
      ),
    );
    final fill = RectangleComponent(
      position: Vector2(54, 210),
      size: Vector2(0, 9),
      paint: Paint()..color = _ink,
    );
    await add(fill);
    final seconds = (duration.inMilliseconds / 1000 - 0.3).clamp(0.5, 6.0);
    fill.add(
      SizeEffect.to(
        Vector2(180, 9),
        EffectController(duration: seconds.toDouble(), curve: Curves.easeInOut),
      ),
    );
  }

  Future<void> _addBootText() async {
    final lines = [
      (0.9, 'BOOTING FLAME CORE'),
      (1.35, 'GENERATING TETROMINOES'),
      (1.8, 'READY'),
    ];
    for (final (delay, text) in lines) {
      final label = TextComponent(
        text: text,
        textRenderer: TextPaint(
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 9,
            color: _ink,
            letterSpacing: 1,
          ),
        ),
        position: Vector2(28, 228 + (delay - 0.9) * 70),
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
