import 'package:flutris/feedback/feedback_cue.dart';
import 'package:flutris/feedback/feedback_service.dart';
import 'package:flutris/game/tetris.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FeedbackCue', () {
    test('every cue has a unique asset and a listed asset', () {
      expect(FeedbackCue.all, hasLength(FeedbackCue.allAssets.length));
      expect(
        FeedbackCue.all.map((c) => c.asset).toSet().length,
        FeedbackCue.all.length,
      );
      for (final cue in FeedbackCue.all) {
        expect(FeedbackCue.allAssets, contains(cue.asset));
        expect(cue.volume, inInclusiveRange(0, 1));
      }
    });

    test('gameplay events map to the right cue', () {
      expect(FeedbackCue.forEvent(TetrisEvent.move), FeedbackCue.move);
      expect(FeedbackCue.forEvent(TetrisEvent.rotate), FeedbackCue.rotate);
      expect(FeedbackCue.forEvent(TetrisEvent.softDrop), FeedbackCue.softDrop);
      expect(FeedbackCue.forEvent(TetrisEvent.hardDrop), FeedbackCue.hardDrop);
      expect(FeedbackCue.forEvent(TetrisEvent.lock), FeedbackCue.lock);
      expect(FeedbackCue.forEvent(TetrisEvent.hold), FeedbackCue.hold);
      expect(FeedbackCue.forEvent(TetrisEvent.lineClear), FeedbackCue.lineClear);
      expect(
        FeedbackCue.forEvent(TetrisEvent.lineClear, clearedLines: 4),
        FeedbackCue.tetris,
      );
      expect(FeedbackCue.forEvent(TetrisEvent.levelUp), FeedbackCue.levelUp);
      expect(FeedbackCue.forEvent(TetrisEvent.victory), FeedbackCue.victory);
      expect(FeedbackCue.forEvent(TetrisEvent.gameOver), FeedbackCue.gameOver);
      expect(FeedbackCue.forEvent(TetrisEvent.timeUp), FeedbackCue.gameOver);
      expect(FeedbackCue.forEvent(TetrisEvent.start), isNull);
    });
  });

  group('FeedbackService', () {
    final service = FeedbackService.instance;
    var clock = DateTime(2024);

    setUp(() {
      service.hapticsEnabled = true;
      service.soundEnabled = true;
      service.onCue = null;
      service.now = () => clock;
      clock = DateTime(2024);
    });

    test('throttles repeated cues', () {
      final cues = <FeedbackCue>[];
      service.onCue = cues.add;

      service.play(FeedbackCue.move);
      service.play(FeedbackCue.move);
      expect(cues, hasLength(1));

      clock = clock.add(const Duration(milliseconds: 100));
      service.play(FeedbackCue.move);
      expect(cues, hasLength(2));
    });

    test('no throttle means every cue fires', () {
      final cues = <FeedbackCue>[];
      service.onCue = cues.add;

      service.play(FeedbackCue.hardDrop);
      service.play(FeedbackCue.hardDrop);
      expect(cues, hasLength(2));
    });

    test('menu music calls are safe before audio is ready', () async {
      service.soundEnabled = true;
      await service.startMenuMusic();
      await service.stopMenuMusic();
      service.syncMenuMusic(inMenu: true);
      expect(service.audioReady, isFalse);
    });

    test('menu and game music switch the active screen', () async {
      service.soundEnabled = true;
      await service.startMenuMusic();
      expect(service.screen, FeedbackScreen.menu);
      await service.startGameMusic();
      expect(service.screen, FeedbackScreen.game);
      await service.stopMenuMusic();
      expect(service.screen, FeedbackScreen.none);
    });

    test('sound and haptics toggles flip both ways', () {
      expect(service.toggleSound(), isFalse);
      expect(service.soundEnabled, isFalse);
      expect(service.toggleSound(), isTrue);

      expect(service.toggleHaptics(), isFalse);
      expect(service.toggleHaptics(), isTrue);
    });

    tearDown(() {
      service.onCue = null;
      service.now = DateTime.now;
      service.hapticsEnabled = true;
      service.soundEnabled = true;
    });
  });
}
