import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class GlassAppBarBackground extends StatelessWidget {
  const GlassAppBarBackground({super.key, required this.isLight});
  final bool isLight;
  @override
  Widget build(BuildContext context) {
    final base = isLight ? Colors.white : const Color(0xFF0B1220);
    final border = isLight ? const Color(0x33000000) : const Color(0x33FFFFFF);
    return ClipRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          color: base.withValues(alpha: 0.72),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Container(height: 0.7, color: border),
          ),
        ),
      ),
    );
  }
}
