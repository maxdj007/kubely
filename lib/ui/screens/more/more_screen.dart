import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/kubely_colors.dart';
import '../../../core/theme/kubely_typography.dart';
import '../../../core/constants/spacing.dart';
import '../../shared/cluster_switcher_pill.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return ColoredBox(
      color: KubelyColors.ink,
      child: CustomScrollView(
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
                    Text('More', style: KubelyTypography.screenTitle),
                    const Spacer(),
                    const ClusterSwitcherPill(compact: true),
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
                const SizedBox(height: 4),

                // Resources section
                _SectionHeader(label: 'RESOURCES'),
                const SizedBox(height: 10),
                _NavCard(
                  icon: LucideIcons.network,
                  label: 'Network',
                  subtitle: 'Services & Ingresses',
                  onTap: () => context.go('/more/network'),
                ),
                const SizedBox(height: 8),
                _NavCard(
                  icon: LucideIcons.hardDrive,
                  label: 'Storage',
                  subtitle: 'Persistent Volume Claims',
                  onTap: () => context.go('/more/storage'),
                ),
                const SizedBox(height: 8),
                _NavCard(
                  icon: LucideIcons.fileText,
                  label: 'Config & Secrets',
                  subtitle: 'ConfigMaps, Secrets, env',
                  onTap: () => context.go('/more/config'),
                ),
                const SizedBox(height: 8),
                _NavCard(
                  icon: LucideIcons.server,
                  label: 'Nodes',
                  subtitle: 'Capacity, cordon, drain',
                  onTap: () => context.go('/more/nodes'),
                ),

                const SizedBox(height: 22),

                // Management section
                _SectionHeader(label: 'MANAGEMENT'),
                const SizedBox(height: 10),
                _NavCard(
                  icon: LucideIcons.layers,
                  label: 'Helm Releases',
                  subtitle: 'Charts, versions, upgrades',
                  color: KubelyColors.accent,
                  onTap: () => context.go('/more/helm'),
                ),

                const SizedBox(height: 22),

                // Cluster section
                _SectionHeader(label: 'CLUSTER'),
                const SizedBox(height: 10),
                _NavCard(
                  icon: LucideIcons.plusCircle,
                  label: 'Add Cluster',
                  subtitle: 'Import kubeconfig',
                  color: KubelyColors.running,
                  onTap: () => context.push('/add-cluster'),
                ),

                const SizedBox(height: 22),

                // App section
                _SectionHeader(label: 'APP'),
                const SizedBox(height: 10),
                _NavCard(
                  icon: LucideIcons.info,
                  label: 'About Kubely',
                  subtitle: 'Version, privacy, credits',
                  color: KubelyColors.textMuted,
                  onTap: () => context.go('/more/about'),
                ),

                SizedBox(
                    height: KubelySpacing.tabBarHeight +
                        MediaQuery.of(context).padding.bottom +
                        20),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(label,
        style: KubelyTypography.eyebrow
            .copyWith(fontSize: 10.5, letterSpacing: 1.0));
  }
}

class _NavCard extends StatelessWidget {
  const _NavCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
    this.color = KubelyColors.accent,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: KubelyColors.surface,
          border: Border.all(color: KubelyColors.hairline),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: KubelyTypography.sectionLabel),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: KubelyTypography.caption
                          .copyWith(color: KubelyColors.textDim, fontSize: 11)),
                ],
              ),
            ),
            Icon(LucideIcons.chevronRight,
                size: 16, color: KubelyColors.textDim),
          ],
        ),
      ),
    );
  }
}
