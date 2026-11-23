import 'package:flame/game.dart';
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
}
