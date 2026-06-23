import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/kubely_colors.dart';
import '../../../core/theme/kubely_typography.dart';
import '../../../core/constants/spacing.dart';
import '../../../state/providers/mock_data_provider.dart';
import '../../shared/namespace_selector.dart';
import '../../shared/segmented_control.dart';
import '../../shared/state_widgets.dart';

class ConfigListScreen extends ConsumerStatefulWidget {
  const ConfigListScreen({super.key});

  @override
  ConsumerState<ConfigListScreen> createState() => _ConfigListScreenState();
}

class _ConfigListScreenState extends ConsumerState<ConfigListScreen> {
  int _segmentIndex = 0;
  String _namespace = 'all';

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final configMaps = ref.watch(configMapListProvider).valueOrNull ?? const <ConfigItemData>[];
    final secrets = ref.watch(secretListProvider).valueOrNull ?? const <ConfigItemData>[];
    final items = _segmentIndex == 0 ? configMaps : secrets;
    final filtered = _namespace == 'all' ? items : items.where((i) => i.namespace == _namespace).toList();
    final label = _segmentIndex == 0 ? 'configmaps' : 'secrets';

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
                  Text('Config', style: KubelyTypography.screenTitle),
                ],
              ),
            ),
          ),

          // Segmented
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: KubelySpacing.screenPadding),
            child: SegmentedControl(
              segments: const ['ConfigMaps', 'Secrets'],
              selectedIndex: _segmentIndex,
              onChanged: (i) => setState(() => _segmentIndex = i),
            ),
          ),

          const SizedBox(height: 10),

          // Namespace selector
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: KubelySpacing.screenPadding),
            child: NamespaceSelector(
              namespace: _namespace,
              count: '${filtered.length} $label',
              showAll: true,
              onChanged: (ns) => setState(() => _namespace = ns),
            ),
          ),

          const SizedBox(height: 12),

          // List
          if (ref.watch(hasNoClustersProvider)) ...[
            Expanded(child: KubelyNoClusterState(onAddCluster: () => context.go('/add-cluster'))),
          ] else if (!ref.watch(hasMockDataProvider)) ...[
            Expanded(
              child: KubelyEmptyState(
                icon: LucideIcons.fileText,
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
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = filtered[index];
                final isSecret = _segmentIndex == 1;
                return GestureDetector(
                  onTap: () => context.go(
                    '/more/config/${Uri.encodeComponent(item.name)}',
                    extra: {
                      'namespace': item.namespace,
                      'isSecret': _segmentIndex == 1,
                    },
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: KubelyColors.surface,
                      border: Border.all(color: KubelyColors.hairline),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: (isSecret
                                    ? KubelyColors.warning
                                    : KubelyColors.info)
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Icon(
                            isSecret
                                ? LucideIcons.keyRound
                                : LucideIcons.fileText,
                            size: 16,
                            color: isSecret
                                ? KubelyColors.warning
                                : KubelyColors.info,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.name,
                                  style: KubelyTypography.monoBody,
                                  overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  Text('${item.keyCount} keys',
                                      style: KubelyTypography.caption
                                          .copyWith(fontSize: 11)),
                                  if (isSecret) ...[
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(item.type,
                                          style: KubelyTypography.monoCaptionSm
                                              .copyWith(
                                                  color:
                                                      KubelyColors.textDim),
                                          overflow: TextOverflow.ellipsis),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        Icon(LucideIcons.chevronRight,
                            size: 16, color: KubelyColors.textDim),
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

