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
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(size.width * .30, size.height * .24)
      ..lineTo(size.width * .43, size.height * .24)
      ..lineTo(size.width * .43, size.height * .68)
      ..lineTo(size.width * .70, size.height * .68)
      ..lineTo(size.width * .70, size.height * .80)
      ..lineTo(size.width * .30, size.height * .80)
      ..close();
    canvas.drawPath(path, white);

    final arrow = Path()
      ..moveTo(size.width * .56, size.height * .30)
      ..lineTo(size.width * .56, size.height * .57)
      ..lineTo(size.width * .46, size.height * .48)
      ..lineTo(size.width * .38, size.height * .56)
      ..lineTo(size.width * .62, size.height * .80)
      ..lineTo(size.width * .86, size.height * .56)
      ..lineTo(size.width * .78, size.height * .48)
      ..lineTo(size.width * .68, size.height * .57)
      ..lineTo(size.width * .68, size.height * .30)
      ..close();
    final arrowFill = Paint()..color = Colors.white;
    canvas.drawPath(arrow, arrowFill);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
