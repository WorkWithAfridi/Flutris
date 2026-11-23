import 'dart:math' as math;

import 'package:flame/game.dart' show GameWidget;
import 'package:flutter/widgets.dart';

import '../feedback/feedback_service.dart';
import '../game/flutris_game.dart';
import '../game/tetris.dart';

const _ink = Color(0xFF302449);

/// A full-screen handheld shell with a Flame game display and tactile controls.
class HandheldScreen extends StatefulWidget {
  const HandheldScreen({super.key});

  @override
  State<HandheldScreen> createState() => _HandheldScreenState();
}

class _HandheldScreenState extends State<HandheldScreen> {
  late final FlutrisGame _game;

  @override
  void initState() {
    super.initState();
    _game = FlutrisGame(renderHud: false, compactMenu: true);
    _game.onStateChanged = _refreshFromGame;
  }

  @override
  void dispose() {
    _game.onStateChanged = null;
    _game.engine.onChanged = null;
    super.dispose();
  }

  String _lastUiSignature = '';
  bool _refreshScheduled = false;

  /// Only the values actually shown by this widget belong here. Engine events
  /// fire several times per second; rebuilding for every one of them is what
  /// made rapid button presses feel laggy.
  String get _uiSignature {
    final engine = _game.engine;
    final flow = _game.flow;
    return '${flow.state.index}|${flow.selected}|${engine.status.index}|'
        '${engine.score}|${engine.lines}|${engine.level}|${engine.combo}|'
        '${engine.holdPiece?.index ?? -1}|${engine.canHold}|'
        '${_game.isHintVisible}|${engine.mode.mode.index}|'
        '${flow.bestScores[engine.mode.mode] ?? 0}';
  }

  void _refreshFromGame() {
    if (!mounted || _refreshScheduled) return;
    _refreshScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshScheduled = false;
      if (!mounted) return;
      final signature = _uiSignature;
      if (signature == _lastUiSignature) return;
      _lastUiSignature = signature;
      setState(() {});
    });
  }

  bool get _hintsAvailable =>
      _game.flow.isPlaying && _game.engine.mode.allowHints;

  @override
  Widget build(BuildContext context) {
    _lastUiSignature = _uiSignature;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final insets = MediaQuery.viewPaddingOf(context);
        final horizontal = math.min(18.0, width * .055);
        final usableHeight = height - insets.top - insets.bottom;
        final widthScale = (width - horizontal * 2) / 288;
        final heightScale = (usableHeight - 170) / 230;
        final controlsScale = math.min(widthScale, heightScale).clamp(.58, 1.0);

        return ColoredBox(
          color: const Color(0xFF382D46),
          child: Stack(
            fit: StackFit.expand,
            children: [
              const IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xBFDCCAF0),
                        Color(0xA67F659E),
                        Color(0xB27A6196),
                      ],
                      stops: [0, .48, 1],
                    ),
                  ),
                ),
              ),
              const IgnorePointer(
                child: CustomPaint(painter: _GlassSheenPainter()),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  horizontal,
                  math.max(10, insets.top + 8),
                  horizontal,
                  math.max(12, insets.bottom + 8),
                ),
                child: Column(
                  children: [
                    _header(),
                    SizedBox(height: 9 * controlsScale),
                    Expanded(child: _display()),
                    SizedBox(height: 12 * controlsScale),
                    _controls(controlsScale),
                    SizedBox(height: 8 * controlsScale),
                    _smallControls(controlsScale),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _header() => Row(
    children: [
      const Text(
        'flutris',
        style: TextStyle(
          fontSize: 21,
          fontWeight: FontWeight.w900,
          fontStyle: FontStyle.italic,
          letterSpacing: -1.2,
          color: _ink,
        ),
      ),
      const Spacer(),
      Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _statusColor,
          boxShadow: [
            BoxShadow(color: _statusColor.withValues(alpha: .5), blurRadius: 8),
          ],
        ),
      ),
      const SizedBox(width: 7),
      _Label(_statusLabel, size: 8, spacing: 1.5),
    ],
  );

  Color get _statusColor => _game.flow.isPaused || _game.flow.isEndScreen
      ? const Color(0xFFCB7B63)
      : const Color(0xFF9ACD7E);

  String get _statusLabel => switch (_game.flow.state) {
    FlowState.menu => 'READY',
    FlowState.playing => 'PLAYING',
    FlowState.paused => 'PAUSED',
    FlowState.gameOver => 'GAME OVER',
    FlowState.victory => 'VICTORY',
    FlowState.timeUp => 'TIME UP',
  };

  Widget _smallControls(double scale) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(width: 46 * scale),
      _smallControl(
        !_hintsAvailable
            ? 'NO HINT'
            : _game.isHintVisible
            ? 'HINT ON'
            : 'HINT',
        _hintsAvailable ? 'Toggle placement hint' : 'Hints unavailable',
        _game.toggleHint,
        scale,
        enabled: _hintsAvailable,
      ),
      SizedBox(width: 12 * scale),
      _smallControl(
        _game.engine.canHold ? 'HOLD READY' : 'HOLD',
        'Hold piece',
        _game.hold,
        scale,
        enabled: _game.engine.canHold,
      ),
      SizedBox(width: 12 * scale),
      _smallControl(
        _pauseControlLabel,
        _pauseControlSemantics,
        _pauseControl,
        scale,
      ),
      const Spacer(),
      Padding(
        padding: EdgeInsets.only(top: 12 * scale),
        child: CustomPaint(
          size: Size(75 * scale, 48 * scale),
          painter: const _SpeakerPainter(),
        ),
      ),
      SizedBox(width: 5 * scale),
    ],
  );

  String get _pauseControlLabel => switch (_game.flow.state) {
    FlowState.menu => 'START',
    FlowState.paused => 'RESUME',
    FlowState.gameOver || FlowState.victory || FlowState.timeUp => 'MENU',
    FlowState.playing => 'PAUSE',
  };

  String get _pauseControlSemantics => switch (_game.flow.state) {
    FlowState.menu => 'Start selected mode',
    FlowState.paused => 'Resume game',
    FlowState.gameOver ||
    FlowState.victory ||
    FlowState.timeUp => 'Return to menu',
    FlowState.playing => 'Pause game',
  };

  VoidCallback get _pauseControl => switch (_game.flow.state) {
    FlowState.menu => _game.confirm,
    FlowState.paused || FlowState.playing => _game.togglePause,
    FlowState.gameOver ||
    FlowState.victory ||
    FlowState.timeUp => _game.confirm,
  };

  Widget _display() => SizedBox.expand(
    child: Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 13),
      decoration: BoxDecoration(
        color: const Color(0xFF302D3E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF493E53), width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x40816A9B),
            offset: Offset(0, 4),
            blurRadius: 0,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 5,
                height: 5,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFAED590),
                  boxShadow: [
                    BoxShadow(color: Color(0x669ADD79), blurRadius: 5),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const _Label(
                'BATTERY',
                size: 7,
                spacing: 1.5,
                color: Color(0xFFADA6BC),
              ),
              const Spacer(),
              const _Label(
                'DOT MATRIX DISPLAY',
                size: 7,
                spacing: 1.2,
                color: Color(0xFFADA6BC),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFFB5C49D),
                border: Border.all(color: const Color(0xFF171E20), width: 3),
              ),
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Column(
                      children: [
                        _lcdHeader(),
                        Expanded(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                flex: 58,
                                child: ClipRect(
                                  child: GameWidget<FlutrisGame>(game: _game),
                                ),
                              ),
                              Container(
                                width: 1,
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                color: _ink.withValues(alpha: .24),
                              ),
                              Expanded(
                                flex: 42,
                                child: _enginePanel(
                                  constraints.maxWidth * .42 - 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 11),
          const _Label(
            'FLUTRIS  •  POCKET EDITION',
            size: 6,
            color: Color(0xFFADA6BC),
          ),
        ],
      ),
    ),
  );

  Widget _lcdHeader() {
    final flow = _game.flow;
    final modeName = flow.isMenu ? 'MODE SELECT' : _game.engine.mode.name;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 7, 8, 2),
      child: Row(
        children: [
          const _Label('FLUTRIS', size: 10, spacing: 1.2),
          const Spacer(),
          _Label(modeName, size: 7, spacing: .6),
        ],
      ),
    );
  }

  Widget _enginePanel(double width) {
    final flow = _game.flow;
    final engine = _game.engine;
    if (flow.isMenu) {
      final mode = flow.selectedMode;
      return Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 6, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _metric('MODE', mode.name, width),
            const SizedBox(height: 12),
            _metric('GOAL', mode.goalLabel, width),
            const SizedBox(height: 12),
            _metric('BEST', _scoreText(flow.bestScores[mode.mode] ?? 0), width),
            const SizedBox(height: 18),
            Text(
              mode.tagline,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 7,
                letterSpacing: .7,
                color: _ink,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              mode.description,
              style: const TextStyle(fontSize: 7, height: 1.35, color: _ink),
            ),
            const Spacer(),
            const Text(
              'D-PAD SELECT\nA TO START',
              style: TextStyle(
                fontSize: 6,
                height: 1.5,
                letterSpacing: .4,
                color: _ink,
              ),
            ),
          ],
        ),
      );
    }

    final best = math.max(engine.best, flow.bestScores[engine.mode.mode] ?? 0);
    final time = engine.mode.timeLimit == null
        ? engine.elapsed
        : engine.remainingTime;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 6, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _metric('SCORE', _scoreText(engine.score), width),
          const SizedBox(height: 8),
          _metric('BEST', _scoreText(best), width),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _metric('LEVEL', _levelText(engine), width / 2)),
              Expanded(child: _metric('LINES', '${engine.lines}', width / 2)),
            ],
          ),
          const SizedBox(height: 8),
          _Label(
            engine.mode.goalType == GoalType.time ? 'TIME LEFT' : 'TIME',
            size: 6,
            spacing: .5,
          ),
          Text(
            _durationText(time),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: _ink,
            ),
          ),
          const SizedBox(height: 8),
          const _Label('NEXT', size: 6, spacing: .7),
          Expanded(
            child: Center(
              child: _PiecePreview(
                type: engine.nextPiece,
                width: math.min(width - 18, 54),
                height: 48,
              ),
            ),
          ),
          Row(
            children: [
              const _Label('HOLD', size: 6, spacing: .6),
              const Spacer(),
              if (engine.holdPiece != null)
                _PiecePreview(
                  type: engine.holdPiece,
                  width: math.min(width * .5, 32),
                  height: 26,
                )
              else
                const _Label('—', size: 8),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metric(String label, String value, double width) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _Label(label, size: 6, spacing: .6),
      const SizedBox(height: 2),
      SizedBox(
        width: math.max(0.0, width - 4),
        child: FittedBox(
          alignment: Alignment.centerLeft,
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            maxLines: 1,
            style: const TextStyle(
              fontSize: 13,
              letterSpacing: .5,
              fontWeight: FontWeight.w800,
              color: _ink,
            ),
          ),
        ),
      ),
    ],
  );

  String _scoreText(int score) => score.toString().padLeft(6, '0');

  String _levelText(TetrisEngine engine) => engine.mode.mode == GameMode.master
      ? 'M${engine.level - engine.mode.startingLevel + 1}'
      : engine.level.toString().padLeft(2, '0');

  String _durationText(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  String get _upSemantics => _game.flow.isMenu ? 'Previous mode' : 'Hard drop';
  String get _downSemantics => _game.flow.isMenu ? 'Next mode' : 'Soft drop';
  String get _leftSemantics =>
      _game.flow.isMenu ? 'Previous mode' : 'Move left';
  String get _rightSemantics => _game.flow.isMenu ? 'Next mode' : 'Move right';
  String get _aCaption => _game.flow.isMenu
      ? 'START'
      : _game.flow.isEndScreen
      ? 'MENU'
      : 'ROTATE';
  String get _aSemantics =>
      _game.flow.isMenu || _game.flow.isEndScreen ? 'Confirm' : 'Rotate piece';
  String get _bCaption => _game.flow.isMenu
      ? 'NEXT'
      : _game.flow.isEndScreen
      ? 'MENU'
      : 'DROP';
  String get _bSemantics => _game.flow.isMenu
      ? 'Next mode'
      : _game.flow.isEndScreen
      ? 'Return to menu'
      : 'Drop piece';

  VoidCallback get _upAction => _game.flow.isMenu
      ? _game.menuUp
      : _game.flow.isEndScreen
      ? _game.confirm
      : _game.hardDrop;

  VoidCallback get _downAction => _game.flow.isMenu
      ? _game.menuDown
      : _game.flow.isEndScreen
      ? _game.confirm
      : _game.moveDown;

  VoidCallback get _leftAction =>
      _game.flow.isMenu ? _game.menuUp : _game.moveLeft;

  VoidCallback get _rightAction =>
      _game.flow.isMenu ? _game.menuDown : _game.moveRight;

  VoidCallback get _aAction => _game.flow.isMenu || _game.flow.isEndScreen
      ? _game.confirm
      : _game.rotate;

  VoidCallback get _bAction => _game.flow.isMenu
      ? _game.menuDown
      : _game.flow.isEndScreen
      ? _game.confirm
      : _game.hardDrop;

  Widget _controls(double scale) {
    final dpadSize = 135 * scale;
    final stemSize = 41 * scale;
    final stemPosition = (dpadSize - stemSize) / 2;

    return SizedBox(
      height: dpadSize,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          SizedBox(
            width: dpadSize,
            height: dpadSize,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _ink.withValues(alpha: .09),
                border: Border.all(color: const Color(0x66533E68)),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: stemSize,
                    height: stemSize,
                    color: const Color(0xFF302D39),
                  ),
                  Positioned(
                    top: 9 * scale,
                    left: stemPosition,
                    child: _direction(
                      _upSemantics,
                      '↑',
                      const BorderRadius.vertical(top: Radius.circular(6)),
                      scale,
                      _upAction,
                    ),
                  ),
                  Positioned(
                    bottom: 9 * scale,
                    left: stemPosition,
                    child: _direction(
                      _downSemantics,
                      '↓',
                      const BorderRadius.vertical(bottom: Radius.circular(6)),
                      scale,
                      _downAction,
                    ),
                  ),
                  Positioned(
                    left: 9 * scale,
                    top: stemPosition,
                    child: _direction(
                      _leftSemantics,
                      '←',
                      const BorderRadius.horizontal(left: Radius.circular(6)),
                      scale,
                      _leftAction,
                    ),
                  ),
                  Positioned(
                    right: 9 * scale,
                    top: stemPosition,
                    child: _direction(
                      _rightSemantics,
                      '→',
                      const BorderRadius.horizontal(right: Radius.circular(6)),
                      scale,
                      _rightAction,
                    ),
                  ),
                  Container(
                    width: 16 * scale,
                    height: 16 * scale,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF24222E),
                      border: Border.all(color: const Color(0xFF51475E)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(
            width: 153 * scale,
            child: Transform.rotate(
              angle: -.22,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _actionButton('B', _bCaption, _bSemantics, scale, _bAction),
                  _actionButton('A', _aCaption, _aSemantics, scale, _aAction),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _direction(
    String label,
    String glyph,
    BorderRadius radius,
    double scale,
    VoidCallback onTap,
  ) => _ConsoleButton(
    label: label,
    width: 41 * scale,
    height: 41 * scale,
    radius: radius,
    onTap: onTap,
    child: Text(
      glyph,
      style: TextStyle(fontSize: 23 * scale, color: const Color(0xFF96909E)),
    ),
  );

  Widget _actionButton(
    String letter,
    String caption,
    String label,
    double scale,
    VoidCallback onTap,
  ) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        padding: EdgeInsets.all(5 * scale),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _ink.withValues(alpha: .16),
          border: Border.all(color: const Color(0x66533E68)),
        ),
        child: _ConsoleButton(
          label: label,
          width: 52 * scale,
          height: 52 * scale,
          radius: BorderRadius.circular(30 * scale),
          color: const Color(0xFF655078),
          onTap: onTap,
          child: Text(
            letter,
            style: TextStyle(
              fontSize: 25 * scale,
              fontWeight: FontWeight.w700,
              color: const Color(0xFFE0D3EC),
            ),
          ),
        ),
      ),
      SizedBox(height: 8 * scale),
      _Label(caption, size: 8 * scale, spacing: 1.7 * scale),
    ],
  );

  Widget _smallControl(
    String text,
    String label,
    VoidCallback onTap,
    double scale, {
    bool enabled = true,
  }) => Column(
    children: [
      Transform.rotate(
        angle: -.15,
        child: _ConsoleButton(
          label: label,
          width: 44 * scale,
          height: 15 * scale,
          radius: BorderRadius.circular(10 * scale),
          onTap: enabled ? onTap : null,
          child: const SizedBox(),
        ),
      ),
      SizedBox(height: 10 * scale),
      _Label(text, size: 7 * scale, spacing: 1 * scale),
    ],
  );
}

class _PiecePreview extends StatelessWidget {
  const _PiecePreview({required this.type, this.width = 54, this.height = 48});

  final PieceType? type;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size(width, height),
    painter: _PiecePreviewPainter(type),
  );
}

class _PiecePreviewPainter extends CustomPainter {
  const _PiecePreviewPainter(this.type);

  final PieceType? type;

  @override
  void paint(Canvas canvas, Size size) {
    final piece = type;
    if (piece == null) return;
    final cells = Tetromino.cells(piece, 0);
    final minX = cells.map((cell) => cell.x).reduce(math.min);
    final maxX = cells.map((cell) => cell.x).reduce(math.max);
    final minY = cells.map((cell) => cell.y).reduce(math.min);
    final maxY = cells.map((cell) => cell.y).reduce(math.max);
    final columns = maxX - minX + 1;
    final rows = maxY - minY + 1;
    final cellSize = math.min(size.width / columns, size.height / rows);
    final origin = Offset(
      (size.width - columns * cellSize) / 2,
      (size.height - rows * cellSize) / 2,
    );
    for (final cell in cells) {
      final rect = Rect.fromLTWH(
        origin.dx + (cell.x - minX) * cellSize,
        origin.dy + (cell.y - minY) * cellSize,
        cellSize,
        cellSize,
      ).deflate(1);
      canvas.drawRect(rect, Paint()..color = _ink);
      canvas.drawRect(
        rect.deflate(math.max(1, cellSize * .18)),
        Paint()..color = const Color(0xFFB5C49D),
      );
      canvas.drawRect(
        rect.deflate(math.max(2, cellSize * .33)),
        Paint()..color = _ink,
      );
    }
  }

  @override
  bool shouldRepaint(_PiecePreviewPainter oldDelegate) =>
      oldDelegate.type != type;
}

class _ConsoleButton extends StatefulWidget {
  const _ConsoleButton({
    required this.label,
    required this.width,
    required this.height,
    required this.radius,
    required this.child,
    this.onTap,
    this.color = const Color(0xFF35313F),
  });
  final String label;
  final double width;
  final double height;
  final BorderRadius radius;
  final Widget child;
  final VoidCallback? onTap;
  final Color color;

  @override
  State<_ConsoleButton> createState() => _ConsoleButtonState();
}

class _ConsoleButtonState extends State<_ConsoleButton> {
  bool _pressed = false;

  void _activate() {
    final onTap = widget.onTap;
    if (onTap == null) return;
    FeedbackService.instance.press();
    onTap();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: widget.onTap != null,
    label: widget.label,
    onTap: widget.onTap == null ? null : _activate,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.onTap == null
          ? null
          : (_) => setState(() => _pressed = true),
      onTapUp: widget.onTap == null
          ? null
          : (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap == null ? null : _activate,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 65),
        transform: Matrix4.translationValues(0, _pressed ? 2 : 0, 0),
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: widget.radius,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              widget.color,
              Color.lerp(widget.color, const Color(0xFF000000), .25)!,
            ],
          ),
          border: Border.all(color: const Color(0xFF26222F), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF69567F),
              offset: Offset(0, _pressed ? 1 : 4),
              blurRadius: _pressed ? 1 : 2,
            ),
          ],
        ),
        child: Center(child: widget.child),
      ),
    ),
  );
}

class _Label extends StatelessWidget {
  const _Label(
    this.text, {
    this.size = 10,
    this.spacing = 0,
    this.color = _ink,
  });
  final String text;
  final double size;
  final double spacing;
  final Color color;

  @override
  Widget build(BuildContext context) => Text(
    text,
    maxLines: 1,
    style: TextStyle(
      fontSize: size,
      letterSpacing: spacing,
      color: color,
      fontWeight: FontWeight.w700,
    ),
  );
}

class _GlassSheenPainter extends CustomPainter {
  const _GlassSheenPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final top = Rect.fromLTWH(0, 0, size.width, size.height * .23);
    canvas.drawRect(
      top,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x24FFFFFF), Color(0x00FFFFFF)],
        ).createShader(top),
    );
    final glint = Paint()
      ..color = const Color(0x22FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1, size.shortestSide * .003)
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(size.width * .07, size.height * .035)
      ..quadraticBezierTo(
        size.width * .19,
        size.height * .008,
        size.width * .36,
        size.height * .025,
      );
    canvas.drawPath(path, glint);
  }

  @override
  bool shouldRepaint(_GlassSheenPainter oldDelegate) => false;
}

class _SpeakerPainter extends CustomPainter {
  const _SpeakerPainter();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(size.width / 75);
    canvas.rotate(-math.pi / 9);
    for (var row = 0; row < 5; row++) {
      for (var col = 0; col < 8; col++) {
        canvas.drawCircle(
          Offset(col * 8.0 - 28, row * 8.0 - 16),
          1.8,
          Paint()..color = const Color(0xFF77608F),
        );
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SpeakerPainter oldDelegate) => false;
}
