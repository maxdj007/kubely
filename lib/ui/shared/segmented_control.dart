import 'package:flutter/material.dart';
import '../../core/theme/kubely_colors.dart';
import '../../core/theme/kubely_radii.dart';
import '../../core/utils/haptics.dart';

class SegmentedControl extends StatelessWidget {
  const SegmentedControl({
    super.key,
    required this.segments,
    required this.selectedIndex,
    required this.onChanged,
  });

  final List<String> segments;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: KubelyColors.surfaceStrip,
        borderRadius: KubelyRadii.segmentedTrack,
      ),
      child: Row(
        children: List.generate(segments.length, (i) {
          final active = i == selectedIndex;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                KubelyHaptics.selection();
                onChanged(i);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 7),
                decoration: BoxDecoration(
                  color: active ? KubelyColors.accent : Colors.transparent,
                  borderRadius: KubelyRadii.segmentedPill,
                ),
                alignment: Alignment.center,
                child: Text(
                  segments[i],
                  style: TextStyle(
                    fontFamily: 'SpaceGrotesk',
                    fontSize: 12.5,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                    color: active ? KubelyColors.ink : KubelyColors.textMuted,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
