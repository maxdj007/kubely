import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/theme/kubely_colors.dart';
import '../../../core/theme/kubely_typography.dart';
import '../../../core/constants/spacing.dart';
import '../../../state/providers/mock_data_provider.dart';
import 'package:go_router/go_router.dart';
import '../../shared/cluster_switcher_pill.dart';
import '../../shared/segmented_control.dart';
import '../../shared/namespace_selector.dart';
import '../../shared/state_widgets.dart';

class NetworkScreen extends ConsumerStatefulWidget {
  const NetworkScreen({super.key});

  @override
  ConsumerState<NetworkScreen> createState() => _NetworkScreenState();
}

class _NetworkScreenState extends ConsumerState<NetworkScreen> {
  int _segmentIndex = 0;
  String _namespace = 'all';

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final services = ref.watch(serviceListProvider).valueOrNull ?? const <ServiceData>[];
    final ingresses = ref.watch(ingressListProvider).valueOrNull ?? const <IngressData>[];
    final noClusters = ref.watch(hasNoClustersProvider);
    final hasMockData = ref.watch(hasMockDataProvider);
    final filteredSvcs = _namespace == 'all'
        ? services
        : services.where((s) => s.namespace == _namespace).toList();
    final filteredIngresses = _namespace == 'all'
        ? ingresses
        : ingresses.where((i) => i.namespace == _namespace).toList();

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
                  Text('Network', style: KubelyTypography.screenTitle),
                  const Spacer(),
                  const ClusterSwitcherPill(compact: true),
                ],
              ),
            ),
          ),

          // Segmented
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: KubelySpacing.screenPadding),
            child: SegmentedControl(
              segments: const ['Services', 'Ingresses'],
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
              showAll: true,
              count: _segmentIndex == 0
                  ? '${filteredSvcs.length} services'
                  : '${filteredIngresses.length} ingresses',
              onChanged: (ns) => setState(() => _namespace = ns),
            ),
          ),

          const SizedBox(height: 12),

          // List
          if (noClusters) ...[
            Expanded(child: KubelyNoClusterState(onAddCluster: () => context.go('/add-cluster'))),
          ] else if (!hasMockData && filteredSvcs.isEmpty) ...[
            Expanded(
              child: KubelyEmptyState(
                icon: LucideIcons.network,
                title: 'No data yet',
                subtitle: 'Live API not connected for this cluster',
              ),
            ),
          ] else ...[
            Expanded(
              child: _segmentIndex == 0
                  ? _buildServicesList(filteredSvcs)
                  : _buildIngressList(filteredIngresses),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildIngressList(List<IngressData> items) {
    if (items.isEmpty) {
      return const Center(
        child: Text('No ingresses', style: TextStyle(color: KubelyColors.textSecondary)),
      );
    }
    return ListView.separated(
      padding: EdgeInsets.only(
        left: KubelySpacing.screenPadding,
        right: KubelySpacing.screenPadding,
        bottom: 40,
      ),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final ing = items[index];
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
                  Icon(LucideIcons.globe, size: 16, color: KubelyColors.info),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(ing.name,
                        style: KubelyTypography.monoBody,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(ing.host,
                  style: KubelyTypography.monoCaption
                      .copyWith(color: KubelyColors.accent),
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Text('→ ${ing.backend}',
                  style: KubelyTypography.monoCaptionSm
                      .copyWith(color: KubelyColors.textDim),
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        );
      },
    );
  }

  Widget _buildServicesList(List<ServiceData> items) {
    if (items.isEmpty) {
      return const Center(
        child: Text('No services', style: TextStyle(color: KubelyColors.textSecondary)),
      );
    }
    return ListView.separated(
      padding: EdgeInsets.only(
        left: KubelySpacing.screenPadding,
        right: KubelySpacing.screenPadding,
        bottom: 40,
      ),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final svc = items[index];
        return GestureDetector(
          onTap: () => context.go(
            '/more/network/svc/${Uri.encodeComponent(svc.name)}',
            extra: {'namespace': svc.namespace},
          ),
          child: Container(
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
                  Flexible(child: Text(svc.name, style: KubelyTypography.monoBody,
                      overflow: TextOverflow.ellipsis, maxLines: 1)),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: svc.type == 'LoadBalancer'
                          ? KubelyColors.accent.withValues(alpha: 0.12)
                          : KubelyColors.info.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(svc.type,
                        style: KubelyTypography.monoCaptionSm.copyWith(
                            color: svc.type == 'LoadBalancer'
                                ? KubelyColors.accent
                                : KubelyColors.info,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _DetailChip(
                      label: 'CLUSTER-IP', value: svc.clusterIp),
                  const SizedBox(width: 12),
                  _DetailChip(label: 'PORT', value: svc.port),
                ],
              ),
            ],
          ),
        ),
        );
      },
    );
  }
}

class _DetailChip extends StatelessWidget {
  const _DetailChip({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label ',
              style: KubelyTypography.eyebrow.copyWith(fontSize: 9)),
          Flexible(
            child: Text(value, style: KubelyTypography.monoCaption,
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

