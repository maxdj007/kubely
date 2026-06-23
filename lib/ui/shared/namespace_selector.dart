import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/theme/kubely_colors.dart';
import '../../core/theme/kubely_typography.dart';
import '../../state/providers/k8s_data_provider.dart';
import 'namespace_picker_sheet.dart';

class NamespaceSelector extends ConsumerWidget {
  const NamespaceSelector({
    super.key,
    required this.namespace,
    required this.count,
    this.onChanged,
    this.onTap,
    this.showAll = false,
  });

  final String namespace;
  final String count;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final bool showAll;

  static const _fallbackNamespaces = [
    'default', 'kube-system', 'kube-public',
  ];

  void _openPicker(BuildContext context, List<String> nsList) async {
    if (onTap != null) {
      onTap!();
      return;
    }
    final result = await NamespacePickerSheet.show(
      context,
      namespaces: nsList,
      selected: namespace,
      showAll: showAll,
    );
    if (result != null && result != namespace) {
      onChanged?.call(result);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nsAsync = ref.watch(namespacesProvider);
    final nsList = nsAsync.valueOrNull ?? _fallbackNamespaces;
    return Row(
      children: [
        Semantics(
          label: 'Namespace filter: $namespace',
          button: true,
          child: GestureDetector(
            onTap: () => _openPicker(context, nsList),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: KubelyColors.surface,
                border: Border.all(color: KubelyColors.hairline),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('ns:',
                      style: KubelyTypography.smallLabel
                          .copyWith(color: KubelyColors.textDim)),
                  const SizedBox(width: 4),
                  Text(namespace, style: KubelyTypography.monoBodySm),
                  const SizedBox(width: 4),
                  Icon(LucideIcons.chevronDown,
                      size: 12, color: KubelyColors.textDim),
                ],
              ),
            ),
          ),
        ),
        const Spacer(),
        Text(count, style: KubelyTypography.monoCount),
      ],
    );
  }
}
