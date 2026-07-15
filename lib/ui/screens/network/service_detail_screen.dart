import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/theme/kubely_colors.dart';
import '../../../core/theme/kubely_typography.dart';
import '../../../core/constants/spacing.dart';
import '../../../state/providers/mock_data_provider.dart';
import '../../shared/hero_card.dart';
import '../../shared/status_dot.dart';
import '../../shared/confirm_bottom_sheet.dart';

class ServiceDetailScreen extends ConsumerWidget {
  const ServiceDetailScreen({
    super.key,
    required this.serviceName,
    required this.namespace,
  });

  final String serviceName;
  final String namespace;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topPadding = MediaQuery.of(context).padding.top;
    final services = ref.watch(serviceListProvider).valueOrNull ?? const [];
    final svc = services.cast<ServiceData?>().firstWhere(
          (s) => s!.name == serviceName && s.namespace == namespace,
          orElse: () => null,
        );

    final isLB = svc?.type == 'LoadBalancer';
    final typeColor = isLB ? KubelyColors.accent : KubelyColors.info;

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
                      child: Text(serviceName,
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
                HeroCard(
                  borderColor: typeColor.withValues(alpha: 0.18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          StatusDot(color: typeColor, size: 10, glow: true),
                          const SizedBox(width: 10),
                          Text(svc?.type ?? 'ClusterIP',
                              style: KubelyTypography.sectionLabel.copyWith(
                                  color: typeColor,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700)),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          _InfoCell(label: 'NAMESPACE', value: namespace),
                          _InfoCell(label: 'CLUSTER-IP', value: svc?.clusterIp ?? '—'),
                          _InfoCell(label: 'PORT', value: svc?.port ?? '—'),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: KubelySpacing.cardGap),

                // Endpoints section
                Text('Connection', style: KubelyTypography.sectionLabel),
                const SizedBox(height: 10),
                _CopyableRow(
                  label: 'Cluster DNS',
                  value: '$serviceName.$namespace.svc.cluster.local',
                ),
                const SizedBox(height: 8),
                _CopyableRow(
                  label: 'Cluster IP',
                  value: '${svc?.clusterIp ?? "—"}:${svc?.port ?? "—"}',
                ),
                if (isLB) ...[
                  const SizedBox(height: 8),
                  _CopyableRow(
                    label: 'External',
                    value: 'Provisioned by cloud provider',
                    accent: true,
                  ),
                ],

                const SizedBox(height: KubelySpacing.cardGap),

                // Actions
                Text('Actions', style: KubelyTypography.sectionLabel),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _ActionButton(
                        icon: LucideIcons.terminal,
                        label: 'Port Forward',
                        color: KubelyColors.accent,
                        bgColor: KubelyColors.accent.withValues(alpha: 0.10),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ActionButton(
                        icon: LucideIcons.fileText,
                        label: 'YAML',
                        color: KubelyColors.textPrimary,
                        bgColor: KubelyColors.surface,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ActionButton(
                        icon: LucideIcons.trash2,
                        label: 'Delete',
                        color: KubelyColors.critical,
                        bgColor: KubelyColors.critical.withValues(alpha: 0.10),
                        onTap: () async {
                          final confirmed = await ConfirmBottomSheet.show(
                            context,
                            action: ConfirmAction.delete,
                            resourceName: serviceName,
                            resourceType: 'service',
                          );
                          if (confirmed == true && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Deleting $serviceName...'),
                                backgroundColor: KubelyColors.critical,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                            Navigator.of(context).maybePop();
                          }
                        },
                      ),
                    ),
                  ],
                ),

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

class _CopyableRow extends StatelessWidget {
  const _CopyableRow({required this.label, required this.value, this.accent = false});
  final String label;
  final String value;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Clipboard.setData(ClipboardData(text: value));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Copied: $value'),
            backgroundColor: KubelyColors.accent,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 1),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: KubelyColors.surface,
          border: Border.all(color: KubelyColors.hairline),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Text(label,
                style: KubelyTypography.caption
                    .copyWith(color: KubelyColors.textDim, fontSize: 11)),
            const Spacer(),
            Flexible(
              child: Text(value,
                  style: KubelyTypography.monoCaption.copyWith(
                      color: accent ? KubelyColors.accent : KubelyColors.textPrimary),
                  overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: 8),
            Icon(LucideIcons.copy, size: 12, color: KubelyColors.textDim),
          ],
        ),
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
