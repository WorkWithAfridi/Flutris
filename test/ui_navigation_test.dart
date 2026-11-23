import 'package:flame/game.dart';
import 'package:flutris/game/tetris.dart';
import 'package:flutris/game/flutris_game.dart';
import 'package:flutris/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('hint renders on the side panel and menu can be quit',
      (tester) async {
    await tester.pumpWidget(const FlutrisApp(showSplash: false));
    await tester.pump();

    final game = tester.state<GameWidgetState<FlutrisGame>>(
      find.byType(GameWidget<FlutrisGame>),
    ).currentGame;
    await tester.runAsync(() => game.loaded);
    await tester.pump();

    for (var i = 0; i < 5; i++) {
      game.menuDown();
    }
    game.confirm();
    await tester.pump();

    game.toggleHint();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    expect(find.text('HINT'), findsOneWidget);
    expect(find.textContaining('COL'), findsWidgets);
    expect(find.bySemanticsLabel(RegExp(r'^Quit to menu')), findsOneWidget);

    game.quitToMenu();
    await tester.pump();
    await tester.pump();

    expect(find.text('READY'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('end screen offers restart and a single menu control',
      (tester) async {
    await tester.pumpWidget(const FlutrisApp(showSplash: false));
    await tester.pump();
    final game = tester.state<GameWidgetState<FlutrisGame>>(
      find.byType(GameWidget<FlutrisGame>),
    ).currentGame;
    await tester.runAsync(() => game.loaded);
    await tester.pump();
    game.confirm();

    final board = List.generate(
      TetrisEngine.rows,
      (_) => List<PieceType?>.filled(TetrisEngine.columns, null),
    );
    board[0][3] = PieceType.j;
    board[0][4] = PieceType.j;
    board[0][5] = PieceType.j;
    game.engine.loadBoard(board);
    game.engine.hardDrop();
    await tester.pump();
    await tester.pump();

    expect(game.flow.state, FlowState.gameOver);
    expect(find.bySemanticsLabel(RegExp(r'^Restart game')), findsWidgets);
    expect(find.bySemanticsLabel(RegExp(r'^Quit to menu')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
