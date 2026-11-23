import 'package:flutris/game/tetris.dart';
import 'package:flutter_test/flutter_test.dart';

List<List<PieceType?>> emptyBoard() => List.generate(
      TetrisEngine.rows,
      (_) => List<PieceType?>.filled(TetrisEngine.columns, null),
    );

ModeConfig testMode({
  required GameMode mode,
  GoalType goalType = GoalType.lines,
  int? goalValue,
  Duration? timeLimit,
  bool instantGravity = false,
  bool allowHold = false,
  bool allowHints = false,
  bool comboScoring = false,
  bool topOutEndsGame = true,
  double scoreMultiplier = 1.0,
}) =>
    ModeConfig(
      mode: mode,
      name: mode.name,
      tagline: 'TEST',
      description: 'Test mode',
      startingLevel: 1,
      maxLevel: 15,
      linesPerLevel: 10,
      goalType: goalType,
      goalValue: goalValue,
      timeLimit: timeLimit,
      instantGravity: instantGravity,
      allowHold: allowHold,
      allowHints: allowHints,
      comboScoring: comboScoring,
      topOutEndsGame: topOutEndsGame,
      scoreMultiplier: scoreMultiplier,
    );

void main() {
  group('modes and levels', () {
    test('six modes are configured with goals and descriptions', () {
      expect(allModes, hasLength(6));
      expect(allModes.map((m) => m.mode).toSet(), GameMode.values.toSet());
      for (final mode in allModes) {
        expect(mode.name, isNotEmpty);
        expect(mode.description, isNotEmpty);
        expect(mode.goalLabel, isNotEmpty);
        expect(mode.gravityForLevel(mode.startingLevel), isA<Duration>());
      }
    });

    test('marathon levels advance every 10 lines and cap at 15', () {
      final levels = LevelSystem(modeConfigs[GameMode.marathon]!);
      expect(levels.levelFor(9), 1);
      expect(levels.levelFor(10), 2);
      expect(levels.levelFor(150), 15);
      expect(levels.levelFor(500), 15);
      expect(levels.linesToNext(9), 1);
      expect(levels.levelProgress(5), 0.5);
      expect(levels.goalProgress(75), 0.5);
    });

    test('gravity accelerates and master is instant', () {
      final marathon = modeConfigs[GameMode.marathon]!;
      expect(marathon.gravityForLevel(1) > marathon.gravityForLevel(10), isTrue);
      expect(modeConfigs[GameMode.master]!.gravityForLevel(1), Duration.zero);
    });

    test('sprint and ultra do not level up', () {
      for (final mode in [GameMode.sprint, GameMode.ultra]) {
        final config = modeConfigs[mode]!;
        final levels = LevelSystem(config);
        expect(config.maxLevel, config.startingLevel);
        expect(levels.levelFor(100), config.startingLevel);
      }
    });
  });

  group('mode-specific engine behaviour', () {
    test('reaching the line goal ends the game with victory', () {
      final engine = TetrisEngine(
        mode: testMode(mode: GameMode.marathon, goalValue: 1),
        seededPieces: [PieceType.o, PieceType.t],
      );
      engine.start();
      final board = emptyBoard();
      for (var x = 0; x < 10; x++) {
        if (x != 3 && x != 4) board[19][x] = PieceType.j;
      }
      engine.loadBoard(board);
      engine.hardDrop();

      expect(engine.status, TetrisStatus.victory);
      expect(engine.isVictory, isTrue);
      expect(engine.activePiece, isNull);
    });

    test('time-limited mode ends with timeUp', () {
      final engine = TetrisEngine(
        mode: testMode(
          mode: GameMode.ultra,
          goalType: GoalType.time,
          timeLimit: const Duration(seconds: 1),
        ),
      );
      engine.start();
      expect(engine.remainingTime, const Duration(seconds: 1));

      engine.tick(const Duration(milliseconds: 999));
      expect(engine.status, TetrisStatus.playing);
      engine.tick(const Duration(milliseconds: 2));
      expect(engine.status, TetrisStatus.timeUp);
      expect(engine.remainingTime, Duration.zero);
    });

    test('instant gravity lands pieces at the bottom', () {
      final engine = TetrisEngine(
        mode: testMode(mode: GameMode.master, instantGravity: true),
        seededPieces: [PieceType.i],
      );
      engine.start();
      expect(engine.activePiece!.y, greaterThanOrEqualTo(15));
    });

    test('zen recovers from a top out instead of ending', () {
      final board = emptyBoard();
      for (var y = 0; y < 20; y++) {
        for (var x = 0; x < 10; x++) {
          board[y][x] = PieceType.j;
        }
      }
      final engine = TetrisEngine(
        mode: testMode(mode: GameMode.zen, topOutEndsGame: false),
      );
      engine.loadBoard(board);
      engine.start(clearBoard: false);

      expect(engine.status, TetrisStatus.playing);
      expect(engine.cellAt(0, 0), isNull);
    });

    test('hold swaps once per piece', () {
      final engine = TetrisEngine(
        mode: testMode(mode: GameMode.tactics, allowHold: true),
        seededPieces: [PieceType.o, PieceType.t, PieceType.i],
        previewCount: 2,
      );
      engine.start();
      final first = engine.activePiece!.type;

      expect(engine.hold(), isTrue);
      expect(engine.holdPiece, first);
      expect(engine.activePiece!.type, PieceType.t);
      expect(engine.canHold, isFalse);
      expect(engine.hold(), isFalse);
    });

    test('combo scoring pays out on consecutive clears', () {
      final engine = TetrisEngine(
        mode: testMode(mode: GameMode.tactics, comboScoring: true),
        seededPieces: List.filled(8, PieceType.o),
      );
      final board = emptyBoard();
      for (var x = 0; x < 10; x++) {
        if (x != 3 && x != 4) board[19][x] = PieceType.j;
      }
      engine.start();
      engine.loadBoard(board);
      engine.hardDrop();
      expect(engine.combo, 0);

      final board2 = emptyBoard();
      for (var x = 0; x < 10; x++) {
        if (x != 3 && x != 4) board2[19][x] = PieceType.j;
      }
      engine.loadBoard(board2);
      engine.hardDrop();
      expect(engine.combo, 1);
    });
  });

  group('placement advisor', () {
    test('finds the vertical I placement that clears four lines', () {
      final board = emptyBoard();
      for (var y = 16; y < 20; y++) {
        for (var x = 1; x < 10; x++) {
          board[y][x] = PieceType.j;
        }
      }
      final engine = TetrisEngine(seededPieces: [PieceType.i]);
      engine.start();
      engine.loadBoard(board);
      engine.placeActivePiece(ActivePiece(PieceType.i));

      final advisor = PlacementAdvisor();
      final best = advisor.suggest(engine);
      expect(best, isNotNull);
      expect(best!.features.lines, 4);
      expect(best.type, PieceType.i);
      expect(best.rationale, contains('Tetris'));

      final ranked = advisor.rank(engine, limit: 3);
      expect(ranked, hasLength(3));
      for (var i = 1; i < ranked.length; i++) {
        expect(ranked[i - 1].score >= ranked[i].score, isTrue);
      }
    });

    test('penalizes creating holes on an empty board', () {
      final engine = TetrisEngine(seededPieces: [PieceType.s]);
      engine.start();
      final placements = const PlacementAdvisor().rank(engine, limit: 10);
      expect(placements, isNotEmpty);
      // The S piece's flat landing has one inherent overhang hole; the
      // advisor should still prefer it over deeper, rougher placements.
      expect(placements.first.features.holes, lessThanOrEqualTo(1));
      expect(placements.every((p) => p.score.isFinite), isTrue);
    });
  });

  group('game flow', () {
    test('menu navigation wraps and confirms the selected mode', () {
      ModeConfig? started;
      final flow = GameFlow(onStart: (mode) => started = mode);
      expect(flow.isMenu, isTrue);
      expect(flow.selectedMode.mode, GameMode.marathon);

      flow.move(-1);
      expect(flow.selectedMode.mode, GameMode.tactics);
      flow.confirm();
      expect(started, allModes.last);
    });

    test('syncs engine status and records best score', () {
      final flow = GameFlow();
      flow.state = FlowState.playing;
      final engine = TetrisEngine(seededPieces: [PieceType.o, PieceType.t]);
      engine.start();
      engine.pause();
      flow.sync(engine);
      expect(flow.isPaused, isTrue);

      engine.resume();
      flow.sync(engine);
      expect(flow.isPlaying, isTrue);
      flow.recordBest(engine);
      expect(flow.bestScores[GameMode.marathon], 0);
    });
  });
}
