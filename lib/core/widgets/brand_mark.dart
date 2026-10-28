import 'package:flutter/material.dart';

/// Compact Loady brand symbol used in the app and empty states.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 56, this.dark = false});

  final double size;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final colors = dark
        ? const [Color(0xFF7EA2FF), Color(0xFF58D8FF)]
        : const [Color(0xFF3D73FF), Color(0xFF58D8FF)];
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size * .29),
        boxShadow: [
          BoxShadow(
            color: colors.first.withAlpha(55),
            blurRadius: size * .24,
            offset: Offset(0, size * .10),
          ),
        ],
      ),
      child: CustomPaint(
        painter: _BrandMarkPainter(),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _BrandMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final white = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * .105
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(size.width * .31, size.height * .25)
      ..lineTo(size.width * .31, size.height * .75)
      ..lineTo(size.width * .57, size.height * .75)
      ..quadraticBezierTo(
        size.width * .77,
        size.height * .75,
        size.width * .77,
        size.height * .50,
      )
      ..quadraticBezierTo(
        size.width * .77,
        size.height * .25,
        size.width * .57,
        size.height * .25,
      )
      ..close();
    canvas.drawPath(path, white);

    final arrow = Path()
      ..moveTo(size.width * .56, size.height * .36)
      ..lineTo(size.width * .56, size.height * .63)
      ..moveTo(size.width * .45, size.height * .53)
      ..lineTo(size.width * .56, size.height * .64)
      ..lineTo(size.width * .67, size.height * .53);
    canvas.drawPath(arrow, white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
