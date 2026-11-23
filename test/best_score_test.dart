import 'package:flutris/game/tetris.dart';
import 'package:flutris/persistence/best_score_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('store persists per-mode bests across a reload', () async {
    final store = BestScoreStore.instance;
    await store.reload();
    expect(store.scores, isEmpty);

    await store.save(GameMode.marathon, 12800);
    await store.save(GameMode.sprint, 4300);

    await store.reload();
    expect(store.scores[GameMode.marathon], 12800);
    expect(store.scores[GameMode.sprint], 4300);
  });

  test('flow notifies when a new best is recorded', () {
    GameMode? savedMode;
    var savedScore = 0;
    final flow = GameFlow(
      onBestChanged: (mode, score) {
        savedMode = mode;
        savedScore = score;
      },
    );
    final engine = TetrisEngine(seededPieces: [PieceType.o]);
    engine.start();
    engine.hardDrop();

    flow.recordBest(engine);

    expect(flow.bestScores[GameMode.marathon], engine.score);
    expect(savedMode, GameMode.marathon);
    expect(savedScore, engine.score);
  });

  test('best survives a simulated app restart', () async {
    final store = BestScoreStore.instance;
    await store.reload();

    final engine = TetrisEngine(seededPieces: [PieceType.o]);
    engine.start();
    engine.hardDrop();

    final flow = GameFlow(
      bestScores: Map<GameMode, int>.of(store.scores),
      onBestChanged: (mode, score) => store.save(mode, score),
    );
    flow.recordBest(engine);

    // Simulate a fresh boot: new flow seeded from the store.
    await store.reload();
    final restarted = GameFlow(
      bestScores: Map<GameMode, int>.of(store.scores),
    );
    expect(restarted.bestScores[GameMode.marathon], engine.score);
  });
}
