import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/kubely_colors.dart';
import '../../../core/theme/kubely_typography.dart';
import '../../../core/constants/spacing.dart';
import '../../../state/providers/mock_data_provider.dart';
import '../../shared/cluster_switcher_pill.dart';
import '../../shared/namespace_selector.dart';
import '../../shared/state_widgets.dart';
import '../../shared/status_dot.dart';
import 'package:go_router/go_router.dart';

class EventsScreen extends ConsumerStatefulWidget {
  const EventsScreen({super.key});

  @override
  ConsumerState<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends ConsumerState<EventsScreen> {
  String _namespace = 'all';
  String _filter = 'all'; // 'all', 'Warning', 'Normal'
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) ref.invalidate(eventListProvider);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  List<EventData> get _filteredEvents {
    var events = ref.read(eventListProvider).valueOrNull ?? const [];
    if (_namespace != 'all') {
      events = events.where((e) => e.namespace == _namespace).toList();
    }
    if (_filter != 'all') {
      events = events.where((e) => e.type == _filter).toList();
    }
    return events;
  }

  @override
  Widget build(BuildContext context) {
    final noClusters = ref.watch(hasNoClustersProvider);
    final hasMockData = ref.watch(hasMockDataProvider);
    final allEvents = ref.watch(eventListProvider).valueOrNull ?? const [];
    final topPadding = MediaQuery.of(context).padding.top;

    if (noClusters) {
      return ColoredBox(
        color: KubelyColors.ink,
        child: KubelyNoClusterState(
          onAddCluster: () => context.go('/add-cluster'),
        ),
      );
    }
    if (!hasMockData) {
      return const ColoredBox(
        color: KubelyColors.ink,
        child: KubelyEmptyState(
          icon: LucideIcons.bell,
          title: 'No data yet',
          subtitle: 'Live API not connected for this cluster',
        ),
      );
    }

    return ColoredBox(
      color: KubelyColors.ink,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                  Text('Events', style: KubelyTypography.screenTitle),
                  const SizedBox(width: 10),
                  // Live indicator
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: KubelyColors.running.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        StatusDot(
                            color: KubelyColors.running, size: 6, glow: true)
                        .animate(onPlay: (c) => c.repeat())
                        .scale(
                          begin: const Offset(1, 1),
                          end: const Offset(1.4, 1.4),
                          duration: 1400.ms,
                          curve: Curves.easeOut,
                        )
                        .fadeOut(
                          begin: 1,
                          delay: 700.ms,
                          duration: 700.ms,
                        ),
                        const SizedBox(width: 5),
                        Text('live',
                            style: KubelyTypography.caption
                                .copyWith(color: KubelyColors.running)),
                      ],
                    ),
                  ),
                  const Spacer(),
                  const ClusterSwitcherPill(compact: true),
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
              count: '${_filteredEvents.length} events',
              onChanged: (ns) => setState(() => _namespace = ns),
            ),
          ),

          const SizedBox(height: 12),

          // Severity filter chips
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: KubelySpacing.screenPadding),
            child: Row(
              children: [
                _FilterChip(
                  label: 'All',
                  active: _filter == 'all',
                  onTap: () => setState(() => _filter = 'all'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Warning',
                  active: _filter == 'Warning',
                  color: KubelyColors.critical,
                  count: '${allEvents.where((e) => e.type == "Warning").length}',
                  onTap: () => setState(() => _filter = 'Warning'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Normal',
                  active: _filter == 'Normal',
                  onTap: () => setState(() => _filter = 'Normal'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Event list
          Expanded(
            child: RefreshIndicator(
              color: KubelyColors.accent,
              backgroundColor: KubelyColors.surface,
              onRefresh: () async {
                ref.invalidate(eventListProvider);
                await ref.read(eventListProvider.future);
              },
              child: ListView.builder(
              padding: EdgeInsets.only(
                bottom: KubelySpacing.tabBarHeight +
                    MediaQuery.of(context).padding.bottom +
                    20,
              ),
              itemCount: _filteredEvents.length,
              itemBuilder: (context, index) {
                final event = _filteredEvents[index];
                final isWarning = event.type == 'Warning';
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: KubelySpacing.screenPadding,
                    vertical: 6,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: StatusDot(
                          color: isWarning
                              ? KubelyColors.warning
                              : KubelyColors.info,
                          size: 8,
                        ),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(event.reason,
                                    style: KubelyTypography.sectionLabel
                                        .copyWith(fontSize: 12.5)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(event.object,
                                      style: KubelyTypography.monoCaption,
                                      overflow: TextOverflow.ellipsis),
                                ),
                                Text(event.age,
                                    style: KubelyTypography.monoCaption),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(event.message,
                                style: KubelyTypography.caption
                                    .copyWith(fontSize: 11.5),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.active,
    this.color,
    this.count,
    this.onTap,
  });

  final String label;
  final bool active;
  final Color? color;
  final String? count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: active ? KubelyColors.accent : Colors.transparent,
        border: Border.all(
          color: active
              ? KubelyColors.accent
              : color ?? KubelyColors.hairlineStrong,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: KubelyTypography.caption.copyWith(
              color: active ? KubelyColors.ink : color ?? KubelyColors.textMuted,
              fontWeight: active ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
          if (count != null) ...[
            const SizedBox(width: 5),
            Text(count!,
                style: KubelyTypography.monoCaptionSm
                    .copyWith(color: active ? KubelyColors.ink : color)),
          ],
        ],
      ),
    ),
    );
  }
}

