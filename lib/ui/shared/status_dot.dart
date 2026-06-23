import 'package:flutter/material.dart';
import '../../core/theme/kubely_shadows.dart';

class StatusDot extends StatelessWidget {
  const StatusDot({
    super.key,
    required this.color,
    this.size = 9,
    this.glow = false,
  });

  final Color color;
  final double size;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Status indicator',
      child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: glow ? KubelyShadows.statusDotGlow(color) : null,
      ),
    ),
    );
  }
}
