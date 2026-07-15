import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/theme/kubely_colors.dart';
import '../../../core/theme/kubely_typography.dart';
import '../../../core/constants/spacing.dart';
import '../../shared/kubely_logo.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: KubelyColors.ink,
      body: Column(
        children: [
          SizedBox(height: topPadding),
          Padding(
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
                  Text('About', style: KubelyTypography.appBarTitle),
                ],
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [
                          KubelyColors.accent.withValues(alpha: 0.08),
                          Colors.transparent,
                        ],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: KubelyLogo(size: 80, showHex: true),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('Kubely',
                      style: KubelyTypography.screenTitle.copyWith(
                        fontSize: 24,
                        letterSpacing: -0.5,
                      )),
                  const SizedBox(height: 4),
                  Text('Version 1.0.0',
                      style: KubelyTypography.monoCaption
                          .copyWith(color: KubelyColors.textMuted)),
                  const SizedBox(height: 24),
                  Text('KUBERNETES · ON DEVICE',
                      style: KubelyTypography.monoSmall.copyWith(
                        letterSpacing: 2.0,
                        color: KubelyColors.textDim,
                      )),
                  const SizedBox(height: 32),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Column(
                      children: [
                        _InfoRow(
                          icon: LucideIcons.shieldCheck,
                          label: '100% on-device',
                          detail: 'No account, no backend, no telemetry',
                        ),
                        const SizedBox(height: 12),
                        _InfoRow(
                          icon: LucideIcons.lock,
                          label: 'Encrypted storage',
                          detail: 'Kubeconfig stored in secure enclave',
                        ),
                        const SizedBox(height: 12),
                        _InfoRow(
                          icon: LucideIcons.globe,
                          label: 'Direct connection',
                          detail: 'Talks to your cluster API directly',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).padding.bottom + 24),
            child: Text('Made for operators who need eyes on their cluster',
                style: KubelyTypography.caption
                    .copyWith(color: KubelyColors.textFaint),
                textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.detail,
  });
  final IconData icon;
  final String label;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: KubelyColors.surface,
        border: Border.all(color: KubelyColors.hairline),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: KubelyColors.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: KubelyTypography.sectionLabel.copyWith(fontSize: 12.5)),
                const SizedBox(height: 2),
                Text(detail,
                    style: KubelyTypography.caption
                        .copyWith(color: KubelyColors.textDim, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
