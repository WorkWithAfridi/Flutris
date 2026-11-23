import 'package:flutter/widgets.dart';
import 'package:flutris/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final size in [(320.0, 568.0), (390.0, 844.0), (844.0, 390.0)]) {
    testWidgets('Console fits ${size.$1} x ${size.$2}', (tester) async {
      tester.view.physicalSize = Size(size.$1, size.$2);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const FlutrisApp(showSplash: false));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.textContaining('FLUTRIS'), findsWidgets);
      await tester.tap(find.bySemanticsLabel('Pause or resume'));
      await tester.pump();
      expect(find.text('PAUSED'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Pause or resume'));
      await tester.pump();
      expect(find.text('PLAYING'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Toggle sound'));
      await tester.pump();
      expect(find.text('SOUND OFF'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
