import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/kubely_colors.dart';
import '../../../core/theme/kubely_typography.dart';
import '../../../core/theme/kubely_radii.dart';
import '../../shared/status_dot.dart';
import '../../shared/provider_badge.dart';

class ClusterSwitcherSheet extends StatelessWidget {
  const ClusterSwitcherSheet({
    super.key,
    required this.clusters,
    required this.activeIndex,
  });

  final List<ClusterOption> clusters;
  final int activeIndex;

  static Future<int?> show(
    BuildContext context, {
    required List<ClusterOption> clusters,
    required int activeIndex,
  }) {
    return showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => ClusterSwitcherSheet(
        clusters: clusters,
        activeIndex: activeIndex,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                Icon(LucideIcons.server, size: 18, color: KubelyColors.accent),
                const SizedBox(width: 10),
                Text('Switch cluster',
                    style: KubelyTypography.appBarTitle),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: KubelyColors.hairline),
          Flexible(
            child: ListView.builder(
              padding: EdgeInsets.only(
                left: 12,
                right: 12,
                top: 6,
                bottom: 8,
              ),
              shrinkWrap: true,
              itemCount: clusters.length,
              itemBuilder: (context, index) {
                final cluster = clusters[index];
                final isActive = index == activeIndex;
                return GestureDetector(
                  onTap: () => Navigator.of(context).pop(index),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 13),
                    margin: const EdgeInsets.symmetric(vertical: 3),
                    decoration: BoxDecoration(
                      color: isActive
                          ? KubelyColors.accent.withValues(alpha: 0.08)
                          : Colors.transparent,
                      border: isActive
                          ? Border.all(
                              color:
                                  KubelyColors.accent.withValues(alpha: 0.25))
                          : null,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        StatusDot(
                          color: cluster.isReachable
                              ? KubelyColors.running
                              : KubelyColors.critical,
                          size: 8,
                          glow: true,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(cluster.name,
                                        style: KubelyTypography.monoBody,
                                        overflow: TextOverflow.ellipsis),
                                  ),
                                  const SizedBox(width: 8),
                                  ProviderBadge(provider: cluster.provider),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                cluster.isReachable
                                    ? 'Connected · ${cluster.region}'
                                    : 'Unreachable',
                                style: KubelyTypography.caption.copyWith(
                                  color: cluster.isReachable
                                      ? KubelyColors.textDim
                                      : KubelyColors.criticalText,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isActive)
                          Icon(LucideIcons.check,
                              size: 18, color: KubelyColors.accent),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Add cluster button
          Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 4,
              bottom: bottomPadding + 16,
            ),
            child: GestureDetector(
              onTap: () {
                Navigator.of(context).pop();
                context.push('/add-cluster');
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: KubelyColors.accent.withValues(alpha: 0.3),
                    style: BorderStyle.solid,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(LucideIcons.plusCircle,
                        size: 18, color: KubelyColors.accent),
                    const SizedBox(width: 8),
                    Text('Add cluster',
                        style: KubelyTypography.sectionLabel
                            .copyWith(color: KubelyColors.accent)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ClusterOption {
  const ClusterOption({
    required this.name,
    required this.provider,
    this.region = '',
    this.isReachable = true,
  });

  final String name;
  final String provider;
  final String region;
  final bool isReachable;
}
