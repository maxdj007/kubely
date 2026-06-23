import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../state/providers/mock_data_provider.dart';
import '../../../core/theme/kubely_colors.dart';
import '../../../core/theme/kubely_typography.dart';
import '../../../core/constants/spacing.dart';
import '../../shared/cluster_switcher_pill.dart';
import '../../shared/on_device_badge.dart';
import '../../shared/hero_card.dart';
import '../../shared/resource_card.dart';
import '../../shared/alert_row.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import '../../shared/notifications_sheet.dart';
import '../../shared/state_widgets.dart';
import '../../../core/utils/reduced_motion.dart';

class VitalsScreen extends ConsumerStatefulWidget {
  const VitalsScreen({super.key});

  @override
  ConsumerState<VitalsScreen> createState() => _VitalsScreenState();
}

class _VitalsScreenState extends ConsumerState<VitalsScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ringController;
  bool _motionChecked = false;

  @override
  void initState() {
    super.initState();
    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_motionChecked) {
      _motionChecked = true;
      if (shouldReduceMotion(context)) {
        _ringController.value = 1.0;
      } else {
        _ringController.forward();
      }
    }
  }

  @override
  void dispose() {
    _ringController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final noClusters = ref.watch(hasNoClustersProvider);
    final healthAsync = ref.watch(clusterHealthProvider);
    final activities = ref.watch(activityProvider);
    final topPadding = MediaQuery.of(context).padding.top;

    if (noClusters) {
      return ColoredBox(
        color: KubelyColors.ink,
        child: KubelyNoClusterState(
          onAddCluster: () => context.go('/add-cluster'),
        ),
      );
    }

    return healthAsync.when(
      loading: () => Scaffold(
        backgroundColor: KubelyColors.ink,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: KubelySpacing.screenPadding),
                child: SizedBox(
                  height: KubelySpacing.appBarHeight,
                  child: Row(
                    children: [
                      const ClusterSwitcherPill(),
                      const Spacer(),
                      const OnDeviceBadge(),
                    ],
                  ),
                ),
              ),
              const Expanded(
                child: KubelyLoadingState(message: 'Fetching cluster data...'),
              ),
            ],
          ),
        ),
      ),
      error: (err, _) => Scaffold(
        backgroundColor: KubelyColors.ink,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: KubelySpacing.screenPadding),
                child: SizedBox(
                  height: KubelySpacing.appBarHeight,
                  child: Row(
                    children: [
                      const ClusterSwitcherPill(),
                      const Spacer(),
                      const OnDeviceBadge(),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: KubelyErrorState(
                  message: '$err',
                  onRetry: () => ref.invalidate(clusterHealthProvider),
                ),
              ),
            ],
          ),
        ),
      ),
      data: (health) =>
          _buildDashboard(context, health, activities, topPadding),
    );
  }

  Widget _buildDashboard(BuildContext context, ClusterHealth health,
      List<ActivityData> activities, double topPadding) {

    return ColoredBox(
      color: KubelyColors.ink,
      child: RefreshIndicator(
        color: KubelyColors.accent,
        backgroundColor: KubelyColors.surface,
        onRefresh: () async {
          await Future.delayed(const Duration(seconds: 1));
        },
        child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: SizedBox(height: topPadding)),
          // App bar
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: KubelySpacing.screenPadding),
              child: SizedBox(
                height: KubelySpacing.appBarHeight,
                child: Row(
                  children: [
                    const ClusterSwitcherPill(),
                    const Spacer(),
                    // Bell with red dot
                    GestureDetector(
                      onTap: () => NotificationsSheet.show(context),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Icon(LucideIcons.bell, size: 22,
                              color: KubelyColors.textSecondary),
                          Positioned(
                            top: -1,
                            right: -1,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: KubelyColors.critical,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: KubelyColors.ink, width: 2),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    const OnDeviceBadge(),
                  ],
                ),
              ),
            ),
          ),

          // Content
          SliverPadding(
            padding: const EdgeInsets.symmetric(
                horizontal: KubelySpacing.screenPadding),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 6),

                // Health hero card
                HeroCard(
                  borderColor: health.isHealthy ? KubelyColors.runningBorder : KubelyColors.warningBorder,
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(health.status,
                                    style: KubelyTypography.monoHeroMetric
                                        .copyWith(
                                            color: health.isHealthy ? KubelyColors.running : KubelyColors.warning)),
                                const SizedBox(height: 3),
                                Text(health.isHealthy ? 'All systems operational' : '${health.alerts.length} issue${health.alerts.length == 1 ? "" : "s"} detected',
                                    style: KubelyTypography.body.copyWith(
                                        color: KubelyColors.textMuted)),
                              ],
                            ),
                          ),
                          AnimatedBuilder(
                            animation: _ringController,
                            builder: (context, _) {
                              final val = health.percent * CurvedAnimation(
                                parent: _ringController,
                                curve: Curves.easeOutCubic,
                              ).value;
                              return CircularPercentIndicator(
                              radius: 31,
                              lineWidth: 6,
                              percent: val.clamp(0.0, 1.0),
                              center: Text('${(val * 100).round()}%',
                                  style: KubelyTypography.monoRingPercent),
                              progressColor: KubelyColors.running,
                              backgroundColor:
                                  Colors.white.withValues(alpha: 0.08),
                              circularStrokeCap: CircularStrokeCap.round,
                            );
                            },
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        child: Divider(
                            height: 1, color: KubelyColors.hairline),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _StatColumn(value: '${health.podCount}', label: 'PODS'),
                          Container(
                              width: 1,
                              height: 30,
                              color: KubelyColors.hairlineLight),
                          _StatColumn(value: '${health.deployCount}', label: 'DEPLOYS'),
                          Container(
                              width: 1,
                              height: 30,
                              color: KubelyColors.hairlineLight),
                          _StatColumn(value: '${health.nodeCount}', label: 'NODES'),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: KubelySpacing.cardGap),

                // CPU + Memory cards
                Row(
                  children: [
                    Expanded(
                      child: ResourceCard(
                        label: 'CPU',
                        percent: health.cpuPercent,
                        percentText: '${(health.cpuPercent * 100).round()}%',
                        detail: health.cpuDetail,
                        gradientType: ResourceGradientType.cpu,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ResourceCard(
                        label: 'Memory',
                        percent: health.memPercent,
                        percentText: '${(health.memPercent * 100).round()}%',
                        detail: health.memDetail,
                        gradientType: ResourceGradientType.memory,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: KubelySpacing.cardGap),

                // Needs attention header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Needs attention',
                        style: KubelyTypography.sectionLabel),
                    Text('${health.alerts.length}',
                        style: KubelyTypography.monoBodySm
                            .copyWith(color: KubelyColors.critical)),
                  ],
                ),

                const SizedBox(height: 10),

                // Alert rows
                ...health.alerts.map((alert) => Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: AlertRow(
                    name: alert.name,
                    status: alert.status,
                    detail: alert.detail,
                    onTap: () => context.go('/workloads/pod/${Uri.encodeComponent(alert.name)}'),
                  ),
                )),

                const SizedBox(height: KubelySpacing.cardGap + 2),

                // Recent activity
                Text('Recent activity',
                    style: KubelyTypography.sectionLabel),
                const SizedBox(height: 10),

                if (activities.isEmpty)
                  Text('No recent activity',
                      style: KubelyTypography.body.copyWith(color: KubelyColors.textDim))
                else
                  ...activities.map((a) => Padding(
                    padding: const EdgeInsets.only(bottom: 11),
                    child: _ActivityRow(
                      iconColor: a.type == 'scale' ? KubelyColors.accent : KubelyColors.info,
                      iconBgColor: (a.type == 'scale' ? KubelyColors.accent : KubelyColors.info).withValues(alpha: 0.12),
                      icon: a.type == 'scale' ? LucideIcons.arrowUpRight : LucideIcons.refreshCw,
                      text: a.text,
                      highlight: a.highlight,
                      suffix: a.suffix,
                      time: a.time,
                    ),
                  )),

                // Bottom padding for tab bar
                SizedBox(
                    height: KubelySpacing.tabBarHeight +
                        MediaQuery.of(context).padding.bottom +
                        20),
              ]),
            ),
          ),
        ],
      ),
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: KubelyTypography.monoMetricLg),
        const SizedBox(height: 2),
        Text(label,
            style: KubelyTypography.eyebrow
                .copyWith(fontSize: 11, letterSpacing: 0.44)),
      ],
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({
    required this.iconColor,
    required this.iconBgColor,
    required this.icon,
    required this.text,
    required this.highlight,
    required this.suffix,
    required this.time,
  });

  final Color iconColor;
  final Color iconBgColor;
  final IconData icon;
  final String text;
  final String highlight;
  final String suffix;
  final String time;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: iconBgColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 14, color: iconColor),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Text.rich(
            TextSpan(
              style: KubelyTypography.body,
              children: [
                TextSpan(text: text),
                TextSpan(
                    text: highlight,
                    style: KubelyTypography.monoBody
                        .copyWith(fontSize: 12.5)),
                TextSpan(text: suffix),
              ],
            ),
          ),
        ),
        Text(time, style: KubelyTypography.monoCaption),
      ],
    );
  }
}
