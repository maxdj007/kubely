import 'package:flutter/material.dart';
import '../../core/theme/kubely_colors.dart';
import '../../core/theme/kubely_typography.dart';
import '../../core/theme/kubely_shadows.dart';

enum ResourceGradientType { cpu, memory }

class ResourceCard extends StatelessWidget {
  const ResourceCard({
    super.key,
    required this.label,
    required this.percent,
    required this.percentText,
    required this.detail,
    required this.gradientType,
  });

  final String label;
  final double percent;
  final String percentText;
  final String detail;
  final ResourceGradientType gradientType;

  @override
  Widget build(BuildContext context) {
    final gradient = gradientType == ResourceGradientType.cpu
        ? KubelyGradients.cpuBar
        : KubelyGradients.memoryBar;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: KubelyColors.surface,
        border: Border.all(color: KubelyColors.hairlineLight),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(label,
                  style: KubelyTypography.body
                      .copyWith(fontSize: 12, color: KubelyColors.textMuted)),
              Text(percentText, style: KubelyTypography.monoMetric),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: SizedBox(
              height: 6,
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: percent.clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: gradient,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 7),
          Text(detail, style: KubelyTypography.monoCaptionSm),
        ],
      ),
    );
  }
}
