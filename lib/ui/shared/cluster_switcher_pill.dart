import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/theme/kubely_colors.dart';
import '../../core/theme/kubely_typography.dart';
import '../../state/providers/cluster_provider.dart';
import '../screens/cluster_switcher/cluster_switcher_sheet.dart';
import 'status_dot.dart';

class ClusterSwitcherPill extends ConsumerWidget {
  const ClusterSwitcherPill({
    super.key,
    this.compact = false,
  });

  final bool compact;

  void _openSwitcher(BuildContext context, WidgetRef ref) async {
    final state = ref.read(clusterProvider);
    final result = await ClusterSwitcherSheet.show(
      context,
      clusters: state.clusters,
      activeIndex: state.activeIndex,
    );
    if (result != null) {
      ref.read(clusterProvider.notifier).setActive(result);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(clusterProvider);

    return Semantics(
      button: true,
      label: 'Switch cluster. Current: ${state.activeName}',
      child: GestureDetector(
      onTap: () => _openSwitcher(context, ref),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 10 : 12,
          vertical: compact ? 6 : 7,
        ),
        decoration: BoxDecoration(
          color: KubelyColors.surfaceAlt,
          border: Border.all(color: KubelyColors.hairline),
          borderRadius: BorderRadius.circular(24),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: compact ? 160 : 200),
          child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            StatusDot(
              color: state.activeIsHealthy
                  ? KubelyColors.running
                  : KubelyColors.critical,
              size: 7,
              glow: true,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                state.activeName,
                style: KubelyTypography.monoBody.copyWith(
                  fontSize: compact ? 12 : 13,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            const SizedBox(width: 4),
            Icon(LucideIcons.chevronDown,
                size: 13, color: KubelyColors.textDim),
          ],
        ),
        ),
      ),
    ),
    );
  }
}
