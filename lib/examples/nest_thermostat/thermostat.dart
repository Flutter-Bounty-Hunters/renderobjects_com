import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

enum ThermostatMode { heating, cooling, off }

/// A Nest-style thermostat rendered entirely by a custom [RenderObject].
///
/// Enforces a 1:1 aspect ratio. Lift temperature changes via
/// [onTargetTempChanged] and feed the new value back through [targetTemp] from
/// a parent [StatefulWidget].
class Thermostat extends LeafRenderObjectWidget {
  const Thermostat({
    super.key,
    required this.targetTemp,
    required this.currentTemp,
    required this.mode,
    this.minTemp = 50.0,
    this.maxTemp = 90.0,
    this.onTargetTempChanged,
  });

  final double targetTemp;
  final double currentTemp;
  final ThermostatMode mode;
  final double minTemp;
  final double maxTemp;
  final ValueChanged<double>? onTargetTempChanged;

  @override
  RenderThermostat createRenderObject(BuildContext context) => RenderThermostat(
    targetTemp: targetTemp,
    currentTemp: currentTemp,
    mode: mode,
    minTemp: minTemp,
    maxTemp: maxTemp,
    onTargetTempChanged: onTargetTempChanged,
  );

  @override
  void updateRenderObject(BuildContext context, RenderThermostat renderObject) {
    renderObject
      ..targetTemp = targetTemp
      ..currentTemp = currentTemp
      ..mode = mode
      ..minTemp = minTemp
      ..maxTemp = maxTemp
      ..onTargetTempChanged = onTargetTempChanged;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DoubleProperty('targetTemp', targetTemp))
      ..add(DoubleProperty('currentTemp', currentTemp))
      ..add(EnumProperty<ThermostatMode>('mode', mode))
      ..add(DoubleProperty('minTemp', minTemp))
      ..add(DoubleProperty('maxTemp', maxTemp))
      ..add(ObjectFlagProperty<ValueChanged<double>>.has('onTargetTempChanged', onTargetTempChanged));
  }
}

// ---------------------------------------------------------------------------
// RenderObject
// ---------------------------------------------------------------------------

class RenderThermostat extends RenderBox {
  RenderThermostat({
    required double targetTemp,
    required double currentTemp,
    required ThermostatMode mode,
    required double minTemp,
    required double maxTemp,
    ValueChanged<double>? onTargetTempChanged,
  }) : _targetTemp = targetTemp,
       _currentTemp = currentTemp,
       _mode = mode,
       _minTemp = minTemp,
       _maxTemp = maxTemp,
       _onTargetTempChanged = onTargetTempChanged {
    _tap = TapGestureRecognizer()..onTapUp = _onTapUp;
    _pan = PanGestureRecognizer()
      ..onStart = _onPanStart
      ..onUpdate = _onPanUpdate;
    _animFrom = _animTo = _animCurrent = _kModeColors[_mode]!;
    _ticker = Ticker(_onTick);
  }

  // -- state --

  double _targetTemp;
  double _currentTemp;
  ThermostatMode _mode;
  double _minTemp;
  double _maxTemp;
  ValueChanged<double>? _onTargetTempChanged;

  late final TapGestureRecognizer _tap;
  late final PanGestureRecognizer _pan;
  double? _lastPanAngle;
  double _panAccum = 0;

  // -- mode color animation --

  late Ticker _ticker;
  late _ModeColors _animFrom;
  late _ModeColors _animTo;
  late _ModeColors _animCurrent;
  Duration? _animStart;
  static const _kModeAnimDuration = Duration(milliseconds: 400);

  void _onTick(Duration elapsed) {
    _animStart ??= elapsed;
    final t = ((elapsed - _animStart!).inMicroseconds / _kModeAnimDuration.inMicroseconds).clamp(0.0, 1.0);
    _animCurrent = _ModeColors.lerp(_animFrom, _animTo, t);
    markNeedsPaint();
    if (t >= 1.0) {
      _ticker.stop();
      _animStart = null;
    }
  }

  // -- setters --

  set targetTemp(double v) {
    if (_targetTemp == v) return;
    _targetTemp = v;
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  set currentTemp(double v) {
    if (_currentTemp == v) return;
    _currentTemp = v;
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  set mode(ThermostatMode v) {
    if (_mode == v) return;
    _mode = v;
    _animFrom = _animCurrent;
    _animTo = _kModeColors[v]!;
    _animStart = null;
    if (!_ticker.isTicking) _ticker.start();
    markNeedsSemanticsUpdate();
  }

  set minTemp(double v) {
    if (_minTemp == v) return;
    _minTemp = v;
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  set maxTemp(double v) {
    if (_maxTemp == v) return;
    _maxTemp = v;
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  set onTargetTempChanged(ValueChanged<double>? v) {
    if (_onTargetTempChanged == v) return;
    _onTargetTempChanged = v;
    markNeedsSemanticsUpdate();
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DoubleProperty('targetTemp', _targetTemp))
      ..add(DoubleProperty('currentTemp', _currentTemp))
      ..add(EnumProperty<ThermostatMode>('mode', _mode))
      ..add(DoubleProperty('minTemp', _minTemp))
      ..add(DoubleProperty('maxTemp', _maxTemp))
      ..add(DoubleProperty('tempRange', _maxTemp - _minTemp))
      ..add(ObjectFlagProperty<ValueChanged<double>>.has('onTargetTempChanged', _onTargetTempChanged))
      ..add(DoubleProperty('dialRadius', hasSize ? _dialR : null, defaultValue: null))
      ..add(DiagnosticsProperty<Size>('size', hasSize ? size : null, defaultValue: null));
  }

  // ---------------------------------------------------------------------------
  // Semantics
  // ---------------------------------------------------------------------------

  String get _modeLabel => switch (_mode) {
    ThermostatMode.heating => 'heating',
    ThermostatMode.cooling => 'cooling',
    ThermostatMode.off => 'off',
  };

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);

    final target = _targetTemp.round();
    final increased = (target + 1).clamp(_minTemp.round(), _maxTemp.round());
    final decreased = (target - 1).clamp(_minTemp.round(), _maxTemp.round());

    config
      ..isSemanticBoundary = true
      ..isEnabled = true
      ..label = 'Thermostat'
      ..value =
          '$target degrees, $_modeLabel, '
          'current temperature ${_currentTemp.round()} degrees'
      ..increasedValue = '$increased degrees'
      ..decreasedValue = '$decreased degrees'
      ..hint = 'Swipe up or down to adjust target temperature';
    config.onIncrease = _onTargetTempChanged == null
        ? null
        : () => _emit((target + 1).toDouble().clamp(_minTemp, _maxTemp));
    config.onDecrease = _onTargetTempChanged == null
        ? null
        : () => _emit((target - 1).toDouble().clamp(_minTemp, _maxTemp));
  }

  @override
  void dispose() {
    _tap.dispose();
    _pan.dispose();
    _ticker.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Layout — square, shortest-side wins
  // ---------------------------------------------------------------------------

  @override
  Size computeDryLayout(BoxConstraints constraints) => _squareSize(constraints);

  // Cached baselines for the temperature numeral, keyed by TextBaseline enum
  // index. Populated during performLayout rather than lazily in
  // computeDistanceToActualBaseline, because baseline queries can arrive after
  // layout completes but before the first paint — computing here ensures the
  // cache is always warm when the framework asks for it.
  final _baselines = <TextBaseline, double>{};

  @override
  void performLayout() {
    size = _squareSize(constraints);

    // Calculate text layout during layout instead of paint, to support baseline
    // reporting.
    //
    // The debug baseline query might happen before `paint()` is called, but
    // it's called after `layout()`. We measure here so that the results are
    // available to both the baseline query, and to `paint()`, instead of
    // running this measurement in two different places.
    final s = size.width;
    final tp = TextPainter(
      text: TextSpan(
        text: _targetTemp.round().toString(),
        style: TextStyle(fontSize: s * 0.22, fontWeight: FontWeight.w800, height: 1.0),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final modeOffset = _mode != ThermostatMode.off ? s * 0.04 : 0.0;
    final textTop = size.height / 2 + modeOffset - tp.height / 2;
    for (final b in TextBaseline.values) {
      _baselines[b] = textTop + tp.computeDistanceToActualBaseline(b);
    }
  }

  /// Returns the distance from the top of the widget to the alphabetic or
  /// ideographic baseline of the temperature numeral, so the thermostat can
  /// participate in baseline-aligned rows.
  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) => _baselines[baseline];

  Size _squareSize(BoxConstraints c) {
    final side = math.min(c.maxWidth.isFinite ? c.maxWidth : 300.0, c.maxHeight.isFinite ? c.maxHeight : 300.0);
    return c.constrain(Size(side, side));
  }

  // ---------------------------------------------------------------------------
  // Hit-testing & gesture dispatch
  // ---------------------------------------------------------------------------

  @override
  bool hitTestSelf(Offset position) => true;

  @override
  void handleEvent(PointerEvent event, BoxHitTestEntry entry) {
    if (event is PointerDownEvent) {
      _tap.addPointer(event);
      _pan.addPointer(event);
    }
  }

  // ---------------------------------------------------------------------------
  // Dial geometry
  // ---------------------------------------------------------------------------

  // The dial arc runs 240° starting at ~7:30 o'clock and going clockwise to
  // ~4:30 o'clock, leaving a 120° gap at the bottom for the +/− buttons.
  // Flutter canvas angles are measured clockwise from the positive x-axis (3 o'clock).
  static const double _kStartAngle = 122.5 * math.pi / 180.0;
  static const double _kSweepAngle = 295.0 * math.pi / 180.0;
  static const double _kTwoPi = 2.0 * math.pi;

  Offset get _center => Offset(size.width / 2, size.height / 2);
  double get _dialR => size.width * 0.43;

  double _rawAngle(Offset local) {
    final rel = local - _center;
    return math.atan2(rel.dy, rel.dx);
  }

  bool _angleInDial(double raw) {
    final start = _kStartAngle % _kTwoPi;
    final shifted = (raw % _kTwoPi - start + _kTwoPi) % _kTwoPi;
    return shifted <= _kSweepAngle;
  }

  double _angleToTemp(double raw) {
    final start = _kStartAngle % _kTwoPi;
    final shifted = (raw % _kTwoPi - start + _kTwoPi) % _kTwoPi;
    return (_minTemp + (shifted / _kSweepAngle) * (_maxTemp - _minTemp)).clamp(_minTemp, _maxTemp);
  }

  bool _onRing(Offset local) {
    const inset = 8.0;
    const len = 0.18;
    final outerR = _dialR - inset;
    final innerR = outerR - len * _dialR;
    final d = (local - _center).distance;
    // Generous tolerance so thick fingers still register across the full notch band.
    return d >= innerR - 8 && d <= outerR + 8;
  }

  // Angular centres of the two button arcs (degrees, Flutter canvas convention).
  static const double _kUpArcCenterDeg = (59.5 + 89.5) / 2; // 74.5°
  static const double _kDownArcCenterDeg = (90.5 + 120.5) / 2; // 105.5°

  // Returns the canvas position at the radial mid-point of a button arc.
  Offset _buttonCenter(double arcCenterDeg) {
    final r = _dialR;
    const inset = 8.0;
    const len = 0.18;
    final outerR = r - inset;
    final innerR = outerR - len * r;
    final arcR = (outerR + innerR) / 2;
    final rad = arcCenterDeg * math.pi / 180.0;
    return _center + Offset(arcR * math.cos(rad), arcR * math.sin(rad));
  }

  _ButtonHit _buttonAt(Offset local) {
    final hitR = _dialR * 0.18;
    if ((local - _buttonCenter(_kUpArcCenterDeg)).distance < hitR) {
      return _ButtonHit.up;
    }
    if ((local - _buttonCenter(_kDownArcCenterDeg)).distance < hitR) {
      return _ButtonHit.down;
    }
    return _ButtonHit.none;
  }

  // ---------------------------------------------------------------------------
  // Gesture handlers
  // ---------------------------------------------------------------------------

  void _onTapUp(TapUpDetails d) {
    final pos = d.localPosition;
    switch (_buttonAt(pos)) {
      case _ButtonHit.down:
        _emit((_targetTemp - 1).clamp(_minTemp, _maxTemp));
        return;
      case _ButtonHit.up:
        _emit((_targetTemp + 1).clamp(_minTemp, _maxTemp));
        return;
      case _ButtonHit.none:
        break;
    }
    if (_onRing(pos)) {
      final angle = _rawAngle(pos);
      if (_angleInDial(angle)) {
        _emit(_angleToTemp(angle).roundToDouble());
      }
    }
  }

  void _onPanStart(DragStartDetails d) {
    _lastPanAngle = _rawAngle(d.localPosition);
    _panAccum = _targetTemp;
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (_lastPanAngle == null) return;
    final cur = _rawAngle(d.localPosition);
    var delta = cur - _lastPanAngle!;
    // Normalize to (−π, π] so short-arc motion never wraps the temperature.
    while (delta > math.pi) {
      delta -= _kTwoPi;
    }
    while (delta < -math.pi) {
      delta += _kTwoPi;
    }
    _lastPanAngle = cur;
    // Accumulate as float so slow drags don't stutter; emit as integer.
    _panAccum = (_panAccum + delta / _kSweepAngle * (_maxTemp - _minTemp)).clamp(_minTemp, _maxTemp);
    _emit(_panAccum.roundToDouble());
  }

  void _emit(double temp) => _onTargetTempChanged?.call(temp);

  // ---------------------------------------------------------------------------
  // Colors
  // ---------------------------------------------------------------------------

  static const _kModeColors = <ThermostatMode, _ModeColors>{
    ThermostatMode.heating: _ModeColors(
      bg: Color(0xFFCC5500),
      circleOverlay: Color(0x18000000),
      buttonOverlay: Color(0x28000000),
    ),
    ThermostatMode.cooling: _ModeColors(
      bg: Color(0xFF1262A8),
      circleOverlay: Color(0x18000000),
      buttonOverlay: Color(0x28000000),
    ),
    ThermostatMode.off: _ModeColors(
      bg: Color(0xFF232323),
      circleOverlay: Color(0x18FFFFFF),
      buttonOverlay: Color(0x28FFFFFF),
    ),
  };

  // ---------------------------------------------------------------------------
  // Paint
  // ---------------------------------------------------------------------------

  @override
  void paint(PaintingContext context, Offset offset) {
    final canvas = context.canvas;
    canvas.save();
    canvas.translate(offset.dx, offset.dy);

    _paintBackground(canvas);
    _paintTicks(canvas);
    _paintButtonArcs(canvas);
    _paintCenterText(canvas);
    _paintButtons(canvas);

    canvas.restore();
  }

  @override
  void debugPaint(PaintingContext context, Offset offset) {
    super.debugPaint(context, offset);

    // The `debugPaint()` method is always run for debug builds, not just when
    // debugging tools activate guidelines. To make sure we only paint these
    // paths when a developer asks for it, we need to check one of Flutter's
    // standard debug paint variables. If it's `false`, we paint nothing.
    if (!debugPaintSizeEnabled) {
      return;
    }

    // The following code paints paths around the dial regions that are
    // tappable and draggable. This helps debug gesture issues.
    //
    // This code is placed into an assert() so that it's not even compiled
    // into a release build. By doing this in all render objects, the size
    // of the release build is reduced, and it's guaranteed that this code
    // will never run in production.
    assert(() {
      final canvas = context.canvas;
      canvas.save();
      canvas.translate(offset.dx, offset.dy);

      final c = _center;
      final r = _dialR;
      const inset = 8.0;
      const len = 0.18;
      final outerR = r - inset;
      final innerR = outerR - len * r;
      final arcR = (outerR + innerR) / 2;

      void circle(double radius, Color color) => canvas.drawCircle(
        c,
        radius,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0,
      );

      // Dial outer boundary (where the ring sits against the background).
      circle(r, const Color(0xFF00FFFF));
      // Outer edge of notch band.
      circle(outerR, const Color(0xFF00FF00));
      // Inner edge of notch band.
      circle(innerR, const Color(0xFFFF00FF));

      // Gap arc — the region reserved for buttons, filled with a translucent
      // orange stroke at the mid-radius of the notch band.
      final gapStart = _kStartAngle + _kSweepAngle;
      final gapSweep = _kTwoPi - _kSweepAngle;
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: arcR),
        gapStart,
        gapSweep,
        false,
        Paint()
          ..color = const Color(0x80FF8000)
          ..style = PaintingStyle.stroke
          ..strokeWidth = outerR - innerR
          ..strokeCap = StrokeCap.butt,
      );

      // Button centre markers — red crosshairs at each button's logical centre.
      for (final deg in [_kUpArcCenterDeg, _kDownArcCenterDeg]) {
        final pos = _buttonCenter(deg);
        const arm = 6.0;
        final paint = Paint()
          ..color = const Color(0xFFFF0000)
          ..strokeWidth = 1.5;
        canvas.drawLine(pos - Offset(arm, 0), pos + Offset(arm, 0), paint);
        canvas.drawLine(pos - Offset(0, arm), pos + Offset(0, arm), paint);
        canvas.drawCircle(pos, 3, Paint()..color = const Color(0xFFFF0000));
      }

      canvas.restore();
      return true;
    }());
  }

  void _paintBackground(Canvas canvas) {
    canvas.drawRect(Offset.zero & size, Paint()..color = _animCurrent.bg);

    // Filled circle behind the notch ring — slightly darker when
    // heating/cooling, slightly lighter when off.
    canvas.drawCircle(_center, _dialR, Paint()..color = _animCurrent.circleOverlay);
  }

  void _paintTicks(Canvas canvas) {
    final c = _center;
    final r = _dialR;
    const inset = 8.0;
    const len = 0.18;
    final outerR = r - inset;
    final innerR = outerR - len * r;

    // One notch every 2 radial degrees regardless of temperature range.
    const notchStepRad = 2.0 * math.pi / 180.0;
    final notchCount = (_kSweepAngle / notchStepRad).round();

    // Map currentTemp and targetTemp to their nearest notch indices.
    final currentNotch = ((_currentTemp - _minTemp) / (_maxTemp - _minTemp) * notchCount).round().clamp(0, notchCount);
    final targetNotch = ((_targetTemp - _minTemp) / (_maxTemp - _minTemp) * notchCount).round().clamp(0, notchCount);
    final loNotch = math.min(currentNotch, targetNotch);
    final hiNotch = math.max(currentNotch, targetNotch);

    for (var i = 0; i <= notchCount; i++) {
      final angle = _kStartAngle + i * notchStepRad;
      final active = i >= loNotch && i <= hiNotch;
      final cosA = math.cos(angle);
      final sinA = math.sin(angle);

      if (i == targetNotch) {
        const halfSweep = 1.5 * math.pi / 180.0;
        final targetInnerR = outerR - len * r * 1.5;
        final path = Path()
          ..arcTo(Rect.fromCircle(center: c, radius: outerR), angle - halfSweep, halfSweep * 2, false)
          ..arcTo(Rect.fromCircle(center: c, radius: targetInnerR), angle + halfSweep, -halfSweep * 2, false)
          ..close();
        canvas.drawPath(
          path,
          Paint()
            ..color = active ? const Color(0xFFFFFFFF) : const Color(0x45FFFFFF)
            ..style = PaintingStyle.fill,
        );
      } else if (i == currentNotch) {
        const halfSweep = 1.5 * math.pi / 180.0;
        final path = Path()
          ..arcTo(Rect.fromCircle(center: c, radius: outerR), angle - halfSweep, halfSweep * 2, false)
          ..arcTo(Rect.fromCircle(center: c, radius: innerR), angle + halfSweep, -halfSweep * 2, false)
          ..close();
        canvas.drawPath(
          path,
          Paint()
            ..color = active ? const Color(0xFFFFFFFF) : const Color(0x45FFFFFF)
            ..style = PaintingStyle.fill,
        );
      } else {
        canvas.drawLine(
          Offset(c.dx + innerR * cosA, c.dy + innerR * sinA),
          Offset(c.dx + outerR * cosA, c.dy + outerR * sinA),
          Paint()
            ..color = active ? const Color(0xFFFFFFFF) : const Color(0x45FFFFFF)
            ..strokeWidth = 1.5
            ..strokeCap = StrokeCap.round,
        );
      }
    }
  }

  void _paintCenterText(Canvas canvas) {
    final c = _center;
    final s = size.width;
    final hasMode = _mode != ThermostatMode.off;

    {
      final label = switch (_mode) {
        ThermostatMode.heating => 'HEATING',
        ThermostatMode.cooling => 'COOLING',
        ThermostatMode.off => 'OFF',
      };
      _paintText(
        canvas,
        label,
        TextStyle(
          color: const Color(0xCCFFFFFF),
          fontSize: s * 0.048,
          fontWeight: FontWeight.w600,
          letterSpacing: s * 0.007,
        ),
        center: Offset(c.dx, c.dy - s * 0.09),
      );
    }

    // Large temperature numeral, nudged down slightly when the mode label
    // is present so the pair reads as a centred unit.
    _paintText(
      canvas,
      _targetTemp.round().toString(),
      TextStyle(color: const Color(0xFFFFFFFF), fontSize: s * 0.22, fontWeight: FontWeight.w800, height: 1.0),
      center: Offset(c.dx, c.dy + (hasMode ? s * 0.04 : 0)),
    );
  }

  void _paintText(Canvas canvas, String text, TextStyle style, {required Offset center}) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  // The gap in the notch arc runs from 45° to 135° (clockwise, 90° total,
  // centered at 6 o'clock). Split it into two button arc segments:
  //   57.5°–59.5°  : side gap (right, 2°)
  //   59.5°–89.5°  : up button arc   (lower-right, 30°)
  //   89.5°–90.5°  : centre gap between buttons (1°)
  //   90.5°–120.5° : down button arc (lower-left, 30°)
  //   120.5°–122.5°: side gap (left, 2°)
  void _paintButtonArcs(Canvas canvas) {
    final c = _center;
    final r = _dialR;
    const inset = 8.0;
    const len = 0.18;
    final outerR = r - inset;
    final innerR = outerR - len * r;
    final arcR = (outerR + innerR) / 2;
    final strokeW = outerR - innerR;

    final paint = Paint()
      ..color = _animCurrent.buttonOverlay
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..strokeCap = StrokeCap.butt;

    final rect = Rect.fromCircle(center: c, radius: arcR);
    const d2r = math.pi / 180.0;

    // Up button arc (lower-right of gap)
    canvas.drawArc(rect, 59.5 * d2r, 30.0 * d2r, false, paint);
    // Down button arc (lower-left of gap)
    canvas.drawArc(rect, 90.5 * d2r, 30.0 * d2r, false, paint);
  }

  void _paintButtons(Canvas canvas) {
    _paintChevron(canvas, _buttonCenter(_kUpArcCenterDeg), pointUp: true);
    _paintChevron(canvas, _buttonCenter(_kDownArcCenterDeg), pointUp: false);
  }

  void _paintChevron(Canvas canvas, Offset pos, {required bool pointUp}) {
    final sz = size.width * 0.018;
    final paint = Paint()
      ..color = const Color(0xCCFFFFFF)
      ..strokeWidth = size.width * 0.006
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    if (pointUp) {
      path
        ..moveTo(pos.dx - sz, pos.dy + sz * 0.55)
        ..lineTo(pos.dx, pos.dy - sz * 0.55)
        ..lineTo(pos.dx + sz, pos.dy + sz * 0.55);
    } else {
      path
        ..moveTo(pos.dx - sz, pos.dy - sz * 0.55)
        ..lineTo(pos.dx, pos.dy + sz * 0.55)
        ..lineTo(pos.dx + sz, pos.dy - sz * 0.55);
    }
    canvas.drawPath(path, paint);
  }
}

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

enum _ButtonHit { none, down, up }

/// A color in the Oklab perceptually-uniform color space, used so mode-color
/// crossfades interpolate "directly" without a desaturated grey dip or a
/// hue detour through unrelated colors.
class _Oklab {
  const _Oklab({required this.l, required this.a, required this.b, required this.alpha});

  final double l;
  final double a;
  final double b;
  final double alpha;

  static double _srgbToLinear(double c) => c <= 0.04045 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

  static double _linearToSrgb(double c) => c <= 0.0031308 ? c * 12.92 : 1.055 * math.pow(c, 1 / 2.4).toDouble() - 0.055;

  factory _Oklab.fromColor(Color color) {
    final r = _srgbToLinear(color.r);
    final g = _srgbToLinear(color.g);
    final b = _srgbToLinear(color.b);

    final l = 0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b;
    final m = 0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b;
    final s = 0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b;

    final l_ = math.pow(l, 1 / 3).toDouble();
    final m_ = math.pow(m, 1 / 3).toDouble();
    final s_ = math.pow(s, 1 / 3).toDouble();

    return _Oklab(
      l: 0.2104542553 * l_ + 0.7936177850 * m_ - 0.0040720468 * s_,
      a: 1.9779984951 * l_ - 2.4285922050 * m_ + 0.4505937099 * s_,
      b: 0.0259040371 * l_ + 0.7827717662 * m_ - 0.8086757660 * s_,
      alpha: color.a,
    );
  }

  Color toColor() {
    final l_ = l + 0.3963377774 * a + 0.2158037573 * b;
    final m_ = l - 0.1055613458 * a - 0.0638541728 * b;
    final s_ = l - 0.0894841775 * a - 1.2914855480 * b;

    final lc = l_ * l_ * l_;
    final mc = m_ * m_ * m_;
    final sc = s_ * s_ * s_;

    final r = 4.0767416621 * lc - 3.3077115913 * mc + 0.2309699292 * sc;
    final g = -1.2684380046 * lc + 2.6097574011 * mc - 0.3413193965 * sc;
    final b2 = -0.0041960863 * lc - 0.7034186147 * mc + 1.7076147010 * sc;

    return Color.from(
      alpha: alpha,
      red: _linearToSrgb(r).clamp(0.0, 1.0),
      green: _linearToSrgb(g).clamp(0.0, 1.0),
      blue: _linearToSrgb(b2).clamp(0.0, 1.0),
    );
  }
}

/// The set of colors that vary by [ThermostatMode] and animate smoothly
/// when the mode changes.
class _ModeColors {
  const _ModeColors({required this.bg, required this.circleOverlay, required this.buttonOverlay});

  final Color bg;
  final Color circleOverlay;
  final Color buttonOverlay;

  static _ModeColors lerp(_ModeColors a, _ModeColors b, double t) {
    return _ModeColors(
      bg: _lerpOklab(a.bg, b.bg, t),
      circleOverlay: _lerpOklab(a.circleOverlay, b.circleOverlay, t),
      buttonOverlay: _lerpOklab(a.buttonOverlay, b.buttonOverlay, t),
    );
  }

  // Interpolate in Oklab, a perceptually-uniform color space. This avoids the
  // failure modes of simpler approaches:
  //  - A straight RGB lerp between near-complementary hues (e.g. heating's
  //    orange and cooling's blue) desaturates through a grey/brown midpoint
  //    that looks like the "off" color.
  //  - An HSV hue lerp swings around the color wheel, which can pass through
  //    unrelated, vivid hues (e.g. green/yellow, or magenta) that read as
  //    chaotic rather than a direct fade.
  // Oklab lerps lightness, and two roughly-perpendicular chroma axes (a/b)
  // directly, producing a fade that goes "straight" between the two colors
  // without a desaturated dip or a hue detour.
  static Color _lerpOklab(Color x, Color y, double t) {
    final labX = _Oklab.fromColor(x);
    final labY = _Oklab.fromColor(y);
    return _Oklab(
      l: labX.l + (labY.l - labX.l) * t,
      a: labX.a + (labY.a - labX.a) * t,
      b: labX.b + (labY.b - labX.b) * t,
      alpha: labX.alpha + (labY.alpha - labX.alpha) * t,
    ).toColor();
  }
}
