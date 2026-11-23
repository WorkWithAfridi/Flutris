import 'package:flutris/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('D-pad whole area is tappable, not just the visual arrow',
      (tester) async {
    await tester.pumpWidget(const FlutrisApp(showSplash: false));
    await tester.pump();

    final down = find.bySemanticsLabel(RegExp(r'^Next mode')).first;
    expect(down, findsOneWidget);
    final rect = tester.getRect(down);

    // Tap well inside the pad but outside the 41px arrow graphic.
    await tester.tapAt(rect.center + const Offset(0, 24));
    await tester.pump();

    expect(find.text('SPRINT 40'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('secondary controls remain tappable',
      (tester) async {
    await tester.pumpWidget(const FlutrisApp(showSplash: false));
    await tester.pump();

    final start = find.bySemanticsLabel(RegExp(r'^Start selected mode'));
    expect(start, findsOneWidget);
    final rect = tester.getRect(start);

    await tester.tapAt(rect.center);
    await tester.pump();
    await tester.pump();

    expect(find.text('PLAYING'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
