import 'dart:math' show Random;

import 'tetromino.dart' show PieceType;

/// 7-bag randomizer: every group of seven pieces contains each tetromino
/// exactly once, shuffled. This avoids long droughts and is the modern
/// Tetris guideline behaviour.
class PieceBag {
  PieceBag([Random? random]) : _random = random ?? Random();

  final Random _random;
  final List<PieceType> _queue = <PieceType>[];

  /// Removes and returns the next piece.
  PieceType next() {
    _ensure(1);
    return _queue.removeAt(0);
  }

  /// Returns up to [count] upcoming pieces without consuming them.
  List<PieceType> peek(int count) {
    if (count <= 0) return const <PieceType>[];
    _ensure(count);
    return List<PieceType>.unmodifiable(_queue.take(count));
  }

  void _ensure(int count) {
    while (_queue.length < count) {
      _queue.addAll(PieceType.values.toList()..shuffle(_random));
    }
  }
}
