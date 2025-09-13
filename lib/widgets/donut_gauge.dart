import 'dart:math' as math;
import 'package:flutter/material.dart';

class DonutGauge extends StatelessWidget {
  final double percent;      // 0..N
  final double diameter;     // px
  final double stroke;       // px
  final bool animate;
  final Color? primaryColor;
  final Color? trackColor;

  const DonutGauge({
    super.key,
    required this.percent,
    this.diameter = 200,
    this.stroke = 16,
    this.animate = true,
    this.primaryColor,
    this.trackColor,
  });

  @override
  Widget build(BuildContext context) {
    final pColor = primaryColor ?? Theme.of(context).colorScheme.primary;
    final tColor = trackColor ?? Colors.grey.shade300;

    final child = CustomPaint(
      size: Size.square(diameter),
      painter: _DonutPainter(
        percent: percent,
        stroke: stroke,
        primary: pColor,
        track: tColor,
      ),
    );

    if (!animate) return child;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: percent),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (_, value, __) => CustomPaint(
        size: Size.square(diameter),
        painter: _DonutPainter(
          percent: value,
          stroke: stroke,
          primary: pColor,
          track: tColor,
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final double percent; // can exceed 1.0
  final double stroke;
  final Color primary;
  final Color track;

  _DonutPainter({
    required this.percent,
    required this.stroke,
    required this.primary,
    required this.track,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - stroke / 2;

    final trackPaint = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    final startAngle = -math.pi / 2;
    final clamped = percent.isFinite ? percent.clamp(0.0, 1.0) : 0.0;
    final sweepMain = 2 * math.pi * clamped;

    final gradient = SweepGradient(
      startAngle: 0,
      endAngle: 2 * math.pi,
      colors: [primary.withOpacity(0.25), primary, primary],
      stops: const [0.0, 0.75, 1.0],
      transform: const GradientRotation(-math.pi / 2),
    );

    final mainPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..shader = gradient.createShader(Rect.fromCircle(center: center, radius: radius));

    final over = percent > 1.0;

    if (!over) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepMain,
        false,
        mainPaint,
      );
    } else {
      final redPaint = Paint()
        ..color = Colors.red
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        2 * math.pi,
        false,
        redPaint,
      );

      final overflow = (percent - 1.0).clamp(0.0, 1.0);
      if (overflow > 0) {
        final outerStroke = stroke * 0.55;
        final outerRadius = radius + stroke * 0.42;
        final overPaint = Paint()
          ..color = Colors.redAccent
          ..style = PaintingStyle.stroke
          ..strokeWidth = outerStroke
          ..strokeCap = StrokeCap.round;

        final overSweep = 2 * math.pi * overflow;
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: outerRadius),
          startAngle,
          overSweep,
          false,
          overPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) {
    return oldDelegate.percent != percent ||
        oldDelegate.stroke != stroke ||
        oldDelegate.primary != primary ||
        oldDelegate.track != track;
  }
}
