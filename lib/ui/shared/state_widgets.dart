import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/theme/kubely_colors.dart';
import '../../core/theme/kubely_typography.dart';

class KubelyEmptyState extends StatelessWidget {
  const KubelyEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: KubelyColors.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, size: 26, color: KubelyColors.textDim),
            ),
            const SizedBox(height: 16),
            Text(title,
                style: KubelyTypography.sectionLabel.copyWith(fontSize: 14),
                textAlign: TextAlign.center),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(subtitle!,
                  style: KubelyTypography.body
                      .copyWith(color: KubelyColors.textDim),
                  textAlign: TextAlign.center),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 18),
              GestureDetector(
                onTap: onAction,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: KubelyColors.accent.withValues(alpha: 0.12),
                    border: Border.all(
                        color: KubelyColors.accent.withValues(alpha: 0.3)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(actionLabel!,
                      style: KubelyTypography.sectionLabel
                          .copyWith(color: KubelyColors.accent, fontSize: 13)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class KubelyLoadingState extends StatelessWidget {
  const KubelyLoadingState({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor:
                  AlwaysStoppedAnimation(KubelyColors.accent),
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 14),
            Text(message!,
                style: KubelyTypography.body
                    .copyWith(color: KubelyColors.textDim)),
          ],
        ],
      ),
    );
  }
}

class KubelyErrorState extends StatelessWidget {
  const KubelyErrorState({
    super.key,
    required this.message,
    this.onRetry,
  });

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: KubelyColors.critical.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(LucideIcons.wifiOff,
                  size: 24, color: KubelyColors.critical),
            ),
            const SizedBox(height: 14),
            Text('Connection error',
                style: KubelyTypography.sectionLabel.copyWith(fontSize: 14)),
            const SizedBox(height: 6),
            Text(message,
                style: KubelyTypography.body
                    .copyWith(color: KubelyColors.textDim),
                textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 18),
              GestureDetector(
                onTap: onRetry,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: KubelyColors.surface,
                    border: Border.all(color: KubelyColors.hairline),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.refreshCw,
                          size: 14, color: KubelyColors.textSecondary),
                      const SizedBox(width: 8),
                      Text('Retry',
                          style: KubelyTypography.sectionLabel
                              .copyWith(color: KubelyColors.textSecondary, fontSize: 13)),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class KubelyNoClusterState extends StatelessWidget {
  const KubelyNoClusterState({super.key, this.onAddCluster});

  final VoidCallback? onAddCluster;

  @override
  Widget build(BuildContext context) {
    return KubelyEmptyState(
      icon: LucideIcons.server,
      title: 'No cluster connected',
      subtitle: 'Import a kubeconfig to get started',
      actionLabel: 'Add cluster',
      onAction: onAddCluster,
    );
  }
}
