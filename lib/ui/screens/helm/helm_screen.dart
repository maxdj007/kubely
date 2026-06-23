import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/kubely_colors.dart';
import '../../../core/theme/kubely_typography.dart';
import '../../../core/constants/spacing.dart';
import '../../../state/providers/mock_data_provider.dart';
import 'package:go_router/go_router.dart';
import '../../shared/namespace_selector.dart';
import '../../shared/state_widgets.dart';

class HelmScreen extends ConsumerStatefulWidget {
  const HelmScreen({super.key});

  @override
  ConsumerState<HelmScreen> createState() => _HelmScreenState();
}

class _HelmScreenState extends ConsumerState<HelmScreen> {
  String _namespace = 'all';

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final releases = ref.watch(helmReleaseListProvider).valueOrNull ?? const <HelmReleaseData>[];
    final filtered = _namespace == 'all' ? releases : releases.where((r) => r.namespace == _namespace).toList();
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
                  Text('Helm', style: KubelyTypography.screenTitle),
                  const Spacer(),
                  Text('${filtered.length} releases',
                      style: KubelyTypography.monoCaption),
                ],
              ),
            ),
          ),

          // Namespace selector (defaults to all for Helm)
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: KubelySpacing.screenPadding),
            child: NamespaceSelector(
              namespace: _namespace,
              count: '${filtered.length} releases',
              showAll: true,
              onChanged: (ns) => setState(() => _namespace = ns),
            ),
          ),

          const SizedBox(height: 12),

          // Release list
          if (ref.watch(hasNoClustersProvider)) ...[
            Expanded(child: KubelyNoClusterState(onAddCluster: () => context.go('/add-cluster'))),
          ] else if (!ref.watch(hasMockDataProvider)) ...[
            Expanded(
              child: KubelyEmptyState(
                icon: LucideIcons.layers,
                title: 'No data yet',
                subtitle: 'Live API not connected for this cluster',
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
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final rel = filtered[index];
                final isDeployed = rel.status == 'deployed';
                final statusColor = isDeployed
                    ? KubelyColors.running
                    : KubelyColors.critical;
                return GestureDetector(
                  onTap: () => context.go(
                    '/more/helm/${Uri.encodeComponent(rel.name)}',
                    extra: {'namespace': rel.namespace},
                  ),
                  child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: KubelyColors.surface,
                    border: Border.all(
                      color: isDeployed
                          ? KubelyColors.hairline
                          : KubelyColors.criticalBorder,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(LucideIcons.layers,
                              size: 16,
                              color: statusColor.withValues(alpha: 0.8)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(rel.name,
                                style: KubelyTypography.monoBody,
                                overflow: TextOverflow.ellipsis),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(rel.status,
                                style: KubelyTypography.monoCaptionSm.copyWith(
                                    color: statusColor,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(rel.namespace,
                          style: KubelyTypography.caption
                              .copyWith(color: KubelyColors.textDim)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _DetailPill(
                              label: 'CHART', value: rel.chart),
                          const SizedBox(width: 10),
                          _DetailPill(
                              label: 'REV', value: '${rel.revision}'),
                        ],
                      ),
                    ],
                  ),
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

class _DetailPill extends StatelessWidget {
  const _DetailPill({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label ',
              style: KubelyTypography.eyebrow
                  .copyWith(fontSize: 8.5, letterSpacing: 0.7)),
          Flexible(
            child: Text(value,
                style: KubelyTypography.monoCaptionSm,
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

