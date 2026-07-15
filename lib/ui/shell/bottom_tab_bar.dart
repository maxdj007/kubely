import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/utils/haptics.dart';
import '../../core/theme/kubely_colors.dart';
import '../../core/theme/kubely_typography.dart';
import '../../core/constants/spacing.dart';

class BottomTabBar extends StatelessWidget {
  const BottomTabBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const _tabs = [
    _TabDef(icon: LucideIcons.activity, label: 'Vitals'),
    _TabDef(icon: LucideIcons.box, label: 'Workloads'),
    _TabDef(icon: LucideIcons.bell, label: 'Events'),
    _TabDef(icon: LucideIcons.terminal, label: 'Shell'),
    _TabDef(icon: LucideIcons.moreHorizontal, label: 'More'),
  ];

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          height: KubelySpacing.tabBarHeight + bottomPadding,
          padding: EdgeInsets.only(bottom: bottomPadding),
          decoration: BoxDecoration(
            color: KubelyColors.tabBarBg,
            border: Border(
              top: BorderSide(color: KubelyColors.hairline, width: 1),
            ),
          ),
          child: Row(
            children: List.generate(_tabs.length, (i) {
              final tab = _tabs[i];
              final active = i == currentIndex;
              return Expanded(
                child: Semantics(
                  label: tab.label,
                  button: true,
                  selected: active,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      KubelyHaptics.light();
                      onTap(i);
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(top: 11),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            tab.icon,
                            size: 23,
                            color: active
                                ? KubelyColors.accent
                                : KubelyColors.textDim,
                          ),
                          const SizedBox(height: 5),
                          Text(
                            tab.label,
                            style: active
                                ? KubelyTypography.tabLabelActive
                                : KubelyTypography.tabLabel,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _TabDef {
  const _TabDef({required this.icon, required this.label});
  final IconData icon;
  final String label;
}
