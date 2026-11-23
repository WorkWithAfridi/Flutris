import 'package:flame/game.dart';
import 'package:flutris/game/flutris_game.dart';
import 'package:flutris/game/splash/flame_splash.dart';
import 'package:flutris/main.dart';
import 'package:flutris/ui/splash_screen.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('splash loads its Flame game and can be skipped', (tester) async {
    await tester.pumpWidget(const FlutrisApp());

    final state = tester.state<GameWidgetState<FlameSplash>>(
      find.byType(GameWidget<FlameSplash>),
    );
    await tester.runAsync(() => state.currentGame.loaded);
    await tester.pump();
    expect(state.currentGame.isLoaded, isTrue);
    expect(find.bySemanticsLabel('Skip splash'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Skip splash'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.bySemanticsLabel('Skip splash'), findsNothing);
    expect(find.byType(GameWidget<FlutrisGame>), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('splash transitions automatically after its duration',
      (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: SplashScreen(
          duration: Duration(milliseconds: 100),
          child: SizedBox(key: Key('content')),
        ),
      ),
    );
    expect(find.bySemanticsLabel('Skip splash'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 550));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.bySemanticsLabel('Skip splash'), findsNothing);
    expect(find.byKey(const Key('content')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
