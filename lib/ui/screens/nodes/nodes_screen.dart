import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/theme/kubely_colors.dart';
import '../../../core/theme/kubely_typography.dart';
import '../../../core/constants/spacing.dart';
import '../../../state/providers/mock_data_provider.dart';
import '../../../state/providers/k8s_data_provider.dart';
import 'package:go_router/go_router.dart';
import '../../shared/state_widgets.dart';
import '../../shared/status_dot.dart';

class NodesScreen extends ConsumerWidget {
  const NodesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topPadding = MediaQuery.of(context).padding.top;

    final rawNodes = ref.watch(realNodesProvider).valueOrNull ?? const [];
    final rawMetrics = ref.watch(realNodeMetricsProvider).valueOrNull ?? const [];
    final podCounts = ref.watch(podCountPerNodeProvider).valueOrNull ?? const {};

    // Parse metrics into a map by node name.
    final metricsMap = <String, _NodeMetrics>{};
    for (final m in rawMetrics) {
      final mName = (m['metadata'] as Map<String, dynamic>?)?['name'] as String? ?? '';
      final usage = m['usage'] as Map<String, dynamic>? ?? {};
      final cpuStr = usage['cpu'] as String? ?? '0';
      final memStr = usage['memory'] as String? ?? '0';
      // Parse CPU: "250m" or "1234567890n"
      double cpuCores = 0;
      if (cpuStr.endsWith('n')) {
        cpuCores = (int.tryParse(cpuStr.replaceAll('n', '')) ?? 0) / 1e9;
      } else if (cpuStr.endsWith('m')) {
        cpuCores = (int.tryParse(cpuStr.replaceAll('m', '')) ?? 0) / 1000;
      } else {
        cpuCores = double.tryParse(cpuStr) ?? 0;
      }
      // Parse Memory: "1234Ki" or "1234Mi" or "1234Gi"
      double memGi = 0;
      if (memStr.endsWith('Ki')) {
        memGi = (int.tryParse(memStr.replaceAll('Ki', '')) ?? 0) / (1024 * 1024);
      } else if (memStr.endsWith('Mi')) {
        memGi = (int.tryParse(memStr.replaceAll('Mi', '')) ?? 0) / 1024;
      } else if (memStr.endsWith('Gi')) {
        memGi = (double.tryParse(memStr.replaceAll('Gi', '')) ?? 0);
      }
      metricsMap[mName] = _NodeMetrics(cpuCores: cpuCores, memGi: memGi);
    }

    final nodes = rawNodes.map((n) {
      final meta = n['metadata'] as Map<String, dynamic>? ?? {};
      final spec = n['spec'] as Map<String, dynamic>? ?? {};
      final status = n['status'] as Map<String, dynamic>? ?? {};
      final conditions = status['conditions'] as List<dynamic>? ?? [];

      final name = meta['name'] as String? ?? '';
      final isCordoned = spec['unschedulable'] as bool? ?? false;

      String statusText = 'NotReady';
      for (final c in conditions) {
        if (c['type'] == 'Ready' && c['status'] == 'True') {
          statusText = 'Ready';
          break;
        }
      }

      // Get instance type from labels
      final labels = meta['labels'] as Map<String, dynamic>? ?? {};
      final instanceType =
          labels['node.kubernetes.io/instance-type'] as String? ??
              labels['beta.kubernetes.io/instance-type'] as String? ??
              '';

      // Compute CPU/MEM percent from allocatable capacity and metrics.
      final allocatable = status['allocatable'] as Map<String, dynamic>? ?? {};
      final capCpuStr = allocatable['cpu'] as String? ?? '4';
      final capMemStr = allocatable['memory'] as String? ?? '16Gi';
      double capCpu = double.tryParse(capCpuStr) ?? 4;
      double capMemGi = 0;
      if (capMemStr.endsWith('Ki')) {
        capMemGi = (int.tryParse(capMemStr.replaceAll('Ki', '')) ?? 0) / (1024 * 1024);
      } else if (capMemStr.endsWith('Mi')) {
        capMemGi = (int.tryParse(capMemStr.replaceAll('Mi', '')) ?? 0) / 1024;
      } else if (capMemStr.endsWith('Gi')) {
        capMemGi = double.tryParse(capMemStr.replaceAll('Gi', '')) ?? 16;
      }

      final metrics = metricsMap[name];
      final cpuPercent = (metrics != null && capCpu > 0) ? (metrics.cpuCores / capCpu).clamp(0.0, 1.0) : 0.0;
      final memPercent = (metrics != null && capMemGi > 0) ? (metrics.memGi / capMemGi).clamp(0.0, 1.0) : 0.0;
      final podCount = podCounts[name] ?? 0;

      return _NodeData(
        name: name,
        status: isCordoned ? 'Cordoned' : statusText,
        instanceType: instanceType,
        cpuPercent: cpuPercent,
        memPercent: memPercent,
        podCount: podCount,
        cordoned: isCordoned,
      );
    }).toList();

    final cordonedCount = nodes.where((n) => n.cordoned).length;

    return Scaffold(
      backgroundColor: KubelyColors.ink,
      body: Column(
        children: [
          SizedBox(height: topPadding),
          // App bar
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: KubelySpacing.screenPadding),
            child: SizedBox(
              height: KubelySpacing.appBarHeight,
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).maybePop(),
                    child: Icon(LucideIcons.chevronLeft,
                        size: 24, color: KubelyColors.textSecondary),
                  ),
                  const SizedBox(width: 12),
                  Text('Nodes', style: KubelyTypography.screenTitle),
                  const Spacer(),
                  Text('${nodes.length}${cordonedCount > 0 ? ", $cordonedCount cordoned" : ""}',
                      style: KubelyTypography.monoCaption),
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Node list
          if (ref.watch(hasNoClustersProvider)) ...[
            Expanded(child: KubelyNoClusterState(onAddCluster: () => context.go('/add-cluster'))),
          ] else if (nodes.isEmpty) ...[
            Expanded(
              child: KubelyEmptyState(
                icon: LucideIcons.server,
                title: 'No nodes found',
                subtitle: 'No nodes returned from the cluster API',
              ),
            ),
          ] else ...[
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.only(
                left: KubelySpacing.screenPadding,
                right: KubelySpacing.screenPadding,
                bottom: 40,
              ),
              itemCount: nodes.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final node = nodes[index];
                final isCordoned = node.cordoned;
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isCordoned
                        ? KubelyColors.warningRowBg
                        : KubelyColors.surface,
                    border: Border.all(
                      color: isCordoned
                          ? KubelyColors.warningBorder
                          : KubelyColors.hairline,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          StatusDot(
                            color: isCordoned
                                ? KubelyColors.warning
                                : KubelyColors.running,
                            size: 8,
                            glow: isCordoned,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(node.name,
                                style: KubelyTypography.monoBody,
                                overflow: TextOverflow.ellipsis),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: KubelyColors.textDim
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(node.instanceType,
                                style: KubelyTypography.monoCaptionSm,
                                overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                      if (isCordoned) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(LucideIcons.lock,
                                size: 12, color: KubelyColors.warning),
                            const SizedBox(width: 5),
                            Text('CORDONED',
                                style: KubelyTypography.eyebrow.copyWith(
                                    color: KubelyColors.warning,
                                    fontSize: 10)),
                          ],
                        ),
                      ],
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _MiniBar(
                                label: 'CPU',
                                percent: node.cpuPercent,
                                color: node.cpuPercent > 0.85
                                    ? KubelyColors.warning
                                    : KubelyColors.accent),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _MiniBar(
                                label: 'MEM',
                                percent: node.memPercent,
                                color: node.memPercent > 0.85
                                    ? KubelyColors.warning
                                    : KubelyColors.info),
                          ),
                          const SizedBox(width: 12),
                          Text('${node.podCount} pods',
                              style: KubelyTypography.monoCaption),
                        ],
                      ),
                      if (isCordoned) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _NodeAction(
                                  label: 'Uncordon',
                                  color: KubelyColors.accent,
                                  onTap: () async {
                                    final client = await ref.read(kubeClientProvider.future);
                                    if (client != null) {
                                      try {
                                        await client.uncordonNode(node.name);
                                        ref.invalidate(realNodesProvider);
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                            content: Text('${node.name} uncordoned'),
                                            backgroundColor: KubelyColors.running,
                                            behavior: SnackBarBehavior.floating,
                                          ));
                                        }
                                      } catch (e) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                            content: Text('Uncordon failed: $e'),
                                            backgroundColor: KubelyColors.critical,
                                            behavior: SnackBarBehavior.floating,
                                          ));
                                        }
                                      }
                                    }
                                  }),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _NodeAction(
                                  label: 'Drain',
                                  color: KubelyColors.warning,
                                  onTap: () async {
                                    final client = await ref.read(kubeClientProvider.future);
                                    if (client != null) {
                                      try {
                                        await client.cordonNode(node.name);
                                        ref.invalidate(realNodesProvider);
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                            content: Text('${node.name} cordoned (drain pods manually via CLI)'),
                                            backgroundColor: KubelyColors.warning,
                                            behavior: SnackBarBehavior.floating,
                                          ));
                                        }
                                      } catch (e) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                            content: Text('Cordon failed: $e'),
                                            backgroundColor: KubelyColors.critical,
                                            behavior: SnackBarBehavior.floating,
                                          ));
                                        }
                                      }
                                    }
                                  }),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
          ],
        ],
      ),
    );
  }
}

class _MiniBar extends StatelessWidget {
  const _MiniBar({
    required this.label,
    required this.percent,
    required this.color,
  });
  final String label;
  final double percent;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: KubelyTypography.eyebrow
                    .copyWith(fontSize: 8.5, letterSpacing: 0.7)),
            Text('${(percent * 100).round()}%',
                style: KubelyTypography.monoCaptionSm),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: SizedBox(
            height: 4,
            child: LinearProgressIndicator(
              value: percent,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
      ],
    );
  }
}

class _NodeAction extends StatelessWidget {
  const _NodeAction({required this.label, required this.color, this.onTap});
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          border: Border.all(color: color.withValues(alpha: 0.25)),
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Text(label,
            style: KubelyTypography.sectionLabel
                .copyWith(color: color, fontSize: 12)),
      ),
    );
  }
}

class _NodeData {
  const _NodeData({
    required this.name,
    required this.status,
    required this.instanceType,
    required this.cpuPercent,
    required this.memPercent,
    required this.podCount,
    required this.cordoned,
  });
  final String name;
  final String status;
  final String instanceType;
  final double cpuPercent;
  final double memPercent;
  final int podCount;
  final bool cordoned;
}

class _NodeMetrics {
  const _NodeMetrics({required this.cpuCores, required this.memGi});
  final double cpuCores;
  final double memGi;
}
