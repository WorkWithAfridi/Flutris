# Core engine integration notes

> For the full API reference, architecture and extension guide, see
> [`ENGINE.md`](../../ENGINE.md) at the project root.

The game logic is split into a pure-Dart rules engine, a pure-Dart flow state
machine, and a thin Flame layer. UI code should never reimplement board rules
or menus — forward input to the game and read its state.

## Files

- `tetromino.dart` — pieces, spawn cells, rotations, SRS kicks, colors.
- `piece_bag.dart` — 7-bag randomizer.
- `game_mode.dart` — six `ModeConfig`s (Marathon, Sprint, Ultra, Master, Zen,
  Tactics) with goals, speed curves and feature flags.
- `level_system.dart` — level progression, gravity/lock curves, goal progress.
- `tetris_engine.dart` — board, gravity, lock delay, collision, line clearing,
  scoring, combos, hold, goals, events. Pure Dart.
- `placement_advisor.dart` — El-Tetris-style one-piece planner for hints.
- `game_flow.dart` — menu/playing/paused/end state machine and best scores.
- `palette.dart` — LCD and color board palettes.
- `components/board_component.dart` — Flame board renderer.
- `components/flow_overlay.dart` — Flame-rendered menu, HUD, hint, end screens.
- `components/line_clear_effect.dart` — Flame line-clear effects.
- `flutris_game.dart` — `FlameGame` owning flow + engine, `update(dt)` loop,
  keyboard input and the render tree.

## Modes

| Mode | Goal | Notes |
| --- | --- | --- |
| Marathon | 150 lines | L1→L15, +level every 10 lines |
| Sprint 40 | 40 lines | Fixed level 5, race the clock |
| Ultra 2:00 | 2 minutes | Fixed level 5, score attack |
| Master | 300 lines | 20G instant gravity, M1→M30, shortening lock delay |
| Zen | endless | Slow gravity, top-out clears the board instead of ending |
| Tactics | 100 lines | Hints, hold, combos, 6-piece preview |

## Wiring the handheld buttons

The start menu and board are rendered **inside the Flame canvas**. A Flutter
shell can render its own HUD beside the board. `GameWidget.controlled` does not
expose the game instance; hold one in the widget's `State` and use the regular
constructor:

```dart
late final FlutrisGame game;

@override
void initState() {
  super.initState();
  game = FlutrisGame(renderHud: false, compactMenu: true);
  game.onStateChanged = () => setState(() {}); // refresh a Flutter HUD
}

@override
Widget build(BuildContext context) => GameWidget<FlutrisGame>(game: game);
```

Forward the existing buttons conditionally:

```dart
if (game.flow.isMenu) {
  // D-pad up/down
  game.menuUp();
  game.menuDown();
  // A button
  game.confirm();
  // B button
  game.back();
} else if (game.flow.isEndScreen) {
  game.confirm(); // back to menu
} else {
  game.moveLeft();   // ←
  game.moveRight();  // →
  game.moveDown();   // ↓ soft drop
  game.hardDrop();   // ↑ / B
  game.rotate();     // A
  game.hold();       // C / Shift (Tactics and modes with hold)
  game.toggleHint(); // H (Tactics/Zen)
  game.togglePause();
}
```

The game already tracks per-mode best scores in `game.flow.bestScores`.

## Keyboard

- Menu: ↑/↓ select, Enter/Space/Z confirm.
- Play: ←/→ (DAS repeat), ↓ soft drop, ↑/X hard drop, Space/Z rotate,
  Q rotate CCW, C/Shift hold, H hint, P/Esc pause, R restart.

## Smart hints

`PlacementAdvisor.rank(engine)` evaluates every rotation × column by dropping
the piece and scoring the resulting board with El-Tetris features (landing
height, lines, row/column transitions, holes, wells, bumpiness). Toggle the
in-canvas hint panel with H; it refreshes every 0.25 s and explains its pick
(e.g. `Tetris (+4 lines) · no holes · flat surface`).

## Scoring

Soft drop 1/cell, hard drop 2/cell. Clears 100/300/500/800 × level × mode
multiplier. Combos +50 × combo/level, back-to-back tetrises ×1.5, perfect
clear +1000. Level +1 every 10 lines until the mode cap.
