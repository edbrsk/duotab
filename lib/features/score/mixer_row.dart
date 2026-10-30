import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/design/design_tokens.dart';
import '../../engine/protocol.dart';
import '../../l10n/app_localizations.dart';
import '../playback/levels.dart';
import '../playback/mix_level.dart';
import '../playback/playback_cubit.dart';
import 'track_drawer.dart' show kTrackRowHeight;

const _readoutWidth = 64.0;
const _meterFloorDb = -60.0;
const _meterBlue = Color(0xFF4F8CFF);
const _meterYellow = Color(0xFFE9C46A);
const _meterRed = Color(0xFFE76F51);
const _knobRing = Color(0xFF8F93B8);

/// One track in the mixer: a dB fader with its meter, the level, and a pan knob.
class MixerRow extends StatefulWidget {
  final TrackSummary track;
  final double volumeDb;
  final double pan;

  const MixerRow({
    required this.track,
    required this.volumeDb,
    required this.pan,
    super.key,
  });

  @override
  State<MixerRow> createState() => _MixerRowState();
}

class _MixerRowState extends State<MixerRow> {
  /// The pan while the knob turns, shown in place of the level.
  double? _turning;

  @override
  Widget build(BuildContext context) {
    final playback = context.read<PlaybackCubit>();
    final l10n = AppLocalizations.of(context)!;
    final index = widget.track.index;
    return _ChannelRow(
      fader: _Fader(
        key: ValueKey('fader-$index'),
        db: widget.volumeDb,
        label: l10n.volumeOf(widget.track.name, dbLabel(widget.volumeDb)),
        onChanged: (db) => playback.setVolumeDb(index, db, save: false),
        onChangeEnd: (db) => playback.setVolumeDb(index, db),
      ),
      meter: _Meter(
        key: ValueKey('meter-$index'),
        levelOf: (levels) => levels?.tracks.elementAtOrNull(index),
      ),
      readout: _turning == null
          ? dbLabel(widget.volumeDb)
          : panLabel(_turning!),
      trailing: _PanKnob(
        key: ValueKey('pan-$index'),
        pan: widget.pan,
        label: l10n.panOf(widget.track.name, panLabel(widget.pan)),
        onTurn: (pan) {
          setState(() => _turning = pan);
          playback.setPan(index, pan, save: false);
        },
        onTurnEnd: (pan) {
          setState(() => _turning = null);
          playback.setPan(index, pan);
        },
      ),
    );
  }
}

/// The mixer's last row: the level of everything played, before the limiter.
class MasterRow extends StatelessWidget {
  final double volumeDb;

  const MasterRow({required this.volumeDb, super.key});

  @override
  Widget build(BuildContext context) {
    final playback = context.read<PlaybackCubit>();
    return _ChannelRow(
      fader: _Fader(
        key: const ValueKey('fader-master'),
        db: volumeDb,
        label: AppLocalizations.of(context)!.masterVolume(dbLabel(volumeDb)),
        onChanged: (db) => playback.setMasterDb(db, save: false),
        onChangeEnd: playback.setMasterDb,
      ),
      meter: _Meter(
        key: const ValueKey('meter-master'),
        levelOf: (levels) => levels?.master,
      ),
      readout: dbLabel(volumeDb),
      trailing: const SizedBox(width: AccessibleSizes.minTouchTarget),
    );
  }
}

class _ChannelRow extends StatelessWidget {
  final Widget fader;
  final Widget meter;
  final String readout;
  final Widget trailing;

  const _ChannelRow({
    required this.fader,
    required this.meter,
    required this.readout,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    height: kTrackRowHeight,
    child: Row(
      children: [
        const SizedBox(width: Spacing.sm),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(height: 30, child: fader),
              SizedBox(height: 8, child: meter),
            ],
          ),
        ),
        SizedBox(
          width: _readoutWidth,
          child: Text(
            readout,
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
          ),
        ),
        trailing,
      ],
    ),
  );
}

/// A horizontal dB fader on Guitar Pro's scale: dragging moves in half
/// decibels, and a double-tap returns it to 0 dB.
class _Fader extends StatefulWidget {
  final double db;
  final String label;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  const _Fader({
    required this.db,
    required this.label,
    required this.onChanged,
    required this.onChangeEnd,
    super.key,
  });

  @override
  State<_Fader> createState() => _FaderState();
}

class _FaderState extends State<_Fader> {
  double? _dragged;

  void _preview(double db) {
    if (db == _dragged) return;
    _dragged = db;
    widget.onChanged(db);
  }

  double _step(double delta) {
    if (widget.db == double.negativeInfinity) {
      return delta > 0 ? minDb : double.negativeInfinity;
    }
    final db = widget.db + delta;
    return db < minDb ? double.negativeInfinity : math.min(db, maxDb);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;
      double dbAt(Offset at) => dbAtPosition((at.dx / width).clamp(0.0, 1.0));
      return Semantics(
        label: widget.label,
        slider: true,
        onIncrease: () => widget.onChangeEnd(_step(0.5)),
        onDecrease: () => widget.onChangeEnd(_step(-0.5)),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (d) => _preview(dbAt(d.localPosition)),
          onHorizontalDragUpdate: (d) => _preview(dbAt(d.localPosition)),
          onHorizontalDragEnd: (_) {
            final db = _dragged;
            _dragged = null;
            if (db != null) widget.onChangeEnd(db);
          },
          onDoubleTap: () => widget.onChangeEnd(0),
          child: CustomPaint(
            size: Size(width, constraints.maxHeight),
            painter: _FaderPainter(faderPosition(widget.db)),
          ),
        ),
      );
    },
  );
}

class _FaderPainter extends CustomPainter {
  final double position;

  const _FaderPainter(this.position);

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    final zero = faderPosition(0) * size.width;
    canvas
      ..drawRRect(
        RRect.fromLTRBR(0, y - 2, size.width, y + 2, const Radius.circular(2)),
        Paint()..color = Colors.white24,
      )
      ..drawLine(
        Offset(zero, y - 8),
        Offset(zero, y + 8),
        Paint()
          ..color = Colors.white54
          ..strokeWidth = 1,
      )
      ..drawCircle(
        Offset(position * size.width, y),
        9,
        Paint()..color = const Color(0xFFBFC6FF),
      );
  }

  @override
  bool shouldRepaint(_FaderPainter old) => old.position != position;
}

/// Two bars, left and right, on the fader's scale: they rise at once and fall
/// 20 dB a second.
class _Meter extends StatefulWidget {
  final MeterLevel? Function(Levels? levels) levelOf;

  const _Meter({required this.levelOf, super.key});

  @override
  State<_Meter> createState() => _MeterState();
}

class _MeterState extends State<_Meter> with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_fall);
  ValueListenable<Levels?>? _levels;
  var _left = double.negativeInfinity;
  var _right = double.negativeInfinity;
  var _incomingLeft = double.negativeInfinity;
  var _incomingRight = double.negativeInfinity;
  var _lastTick = Duration.zero;

  bool get _showing => _left > _meterFloorDb || _right > _meterFloorDb;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final levels = context.read<PlaybackCubit>().levels;
    if (levels == _levels) return;
    _levels?.removeListener(_arrived);
    _levels = levels..addListener(_arrived);
  }

  void _arrived() {
    final level = widget.levelOf(_levels!.value);
    _incomingLeft = level?.left ?? double.negativeInfinity;
    _incomingRight = level?.right ?? double.negativeInfinity;
    setState(() {
      _left = math.max(_left, _incomingLeft);
      _right = math.max(_right, _incomingRight);
    });
    if (_showing && !_ticker.isActive) {
      _lastTick = Duration.zero;
      _ticker.start();
    }
  }

  void _fall(Duration elapsed) {
    final since = elapsed - _lastTick;
    _lastTick = elapsed;
    setState(() {
      _left = meterShown(shown: _left, since: since, incoming: _incomingLeft);
      _right = meterShown(
        shown: _right,
        since: since,
        incoming: _incomingRight,
      );
    });
    if (!_showing) _ticker.stop();
  }

  @override
  void dispose() {
    _levels?.removeListener(_arrived);
    _ticker.dispose();
    super.dispose();
  }

  double _fraction(double db) => db > _meterFloorDb ? faderPosition(db) : 0;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.infinite,
    painter: MeterPainter(
      leftFraction: _fraction(_left),
      rightFraction: _fraction(_right),
    ),
  );
}

/// Public so tests can read where each bar ends.
class MeterPainter extends CustomPainter {
  final double leftFraction;
  final double rightFraction;

  const MeterPainter({required this.leftFraction, required this.rightFraction});

  @override
  void paint(Canvas canvas, Size size) {
    _bar(canvas, size, leftFraction, 0);
    _bar(canvas, size, rightFraction, 4);
  }

  void _bar(Canvas canvas, Size size, double fraction, double top) {
    final yellow = faderPosition(-6) * size.width;
    final red = faderPosition(-1) * size.width;
    final end = fraction * size.width;
    for (final (from, to, color) in [
      (0.0, yellow, _meterBlue),
      (yellow, red, _meterYellow),
      (red, size.width, _meterRed),
    ]) {
      if (end <= from) break;
      canvas.drawRect(
        Rect.fromLTRB(from, top, math.min(end, to), top + 3),
        Paint()..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(MeterPainter old) =>
      old.leftFraction != leftFraction || old.rightFraction != rightFraction;
}

/// Left to right: dragging moves it a step per 4 pt, and a double-tap centres it.
class _PanKnob extends StatefulWidget {
  final double pan;
  final String label;
  final ValueChanged<double> onTurn;
  final ValueChanged<double> onTurnEnd;

  const _PanKnob({
    required this.pan,
    required this.label,
    required this.onTurn,
    required this.onTurnEnd,
    super.key,
  });

  @override
  State<_PanKnob> createState() => _PanKnobState();
}

class _PanKnobState extends State<_PanKnob> {
  static const _step = 0.02;
  static const _pointsPerStep = 4.0;

  double _from = 0;
  double _dragged = 0;
  double? _turned;

  double _panAfter(double dx) {
    final steps = (dx / _pointsPerStep).truncate();
    return ((_from + steps * _step).clamp(-1.0, 1.0) * 50).round() / 50;
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: widget.label,
    slider: true,
    onIncrease: () => widget.onTurnEnd(math.min(1, widget.pan + _step)),
    onDecrease: () => widget.onTurnEnd(math.max(-1, widget.pan - _step)),
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: (_) {
        _from = widget.pan;
        _dragged = 0;
        _turned = null;
      },
      onHorizontalDragUpdate: (d) {
        _dragged += d.delta.dx;
        final pan = _panAfter(_dragged);
        if (pan == (_turned ?? widget.pan)) return;
        _turned = pan;
        widget.onTurn(pan);
      },
      onHorizontalDragEnd: (_) {
        final pan = _turned ?? widget.pan;
        // From here the knob draws the pan it is given.
        setState(() => _turned = null);
        widget.onTurnEnd(pan);
      },
      onDoubleTap: () => widget.onTurnEnd(0),
      child: SizedBox.square(
        dimension: AccessibleSizes.minTouchTarget,
        child: CustomPaint(painter: _KnobPainter(_turned ?? widget.pan)),
      ),
    ),
  );
}

class _KnobPainter extends CustomPainter {
  final double pan;

  const _KnobPainter(this.pan);

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    canvas.drawCircle(
      centre,
      13,
      Paint()
        ..color = _knobRing
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    final angle = pan * 135 * math.pi / 180;
    canvas.drawLine(
      centre,
      centre + Offset(math.sin(angle), -math.cos(angle)) * 10,
      Paint()
        ..color = Colors.white
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_KnobPainter old) => old.pan != pan;
}
