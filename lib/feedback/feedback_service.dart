import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import 'feedback_cue.dart';

/// Shared haptic + sound feedback for the UI buttons and the game engine.
///
/// One instance serves both worlds so a single sound toggle controls
/// everything. Audio is silent until [preload] succeeds, which also keeps
/// widget tests free of plugin-channel errors.
class FeedbackService {
  FeedbackService._();

  static final FeedbackService instance = FeedbackService._();

  bool soundEnabled = true;
  bool hapticsEnabled = true;
  bool audioReady = false;

  /// Injectable clock so throttling can be tested deterministically.
  DateTime Function() now = DateTime.now;

  /// Optional observer for tests/diagnostics, called once per unthrottled cue.
  void Function(FeedbackCue cue)? onCue;

  final Map<FeedbackCue, DateTime> _lastPlayed = <FeedbackCue, DateTime>{};

  /// Loads all effects into Flame's audio cache. Call once during game load.
  Future<void> preload() async {
    try {
      await FlameAudio.audioCache.loadAll(FeedbackCue.allAssets);
      audioReady = true;
    } catch (_) {
      audioReady = false;
    }
  }

  /// Feedback for a tactile console button press.
  void press() => play(FeedbackCue.tap);

  /// Feedback for moving between menu entries.
  void navigate() => play(FeedbackCue.navigate);

  bool toggleSound() {
    soundEnabled = !soundEnabled;
    return soundEnabled;
  }

  bool toggleHaptics() {
    hapticsEnabled = !hapticsEnabled;
    return hapticsEnabled;
  }

  /// Triggers both channels for [cue], respecting its throttle window.
  void play(FeedbackCue cue) {
    final throttle = cue.throttle;
    if (throttle > Duration.zero) {
      final instant = now();
      final last = _lastPlayed[cue];
      if (last != null && instant.difference(last) < throttle) return;
      _lastPlayed[cue] = instant;
    }
    onCue?.call(cue);
    _haptic(cue.haptic);
    _sound(cue);
  }

  void _haptic(FeedbackHaptic haptic) {
    if (!hapticsEnabled) return;
    _guard(() => switch (haptic) {
          FeedbackHaptic.selection => HapticFeedback.selectionClick(),
          FeedbackHaptic.light => HapticFeedback.lightImpact(),
          FeedbackHaptic.medium => HapticFeedback.mediumImpact(),
          FeedbackHaptic.heavy => HapticFeedback.heavyImpact(),
          FeedbackHaptic.success => HapticFeedback.successNotification(),
          FeedbackHaptic.warning => HapticFeedback.warningNotification(),
        });
  }

  void _sound(FeedbackCue cue) {
    if (!soundEnabled || !audioReady) return;
    _guard(() => FlameAudio.play(cue.asset, volume: cue.volume));
  }

  /// Never let a platform-channel failure escape into the game loop.
  void _guard(Future<void> Function() action) {
    try {
      action().then<void>((_) {}, onError: (Object _) {});
    } catch (_) {
      // Feedback is best-effort; gameplay must continue.
    }
  }
}
