import 'package:flutter/material.dart';
import '../../core/theme/kubely_colors.dart';

class ProviderBadge extends StatelessWidget {
  const ProviderBadge({super.key, required this.provider});

  final String provider;

  Color get _color {
    switch (provider.toUpperCase()) {
      case 'EKS':
        return KubelyColors.providerEks;
      case 'GKE':
        return KubelyColors.providerGke;
      default:
        return KubelyColors.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        provider.toUpperCase(),
        style: TextStyle(
          fontFamily: 'SpaceGrotesk',
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          color: _color,
        ),
      ),
    );
  }
}
