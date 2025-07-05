import 'package:flutter/material.dart';
import 'dart:math' as math;

enum JoystickMode {
  all,
  horizontal,
  vertical,
}

enum JoystickBehavior {
  free,
  sticky,
}

class VirtualJoystick extends StatefulWidget {
  final double size;
  final Function(double x, double y) onChanged;
  final JoystickMode mode;
  final JoystickBehavior behavior;
  final Color baseColor;
  final Color knobColor;
  final double knobRadius;
  final double baseRadius;

  const VirtualJoystick({
    super.key,
    this.size = 200.0,
    required this.onChanged,
    this.mode = JoystickMode.all,
    this.behavior = JoystickBehavior.free,
    this.baseColor = const Color(0xFF444444),
    this.knobColor = const Color(0xFF888888),
    this.knobRadius = 30.0,
    this.baseRadius = 100.0,
  });

  @override
  State<VirtualJoystick> createState() => _VirtualJoystickState();
}

class _VirtualJoystickState extends State<VirtualJoystick> {
  Offset _knobPosition = Offset.zero;
  bool _isActive = false;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: GestureDetector(
        onPanStart: _onPanStart,
        onPanUpdate: _onPanUpdate,
        onPanEnd: _onPanEnd,
        child: CustomPaint(
          painter: JoystickPainter(
            knobPosition: _knobPosition,
            isActive: _isActive,
            baseColor: widget.baseColor,
            knobColor: widget.knobColor,
            knobRadius: widget.knobRadius,
            baseRadius: widget.baseRadius,
          ),
          size: Size(widget.size, widget.size),
        ),
      ),
    );
  }

  void _onPanStart(DragStartDetails details) {
    setState(() {
      _isActive = true;
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final center = Offset(widget.size / 2, widget.size / 2);
    final delta = details.localPosition - center;

    // Constrain movement within the base circle
    final distance =
        math.min(delta.distance, widget.baseRadius - widget.knobRadius);
    final angle = math.atan2(delta.dy, delta.dx);

    Offset newPosition = Offset(
      math.cos(angle) * distance,
      math.sin(angle) * distance,
    );

    // Apply joystick mode constraints
    switch (widget.mode) {
      case JoystickMode.horizontal:
        newPosition = Offset(newPosition.dx, 0);
        break;
      case JoystickMode.vertical:
        newPosition = Offset(0, newPosition.dy);
        break;
      case JoystickMode.all:
        // No constraints
        break;
    }

    setState(() {
      _knobPosition = newPosition;
    });

    // Normalize position to -1.0 to 1.0 range
    final normalizedX =
        _knobPosition.dx / (widget.baseRadius - widget.knobRadius);
    final normalizedY =
        -_knobPosition.dy / (widget.baseRadius - widget.knobRadius); // Invert Y

    widget.onChanged(normalizedX, normalizedY);
  }

  void _onPanEnd(DragEndDetails details) {
    setState(() {
      _isActive = false;
      if (widget.behavior == JoystickBehavior.free) {
        _knobPosition = Offset.zero;
        widget.onChanged(0.0, 0.0);
      }
    });
  }
}

class JoystickPainter extends CustomPainter {
  final Offset knobPosition;
  final bool isActive;
  final Color baseColor;
  final Color knobColor;
  final double knobRadius;
  final double baseRadius;

  JoystickPainter({
    required this.knobPosition,
    required this.isActive,
    required this.baseColor,
    required this.knobColor,
    required this.knobRadius,
    required this.baseRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final basePaint = Paint()
      ..color = baseColor
      ..style = PaintingStyle.fill;

    final baseStrokePaint = Paint()
      ..color = baseColor.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final knobPaint = Paint()
      ..color = isActive ? knobColor.withValues(alpha: 0.9) : knobColor
      ..style = PaintingStyle.fill;

    final knobStrokePaint = Paint()
      ..color = isActive ? Colors.white : knobColor.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    // Draw base circle
    canvas.drawCircle(center, baseRadius, basePaint);
    canvas.drawCircle(center, baseRadius, baseStrokePaint);

    // Draw center crosshair
    final crosshairPaint = Paint()
      ..color = baseColor.withValues(alpha: 0.5)
      ..strokeWidth = 1.0;

    canvas.drawLine(
      Offset(center.dx - 10, center.dy),
      Offset(center.dx + 10, center.dy),
      crosshairPaint,
    );

    canvas.drawLine(
      Offset(center.dx, center.dy - 10),
      Offset(center.dx, center.dy + 10),
      crosshairPaint,
    );

    // Draw knob
    final knobCenter = center + knobPosition;
    canvas.drawCircle(knobCenter, knobRadius, knobPaint);
    canvas.drawCircle(knobCenter, knobRadius, knobStrokePaint);

    // Draw knob indicator
    if (isActive) {
      final indicatorPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;

      canvas.drawCircle(knobCenter, 3.0, indicatorPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
