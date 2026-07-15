import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/kubely_colors.dart';
import '../../../core/theme/kubely_typography.dart';
import '../../../core/constants/spacing.dart';
import '../../../state/providers/mock_data_provider.dart';
import '../../shared/cluster_switcher_pill.dart';
import '../../shared/segmented_control.dart';
import '../../shared/namespace_selector.dart';
import '../../shared/status_dot.dart';
import '../../shared/sparkline.dart';
import '../../shared/swipe_action_row.dart';
import '../../shared/confirm_bottom_sheet.dart';
import '../../shared/state_widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class WorkloadsScreen extends ConsumerStatefulWidget {
  const WorkloadsScreen({super.key});

  @override
  ConsumerState<WorkloadsScreen> createState() => _WorkloadsScreenState();
}

class _WorkloadsScreenState extends ConsumerState<WorkloadsScreen> {
  int _segmentIndex = 0;
  String _namespace = 'all';
  bool _searchOpen = false;
  String _searchQuery = '';
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  List<PodData> get _filteredPods {
    var pods = ref.read(podListProvider).valueOrNull ?? const [];
    if (_namespace != 'all') {
      pods = pods.where((p) => p.namespace == _namespace).toList();
    }
    if (_searchQuery.isNotEmpty) {
      pods = pods.where((p) => p.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    }
    return pods;
  }

  List<DeployData> get _filteredDeploys {
    var deploys = ref.read(deployListProvider).valueOrNull ?? const [];
    if (_namespace != 'all') {
      deploys = deploys.where((d) => d.namespace == _namespace).toList();
    }
    if (_searchQuery.isNotEmpty) {
      deploys = deploys.where((d) => d.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    }
    return deploys;
  }

  List<ServiceData> get _filteredServices {
    var services = ref.read(serviceListProvider).valueOrNull ?? const [];
    if (_namespace != 'all') {
      services = services.where((s) => s.namespace == _namespace).toList();
    }
    if (_searchQuery.isNotEmpty) {
      services = services.where((s) => s.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    }
    return services;
  }

  String get _countLabel {
    switch (_segmentIndex) {
      case 0:
        return '${_filteredPods.length} pods';
      case 1:
        return '${_filteredDeploys.length} deployments';
      case 2:
        return '${_filteredServices.length} services';
      default:
        return '';
    }
  }

  void _toggleSearch() {
    setState(() {
      _searchOpen = !_searchOpen;
      if (!_searchOpen) {
        _searchController.clear();
        _searchQuery = '';
        _searchFocus.unfocus();
      } else {
        _searchFocus.requestFocus();
      }
    });
  }

  void _onRestart(String name) async {
    final confirmed = await ConfirmBottomSheet.show(
      context,
      action: ConfirmAction.restart,
      resourceName: name,
    );
    if (confirmed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Restarting $name...'),
          backgroundColor: KubelyColors.info,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _onDelete(String name) async {
    final confirmed = await ConfirmBottomSheet.show(
      context,
      action: ConfirmAction.delete,
      resourceName: name,
    );
    if (confirmed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Deleting $name...'),
          backgroundColor: KubelyColors.critical,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(podListProvider);
    ref.watch(deployListProvider);
    ref.watch(serviceListProvider);
    final topPadding = MediaQuery.of(context).padding.top;
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
              height: KubelySpacing.appBarHeight,
              child: Row(
                children: [
                  Text('Workloads', style: KubelyTypography.screenTitle),
                  const Spacer(),
                  GestureDetector(
                    onTap: _toggleSearch,
                    child: Icon(
                      _searchOpen ? LucideIcons.x : LucideIcons.search,
                      size: 20,
                      color: _searchOpen
                          ? KubelyColors.accent
                          : KubelyColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const ClusterSwitcherPill(compact: true),
                ],
              ),
            ),
          ),

          // Search bar
          if (_searchOpen)
            Padding(
              padding: const EdgeInsets.only(
                left: KubelySpacing.screenPadding,
                right: KubelySpacing.screenPadding,
                bottom: 10,
              ),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                decoration: BoxDecoration(
                  color: KubelyColors.surface,
                  border: Border.all(
                      color: KubelyColors.accent.withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(LucideIcons.search,
                        size: 16, color: KubelyColors.accent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        focusNode: _searchFocus,
                        style: KubelyTypography.monoBody.copyWith(fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Filter by name…',
                          hintStyle: KubelyTypography.monoBody.copyWith(
                              color: KubelyColors.textDim, fontSize: 13),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 10),
                        ),
                        onChanged: (v) => setState(() => _searchQuery = v),
                      ),
                    ),
                    if (_searchQuery.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                        child: Icon(LucideIcons.x,
                            size: 14, color: KubelyColors.textDim),
                      ),
                  ],
                ),
              ),
            ),

          // Segmented control
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: KubelySpacing.screenPadding),
            child: SegmentedControl(
              segments: const ['Pods', 'Deployments', 'Services'],
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
              count: _countLabel,
              showAll: true,
              onChanged: (ns) => setState(() => _namespace = ns),
            ),
          ),

          const SizedBox(height: 6),

          // List
          if (ref.watch(hasNoClustersProvider)) ...[
            Expanded(child: KubelyNoClusterState(onAddCluster: () => context.go('/add-cluster'))),
          ] else if (!ref.watch(hasMockDataProvider)) ...[
            const Expanded(
              child: KubelyEmptyState(
                icon: LucideIcons.box,
                title: 'No data yet',
                subtitle: 'Live API not connected for this cluster',
              ),
            ),
          ] else ...[
          Expanded(
            child: _segmentIndex == 0
                ? _buildPodList(context)
                : _segmentIndex == 1
                    ? _buildDeploymentList(context)
                    : _buildServiceList(context),
          ),
          ],
        ],
      ),
    );
  }

  Widget _buildPodList(BuildContext context) {
    final pods = _filteredPods;
    return RefreshIndicator(
      color: KubelyColors.accent,
      backgroundColor: KubelyColors.surface,
      onRefresh: () async {
        await Future.delayed(const Duration(seconds: 1));
      },
      child: ListView.builder(
        padding: EdgeInsets.only(
          left: 8,
          right: 8,
          bottom: KubelySpacing.tabBarHeight +
              MediaQuery.of(context).padding.bottom +
              20,
        ),
        itemCount: pods.length,
        itemBuilder: (context, index) {
          final pod = pods[index];
          final isError =
              pod.status == 'CrashLoopBackOff' || pod.status == 'Error';
          final isWarning = pod.status == 'Pending';

          final row = GestureDetector(
            onTap: () => context.go(
                '/workloads/pod/${Uri.encodeComponent(pod.name)}'),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
              decoration: BoxDecoration(
                color: KubelyColors.ink,
                border: Border(
                  bottom: BorderSide(
                    color: Colors.white.withValues(alpha: 0.04),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  StatusDot(
                    color: KubelyColors.statusColor(pod.status),
                    size: 8,
                    glow: isError || isWarning,
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(pod.name,
                            style: KubelyTypography.monoBody,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Text('${pod.status} · ${pod.age}',
                            style: KubelyTypography.caption.copyWith(
                              color:
                                  KubelyColors.statusTextColor(pod.status),
                              fontSize: 11.5,
                            )),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Sparkline(
                    data: pod.sparkline,
                    lineColor: isError
                        ? KubelyColors.critical
                        : isWarning
                            ? KubelyColors.warning
                            : KubelyColors.accent,
                  ),
                  const SizedBox(width: 8),
                  Icon(LucideIcons.chevronRight,
                      size: 16, color: KubelyColors.textDim),
                ],
              ),
            ),
          );

          return SwipeActionRow(
            key: ValueKey(pod.name),
            onRestart: () => _onRestart(pod.name),
            onDelete: () => _onDelete(pod.name),
            child: row,
          );
        },
      ),
    );
  }

  Widget _buildDeploymentList(BuildContext context) {
    final deploys = _filteredDeploys;
    return RefreshIndicator(
      color: KubelyColors.accent,
      backgroundColor: KubelyColors.surface,
      onRefresh: () async {
        await Future.delayed(const Duration(seconds: 1));
      },
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
          final isDegraded = dep.ready < dep.desired && dep.ready > 0;
          final isFailed = dep.ready == 0 && dep.desired > 0;

          final row = GestureDetector(
            onTap: () => context.go(
              '/workloads/deploy/${Uri.encodeComponent(dep.name)}',
              extra: {
                'namespace': dep.namespace,
                'ready': dep.ready,
                'desired': dep.desired,
              },
            ),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
              decoration: BoxDecoration(
                color: KubelyColors.ink,
                border: Border(
                  bottom: BorderSide(
                    color: Colors.white.withValues(alpha: 0.04),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  StatusDot(
                    color: isFailed
                        ? KubelyColors.warning
                        : isDegraded
                            ? KubelyColors.critical
                            : KubelyColors.running,
                    size: 8,
                    glow: !isHealthy,
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(dep.name, style: KubelyTypography.monoBody, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
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
                          : isDegraded
                              ? KubelyColors.critical
                              : KubelyColors.warning,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(LucideIcons.chevronRight,
                      size: 16, color: KubelyColors.textDim),
                ],
              ),
            ),
          );

          return SwipeActionRow(
            key: ValueKey('dep-${dep.name}'),
            onRestart: () => _onRestart(dep.name),
            onDelete: () => _onDelete(dep.name),
            child: row,
          );
        },
      ),
    );
  }

  Widget _buildServiceList(BuildContext context) {
    final services = _filteredServices;
    return RefreshIndicator(
      color: KubelyColors.accent,
      backgroundColor: KubelyColors.surface,
      onRefresh: () async {
        await Future.delayed(const Duration(seconds: 1));
      },
      child: ListView.builder(
        padding: EdgeInsets.only(
          left: 8,
          right: 8,
          bottom: KubelySpacing.tabBarHeight +
              MediaQuery.of(context).padding.bottom +
              20,
        ),
        itemCount: services.length,
        itemBuilder: (context, index) {
          final svc = services[index];
          final isLB = svc.type == 'LoadBalancer';
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Colors.white.withValues(alpha: 0.04),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isLB ? KubelyColors.accent : KubelyColors.info,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(svc.name, style: KubelyTypography.monoBody,
                                overflow: TextOverflow.ellipsis, maxLines: 1),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: (isLB
                                      ? KubelyColors.accent
                                      : KubelyColors.info)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              svc.type,
                              style: KubelyTypography.monoCaptionSm.copyWith(
                                color: isLB
                                    ? KubelyColors.accent
                                    : KubelyColors.info,
                                fontWeight: FontWeight.w600,
                                fontSize: 9.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${svc.clusterIp}:${svc.port}',
                        style: KubelyTypography.monoCaption,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(LucideIcons.chevronRight,
                    size: 16, color: KubelyColors.textDim),
              ],
            ),
          );
        },
      ),
    );
  }
}
