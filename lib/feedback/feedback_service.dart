import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import 'feedback_cue.dart';

/// Which screen's background track should be playing.
enum FeedbackScreen { none, menu, game }

/// Shared haptic + sound feedback for the UI buttons and the game engine.
///
/// One instance serves both worlds so a single sound toggle controls
/// everything. Sounds come from preallocated [AudioPool]s: creating a fresh
/// `AudioPlayer` on every tap leaks players and makes audio stop working after
/// a while, which pooling avoids. Audio is silent until [preload] succeeds.
class FeedbackService {
  FeedbackService._();

  static final FeedbackService instance = FeedbackService._();

  static const String menuBgmAsset = 'menu_bgm.wav';
  static const String gameBgmAsset = 'game_bgm.wav';

  bool soundEnabled = true;
  bool hapticsEnabled = true;
  bool audioReady = false;

  /// Injectable clock so throttling can be tested deterministically.
  DateTime Function() now = DateTime.now;

  /// Optional observer for tests/diagnostics, called once per unthrottled cue.
  void Function(FeedbackCue cue)? onCue;

  final Map<FeedbackCue, DateTime> _lastPlayed = <FeedbackCue, DateTime>{};
  final Map<String, AudioPool> _pools = <String, AudioPool>{};
  Future<void>? _preloadFuture;
  FeedbackScreen screen = FeedbackScreen.none;
  String? _currentTrack;

  /// Loads and pools all effects. Idempotent and never blocks the caller's
  /// game load: failures leave feedback silently disabled.
  Future<void> preload() => _preloadFuture ??= _preload();

  Future<void> _preload() async {
    try {
      await FlameAudio.audioCache.loadAll([
        ...FeedbackCue.allAssets,
        menuBgmAsset,
        gameBgmAsset,
      ]);
      for (final asset in FeedbackCue.allAssets) {
        try {
          _pools[asset] = await FlameAudio.createPool(
            asset,
            minPlayers: 1,
            maxPlayers: 2,
          );
        } catch (_) {
          // One bad asset must not silence every other cue.
        }
      }
      audioReady = _pools.isNotEmpty;
      _syncMusic();
    } catch (_) {
      audioReady = false;
    }
  }


  /// Selects which background track should play.
  void setScreen(FeedbackScreen value) {
    screen = value;
    _syncMusic();
  }

  Future<void> startMenuMusic() async => setScreen(FeedbackScreen.menu);

  Future<void> startGameMusic() async => setScreen(FeedbackScreen.game);

  Future<void> stopMenuMusic() async => setScreen(FeedbackScreen.none);

  /// Backwards-compatible helper for callers that only know about the menu.
  void syncMenuMusic({required bool inMenu}) =>
      setScreen(inMenu ? FeedbackScreen.menu : FeedbackScreen.none);

  void _syncMusic() {
    if (!soundEnabled || !audioReady || screen == FeedbackScreen.none) {
      _stopMusic();
      return;
    }
    final track = screen == FeedbackScreen.menu ? menuBgmAsset : gameBgmAsset;
    if (_currentTrack == track) return;
    _switchTrack(track);
  }

  Future<void> _switchTrack(String track) async {
    try {
      await FlameAudio.bgm.stop();
      await FlameAudio.bgm.initialize();
      await FlameAudio.bgm.play(
        track,
        volume: track == gameBgmAsset ? 0.12 : 0.28,
      );
      _currentTrack = track;
    } catch (_) {
      _currentTrack = null;
    }
  }

  Future<void> _stopMusic() async {
    if (_currentTrack == null) return;
    _currentTrack = null;
    try {
      await FlameAudio.bgm.stop();
    } catch (_) {
      // Feedback is best-effort.
    }
  }

  /// Feedback for a tactile console button press.
  void press() => play(FeedbackCue.tap);

  /// Feedback for moving between menu entries.
  void navigate() => play(FeedbackCue.navigate);

  bool toggleSound() {
    soundEnabled = !soundEnabled;
    _syncMusic();
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
    final pool = _pools[cue.asset];
    if (pool == null) return;
    _guard(() => pool.start(volume: cue.volume));
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
