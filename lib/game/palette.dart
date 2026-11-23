import 'dart:ui' show Color;

/// Colors used by the Flame board renderer. Kept separate from the rules
/// engine so the UI can swap themes without touching game logic.
class BoardPalette {
  const BoardPalette({
    required this.background,
    required this.field,
    required this.grid,
    required this.ink,
    required this.highlight,
    required this.ghost,
    required this.flash,
    this.coloredPieces = false,
  });

  final Color background;
  final Color field;
  final Color grid;
  final Color ink;
  final Color highlight;
  final Color ghost;
  final Color flash;
  final bool coloredPieces;
}

/// Monochrome Game Boy style palette matching the handheld shell prototype.
const lcdPalette = BoardPalette(
  background: Color(0xFFACBD94),
  field: Color(0xFFB5C49D),
  grid: Color(0x15354839),
  ink: Color(0xFF354839),
  highlight: Color(0xFFA1B28A),
  ghost: Color(0x66354839),
  flash: Color(0xFFF3F0D8),
);

/// Classic colorful tetromino palette.
const colorPalette = BoardPalette(
  background: Color(0xFF1D1B2E),
  field: Color(0xFF14131F),
  grid: Color(0x18FFFFFF),
  ink: Color(0xFFFFFFFF),
  highlight: Color(0xFFFFFFFF),
  ghost: Color(0x55FFFFFF),
  flash: Color(0xFFFFF4B0),
  coloredPieces: true,
);
