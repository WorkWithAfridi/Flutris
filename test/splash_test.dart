import 'package:flame/components.dart' show PositionComponent;
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

  testWidgets('splash scene is centered and scaled to the whole canvas',
      (tester) async {
    final game = FlameSplash(duration: const Duration(seconds: 10));
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 400,
          height: 800,
          child: GameWidget<FlameSplash>(game: game),
        ),
      ),
    );
    await tester.runAsync(() => game.loaded);
    await tester.pump();

    expect(game.backgroundColor(), const Color(0xFF382D46));
    expect(game.size.x, greaterThan(0));
    expect(game.size.y, greaterThan(0));

    final canvas = game.size;
    final scale = canvas.x < canvas.y ? canvas.x / 288 : canvas.y / 288;
    final scene = game.children
        .whereType<PositionComponent>()
        .firstWhere((component) => component.size.x == 288);
    expect(scene.scale.x, closeTo(scale, 0.01));
    expect(scene.position.x, closeTo((canvas.x - 288 * scale) / 2, 0.01));
    expect(scene.position.y, closeTo((canvas.y - 288 * scale) / 2, 0.01));
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
