# Flutris Engine Reference

This document describes the game engine for Flutris: its architecture, rules,
public API and how to extend it. For a short UI-wiring cheat sheet see
[`lib/game/ENGINE.md`](lib/game/ENGINE.md).

---

## 1. Overview

Flutris separates **rules** from **presentation**:

- The **rules engine** (`TetrisEngine`) is pure Dart. It owns the board, pieces,
  timing, scoring and goals. It knows nothing about Flutter or Flame widgets.
- The **flow controller** (`GameFlow`) is pure Dart. It owns menu/play/pause/end
  navigation and per-mode best scores.
- The **Flame layer** (`FlutrisGame` + components) drives the engine from
  `update(dt)`, renders it, handles keyboard input, and forwards on-screen
  button presses.
- The **placement advisor** (`PlacementAdvisor`) is a pure-Dart planner used for
  the in-game hint panel. It never mutates game state.

This split means the engine can be tested with plain unit tests, reused for
replays/simulations, and driven by any renderer (Flame, Flutter widgets, or a
headless bot).

### Architecture

```
Widgets (handheld shell)  ──buttons──▶  FlutrisGame
                                          │  (FlameGame, update/render loop)
                    ┌─────────────────────┼──────────────────────┐
                    ▼                     ▼                      ▼
              GameFlow             TetrisEngine          PlacementAdvisor
            (menu / HUD)         (rules + state)          (hint scoring)
                    │                     │
                    └──── FlowOverlay ────┴──── BoardComponent / Effects
                              (Flame canvas)
```

---

## 2. File map

| File | Purpose |
| --- | --- |
| `lib/game/tetromino.dart` | `PieceType`, `ActivePiece`, spawn cells, generated rotations, SRS kick tables, colors, `Cell` typedef |
| `lib/game/piece_bag.dart` | 7-bag randomizer with `next()` / `peek()` |
| `lib/game/game_mode.dart` | `GameMode`, `GoalType`, `ModeConfig`, `modeConfigs`, `allModes` |
| `lib/game/level_system.dart` | `LevelSystem` — progression, gravity/lock curves, goal progress |
| `lib/game/tetris_engine.dart` | `TetrisStatus`, `TetrisEvent`, `TetrisSnapshot`, `TetrisEngine` |
| `lib/game/placement_advisor.dart` | `BoardFeatures`, `Placement`, `AdvisorWeights`, `PlacementAdvisor` |
| `lib/game/game_flow.dart` | `FlowState`, `GameFlow` |
| `lib/game/palette.dart` | `BoardPalette`, `lcdPalette`, `colorPalette` |
| `lib/game/components/board_component.dart` | Flame board renderer |
| `lib/game/components/flow_overlay.dart` | Flame menu, HUD, hint and end-screen renderer |
| `lib/game/components/line_clear_effect.dart` | Flame line-clear effects |
| `lib/game/flutris_game.dart` | `FlameGame` integration |
| `lib/game/splash/flame_splash.dart` | Animated Flame splash game |
| `lib/game/tetris.dart` | Barrel export of the pure-Dart API |
| `lib/ui/splash_screen.dart` | Flutter wrapper: splash → UI cross-fade |
| `test/game/` | Unit and widget tests |

---

## 3. Quick start

### Headless engine

```dart
import 'package:flutris/game/tetris.dart';

final engine = TetrisEngine(
  mode: modeConfigs[GameMode.marathon]!,
  seededPieces: [PieceType.o, PieceType.t], // optional determinism for tests
  previewCount: 5,
);

engine.onEvent = (event) => print(event);
engine.onLinesCleared = (rows) => print('cleared $rows');
engine.onChanged = () => print(engine.snapshot.score);

engine.start();
engine.moveLeft();
engine.rotateClockwise();
engine.hardDrop();
engine.tick(const Duration(milliseconds: 16)); // call every frame
```

### Flame game

```dart
final game = FlutrisGame();          // starts at the mode menu
await tester.pumpWidget(GameWidget<FlutrisGame>(game: game));
game.menuDown();                     // highlight Sprint
game.confirm();                      // start it
game.moveLeft();
game.hardDrop();
```

---

## 4. Modes

`GameMode` values and their `ModeConfig` presets:

| Mode | Goal | Level | Gravity | Notable features |
| --- | --- | --- | --- | --- |
| `marathon` | 150 lines → victory | 1 → 15, +1 / 10 lines | classic curve | combos |
| `sprint` | 40 lines → victory | fixed at 5 | classic @ L5 | score ×0.5 |
| `ultra` | 2:00 timer → `timeUp` | fixed at 5 | classic @ L5 | score ×1.5, combos |
| `master` | 300 lines → victory | 15 → 30 (M1→M30) | **20G instant** | lock delay 500→80 ms, score ×2, combos |
| `zen` | none (endless) | 1 → 10 | 1.8× slower | top-out clears the board, hints, score ×0.75 |
| `tactics` | 100 lines → victory | 3 → 15 | classic | hints, hold, combos, 6-piece preview, score ×1.2 |

### `ModeConfig` fields

| Field | Type | Meaning |
| --- | --- | --- |
| `mode` | `GameMode` | Enum identity |
| `name`, `tagline`, `description` | `String` | Menu copy |
| `startingLevel`, `maxLevel` | `int` | Level range |
| `linesPerLevel` | `int` | Lines per level-up (0 disables progression) |
| `goalType` | `GoalType` | `lines`, `time` or `none` |
| `goalValue` | `int?` | Target line count |
| `timeLimit` | `Duration?` | Countdown length |
| `gravityScale` | `double` | Multiplies classic gravity seconds |
| `instantGravity` | `bool` | 20G: pieces land at spawn |
| `startingLockDelayMillis`, `minimumLockDelayMillis` | `int` | Lock-delay range across levels |
| `allowHold`, `allowHints`, `comboScoring` | `bool` | Feature flags |
| `topOutEndsGame` | `bool` | If false, top-out clears the board |
| `scoreMultiplier` | `double` | Multiplies clear points |
| `previewCount` | `int` | Length of the next-piece queue |

`goalLabel` returns a short display string such as `150 LINES`, `2:00`, or
`ENDLESS`.

---

## 5. Levels, gravity and scoring

### Gravity

`ModeConfig.gravityForLevel(level)` uses the classic accelerating curve:

```
base  = clamp(0.8 - (level - 1) * 0.007, 0.2, 1.0)
secs  = base^(level - 1) * gravityScale, clamped to >= 0.04
```

Level 1 is 1000 ms/row; Master overrides this to `Duration.zero` (20G).

### Lock delay

Default 500 ms after a piece lands, with up to 15 resets from successful
moves/rotations. Master shortens it toward 80 ms at M30.

### Scoring

| Action | Points |
| --- | --- |
| Soft drop | 1 per cell |
| Hard drop | 2 per cell |
| Single / Double / Triple / Tetris | 100 / 300 / 500 / 800 × level × mode multiplier |
| Combo (mode flag) | +50 × combo × level |
| Back-to-back tetris or perfect clear (mode flag) | ×1.5 on the clear |
| Perfect clear | +1000 |
| Level up | +1 level per `linesPerLevel` lines |

`best` tracks the high score across resets and is reported through
`TetrisSnapshot.best` and `GameFlow.bestScores`.

---

## 6. `TetrisEngine` API

### Constructor

```dart
TetrisEngine({
  Random? random,            // seeded bag randomness
  int? startingLevel,        // defaults to mode.startingLevel
  int? best,                 // initial best score
  List<PieceType>? seededPieces, // deterministic queue for tests/replays
  int? previewCount,         // defaults to mode.previewCount
  ModeConfig? mode,          // defaults to marathon
});
```

Constants: `columns = 10`, `rows = 20`, `lockDelayMillis = 500`,
`maxLockResets = 15`, `linesPerLevel = 10`, `defaultPreviewCount = 5`.

### Callbacks

| Callback | Signature | Fired when |
| --- | --- | --- |
| `onChanged` | `void Function()` | Any state change (discrete, not every frame) |
| `onLinesCleared` | `void Function(List<int> rows)` | Rows were just cleared (for effects) |
| `onEvent` | `void Function(TetrisEvent event)` | Discrete gameplay event |

`TetrisEvent` values: `start`, `pause`, `resume`, `reset`, `move`, `rotate`,
`softDrop`, `hardDrop`, `lock`, `lineClear`, `levelUp`, `combo`,
`perfectClear`, `hold`, `victory`, `timeUp`, `gameOver`.

### State getters

| Getter | Type | Description |
| --- | --- | --- |
| `status` | `TetrisStatus` | `ready`, `playing`, `paused`, `gameOver`, `victory`, `timeUp` |
| `isPlaying` / `isPaused` / `isGameOver` / `isVictory` / `isTimeUp` / `isFinished` | `bool` | Status shortcuts |
| `score`, `lines`, `level`, `best` | `int` | Stats |
| `elapsed`, `remainingTime` | `Duration` | Clock; `remainingTime` is zero outside timed modes |
| `combo`, `isBackToBack` | `int` / `bool` | Combo state |
| `holdPiece`, `canHold` | `PieceType?` / `bool` | Hold state |
| `linesToNextLevel`, `levelProgress`, `goalProgress` | `int` / `double` / `double` | Progress indicators |
| `activePiece` | `ActivePiece?` | Falling piece (may sit above the board at spawn) |
| `nextPiece`, `upcoming` | `PieceType?` / `List<PieceType>` | Queue head and remainder |
| `activeCells`, `ghostCells` | `List<Cell>` | Absolute board coordinates |
| `lastClearedRows` | `List<int>` | Rows from the most recent lock |
| `snapshot` | `TetrisSnapshot` | Immutable bundle of the above for HUDs |

`cellAt(x, y)` returns the settled `PieceType?` at a coordinate (out of bounds
returns `null`); it excludes the falling piece.

### Lifecycle and input

| Method | Description |
| --- | --- |
| `start({bool clearBoard = true})` | New game; `clearBoard: false` preserves a board loaded via `loadBoard` (replays/restores). Resumes if paused. |
| `reset()` | Back to `ready`, clears board/stats, keeps `best` |
| `pause()`, `resume()`, `togglePause()` | Pause control |
| `moveLeft()`, `moveRight()` | Lateral movement with SRS collision |
| `softDrop()` | Move down one row, +1 point |
| `hardDrop()` | Drop to ghost position, +2/cell, lock immediately |
| `rotateClockwise()`, `rotateCounterClockwise()` | 90° rotations with SRS kicks |
| `hold()` | Swap with held piece once per drop (mode flag required) |
| `tick(Duration delta)` | Advance gravity, lock delay and mode timer |

All input methods return `bool` (except lifecycle/`tick`): `true` when the
action succeeded. `tick` should be called from the render loop with the frame
delta.

### Test/replay helpers

- `loadBoard(List<List<PieceType?>> cells)` — replaces the settled board;
  throws `ArgumentError` for a non-20×10 grid.
- `placeActivePiece(ActivePiece piece)` — injects a specific falling piece for
  scripted scenarios (e.g. wall-kick tests).

### Board coordinates

`Cell` is `Point<int>` with **+x right, +y down**. `(0,0)` is the top-left of
the visible 10×20 well. Spawn is `(3, -1)`, so newly spawned pieces may have
cells above the board; those cells do not collide and are not drawn.

---

## 7. Piece geometry (SRS)

`Tetromino` stores spawn cells and derives the four rotation states by rotating
inside each piece's bounding box: 4×4 for I, 3×3 for J/L/S/T/Z, 2×2 for O.

| Piece | Spawn cells |
| --- | --- |
| I | (0,1)(1,1)(2,1)(3,1) |
| O | (0,0)(1,0)(0,1)(1,1) |
| T | (1,0)(0,1)(1,1)(2,1) |
| S | (1,0)(2,0)(0,1)(1,1) |
| Z | (0,0)(1,0)(1,1)(2,1) |
| J | (0,0)(0,1)(1,1)(2,1) |
| L | (2,0)(0,1)(1,1)(2,1) |

`Tetromino.kicks(type, from, to)` returns SRS wall-kick offsets in priority
order, with Y converted to down-positive screen coordinates. All 90°
transitions for I and JLSTZ have five offsets; 180° transitions and O fall
back to `(0,0)`. `Tetromino.color(type)` exposes a suggested ARGB color;
renderers may ignore it for a monochrome LCD look.

---

## 8. Placement advisor (hints)

`PlacementAdvisor` performs a one-piece search (El-Tetris style):

1. For every distinct rotation and every legal column, straight-drop the piece
   onto a copy of the current board.
2. Measure features **before** removing completed rows.
3. Score the candidate with a linear combination; highest wins.

```dart
final advisor = PlacementAdvisor();          // uses elTetrisWeights
final best = advisor.suggest(engine);         // Placement?
final top5 = advisor.rank(engine, limit: 5);  // best first
```

`Placement` exposes `type`, `rotation`, `x`, `y`, `score`, `features`,
`linesCleared` and a human-readable `rationale` (e.g.
`Tetris (+4 lines) · no holes · flat surface`).

`BoardFeatures` fields: `landingHeight`, `lines`, `holes`, `bumpiness`,
`aggregateHeight`, `rowTransitions`, `columnTransitions`, `wells`.

`AdvisorWeights` defaults (El-Tetris):

| Feature | Weight |
| --- | --- |
| landing height | −4.50 |
| lines | +3.42 |
| row transitions | −3.22 |
| column transitions | −9.35 |
| holes | −7.90 |
| wells | −3.39 |
| bumpiness | −0.18 |

Pass custom `AdvisorWeights` to change the play style. The advisor is used by
`FlowOverlayComponent` for the hint panel; the game refreshes it every 0.25 s
while visible.

---

## 9. Flow and Flame integration

### `GameFlow`

```dart
final flow = GameFlow(
  modes: allModes,
  bestScores: {GameMode.marathon: 12800},
  onStart: (mode) => print('start ${mode.name}'),
);
```

- `state`: `FlowState.menu`, `playing`, `paused`, `gameOver`, `victory`, `timeUp`
- `selected`, `selectedMode`, `isMenu`, `isPlaying`, `isPaused`, `isEndScreen`
- `move(int delta)` wraps the menu cursor; `confirm()` starts the selected mode
  or returns to the menu from an end screen; `toMenu()` forces the menu.
- `sync(TetrisEngine engine)` mirrors engine status into flow state;
  `recordBest(engine)` stores per-mode high scores.

### `FlutrisGame`

```dart
FlutrisGame({
  TetrisEngine? engine,
  BoardPalette palette = lcdPalette,
  bool startInMenu = true,
  bool renderHud = true,
  bool compactMenu = false,
});
```

Public members: `engine`, `flow`, `onStateChanged`, `isHintVisible`, plus input
forwarding. Set `renderHud: false` when Flutter renders a dedicated HUD; assign
`onStateChanged` to refresh that Flutter UI after menu or engine changes. Set
`compactMenu: true` when the Flutter panel already shows selected-mode details.

```dart
game.menuUp(); game.menuDown(); game.confirm(); game.back();
game.moveLeft(); game.moveRight(); game.moveDown(); game.hardDrop();
game.rotate(); game.rotateCounterClockwise(); game.hold();
game.togglePause(); game.restart(); game.toggleHint();
```

Keyboard map:

| Key(s) | Action |
| --- | --- |
| Menu: ↑/↓ | Move cursor |
| Menu: Enter / Space / Z | Confirm |
| ←/→ or A/D | Move (with DAS-style repeat) |
| ↓ | Soft drop |
| ↑ or X | Hard drop |
| Space / Z | Rotate clockwise |
| Q | Rotate counterclockwise |
| C / Shift | Hold |
| H | Toggle hint panel |
| P / Esc | Pause |
| R | Restart |

The game swaps in a fresh mode-specific engine when a mode is chosen, rewires
callbacks, and updates the board/overlay engine references.

---

## 10. Testing

```sh
flutter analyze
flutter test test/game        # engine, modes, advisor, flow, Flame integration
flutter test                 # includes the handheld UI layout tests
```

Test files:

- `tetromino_test.dart` — geometry, rotation normalization, SRS kick coverage
- `piece_bag_test.dart` — 7-bag distribution and peek semantics
- `tetris_engine_test.dart` — lifecycle, movement, gravity, lock delay, clears, scoring, events
- `modes_test.dart` — all modes, levels, victory/time-up/20G/Zen/hold/combos, advisor, flow
- `flutris_game_test.dart` — game widget loads, menu navigation, input forwarding

Deterministic tests use `seededPieces`, `previewCount`, `loadBoard` and
`placeActivePiece` rather than random seeds.

---

## 11. Extending the engine

### Add a mode

1. Add a `GameMode` value in `game_mode.dart`.
2. Add a `ModeConfig` entry to `modeConfigs` and `allModes`.
3. If it needs new rules, extend `TetrisEngine` with a feature flag or a
   dedicated check (e.g. garbage rows would be a timed board mutation in
   `tick`); keep rules out of the renderer.
4. Add tests for its goal, speed and feature flags.

### Change scoring

Adjust the clear table in `TetrisEngine._lockPiece()` and document it here.
Keep `best` updates through `_addScore()` so records stay correct.

### Persist best scores

`GameFlow.bestScores` is in-memory. Inject a prefilled map at startup and
write it back when `recordBest()` changes a value.

### Replace hint logic

Pass custom `AdvisorWeights` to `PlacementAdvisor`, then supply that advisor
to `FlowOverlayComponent`'s constructor.

---

## 12. Splash screen

`FlutrisApp` shows `SplashScreen` on launch (disable with
`FlutrisApp(showSplash: false)` in tests). `SplashScreen` hosts a
`FlameSplash` game and cross-fades to `HandheldScreen` when it finishes.

`FlameSplash` is a `FlameGame` with a virtual 288×288 scene scaled to any
canvas. Its motion uses Flame effects/controllers throughout:

- staggered dot-matrix reveal (`ScaleEffect` with staggered `startDelay`)
- logo scale-in with `Curves.easeOutBack`
- infinite moving scanline (`MoveEffect` + `InfiniteEffectController`)
- progress bar filling via `SizeEffect`
- boot text lines appearing in sequence

The splash completes after `duration` (default 2.6 s) via `TimerComponent`,
fires `onFinished` once, and can be skipped by tapping (the overlay
`GestureDetector` sits above the `GameWidget` so it receives taps). A fallback
`Timer` in `SplashScreen` guarantees the transition if the game loop is
paused by the platform.

## 13. Haptic and sound feedback

`lib/feedback/` contains a single `FeedbackService` shared by the UI buttons
and the game engine:

- `feedback_cue.dart` maps each cue to a WAV asset, a `HapticFeedback` style,
  a volume and an optional anti-spam throttle. `FeedbackCue.forEvent()` maps
  `TetrisEvent` values to cues (a 4-line clear becomes the Tetris cue).
- `feedback_service.dart` owns the enable flags, fire-and-forget playback and
  platform-error guards. Audio is silent until `preload()` succeeds; the game
  calls it fire-and-forget in `onLoad` so loading is never blocked.
- Every tactile `_ConsoleButton` calls `FeedbackService.instance.press()`.
- `FlutrisGame` forwards engine events through `FeedbackCue.forEvent()` and
  plays `navigate` / `press` cues for keyboard menu input.
- Toggle sound at runtime with `FeedbackService.instance.toggleSound()` or the
  **M** key; `toggleHaptics()` disables vibration independently.

Assets live in `assets/audio/` and are short procedurally generated WAVs
(22.05 kHz mono). New cues: add a WAV and a `FeedbackCue` constant.

## 14. Current limitations

- No audio: `onEvent` is the hook for a future sound layer (e.g. `flame_audio`).
- No hold/preview rendering in `BoardComponent` yet; the HUD shows mode,
  level, lines, timer and hints, and the handheld UI owns the NEXT preview.
- No garbage/attack modes, no online play, no replay serialization.
- The placement advisor is one-piece and considers straight drops only (the
  standard El-Tetris trade-off); it does not plan multiple pieces ahead.
