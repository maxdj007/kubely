import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/theme/kubely_colors.dart';
import '../../core/theme/kubely_typography.dart';
import '../../core/theme/kubely_radii.dart';

enum ConfirmAction { restart, delete }

class ConfirmBottomSheet extends StatelessWidget {
  const ConfirmBottomSheet({
    super.key,
    required this.action,
    required this.resourceName,
    this.resourceType = 'pod',
    this.podCount,
  });

  final ConfirmAction action;
  final String resourceName;
  final String resourceType;
  final int? podCount;

  static Future<bool?> show(
    BuildContext context, {
    required ConfirmAction action,
    required String resourceName,
    String resourceType = 'pod',
    int? podCount,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => ConfirmBottomSheet(
        action: action,
        resourceName: resourceName,
        resourceType: resourceType,
        podCount: podCount,
      ),
    );
  }

  bool get _isDelete => action == ConfirmAction.delete;
  bool get _isRestart => action == ConfirmAction.restart;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: KubelyColors.sheetBackground,
        borderRadius: KubelyRadii.sheet,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          // Drag handle
          Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 18),

          if (_isRestart) _buildRestartContent(),
          if (_isDelete) _buildDeleteContent(),

          const SizedBox(height: 20),

          // Buttons — Cancel | Action
          Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              bottom: bottomPadding + 16,
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(false),
                    child: Container(
                      height: 52,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: KubelyColors.surface,
                        border:
                            Border.all(color: KubelyColors.hairlineInput),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text('Cancel',
                          style: KubelyTypography.sectionLabel.copyWith(
                              color: KubelyColors.textSecondary,
                              fontSize: 14)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(true),
                    child: Container(
                      height: 52,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _isDelete
                            ? KubelyColors.critical
                            : KubelyColors.info,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        _isDelete ? 'Delete' : 'Restart rollout',
                        style: KubelyTypography.buttonText.copyWith(
                          fontSize: 14,
                          color: _isDelete
                              ? KubelyColors.textPrimary
                              : const Color(0xFF04101F),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRestartContent() {
    final pods = podCount ?? 1;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header — blue icon in rounded square + title + subtitle
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: KubelyColors.info.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(LucideIcons.refreshCw,
                    size: 22, color: KubelyColors.info),
              ),
              const SizedBox(width: 13),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Rolling restart',
                      style: KubelyTypography.appBarTitle
                          .copyWith(fontSize: 17)),
                  const SizedBox(height: 3),
                  Text('$resourceType/$resourceName · $pods pods',
                      style: KubelyTypography.monoCaption
                          .copyWith(color: KubelyColors.textMuted)),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Strategy info card
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: KubelyColors.surfaceStrip,
              border: Border.all(color: KubelyColors.hairline),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Text.rich(
              TextSpan(
                style: KubelyTypography.body.copyWith(
                    color: KubelyColors.textSecondary, height: 1.6),
                children: [
                  const TextSpan(
                      text: 'Pods are replaced gradually — '),
                  TextSpan(
                    text: 'maxUnavailable 25%',
                    style: TextStyle(color: KubelyColors.running),
                  ),
                  const TextSpan(
                      text:
                          '. No downtime expected. Config & secrets are re-read on start.'),
                ],
              ),
            ),
          ),

          const SizedBox(height: 14),

          // Amber production warning
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 13, vertical: 12),
            decoration: BoxDecoration(
              color: KubelyColors.warning.withValues(alpha: 0.08),
              border: Border.all(color: KubelyColors.warningBorder),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Row(
              children: [
                Icon(LucideIcons.alertTriangle,
                    size: 16, color: KubelyColors.warning),
                const SizedBox(width: 10),
                Text('This is a production cluster',
                    style: KubelyTypography.caption.copyWith(
                        color: KubelyColors.warningText,
                        fontSize: 11.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeleteContent() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          // Icon
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: KubelyColors.critical.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(LucideIcons.trash2,
                size: 24, color: KubelyColors.critical),
          ),
          const SizedBox(height: 16),

          // Title
          Text('Delete $resourceType',
              style:
                  KubelyTypography.appBarTitle.copyWith(fontSize: 17)),
          const SizedBox(height: 8),

          // Resource name pill
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: KubelyColors.surface,
              border: Border.all(color: KubelyColors.hairline),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(resourceName,
                style: KubelyTypography.monoBody,
                textAlign: TextAlign.center),
          ),
          const SizedBox(height: 14),

          // Description
          Text(
            'This will permanently delete the $resourceType. This action cannot be undone.',
            style: KubelyTypography.body.copyWith(
                color: KubelyColors.textMuted, height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),

          // Warning
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 13, vertical: 12),
            decoration: BoxDecoration(
              color: KubelyColors.warning.withValues(alpha: 0.08),
              border: Border.all(color: KubelyColors.warningBorder),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Row(
              children: [
                Icon(LucideIcons.alertTriangle,
                    size: 16, color: KubelyColors.warning),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('This action is irreversible in production',
                      style: KubelyTypography.caption.copyWith(
                          color: KubelyColors.warningText,
                          fontSize: 11.5)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
