import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/theme/kubely_colors.dart';
import '../../../core/theme/kubely_typography.dart';
import '../../../core/constants/spacing.dart';
import '../../../state/providers/mock_data_provider.dart';
import '../../../state/providers/cluster_provider.dart';
import '../../shared/on_device_badge.dart';
import '../../shared/status_dot.dart';
import '../../shared/segmented_control.dart';

class CommandHomeScreen extends ConsumerStatefulWidget {
  const CommandHomeScreen({super.key});

  @override
  ConsumerState<CommandHomeScreen> createState() => _CommandHomeScreenState();
}

class _CommandHomeScreenState extends ConsumerState<CommandHomeScreen> {
  int _segmentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final cluster = ref.watch(clusterProvider);
    final health = ref.watch(clusterHealthProvider).valueOrNull;
    final deploys = ref.watch(deployListProvider).valueOrNull ?? const [];

    return ColoredBox(
      color: KubelyColors.ink,
      child: Column(
        children: [
          SizedBox(height: topPadding),

          // App bar
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: KubelySpacing.screenPadding),
            child: SizedBox(
              height: 50,
              child: Row(
                children: [
                  StatusDot(
                      color: cluster.activeIsHealthy
                          ? KubelyColors.running
                          : KubelyColors.warning,
                      size: 7,
                      glow: true),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(cluster.activeName,
                        style: KubelyTypography.monoBody
                            .copyWith(fontSize: 14, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1),
                  ),
                  const SizedBox(width: 8),
                  const OnDeviceBadge(),
                ],
              ),
            ),
          ),

          // Command / search bar
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: KubelyColors.surface,
                border: Border.all(color: KubelyColors.hairlineInput),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(LucideIcons.search,
                      size: 17, color: KubelyColors.accent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        style: KubelyTypography.body
                            .copyWith(color: KubelyColors.textDim, fontSize: 13.5),
                        children: [
                          const TextSpan(text: 'Search or run '),
                          TextSpan(
                            text: 'kubectl…',
                            style: KubelyTypography.monoBody
                                .copyWith(color: KubelyColors.textMuted, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12)),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text('/',
                        style: KubelyTypography.monoBodySm
                            .copyWith(color: KubelyColors.textDim)),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Dense vitals strip
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              decoration: BoxDecoration(
                color: KubelyColors.surfaceStrip,
                border: Border.all(color: KubelyColors.hairlineLight),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  _VitalCell(
                      value: '${health != null ? (health.cpuPercent * 100).round() : 0}%',
                      label: 'CPU'),
                  _Divider(),
                  _VitalCell(
                      value: '${health != null ? (health.memPercent * 100).round() : 0}%',
                      label: 'MEM'),
                  _Divider(),
                  _VitalCell(
                      value: '${health?.podCount ?? 0}',
                      label: 'PODS'),
                  _Divider(),
                  _VitalCell(
                      value: '${health?.alerts.length ?? 0}',
                      label: 'WARN',
                      valueColor: (health?.alerts.isNotEmpty ?? false)
                          ? KubelyColors.critical
                          : null),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Segmented control
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedControl(
              segments: const ['Deployments', 'Pods', 'Nodes'],
              selectedIndex: _segmentIndex,
              onChanged: (i) => setState(() => _segmentIndex = i),
            ),
          ),

          const SizedBox(height: 6),

          // Deployment list
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.only(
                left: 8,
                right: 8,
                bottom: KubelySpacing.tabBarHeight +
                    MediaQuery.of(context).padding.bottom +
                    20,
              ),
              itemCount: deploys.length,
              itemBuilder: (context, index) {
                final dep = deploys[index];
                final isHealthy = dep.ready == dep.desired && dep.desired > 0;
                final isFailed = dep.ready == 0 && dep.desired > 0;

                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 11),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.white.withValues(alpha: 0.04),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      StatusDot(
                        color: isFailed
                            ? KubelyColors.warning
                            : isHealthy
                                ? KubelyColors.running
                                : KubelyColors.critical,
                        size: 8,
                        glow: !isHealthy,
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(dep.name,
                                  style: KubelyTypography.monoBody,
                                  overflow: TextOverflow.ellipsis),
                            ),
                            const SizedBox(width: 7),
                            Text(dep.namespace,
                                style: KubelyTypography.caption
                                    .copyWith(fontSize: 11)),
                          ],
                        ),
                      ),
                      Text(
                        '${dep.ready}/${dep.desired}',
                        style: KubelyTypography.monoBody.copyWith(
                          color: isHealthy
                              ? KubelyColors.running
                              : isFailed
                                  ? KubelyColors.warning
                                  : KubelyColors.critical,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(LucideIcons.moreVertical,
                          size: 16, color: KubelyColors.textDim),
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

class _VitalCell extends StatelessWidget {
  const _VitalCell({required this.value, required this.label, this.valueColor});
  final String value;
  final String label;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Column(
          children: [
            Text(value,
                style: KubelyTypography.monoMetricSm
                    .copyWith(color: valueColor)),
            const SizedBox(height: 2),
            Text(label,
                style: KubelyTypography.monoSmall
                    .copyWith(letterSpacing: 0.6)),
          ],
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 30, color: KubelyColors.hairlineLight);
  }
}
