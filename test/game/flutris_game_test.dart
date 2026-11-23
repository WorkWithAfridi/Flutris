import 'package:flame/game.dart';
import 'package:flutris/game/flutris_game.dart';
import 'package:flutris/game/tetris.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('game starts at the mode menu and can launch a mode',
      (tester) async {
    final game = FlutrisGame();
    await tester.pumpWidget(GameWidget<FlutrisGame>(game: game));
    await tester.runAsync(() => game.loaded);
    await tester.pump();

    expect(game.isLoaded, isTrue);
    expect(game.flow.isMenu, isTrue);
    expect(game.flow.selectedMode.mode, GameMode.marathon);

    game.menuDown();
    expect(game.flow.selectedMode.mode, GameMode.sprint);

    game.confirm();
    await tester.pump();
    expect(game.flow.isPlaying, isTrue);
    expect(game.engine.mode.mode, GameMode.sprint);
    expect(game.engine.isPlaying, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('game drives the engine and forwards on-screen input',
      (tester) async {
    final game = FlutrisGame();
    await tester.pumpWidget(GameWidget<FlutrisGame>(game: game));
    await tester.runAsync(() => game.loaded);
    await tester.pump();

    game.confirm(); // Marathon
    await tester.pump();

    final engine = game.engine;
    expect(engine.activePiece?.type, isNotNull);
    final x = engine.activePiece!.x;
    game.moveLeft();
    expect(engine.activePiece!.x, x - 1);

    game.hardDrop();
    expect(engine.lines, greaterThanOrEqualTo(0));
    expect(tester.takeException(), isNull);
  });

  testWidgets('hint and hold controls are available', (tester) async {
    final game = FlutrisGame();
    await tester.pumpWidget(GameWidget<FlutrisGame>(game: game));
    await tester.runAsync(() => game.loaded);
    await tester.pump();

    game.menuDown();
    game.menuDown();
    game.menuDown();
    game.menuDown();
    game.menuDown(); // Tactics: hints + hold enabled
    game.confirm();
    await tester.pump();

    expect(game.engine.mode.mode, GameMode.tactics);
    game.toggleHint();
    expect(game.engine.mode.allowHints, isTrue);
    expect(game.engine.mode.allowHold, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('quitToMenu resets the engine and returns to the menu',
      (tester) async {
    final game = FlutrisGame();
    await tester.pumpWidget(GameWidget<FlutrisGame>(game: game));
    await tester.runAsync(() => game.loaded);
    await tester.pump();

    game.confirm();
    game.hardDrop();
    expect(game.engine.score, greaterThan(0));

    game.quitToMenu();
    expect(game.flow.isMenu, isTrue);
    expect(game.engine.status, TetrisStatus.ready);
    expect(game.engine.score, 0);
    expect(game.engine.activePiece, isNull);
  });

  testWidgets('hint is computed and exposed for the side panel', (tester) async {
    final game = FlutrisGame();
    await tester.pumpWidget(GameWidget<FlutrisGame>(game: game));
    await tester.runAsync(() => game.loaded);
    await tester.pump();

    for (var i = 0; i < 5; i++) {
      game.menuDown();
    }
    game.confirm();
    game.toggleHint();
    await tester.pump(const Duration(milliseconds: 400));

    expect(game.isHintVisible, isTrue);
    expect(game.placementHint, isNotNull);
    expect(game.hintSummary, isNotEmpty);
  });
}