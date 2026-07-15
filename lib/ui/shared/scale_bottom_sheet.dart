import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/theme/kubely_colors.dart';
import '../../core/theme/kubely_typography.dart';
import '../../core/theme/kubely_radii.dart';

class ScaleBottomSheet extends StatefulWidget {
  const ScaleBottomSheet({
    super.key,
    required this.resourceName,
    required this.currentReplicas,
  });

  final String resourceName;
  final int currentReplicas;

  static Future<int?> show(
    BuildContext context, {
    required String resourceName,
    required int currentReplicas,
  }) {
    return showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => ScaleBottomSheet(
        resourceName: resourceName,
        currentReplicas: currentReplicas,
      ),
    );
  }

  @override
  State<ScaleBottomSheet> createState() => _ScaleBottomSheetState();
}

class _ScaleBottomSheetState extends State<ScaleBottomSheet> {
  late int _replicas;
  static const _maxSlider = 15;

  @override
  void initState() {
    super.initState();
    _replicas = widget.currentReplicas;
  }

  bool get _hasChanged => _replicas != widget.currentReplicas;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final sliderFraction =
        _maxSlider > 0 ? (_replicas / _maxSlider).clamp(0.0, 1.0) : 0.0;

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

          // Title row — scale icon + "Scale deployment"
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Icon(LucideIcons.arrowUpRight,
                    size: 20, color: KubelyColors.accent),
                const SizedBox(width: 10),
                Text('Scale deployment',
                    style: KubelyTypography.appBarTitle
                        .copyWith(fontSize: 17)),
              ],
            ),
          ),

          const SizedBox(height: 22),

          // "REPLICAS" eyebrow
          Text('REPLICAS',
              style: KubelyTypography.eyebrow
                  .copyWith(fontSize: 11, letterSpacing: 0.88)),

          const SizedBox(height: 8),

          // Stepper: [ - ]  54  [ + ]
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Minus button — neutral surface
              GestureDetector(
                onTap: _replicas > 0
                    ? () => setState(() => _replicas--)
                    : null,
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: KubelyColors.surface,
                    border: Border.all(
                        color: KubelyColors.hairlineInput),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(LucideIcons.minus,
                      size: 20,
                      color: _replicas > 0
                          ? KubelyColors.textSecondary
                          : KubelyColors.textFaint),
                ),
              ),
              const SizedBox(width: 24),
              // Big number
              SizedBox(
                width: 70,
                child: Text(
                  '$_replicas',
                  textAlign: TextAlign.center,
                  style: KubelyTypography.monoHeroLarge.copyWith(
                    fontSize: 54,
                    color: KubelyColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 24),
              // Plus button — teal tinted (from the design)
              GestureDetector(
                onTap: _replicas < _maxSlider
                    ? () => setState(() => _replicas++)
                    : null,
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: KubelyColors.accent.withValues(alpha: 0.14),
                    border: Border.all(
                        color:
                            KubelyColors.accent.withValues(alpha: 0.35)),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(LucideIcons.plus,
                      size: 20, color: KubelyColors.accent),
                ),
              ),
            ],
          ),

          const SizedBox(height: 22),

          // Gradient slider track with glowing thumb
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: LayoutBuilder(builder: (context, constraints) {
              final trackWidth = constraints.maxWidth;
              final thumbPos = sliderFraction * trackWidth;
              return GestureDetector(
                onHorizontalDragUpdate: (details) {
                  final dx = details.localPosition.dx
                      .clamp(0.0, trackWidth);
                  final newVal = (dx / trackWidth * _maxSlider).round();
                  if (newVal != _replicas) {
                    setState(() => _replicas = newVal);
                  }
                },
                onTapDown: (details) {
                  final dx = details.localPosition.dx
                      .clamp(0.0, trackWidth);
                  setState(() =>
                      _replicas = (dx / trackWidth * _maxSlider).round());
                },
                child: SizedBox(
                  height: 30,
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.centerLeft,
                    children: [
                      // Track background
                      Positioned(
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 6,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                      // Active track — teal-to-blue gradient
                      Positioned(
                        left: 0,
                        width: thumbPos.clamp(0.0, trackWidth),
                        child: Container(
                          height: 6,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                KubelyColors.accent,
                                KubelyColors.info,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                      // Thumb — glowing teal circle
                      Positioned(
                        left: thumbPos - 10,
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: KubelyColors.accent,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: KubelyColors.accent
                                    .withValues(alpha: 0.5),
                                blurRadius: 12,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),

          const SizedBox(height: 8),

          // Labels: 0 ... current: N ... max
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('0', style: KubelyTypography.monoCaptionSm),
                Text('current: ${widget.currentReplicas}',
                    style: KubelyTypography.monoCaption
                        .copyWith(color: KubelyColors.textMuted)),
                Text('$_maxSlider',
                    style: KubelyTypography.monoCaptionSm),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // Buttons: Cancel | Scale to N
          Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              bottom: bottomPadding + 16,
            ),
            child: Row(
              children: [
                // Cancel — surface background, hairline border
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
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
                ),
                const SizedBox(width: 10),
                // Scale to N — teal filled
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 52,
                    child: GestureDetector(
                      onTap: _hasChanged
                          ? () => Navigator.of(context).pop(_replicas)
                          : null,
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _hasChanged
                              ? KubelyColors.accent
                              : KubelyColors.textDim,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text('Scale to $_replicas',
                            style: KubelyTypography.buttonText
                                .copyWith(fontSize: 14)),
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
}
