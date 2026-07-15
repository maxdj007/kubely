import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/theme/kubely_colors.dart';
import '../../core/theme/kubely_typography.dart';
import '../../core/theme/kubely_radii.dart';
import '../../state/providers/mock_data_provider.dart';
import 'status_dot.dart';

class NotificationsSheet extends ConsumerWidget {
  const NotificationsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const NotificationsSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alerts = ref.watch(notificationProvider);
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.6,
      ),
      decoration: const BoxDecoration(
        color: KubelyColors.sheetBackground,
        borderRadius: KubelyRadii.sheet,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: KubelyColors.textFaint,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Icon(LucideIcons.bell, size: 18, color: KubelyColors.critical),
                const SizedBox(width: 10),
                Text('Alerts', style: KubelyTypography.appBarTitle),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: KubelyColors.critical.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text('${alerts.length}',
                      style: KubelyTypography.monoCaptionSm
                          .copyWith(color: KubelyColors.critical, fontWeight: FontWeight.w700)),
                ),
                const Spacer(),
                Text('Mark all read',
                    style: KubelyTypography.caption
                        .copyWith(color: KubelyColors.accent)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: KubelyColors.hairline),
          Flexible(
            child: ListView.builder(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 8,
                bottom: bottomPadding + 16,
              ),
              shrinkWrap: true,
              itemCount: alerts.length,
              itemBuilder: (context, index) {
                final alert = alerts[index];
                final isCritical = alert.severity == 'critical';
                final color =
                    isCritical ? KubelyColors.critical : KubelyColors.warning;
                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: KubelyColors.surface,
                    border: Border.all(
                      color: isCritical
                          ? KubelyColors.criticalBorder
                          : KubelyColors.warningBorder,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child:
                            StatusDot(color: color, size: 8, glow: true),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(alert.title,
                                      style: KubelyTypography.sectionLabel
                                          .copyWith(fontSize: 12.5)),
                                ),
                                Text(alert.time,
                                    style: KubelyTypography.monoCaption),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(alert.resource,
                                style: KubelyTypography.monoCaption
                                    .copyWith(color: KubelyColors.textMuted)),
                            const SizedBox(height: 4),
                            Text(alert.message,
                                style: KubelyTypography.caption
                                    .copyWith(fontSize: 11.5)),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
