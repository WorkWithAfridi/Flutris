import 'package:flame/game.dart';
import 'package:flutris/game/flutris_game.dart';
import 'package:flutris/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Flutris mounts and loads its Flame game', (tester) async {
    await tester.pumpWidget(const FlutrisApp(showSplash: false));
    final state = tester.state<GameWidgetState<FlutrisGame>>(
      find.byType(GameWidget<FlutrisGame>),
    );
    await tester.runAsync(() => state.currentGame.loaded);
    await tester.pump();
    expect(state.currentGame.isLoaded, isTrue);
    expect(tester.takeException(), isNull);
  });
}
