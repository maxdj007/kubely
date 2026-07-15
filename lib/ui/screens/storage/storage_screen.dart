import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/theme/kubely_colors.dart';
import '../../../core/theme/kubely_typography.dart';
import '../../../core/constants/spacing.dart';
import '../../../state/providers/mock_data_provider.dart';
import 'package:go_router/go_router.dart';
import '../../shared/namespace_selector.dart';
import '../../shared/state_widgets.dart';

class StorageScreen extends ConsumerStatefulWidget {
  const StorageScreen({super.key});

  @override
  ConsumerState<StorageScreen> createState() => _StorageScreenState();
}

class _StorageScreenState extends ConsumerState<StorageScreen> {
  String _namespace = 'all';

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final pvcs = ref.watch(pvcListProvider).valueOrNull ?? const <PvcData>[];
    final filtered = _namespace == 'all' ? pvcs : pvcs.where((p) => p.namespace == _namespace).toList();
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
                  Text('Storage', style: KubelyTypography.screenTitle),
                  const Spacer(),
                  Text('${filtered.length} PVCs',
                      style: KubelyTypography.monoCaption),
                ],
              ),
            ),
          ),

          // Namespace selector
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: KubelySpacing.screenPadding),
            child: NamespaceSelector(
              namespace: _namespace,
              count: '${filtered.length} PVCs',
              showAll: true,
              onChanged: (ns) => setState(() => _namespace = ns),
            ),
          ),

          const SizedBox(height: 12),

          // PVC list
          if (ref.watch(hasNoClustersProvider)) ...[
            Expanded(child: KubelyNoClusterState(onAddCluster: () => context.go('/add-cluster'))),
          ] else if (!ref.watch(hasMockDataProvider)) ...[
            Expanded(
              child: KubelyEmptyState(
                icon: LucideIcons.database,
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
                final pvc = filtered[index];
                final isBound = pvc.status == 'Bound';
                final statusColor = isBound ? KubelyColors.running : KubelyColors.warning;
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: KubelyColors.surface,
                    border: Border.all(color: KubelyColors.hairline),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(LucideIcons.database,
                              size: 16, color: KubelyColors.info),
                          const SizedBox(width: 8),
                          Expanded(
                              child: Text(pvc.name,
                                  style: KubelyTypography.monoBody,
                                  overflow: TextOverflow.ellipsis)),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(pvc.status,
                                style: KubelyTypography.monoCaptionSm.copyWith(
                                    color: statusColor,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(pvc.capacity,
                              style: KubelyTypography.monoCaption
                                  .copyWith(color: KubelyColors.textMuted)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(pvc.storageClass,
                                style: KubelyTypography.monoCaption,
                                overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
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

