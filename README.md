# Flutris

A Flutter + Flame Tetris game with a handheld console UI, six game modes and
an animated splash screen.

## Getting started

```sh
flutter pub get
flutter run
```

To choose a device, run `flutter devices`, then `flutter run -d <device-id>`.

## Features

- Six modes: Marathon (150 lines), Sprint 40, Ultra 2:00, Master (20G),
  Zen (endless, no top-out loss) and Tactics (hints, hold, combos).
- SRS rotation with wall kicks, ghost piece, lock delay, 7-bag randomizer,
  combos, back-to-back bonuses and perfect clears.
- Animated Flame splash with tap-to-skip, followed by a responsive handheld
  shell with a dot-matrix LCD, D-pad, A/B buttons and haptics.
- Planning hints powered by a one-piece placement advisor (El-Tetris heuristics).
- Keyboard controls for desktop/web; on-screen buttons forward to the same API.

## Project structure

- `lib/main.dart`: Flutter entry point; shows the splash then the handheld UI.
- `lib/game/splash/flame_splash.dart`: animated Flame splash game.
- `lib/ui/splash_screen.dart`: splash → UI cross-fade wrapper.
- `lib/ui/handheld_screen.dart`: responsive console shell and controls.
- `lib/game/flutris_game.dart`: Flame game hosting the engine and menu.
- `lib/game/components/`: board renderer, flow overlay and line-clear effects.
- `lib/game/`: pure-Dart rules engine, modes, levels, advisor and flow.
- `ENGINE.md`: full engine reference. `lib/game/ENGINE.md`: UI wiring notes.

## Checks

```sh
flutter analyze
flutter test
```
