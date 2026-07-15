import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/theme/kubely_colors.dart';
import '../../core/theme/kubely_typography.dart';
import 'status_dot.dart';

class AlertRow extends StatelessWidget {
  const AlertRow({
    super.key,
    required this.name,
    required this.status,
    required this.detail,
    this.onTap,
  });

  final String name;
  final String status;
  final String detail;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: KubelyColors.surface,
          border: Border.all(color: KubelyColors.statusBorderColor(status)),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            StatusDot(
              color: KubelyColors.statusColor(status),
              size: 9,
              glow: true,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: KubelyTypography.monoBody,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(detail,
                      style: KubelyTypography.caption.copyWith(
                        color: KubelyColors.statusTextColor(status),
                        fontSize: 11.5,
                      )),
                ],
              ),
            ),
            Icon(LucideIcons.chevronRight,
                size: 16, color: KubelyColors.textDim),
          ],
        ),
      ),
    );
  }
}
