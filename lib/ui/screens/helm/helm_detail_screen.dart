import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/theme/kubely_colors.dart';
import '../../../core/theme/kubely_typography.dart';
import '../../../core/constants/spacing.dart';
import '../../../state/providers/mock_data_provider.dart';
import '../../shared/hero_card.dart';
import '../../shared/status_dot.dart';
import '../../shared/confirm_bottom_sheet.dart';

class HelmDetailScreen extends ConsumerWidget {
  const HelmDetailScreen({
    super.key,
    required this.releaseName,
    required this.namespace,
  });

  final String releaseName;
  final String namespace;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topPadding = MediaQuery.of(context).padding.top;
    final revisionsAsync =
        ref.watch(helmRevisionListProvider('$namespace/$releaseName'));
    final revisions = revisionsAsync.valueOrNull ?? const [];
    final latest = revisions.isNotEmpty ? revisions.first : null;
    final statusColor = latest?.status == 'deployed'
        ? KubelyColors.running
        : latest?.status == 'superseded'
            ? KubelyColors.textDim
            : KubelyColors.warning;

    return Scaffold(
      backgroundColor: KubelyColors.ink,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: SizedBox(height: topPadding)),
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
                      child: Text(releaseName,
                          style: KubelyTypography.monoBody.copyWith(
                              fontSize: 14, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis),
                    ),
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
                if (latest != null)
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
                            Text(latest.status,
                                style: KubelyTypography.sectionLabel.copyWith(
                                    color: statusColor,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700)),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            _InfoCell(label: 'NAMESPACE', value: namespace),
                            _InfoCell(
                                label: 'CHART', value: latest.chart),
                            _InfoCell(
                                label: 'REVISION',
                                value: '${latest.revision}'),
                          ],
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: KubelySpacing.cardGap),

                // Actions
                Text('Actions', style: KubelyTypography.sectionLabel),
                const SizedBox(height: 10),
                Row(
                  children: [
                    if (revisions.length > 1)
                      Expanded(
                        child: _ActionButton(
                          icon: LucideIcons.history,
                          label: 'Rollback',
                          color: KubelyColors.warning,
                          bgColor: KubelyColors.warning.withValues(alpha: 0.10),
                          onTap: () {
                            final prev = revisions.length > 1 ? revisions[1] : null;
                            if (prev != null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Rollback to rev ${prev.revision} — use "helm rollback $releaseName ${prev.revision}" via CLI'),
                                  backgroundColor: KubelyColors.warning,
                                  behavior: SnackBarBehavior.floating,
                                  duration: const Duration(seconds: 4),
                                ),
                              );
                            }
                          },
                        ),
                      ),
                    if (revisions.length > 1) const SizedBox(width: 10),
                    Expanded(
                      child: _ActionButton(
                        icon: LucideIcons.fileText,
                        label: 'Values',
                        color: KubelyColors.textPrimary,
                        bgColor: KubelyColors.surface,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ActionButton(
                        icon: LucideIcons.trash2,
                        label: 'Uninstall',
                        color: KubelyColors.critical,
                        bgColor: KubelyColors.critical.withValues(alpha: 0.10),
                        onTap: () async {
                          final confirmed = await ConfirmBottomSheet.show(
                            context,
                            action: ConfirmAction.delete,
                            resourceName: releaseName,
                            resourceType: 'Helm release',
                          );
                          if (confirmed == true && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Uninstall — use "helm uninstall $releaseName -n $namespace" via CLI'),
                                backgroundColor: KubelyColors.critical,
                                behavior: SnackBarBehavior.floating,
                                duration: const Duration(seconds: 4),
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: KubelySpacing.cardGap),

                // Revision history
                Text('Revision history',
                    style: KubelyTypography.sectionLabel),
                const SizedBox(height: 6),
                Text('${revisions.length} revisions',
                    style: KubelyTypography.monoCaption),
                const SizedBox(height: 12),

                if (revisionsAsync.isLoading)
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(
                              KubelyColors.accent),
                        ),
                      ),
                    ),
                  ),

                ...revisions.map((rev) {
                  final isLatest = rev == revisions.first;
                  final revColor = rev.status == 'deployed'
                      ? KubelyColors.running
                      : rev.status == 'superseded'
                          ? KubelyColors.textDim
                          : rev.status == 'failed'
                              ? KubelyColors.critical
                              : KubelyColors.warning;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: KubelyColors.surface,
                        border: Border.all(
                          color: isLatest
                              ? revColor.withValues(alpha: 0.25)
                              : KubelyColors.hairline,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: revColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: Center(
                              child: Text('${rev.revision}',
                                  style: KubelyTypography.monoBody.copyWith(
                                      color: revColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text('Revision ${rev.revision}',
                                        style: KubelyTypography.sectionLabel
                                            .copyWith(fontSize: 12.5)),
                                    if (isLatest) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: KubelyColors.accent
                                              .withValues(alpha: 0.14),
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: Text('latest',
                                            style: KubelyTypography
                                                .monoCaptionSm
                                                .copyWith(
                                                    color:
                                                        KubelyColors.accent,
                                                    fontWeight:
                                                        FontWeight.w600,
                                                    fontSize: 9)),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(rev.chart,
                                    style: KubelyTypography.monoCaption,
                                    overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: revColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(rev.status,
                                style: KubelyTypography.monoCaptionSm
                                    .copyWith(
                                        color: revColor,
                                        fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    ),
                  );
                }),

                const SizedBox(height: 40),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon, required this.label,
    required this.color, required this.bgColor, this.onTap,
  });
  final IconData icon;
  final String label;
  final Color color;
  final Color bgColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
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
