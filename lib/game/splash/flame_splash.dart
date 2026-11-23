import 'dart:math' as math;
import 'dart:ui' show Canvas, Color, Offset, Paint;

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/painting.dart' show Alignment, LinearGradient;

import '../../feedback/feedback_service.dart';

/// Virtual size of the icon scene. Scaled and centered on any canvas.
const double _sceneSize = 200;

/// Minimal splash: the app icon on the handheld's purple shell gradient,
/// with a scale-in reveal and a gentle breathing pulse.
class FlameSplash extends FlameGame {
  FlameSplash({
    this.duration = const Duration(milliseconds: 2200),
    this.onFinished,
  });

  final Duration duration;
  final void Function()? onFinished;

  _ShellBackdrop? _backdrop;
  _IconScene? _scene;
  bool _completed = false;

  @override
  Color backgroundColor() => const Color(0xFF382D46);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    // Audio is ready by the time the splash hands over to the menu.
    FeedbackService.instance.preload();

    _backdrop = _ShellBackdrop();
    _scene = _IconScene(initialSize: size.clone());
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

/// The same lavender → plum gradient as the handheld shell.
class _ShellBackdrop extends PositionComponent {
  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    this.size = size.clone();
  }

  @override
  void render(Canvas canvas) {
    final rect = Offset.zero & size.toSize();
    canvas.drawRect(
      rect,
      Paint()..color = const Color(0xFF382D46),
    );
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
  }
}

class _IconScene extends PositionComponent {
  _IconScene({required Vector2 initialSize})
      : _initialSize = initialSize.clone();

  final Vector2 _initialSize;

  void layoutScene(Vector2 canvas) {
    final scale = math.min(canvas.x, canvas.y) / _sceneSize;
    this.scale = Vector2.all(scale);
    position = Vector2(
      (canvas.x - _sceneSize * scale) / 2,
      (canvas.y - _sceneSize * scale) / 2,
    );
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    size = Vector2.all(_sceneSize);
    layoutScene(_initialSize);
  }
}
