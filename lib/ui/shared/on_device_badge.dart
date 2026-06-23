import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/theme/kubely_colors.dart';
import '../../core/theme/kubely_typography.dart';

class OnDeviceBadge extends StatelessWidget {
  const OnDeviceBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: KubelyColors.surface,
        border: Border.all(color: KubelyColors.hairlineStrong),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.shieldCheck, size: 14, color: KubelyColors.running),
          const SizedBox(width: 5),
          Text('On device',
              style: KubelyTypography.badgeText
                  .copyWith(color: KubelyColors.running)),
        ],
      ),
    );
  }
}
