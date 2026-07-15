import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/theme/kubely_colors.dart';
import '../../../core/theme/kubely_typography.dart';
import '../../../core/constants/spacing.dart';
import '../../../state/providers/mock_data_provider.dart';
import '../../../state/providers/k8s_data_provider.dart';
import '../../shared/hero_card.dart';
import '../../shared/status_dot.dart';
import '../../shared/confirm_bottom_sheet.dart';

class PodDetailScreen extends ConsumerWidget {
  const PodDetailScreen({super.key, required this.podName});

  final String podName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topPadding = MediaQuery.of(context).padding.top;
    final detailAsync = ref.watch(podDetailProvider(podName));

    // Fallback to podListProvider for basic data while detail loads
    final allPods = ref.watch(podListProvider).valueOrNull ?? const [];
    final basicPod = allPods.cast<PodData?>().firstWhere(
          (p) => p!.name == podName,
          orElse: () => null,
        );

    final detail = detailAsync.valueOrNull;
    final status = detail?.status ?? basicPod?.status ?? 'Unknown';
    final age = detail?.age ?? basicPod?.age ?? '';
    final ns = detail?.namespace ?? basicPod?.namespace ?? 'default';
    final nodeName = detail?.nodeName ?? '—';
    final restarts = detail?.restartCount;
    final containers = detail?.containers ?? const [];
    final events = detail?.events ?? const [];
    final statusColor = KubelyColors.statusColor(status);

    return Scaffold(
      backgroundColor: KubelyColors.ink,
      body: CustomScrollView(
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
                    GestureDetector(
                      onTap: () => Navigator.of(context).maybePop(),
                      child: Icon(LucideIcons.chevronLeft,
                          size: 24, color: KubelyColors.textSecondary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(podName,
                          style: KubelyTypography.monoBody.copyWith(
                              fontSize: 14, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis),
                    ),
                    Icon(LucideIcons.moreVertical,
                        size: 20, color: KubelyColors.textDim),
                  ],
                ),
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.symmetric(
                horizontal: KubelySpacing.screenPadding),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 6),

                // Status hero
                HeroCard(
                  borderColor: statusColor.withValues(alpha: 0.18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          StatusDot(
                              color: statusColor, size: 10, glow: true),
                          const SizedBox(width: 10),
                          Text(status,
                              style: KubelyTypography.sectionLabel.copyWith(
                                  color: statusColor,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700)),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          _InfoCell(label: 'NAMESPACE', value: ns),
                          _InfoCell(label: 'NODE', value: nodeName),
                          _InfoCell(
                              label: 'RESTARTS',
                              value: restarts != null ? '$restarts' : '—'),
                          _InfoCell(label: 'AGE', value: age),
                        ],
                      ),
                    ],
                  ),
                ),

                // Containers section
                if (containers.isNotEmpty) ...[
                  const SizedBox(height: KubelySpacing.cardGap),
                  Row(
                    children: [
                      Text('Containers', style: KubelyTypography.sectionLabel),
                      const SizedBox(width: 6),
                      Text('(${containers.length})',
                          style: KubelyTypography.caption
                              .copyWith(color: KubelyColors.textDim)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ...containers.map((c) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 11),
                          decoration: BoxDecoration(
                            color: KubelyColors.surface,
                            border: Border.all(color: KubelyColors.hairline),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                c.ready
                                    ? LucideIcons.checkCircle
                                    : LucideIcons.alertCircle,
                                size: 16,
                                color: c.ready
                                    ? KubelyColors.running
                                    : KubelyColors.warning,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(c.name,
                                        style: KubelyTypography.monoBody,
                                        overflow: TextOverflow.ellipsis),
                                    const SizedBox(height: 2),
                                    Text(c.image,
                                        style: KubelyTypography.monoCaptionSm,
                                        overflow: TextOverflow.ellipsis),
                                  ],
                                ),
                              ),
                              Text(c.ready ? 'Ready' : c.state,
                                  style: KubelyTypography.caption.copyWith(
                                      color: c.ready
                                          ? KubelyColors.running
                                          : KubelyColors.warning)),
                            ],
                          ),
                        ),
                      )),
                ],

                // Resources section
                if (containers.any((c) =>
                    c.cpuUsage != null || c.memUsage != null)) ...[
                  const SizedBox(height: KubelySpacing.cardGap),
                  Text('Resources', style: KubelyTypography.sectionLabel),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                          child: _MiniResource(
                        label: 'CPU',
                        usage: containers.first.cpuUsage ?? '—',
                        limit: containers.first.cpuLimit ?? '—',
                      )),
                      const SizedBox(width: 12),
                      Expanded(
                          child: _MiniResource(
                        label: 'Memory',
                        usage: containers.first.memUsage ?? '—',
                        limit: containers.first.memLimit ?? '—',
                      )),
                    ],
                  ),
                ],

                const SizedBox(height: KubelySpacing.cardGap),

                // Action grid
                Text('Actions', style: KubelyTypography.sectionLabel),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                        child: _ActionButton(
                            icon: LucideIcons.fileText,
                            label: 'Logs',
                            color: KubelyColors.textPrimary,
                            bgColor: KubelyColors.surface,
                            onTap: () => context.go(
                                '/workloads/pod/${Uri.encodeComponent(podName)}/logs'))),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _ActionButton(
                            icon: LucideIcons.terminal,
                            label: 'Exec',
                            color: KubelyColors.textPrimary,
                            bgColor: KubelyColors.surface,
                            onTap: () => context.go('/shell'))),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _ActionButton(
                            icon: LucideIcons.refreshCw,
                            label: 'Restart',
                            color: KubelyColors.info,
                            bgColor:
                                KubelyColors.info.withValues(alpha: 0.10),
                            onTap: () async {
                              final confirmed =
                                  await ConfirmBottomSheet.show(
                                context,
                                action: ConfirmAction.restart,
                                resourceName: podName,
                              );
                              if (confirmed == true && context.mounted) {
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(SnackBar(
                                  content: Text('Restarting $podName...'),
                                  backgroundColor: KubelyColors.info,
                                  behavior: SnackBarBehavior.floating,
                                ));
                                // Restart a pod = delete it (K8s recreates managed pods)
                                final client = await ref.read(kubeClientProvider.future);
                                if (client != null) {
                                  try {
                                    await client.deletePod(ns, podName);
                                    ref.invalidate(podListProvider);
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                        content: Text('Restart failed: $e'),
                                        backgroundColor: KubelyColors.critical,
                                        behavior: SnackBarBehavior.floating,
                                      ));
                                    }
                                  }
                                }
                              }
                            })),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _ActionButton(
                            icon: LucideIcons.trash2,
                            label: 'Delete',
                            color: KubelyColors.critical,
                            bgColor:
                                KubelyColors.critical.withValues(alpha: 0.10),
                            onTap: () async {
                              final confirmed =
                                  await ConfirmBottomSheet.show(
                                context,
                                action: ConfirmAction.delete,
                                resourceName: podName,
                              );
                              if (confirmed == true && context.mounted) {
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(SnackBar(
                                  content: Text('Deleting $podName...'),
                                  backgroundColor: KubelyColors.critical,
                                  behavior: SnackBarBehavior.floating,
                                ));
                                // Call the real delete API
                                final client = await ref.read(kubeClientProvider.future);
                                if (client != null) {
                                  try {
                                    await client.deletePod(ns, podName);
                                    ref.invalidate(podListProvider);
                                    ref.invalidate(clusterHealthProvider);
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                        content: Text('Delete failed: $e'),
                                        backgroundColor: KubelyColors.critical,
                                        behavior: SnackBarBehavior.floating,
                                      ));
                                    }
                                    return; // Don't pop on failure
                                  }
                                }
                                if (context.mounted) {
                                  Navigator.of(context).maybePop();
                                }
                              }
                            })),
                  ],
                ),

                // Recent events
                if (events.isNotEmpty) ...[
                  const SizedBox(height: KubelySpacing.cardGap),
                  Text('Recent events', style: KubelyTypography.sectionLabel),
                  const SizedBox(height: 10),
                  ...events.take(10).map((e) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 28,
                              child: Text(e.time,
                                  style: KubelyTypography.monoCaption
                                      .copyWith(color: KubelyColors.textDim)),
                            ),
                            Text(' — ',
                                style: KubelyTypography.caption
                                    .copyWith(color: KubelyColors.textFaint)),
                            Expanded(
                              child: Text(e.message,
                                  style: KubelyTypography.caption.copyWith(
                                    fontSize: 11.5,
                                    color: e.type == 'Warning'
                                        ? KubelyColors.warningText
                                        : null,
                                  )),
                            ),
                          ],
                        ),
                      )),
                ] else if (detailAsync.isLoading) ...[
                  const SizedBox(height: KubelySpacing.cardGap),
                  Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation(KubelyColors.accent),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 40),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCell extends StatelessWidget {
  const _InfoCell({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: KubelyTypography.eyebrow
                  .copyWith(fontSize: 9.5, letterSpacing: 0.8)),
          const SizedBox(height: 3),
          Text(value,
              style: KubelyTypography.monoCaption
                  .copyWith(color: KubelyColors.textPrimary),
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _MiniResource extends StatelessWidget {
  const _MiniResource({
    required this.label,
    required this.usage,
    required this.limit,
  });
  final String label;
  final String usage;
  final String limit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: KubelyColors.surface,
        border: Border.all(color: KubelyColors.hairline),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style: KubelyTypography.caption
                      .copyWith(color: KubelyColors.textMuted)),
              Text(usage, style: KubelyTypography.monoBody),
            ],
          ),
          const SizedBox(height: 5),
          Text('limit: $limit', style: KubelyTypography.monoCaptionSm),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.bgColor,
    this.onTap,
  });
  final IconData icon;
  final String label;
  final Color color;
  final Color bgColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: bgColor,
            border: Border.all(color: KubelyColors.hairline),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(height: 6),
              Text(label,
                  style: KubelyTypography.caption
                      .copyWith(color: color, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }
}
