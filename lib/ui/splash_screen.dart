import 'dart:async';

import 'package:flame/game.dart' show GameWidget;
import 'package:flutter/widgets.dart';

import '../game/splash/flame_splash.dart';

/// Shows the animated Flame splash, then cross-fades to [child].
///
/// The splash can be skipped by tapping it. A fallback timer guarantees the
/// transition even if the Flame loop is paused by the platform.
class SplashScreen extends StatefulWidget {
  const SplashScreen({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 2600),
  });

  final Widget child;
  final Duration duration;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late final FlameSplash _splash;
  Timer? _fallback;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _splash = FlameSplash(
      duration: widget.duration,
      onFinished: _onFinished,
    );
    _fallback = Timer(widget.duration + const Duration(milliseconds: 300), _onFinished);
  }

  @override
  void dispose() {
    _fallback?.cancel();
    super.dispose();
  }

  void _onFinished() {
    if (_finished || !mounted) return;
    setState(() => _finished = true);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 450),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: _finished
          ? KeyedSubtree(key: const ValueKey<String>('app'), child: widget.child)
          : KeyedSubtree(
              key: const ValueKey<String>('splash'),
              child: ColoredBox(
                color: const Color(0xFF2B2438),
                child: Stack(
                  children: [
                    SizedBox.expand(child: GameWidget<FlameSplash>(game: _splash)),
                    const Center(child: _AppIcon()),
                    // Placed above the game so it receives taps first;
                    // GameWidget's own opaque hit test would swallow them.
                    Positioned.fill(
                      child: Semantics(
                        button: true,
                        label: 'Skip splash',
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: _onFinished,
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

/// The app icon, scaled in and then gently breathing.
class _AppIcon extends StatefulWidget {
  const _AppIcon();

  @override
  State<_AppIcon> createState() => _AppIconState();
}

class _AppIconState extends State<_AppIcon> with TickerProviderStateMixin {
  late final AnimationController _entry = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  )..forward();

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _entry.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: FadeTransition(
          opacity: CurvedAnimation(parent: _entry, curve: Curves.easeOut),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.65, end: 1).animate(
              CurvedAnimation(parent: _entry, curve: Curves.easeOutBack),
            ),
            child: ScaleTransition(
              scale: Tween<double>(begin: 1, end: 1.04).animate(
                CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
              ),
              child: Container(
                width: 160,
                height: 160,
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFE6D8F0),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x80573379),
                      blurRadius: 24,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/branding/flutris-app-icon.png',
                    width: 154,
                    height: 154,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}
