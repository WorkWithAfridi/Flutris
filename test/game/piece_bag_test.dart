import 'dart:math' show Random;

import 'package:flutris/game/tetris.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every group of seven contains each piece exactly once', () {
    final bag = PieceBag(Random(42));
    for (var group = 0; group < 5; group++) {
      final drawn = {for (var i = 0; i < 7; i++) bag.next()};
      expect(drawn, PieceType.values.toSet(), reason: 'group $group');
    }
  });

  test('peek does not consume pieces', () {
    final bag = PieceBag(Random(7));
    final preview = bag.peek(10);
    expect(preview, hasLength(10));

    final drawn = List.generate(10, (_) => bag.next());
    expect(drawn, preview);
  });

  test('peek(0) is empty', () {
    expect(PieceBag().peek(0), isEmpty);
  });
}
