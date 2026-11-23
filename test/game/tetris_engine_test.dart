import 'package:flutris/game/tetris.dart';
import 'package:flutter_test/flutter_test.dart';

TetrisEngine engineWith(List<PieceType> pieces) =>
    TetrisEngine(seededPieces: pieces, previewCount: 2);

List<List<PieceType?>> emptyBoard() => List.generate(
      TetrisEngine.rows,
      (_) => List<PieceType?>.filled(TetrisEngine.columns, null),
    );

void main() {
  group('lifecycle', () {
    test('start sets up active piece and preview queue', () {
      final engine = engineWith([PieceType.o, PieceType.t, PieceType.i]);
      expect(engine.status, TetrisStatus.ready);

      engine.start();

      expect(engine.status, TetrisStatus.playing);
      expect(engine.activePiece?.type, PieceType.o);
      expect(engine.activePiece?.y, spawnY);
      expect(engine.nextPiece, PieceType.t);
      expect(engine.upcoming, [PieceType.i]);
    });

    test('pause stops the clock and resume restarts it', () {
      final engine = engineWith([PieceType.o]);
      engine.start();
      engine.pause();
      engine.tick(const Duration(seconds: 5));
      expect(engine.elapsed, Duration.zero);
      expect(engine.activePiece?.y, spawnY);

      engine.resume();
      engine.tick(const Duration(seconds: 1));
      expect(engine.elapsed, const Duration(seconds: 1));
      expect(engine.activePiece?.y, spawnY + 1);
    });

    test('reset clears the board and stats but keeps best', () {
      final engine = engineWith([PieceType.o, PieceType.t]);
      engine.start();
      engine.hardDrop();
      final best = engine.best;
      expect(best, greaterThan(0));

      engine.reset();
      expect(engine.status, TetrisStatus.ready);
      expect(engine.score, 0);
      expect(engine.lines, 0);
      expect(engine.elapsed, Duration.zero);
      expect(engine.activePiece, isNull);
      expect(engine.cellAt(3, 19), isNull);
      expect(engine.best, best);
    });
  });

  group('movement and collision', () {
    test('left/right move the piece and stop at walls', () {
      final engine = engineWith([PieceType.o]);
      engine.start();
      expect(engine.activePiece!.x, 3);

      expect(engine.moveLeft(), isTrue);
      expect(engine.activePiece!.x, 2);
      engine.moveRight();
      engine.moveRight();
      expect(engine.activePiece!.x, 4);

      engine.placeActivePiece(ActivePiece(PieceType.o, x: 0, y: 5));
      expect(engine.moveLeft(), isFalse);
      expect(engine.activePiece!.x, 0);

      engine.placeActivePiece(ActivePiece(PieceType.o, x: 8, y: 5));
      expect(engine.moveRight(), isFalse);
      expect(engine.activePiece!.x, 8);
    });

    test('soft drop awards one point per row', () {
      final engine = engineWith([PieceType.o]);
      engine.start();
      expect(engine.softDrop(), isTrue);
      expect(engine.activePiece!.y, spawnY + 1);
      expect(engine.score, 1);
    });

    test('hard drop locks immediately and awards two points per row', () {
      final engine = engineWith([PieceType.o, PieceType.t]);
      engine.start();
      engine.hardDrop();

      expect(engine.cellAt(3, 19), PieceType.o);
      expect(engine.cellAt(4, 19), PieceType.o);
      expect(engine.activePiece?.type, PieceType.t);
      expect(engine.score, 38); // 19 rows * 2
    });

    test('rotation uses SRS wall kicks', () {
      final engine = engineWith([PieceType.t]);
      engine.start();
      engine.placeActivePiece(
        ActivePiece(PieceType.t, x: 8, y: 5, rotation: 3),
      );

      expect(engine.rotateClockwise(), isTrue);
      expect(engine.activePiece!.rotation, 0);
      expect(engine.activePiece!.x, 7); // kicked one cell left off the wall
    });

    test('blocked spawn ends the game', () {
      final board = emptyBoard();
      board[0][3] = PieceType.j;
      board[0][4] = PieceType.j;
      board[0][5] = PieceType.j;

      final engine = engineWith([PieceType.t]);
      engine.loadBoard(board);
      engine.start(clearBoard: false);

      expect(engine.status, TetrisStatus.gameOver);
      expect(engine.activePiece, isNull);
    });
  });

  group('timing', () {
    test('gravity steps the piece down once per interval', () {
      final engine = engineWith([PieceType.o]);
      engine.start();
      engine.tick(const Duration(milliseconds: 999));
      expect(engine.activePiece!.y, spawnY);

      engine.tick(const Duration(milliseconds: 1));
      expect(engine.activePiece!.y, spawnY + 1);
    });

    test('a grounded piece locks after the lock delay', () {
      final engine = engineWith([PieceType.o, PieceType.t]);
      engine.start();
      while (engine.softDrop()) {
        // Drop until the piece can no longer move down.
      }
      expect(engine.activePiece?.type, PieceType.o);

      engine.tick(const Duration(milliseconds: 499));
      expect(engine.activePiece?.type, PieceType.o);

      engine.tick(const Duration(milliseconds: 2));
      expect(engine.activePiece?.type, PieceType.t);
    });

    test('moving resets the lock delay', () {
      final engine = engineWith([PieceType.o, PieceType.t]);
      engine.start();
      while (engine.softDrop()) {}

      engine.tick(const Duration(milliseconds: 400));
      expect(engine.moveLeft(), isTrue);
      engine.tick(const Duration(milliseconds: 400));
      expect(engine.activePiece?.type, PieceType.o);
    });
  });

  group('line clearing and scoring', () {
    test('a completed row is cleared and scored', () {
      final board = emptyBoard();
      for (var x = 0; x < TetrisEngine.columns; x++) {
        if (x != 3 && x != 4) board[19][x] = PieceType.j;
      }
      final cleared = <List<int>>[];
      final engine = engineWith([PieceType.o, PieceType.t])
        ..onLinesCleared = cleared.add;

      engine.start();
      engine.loadBoard(board);
      engine.hardDrop();

      expect(engine.lines, 1);
      expect(engine.lastClearedRows, [19]);
      expect(cleared, [
        [19]
      ]);
      expect(engine.score, 138); // 38 hard drop + 100 single
      expect(engine.cellAt(0, 19), isNull);
    });

    test('a double line clear scores 300 x level', () {
      final board = emptyBoard();
      for (final row in [18, 19]) {
        for (var x = 0; x < TetrisEngine.columns; x++) {
          if (x != 3 && x != 4) board[row][x] = PieceType.j;
        }
      }
      final engine = engineWith([PieceType.o, PieceType.t]);

      engine.start();
      engine.loadBoard(board);
      engine.hardDrop();

      expect(engine.lines, 2);
      expect(engine.score, 1338); // 38 hard drop + 300 double + 1000 perfect clear
      expect(engine.lastClearedRows, [18, 19]);
    });

    test('best score is updated', () {
      final board = emptyBoard();
      for (var x = 0; x < TetrisEngine.columns; x++) {
        if (x != 3 && x != 4) board[19][x] = PieceType.j;
      }
      final engine = engineWith([PieceType.o, PieceType.t]);
      engine.start();
      engine.loadBoard(board);
      engine.hardDrop();
      expect(engine.best, 138);
    });
  });

  test('snapshot reflects engine state', () {
    final engine = engineWith([PieceType.o, PieceType.t]);
    engine.start();
    final snapshot = engine.snapshot;
    expect(snapshot.status, TetrisStatus.playing);
    expect(snapshot.activeType, PieceType.o);
    expect(snapshot.nextPiece, PieceType.t);
    expect(snapshot.activeCells, engine.activeCells);
    expect(snapshot.ghostCells, engine.ghostCells);
  });

  test('emits discrete gameplay events', () {
    final board = emptyBoard();
    for (var x = 0; x < TetrisEngine.columns; x++) {
      if (x != 3 && x != 4) board[19][x] = PieceType.j;
    }
    final events = <TetrisEvent>[];
    final engine = engineWith([PieceType.o, PieceType.t]);
    engine.onEvent = events.add;

    engine.start();
    engine.loadBoard(board);
    engine.hardDrop();
    engine.togglePause();

    expect(events, contains(TetrisEvent.start));
    expect(events, contains(TetrisEvent.hardDrop));
    expect(events, contains(TetrisEvent.lock));
    expect(events, contains(TetrisEvent.lineClear));
    expect(events, contains(TetrisEvent.pause));
  });
}
