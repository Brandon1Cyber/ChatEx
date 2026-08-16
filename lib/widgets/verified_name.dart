import 'dart:math' as math;

import 'package:flutter/material.dart';

/// ============================================================================
/// CHATTªX — VERIFIED NAME
/// ============================================================================
///
/// One verification badge used everywhere in ChattªX.
///
/// Badge size remains EXACTLY:
///     17 × 17
///
/// Badge color remains EXACTLY:
///     #2196F3
///
/// Only the badge shape has been changed.
/// ============================================================================

class VerifiedName extends StatelessWidget {
  final String name;
  final bool verified;
  final double fontSize;
  final FontWeight fontWeight;
  final Color textColor;

  const VerifiedName({
    super.key,
    required this.name,
    this.verified = false,
    this.fontSize = 16,
    this.fontWeight = FontWeight.w700,
    this.textColor = Colors.white,
  });

  static const Color verificationBlue = Color(0xFF2196F3);

  Widget _buildVerificationBadge() {
    return const SizedBox(
      width: 17,
      height: 17,
      child: CustomPaint(
        painter: _VerificationBadgePainter(),
        child: Center(
          child: Icon(
            Icons.check_rounded,
            color: Colors.white,
            size: 11,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: textColor,
              fontSize: fontSize,
              fontWeight: fontWeight,
            ),
          ),
        ),
        if (verified) ...[
          const SizedBox(width: 5),
          _buildVerificationBadge(),
        ],
      ],
    );
  }
}

/// ============================================================================
/// PLAIN BLUE CHATTªX VERIFICATION BADGE
/// ============================================================================

class _VerificationBadgePainter extends CustomPainter {
  const _VerificationBadgePainter();

  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    final double centerX = size.width / 2;
    final double centerY = size.height / 2;

    final double outerRadius =
        math.min(size.width, size.height) / 2;

    final double innerRadius =
        outerRadius * 0.80;

    final Path path = Path();

    const int points = 16;

    for (int i = 0; i < points; i++) {
      final double angle =
          -math.pi / 2 +
          (2 * math.pi * i / points);

      final double radius =
          i.isEven ? outerRadius : innerRadius;

      final double x =
          centerX + math.cos(angle) * radius;

      final double y =
          centerY + math.sin(angle) * radius;

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    path.close();

    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF2196F3)
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(
    covariant _VerificationBadgePainter oldDelegate,
  ) {
    return false;
  }
}