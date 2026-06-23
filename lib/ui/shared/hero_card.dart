import 'package:flutter/material.dart';
import '../../core/theme/kubely_colors.dart';
import '../../core/theme/kubely_shadows.dart';

class HeroCard extends StatelessWidget {
  const HeroCard({
    super.key,
    required this.child,
    this.borderColor,
  });

  final Widget child;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: KubelyGradients.heroCard,
        border: Border.all(
          color: borderColor ?? KubelyColors.hairline,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: KubelyShadows.heroInnerGlow,
      ),
      child: child,
    );
  }
}
