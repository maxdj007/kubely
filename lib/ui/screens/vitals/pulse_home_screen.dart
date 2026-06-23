import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/kubely_colors.dart';
import '../../../core/theme/kubely_typography.dart';
import '../../../core/constants/spacing.dart';
import '../../../state/providers/mock_data_provider.dart';
import '../../shared/cluster_switcher_pill.dart';
import '../../../core/utils/reduced_motion.dart';

const _emptyPulseHealth = ClusterHealth(
  status: 'Loading', percent: 0, podCount: 0, deployCount: 0,
  nodeCount: 0, cpuPercent: 0, memPercent: 0,
  cpuDetail: '', memDetail: '', alerts: [],
);

class PulseHomeScreen extends ConsumerStatefulWidget {
  const PulseHomeScreen({super.key});

  @override
  ConsumerState<PulseHomeScreen> createState() => _PulseHomeScreenState();
}

class _PulseHomeScreenState extends ConsumerState<PulseHomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  bool _motionChecked = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3400),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_motionChecked) {
      _motionChecked = true;
      if (!shouldReduceMotion(context)) {
        _pulseController.repeat();
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final health = ref.watch(clusterHealthProvider).valueOrNull ?? _emptyPulseHealth;
    final reduceMotion = shouldReduceMotion(context);

    return ColoredBox(
      color: KubelyColors.ink,
      child: Column(
        children: [
          SizedBox(height: topPadding),

          // Minimal top bar
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: KubelySpacing.screenPadding),
            child: SizedBox(
              height: 50,
              child: Row(
                children: [
                  Icon(Icons.settings,
                      size: 22, color: KubelyColors.textDim),
                  const Spacer(),
                  const ClusterSwitcherPill(compact: true),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Pulse hero ring
          SizedBox(
            width: 210,
            height: 210,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Expanding radial glow (hidden when reduced motion)
                if (!reduceMotion)
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      final t = _pulseController.value;
                      final scale = 1.0 + (t * 0.25);
                      final opacity = (1.0 - t) * 0.5;
                      return Transform.scale(
                        scale: scale,
                        child: Container(
                          width: 180,
                          height: 180,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                KubelyColors.running
                                    .withValues(alpha: opacity * 0.3),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                // Ring background
                CustomPaint(
                  size: const Size(210, 210),
                  painter: _PulseRingPainter(
                    percent: health.percent,
                    color: health.isHealthy
                        ? KubelyColors.running
                        : KubelyColors.warning,
                    nodeCount: health.nodeCount,
                  ),
                ),

                // Center text
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${(health.percent * 100).round()}%',
                      style: KubelyTypography.monoHeroLarge.copyWith(
                        fontSize: 46,
                        color: KubelyColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'CLUSTER HEALTH',
                      style: KubelyTypography.eyebrow.copyWith(
                        fontSize: 10,
                        letterSpacing: 1.2,
                        color: KubelyColors.textDim,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ).animate(
              autoPlay: !reduceMotion,
              value: reduceMotion ? 1.0 : 0.0,
          ).fadeIn(duration: 800.ms).scale(
              begin: const Offset(0.9, 0.9),
              end: const Offset(1.0, 1.0),
              duration: 800.ms,
              curve: Curves.easeOutCubic),

          const SizedBox(height: 28),

          // Horizontal namespace cards
          SizedBox(
            height: 72,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _NamespaceCard(name: 'default', podCount: 24, active: true),
                const SizedBox(width: 10),
                _NamespaceCard(name: 'kube-system', podCount: 8),
                const SizedBox(width: 10),
                _NamespaceCard(name: 'infra', podCount: 6),
                const SizedBox(width: 10),
                _NamespaceCard(name: 'monitoring', podCount: 5),
                const SizedBox(width: 10),
                _NamespaceCard(name: 'jobs', podCount: 4),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Two large tiles
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: _StatTile(
                    label: 'Workloads',
                    value: '${health.podCount}',
                    subtitle: 'pods running',
                    color: KubelyColors.accent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatTile(
                    label: 'Active alerts',
                    value: '${health.alerts.length}',
                    subtitle: health.alerts.isEmpty
                        ? 'all clear'
                        : 'needs attention',
                    color: health.alerts.isEmpty
                        ? KubelyColors.running
                        : KubelyColors.critical,
                  ),
                ),
              ],
            ),
          ),

          const Spacer(),
        ],
      ),
    );
  }
}

class _PulseRingPainter extends CustomPainter {
  _PulseRingPainter({
    required this.percent,
    required this.color,
    required this.nodeCount,
  });

  final double percent;
  final Color color;
  final int nodeCount;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;
    final strokeWidth = 8.0;

    // Background ring
    final bgPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, bgPaint);

    // Progress arc
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      2 * pi * percent,
      false,
      progressPaint,
    );

    // Node dots around circumference
    final dotRadius = 4.0;
    for (var i = 0; i < nodeCount; i++) {
      final angle = -pi / 2 + (2 * pi * i / nodeCount);
      final dotCenter = Offset(
        center.dx + (radius + 16) * cos(angle),
        center.dy + (radius + 16) * sin(angle),
      );
      final dotPaint = Paint()..color = color.withValues(alpha: 0.6);
      canvas.drawCircle(dotCenter, dotRadius, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _PulseRingPainter old) =>
      percent != old.percent || color != old.color || nodeCount != old.nodeCount;
}

class _NamespaceCard extends StatelessWidget {
  const _NamespaceCard({
    required this.name,
    required this.podCount,
    this.active = false,
  });
  final String name;
  final int podCount;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: active
            ? KubelyColors.accent.withValues(alpha: 0.08)
            : KubelyColors.surface,
        border: Border.all(
          color: active
              ? KubelyColors.accent.withValues(alpha: 0.3)
              : KubelyColors.hairline,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(name,
              style: KubelyTypography.monoBodySm.copyWith(
                color: active ? KubelyColors.accent : KubelyColors.textPrimary,
              ),
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text('$podCount pods',
              style: KubelyTypography.monoCaptionSm),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.subtitle,
    required this.color,
  });
  final String label;
  final String value;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: KubelyColors.surface,
        border: Border.all(color: KubelyColors.hairline),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: KubelyTypography.body
                  .copyWith(color: KubelyColors.textMuted, fontSize: 12)),
          const SizedBox(height: 6),
          Text(value,
              style: KubelyTypography.monoHeroMetric
                  .copyWith(color: color, fontSize: 32)),
          const SizedBox(height: 4),
          Text(subtitle, style: KubelyTypography.caption.copyWith(fontSize: 11)),
        ],
      ),
    );
  }
}
