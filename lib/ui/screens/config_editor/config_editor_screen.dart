import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/kubely_colors.dart';
import '../../../core/theme/kubely_typography.dart';
import '../../../core/theme/kubely_shadows.dart';
import '../../../core/constants/spacing.dart';
import '../../../state/providers/k8s_data_provider.dart';

class ConfigEditorScreen extends ConsumerStatefulWidget {
  const ConfigEditorScreen({
    super.key,
    this.configName = 'app-config',
    this.namespace = 'default',
    this.isSecret = false,
  });

  final String configName;
  final String namespace;
  final bool isSecret;

  @override
  ConsumerState<ConfigEditorScreen> createState() => _ConfigEditorScreenState();
}

class _ConfigEditorScreenState extends ConsumerState<ConfigEditorScreen> {
  bool _hasEdits = false;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  int _editingIndex = -1;
  final _entries = <_ConfigEntry>[];
  final _controllers = <TextEditingController>[];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _fetchData() async {
    final client = await ref.read(kubeClientProvider.future);
    if (client == null) {
      setState(() {
        _loading = false;
        _error = 'No cluster connected';
      });
      return;
    }

    try {
      final path = widget.isSecret
          ? '/api/v1/namespaces/${widget.namespace}/secrets/${widget.configName}'
          : '/api/v1/namespaces/${widget.namespace}/configmaps/${widget.configName}';
      final resp =
          await client.dio.get(path).timeout(const Duration(seconds: 15));
      final data = resp.data as Map<String, dynamic>;
      final entries = (data['data'] as Map<String, dynamic>?) ?? {};

      setState(() {
        _entries.clear();
        _controllers.clear();
        for (final e in entries.entries) {
          final value = widget.isSecret ? '••••••••' : e.value as String;
          _entries.add(_ConfigEntry(e.key, value));
          _controllers.add(TextEditingController(text: value));
        }
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  Future<void> _applyChanges() async {
    if (_saving || widget.isSecret) return;
    setState(() => _saving = true);

    final client = await ref.read(kubeClientProvider.future);
    if (client == null) {
      setState(() => _saving = false);
      return;
    }

    try {
      final data = <String, String>{};
      for (var i = 0; i < _entries.length; i++) {
        data[_entries[i].key] = _controllers[i].text;
      }
      await client.updateConfigMap(widget.namespace, widget.configName, data);
      if (mounted) {
        setState(() {
          _hasEdits = false;
          _saving = false;
          for (var i = 0; i < _entries.length; i++) {
            _entries[i].value = _controllers[i].text;
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.configName} updated'),
            backgroundColor: KubelyColors.running,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update: $e'),
            backgroundColor: KubelyColors.critical,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      backgroundColor: KubelyColors.ink,
      body: Column(
        children: [
          SizedBox(height: topPadding),
          // App bar
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
                  Expanded(
                    child: Text(widget.configName,
                        style: KubelyTypography.monoBody.copyWith(
                            fontSize: 14, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis),
                  ),
                  if (_hasEdits)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: KubelyColors.warning.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text('EDITED',
                          style: KubelyTypography.eyebrow.copyWith(
                              color: KubelyColors.warning,
                              fontSize: 9.5,
                              letterSpacing: 0.8)),
                    ),
                ],
              ),
            ),
          ),

          // Key count + namespace
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: KubelySpacing.screenPadding),
            child: Row(
              children: [
                Text('${_entries.length} KEYS',
                    style: KubelyTypography.eyebrow
                        .copyWith(fontSize: 10, letterSpacing: 0.9)),
                const SizedBox(width: 8),
                Text('namespace ',
                    style: KubelyTypography.caption
                        .copyWith(color: KubelyColors.textDim)),
                Flexible(
                  child: Text(widget.namespace, style: KubelyTypography.monoCaption,
                      overflow: TextOverflow.ellipsis),
                ),
                if (widget.isSecret) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: KubelyColors.warning.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text('SECRET',
                        style: KubelyTypography.eyebrow.copyWith(
                            color: KubelyColors.warning,
                            fontSize: 9,
                            letterSpacing: 0.8)),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Content
          Expanded(
            child: _loading
                ? Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation(KubelyColors.accent),
                      ),
                    ),
                  )
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(LucideIcons.alertCircle,
                                  size: 32, color: KubelyColors.critical),
                              const SizedBox(height: 12),
                              Text(_error!,
                                  style: KubelyTypography.body.copyWith(
                                      color: KubelyColors.criticalText),
                                  textAlign: TextAlign.center),
                              const SizedBox(height: 12),
                              GestureDetector(
                                onTap: _fetchData,
                                child: Text('Retry',
                                    style: KubelyTypography.sectionLabel
                                        .copyWith(color: KubelyColors.accent)),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _entries.isEmpty
                        ? Center(
                            child: Text('No data keys',
                                style: KubelyTypography.body
                                    .copyWith(color: KubelyColors.textDim)),
                          )
                        : ListView.separated(
                            padding: EdgeInsets.only(
                              left: KubelySpacing.screenPadding,
                              right: KubelySpacing.screenPadding,
                              bottom: 20,
                            ),
                            itemCount: _entries.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final entry = _entries[index];
                              final isEditing = index == _editingIndex;
                              return GestureDetector(
                                onTap: () => setState(() {
                                  _editingIndex = isEditing ? -1 : index;
                                }),
                                child: Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: KubelyColors.surface,
                                    border: Border.all(
                                      color: isEditing
                                          ? KubelyColors.accent
                                          : KubelyColors.hairline,
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                    boxShadow: isEditing
                                        ? [
                                            BoxShadow(
                                              color: KubelyColors.accent
                                                  .withValues(alpha: 0.08),
                                              blurRadius: 12,
                                            )
                                          ]
                                        : null,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(entry.key,
                                          style: KubelyTypography.monoBody
                                              .copyWith(
                                                  color:
                                                      KubelyColors.yamlKey),
                                          overflow: TextOverflow.ellipsis),
                                      const SizedBox(height: 8),
                                      if (isEditing && !widget.isSecret)
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: KubelyColors.inkDeep,
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            border: Border.all(
                                                color: KubelyColors.accent
                                                    .withValues(alpha: 0.3)),
                                          ),
                                          child: TextField(
                                            controller: _controllers[index],
                                            style: KubelyTypography
                                                .monoTerminal,
                                            maxLines: null,
                                            decoration:
                                                const InputDecoration(
                                              border: InputBorder.none,
                                              isDense: true,
                                              contentPadding: EdgeInsets.zero,
                                            ),
                                            onChanged: (v) {
                                              if (!_hasEdits) {
                                                setState(
                                                    () => _hasEdits = true);
                                              }
                                            },
                                          ),
                                        )
                                      else
                                        Text(entry.value,
                                            style: KubelyTypography
                                                .monoTerminal
                                                .copyWith(
                                                    color: KubelyColors
                                                        .textSecondary)),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
          ),

          // Footer with Apply button
          if (_hasEdits && !widget.isSecret)
            Container(
              padding: EdgeInsets.only(
                left: KubelySpacing.screenPadding,
                right: KubelySpacing.screenPadding,
                top: 12,
                bottom: bottomPadding + 16,
              ),
              decoration: BoxDecoration(
                color: KubelyColors.ink,
                border:
                    Border(top: BorderSide(color: KubelyColors.hairline)),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: KubelyColors.warning.withValues(alpha: 0.08),
                      border: Border.all(color: KubelyColors.warningBorder),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(LucideIcons.alertTriangle,
                            size: 14, color: KubelyColors.warning),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Pods using this map need a restart',
                            style: KubelyTypography.caption.copyWith(
                                color: KubelyColors.warningText,
                                fontSize: 11.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 46,
                          child: OutlinedButton(
                            onPressed: () {
                              for (var i = 0; i < _entries.length; i++) {
                                _controllers[i].text = _entries[i].value;
                              }
                              setState(() => _hasEdits = false);
                            },
                            style: OutlinedButton.styleFrom(
                              side:
                                  BorderSide(color: KubelyColors.hairline),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text('Cancel',
                                style: KubelyTypography.sectionLabel
                                    .copyWith(
                                        color: KubelyColors.textMuted)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SizedBox(
                          height: 46,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: KubelyColors.accent,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: KubelyShadows.accentButtonGlow,
                            ),
                            child: TextButton(
                              onPressed: _saving ? null : _applyChanges,
                              child: _saving
                                  ? SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation(
                                                KubelyColors.ink),
                                      ),
                                    )
                                  : Text('Apply changes',
                                      style: KubelyTypography.buttonText
                                          .copyWith(fontSize: 14)),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ConfigEntry {
  _ConfigEntry(this.key, this.value);
  final String key;
  String value;
}
