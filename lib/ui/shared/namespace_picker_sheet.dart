import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/theme/kubely_colors.dart';
import '../../core/theme/kubely_typography.dart';
import '../../core/theme/kubely_radii.dart';

class NamespacePickerSheet extends StatelessWidget {
  const NamespacePickerSheet({
    super.key,
    required this.namespaces,
    required this.selected,
    this.showAll = false,
  });

  final List<String> namespaces;
  final String selected;
  final bool showAll;

  static Future<String?> show(
    BuildContext context, {
    required List<String> namespaces,
    required String selected,
    bool showAll = false,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => NamespacePickerSheet(
        namespaces: namespaces,
        selected: selected,
        showAll: showAll,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allItems = [
      if (showAll) 'all',
      ...namespaces,
    ];
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.55,
      ),
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
              color: KubelyColors.textFaint,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Icon(LucideIcons.layers, size: 18, color: KubelyColors.accent),
                const SizedBox(width: 10),
                Text('Select namespace',
                    style: KubelyTypography.appBarTitle),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: KubelyColors.hairline),
          Flexible(
            child: ListView.builder(
              padding: EdgeInsets.only(
                left: 8,
                right: 8,
                top: 6,
                bottom: bottomPadding + 16,
              ),
              shrinkWrap: true,
              itemCount: allItems.length,
              itemBuilder: (context, index) {
                final ns = allItems[index];
                final isSelected = ns == selected;
                return GestureDetector(
                  onTap: () => Navigator.of(context).pop(ns),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 13),
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? KubelyColors.accent.withValues(alpha: 0.08)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected
                                  ? KubelyColors.accent
                                  : KubelyColors.textFaint,
                              width: isSelected ? 5 : 2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          ns,
                          style: KubelyTypography.monoBody.copyWith(
                            color: isSelected
                                ? KubelyColors.accent
                                : KubelyColors.textPrimary,
                          ),
                        ),
                        if (ns == 'all') ...[
                          const SizedBox(width: 8),
                          Text('all namespaces',
                              style: KubelyTypography.caption
                                  .copyWith(color: KubelyColors.textDim)),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
