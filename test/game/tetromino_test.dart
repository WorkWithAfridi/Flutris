import 'package:flutris/game/tetris.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Tetromino geometry', () {
    test('every piece has four cells in every rotation, inside its box', () {
      for (final type in PieceType.values) {
        final size = Tetromino.boxSize(type);
        for (var rotation = 0; rotation < 4; rotation++) {
          final cells = Tetromino.cells(type, rotation);
          expect(cells, hasLength(4), reason: '$type rotation $rotation');
          expect(
            cells.every((c) =>
                c.x >= 0 && c.x < size && c.y >= 0 && c.y < size),
            isTrue,
            reason: '$type rotation $rotation out of $size box',
          );
        }
      }
    });

    test('rotations are distinct states except for the O piece', () {
      for (final type in PieceType.values) {
        final states = <String>[
          for (var r = 0; r < 4; r++)
            (Tetromino.cells(type, r)
                  .map((c) => '${c.x},${c.y}')
                  .toList()
                  ..sort())
                .join(';'),
        ];
        if (type == PieceType.o) {
          expect(states.toSet(), hasLength(1), reason: '$type');
        } else {
          expect(states.toSet().length, greaterThanOrEqualTo(2), reason: '$type');
        }
      }
    });

    test('rotation wraps and normalizes negative values', () {
      for (final type in PieceType.values) {
        expect(Tetromino.cells(type, 4), Tetromino.cells(type, 0));
        expect(Tetromino.cells(type, -1), Tetromino.cells(type, 3));
      }
    });

    test('SRS kick tables cover all eight transitions', () {
      for (final type in PieceType.values) {
        for (var from = 0; from < 4; from++) {
          for (var to = 0; to < 4; to++) {
            if (from == to) continue;
            final kicks = Tetromino.kicks(type, from, to);
            expect(kicks, isNotEmpty, reason: '$type $from->$to');
            expect(kicks.first.x, 0, reason: '$type $from->$to');
            expect(kicks.first.y, 0, reason: '$type $from->$to');
            if (type != PieceType.o && (from - to).abs() != 2) {
              expect(kicks, hasLength(5), reason: '$type $from->$to');
            }
          }
        }
      }
    });

    test('O piece never needs a kick', () {
      final kicks = Tetromino.kicks(PieceType.o, 0, 1);
      expect(kicks, hasLength(1));
      expect(kicks.single.x, 0);
      expect(kicks.single.y, 0);
    });
  });
}
