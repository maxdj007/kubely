import 'dart:async';
import 'package:dio/dio.dart' show Options, ResponseType;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/kubely_colors.dart';
import '../../../core/theme/kubely_typography.dart';
import '../../../core/constants/spacing.dart';
import '../../../data/services/kubernetes_logs.dart';
import '../../../state/providers/k8s_data_provider.dart';

class LogsScreen extends ConsumerStatefulWidget {
  const LogsScreen({super.key, required this.podName, this.containerName});

  final String podName;
  final String? containerName;

  @override
  ConsumerState<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends ConsumerState<LogsScreen> {
  bool _showTimestamps = false;
  bool _follow = true;
  bool _loading = true;
  String? _error;
  String _namespace = 'default';
  final _scrollController = ScrollController();
  final _lines = <String>[];
  KubernetesLogStream? _logStream;
  StreamSubscription<String>? _streamSub;

  @override
  void initState() {
    super.initState();
    _fetchLogs();
  }

  Future<void> _resolveNamespace() async {
    final client = await ref.read(kubeClientProvider.future);
    if (client == null) return;
    try {
      final podsResp = await client.dio
          .get('/api/v1/pods')
          .timeout(const Duration(seconds: 10));
      final allPods = (podsResp.data['items'] as List<dynamic>?) ?? [];
      for (final p in allPods) {
        final meta = p['metadata'] as Map<String, dynamic>? ?? {};
        if (meta['name'] == widget.podName) {
          _namespace = meta['namespace'] as String? ?? 'default';
          break;
        }
      }
    } catch (_) {}
  }

  Future<void> _fetchLogs() async {
    _stopStream();
    setState(() {
      _loading = true;
      _error = null;
      _lines.clear();
    });

    final client = await ref.read(kubeClientProvider.future);
    if (client == null) {
      setState(() {
        _loading = false;
        _error = 'No cluster connected';
      });
      return;
    }

    await _resolveNamespace();

    try {
      final queryParams = <String, String>{
        'tailLines': '200',
        if (_showTimestamps) 'timestamps': 'true',
        if (widget.containerName != null) 'container': widget.containerName!,
      };

      final resp = await client.dio
          .get(
            '/api/v1/namespaces/$_namespace/pods/${widget.podName}/log',
            queryParameters: queryParams,
            options: Options(responseType: ResponseType.plain),
          )
          .timeout(const Duration(seconds: 15));

      final logText = resp.data as String? ?? '';
      setState(() {
        _lines.addAll(logText.split('\n').where((l) => l.isNotEmpty));
        _loading = false;
      });

      _scrollToBottom();

      if (_follow) {
        _startStream(client.dio);
      }
    } catch (e) {
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  void _startStream(dynamic dio) {
    _stopStream();
    _logStream = KubernetesLogStream(
      dio: dio,
      namespace: _namespace,
      pod: widget.podName,
      container: widget.containerName,
      follow: true,
      tailLines: 1,
      timestamps: _showTimestamps,
    );

    _streamSub = _logStream!.lines.listen(
      (line) {
        if (line.isNotEmpty && mounted) {
          setState(() => _lines.add(line));
          _scrollToBottom();
        }
      },
      onError: (e) {
        if (mounted) {
          setState(() => _error = 'Stream error: $e');
        }
      },
    );

    _logStream!.start();
  }

  void _stopStream() {
    _streamSub?.cancel();
    _streamSub = null;
    _logStream?.dispose();
    _logStream = null;
  }

  void _toggleFollow() {
    setState(() => _follow = !_follow);
    if (_follow) {
      _startStreamFromClient();
    } else {
      _stopStream();
    }
  }

  Future<void> _startStreamFromClient() async {
    final client = await ref.read(kubeClientProvider.future);
    if (client != null) {
      _startStream(client.dio);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  @override
  void dispose() {
    _stopStream();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: KubelyColors.inkDeep,
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
                  Text('logs',
                      style: KubelyTypography.appBarTitle
                          .copyWith(color: KubelyColors.textMuted)),
                  const SizedBox(width: 6),
                  Text('·',
                      style: KubelyTypography.appBarTitle
                          .copyWith(color: KubelyColors.textDim)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(widget.containerName ?? widget.podName,
                        style: KubelyTypography.monoBody,
                        overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ),
          ),

          // Controls bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: KubelyColors.ink,
              border:
                  Border(bottom: BorderSide(color: KubelyColors.hairline)),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    setState(() => _showTimestamps = !_showTimestamps);
                    _fetchLogs();
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _showTimestamps
                          ? KubelyColors.accent.withValues(alpha: 0.12)
                          : KubelyColors.surface,
                      border: Border.all(
                        color: _showTimestamps
                            ? KubelyColors.accent.withValues(alpha: 0.3)
                            : KubelyColors.hairline,
                      ),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.clock,
                            size: 12,
                            color: _showTimestamps
                                ? KubelyColors.accent
                                : KubelyColors.textDim),
                        const SizedBox(width: 5),
                        Text('Timestamps',
                            style: KubelyTypography.caption.copyWith(
                              color: _showTimestamps
                                  ? KubelyColors.accent
                                  : KubelyColors.textDim,
                              fontSize: 10.5,
                            )),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _fetchLogs,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: KubelyColors.surface,
                      border: Border.all(color: KubelyColors.hairline),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.refreshCw,
                            size: 12, color: KubelyColors.textDim),
                        const SizedBox(width: 5),
                        Text('Refresh',
                            style: KubelyTypography.caption.copyWith(
                              color: KubelyColors.textDim,
                              fontSize: 10.5,
                            )),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _toggleFollow,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _follow
                          ? KubelyColors.running.withValues(alpha: 0.12)
                          : KubelyColors.surface,
                      border: Border.all(
                        color: _follow
                            ? KubelyColors.running.withValues(alpha: 0.3)
                            : KubelyColors.hairline,
                      ),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.arrowDownToLine,
                            size: 12,
                            color: _follow
                                ? KubelyColors.running
                                : KubelyColors.textDim),
                        const SizedBox(width: 5),
                        Text(_follow ? 'Streaming' : 'Follow',
                            style: KubelyTypography.caption.copyWith(
                              color: _follow
                                  ? KubelyColors.running
                                  : KubelyColors.textDim,
                              fontSize: 10.5,
                            )),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                Text('${_lines.length} lines',
                    style: KubelyTypography.monoCaption),
              ],
            ),
          ),

          // Log body
          Expanded(
            child: _loading
                ? const Center(
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
                                onTap: _fetchLogs,
                                child: Text('Retry',
                                    style: KubelyTypography.sectionLabel
                                        .copyWith(color: KubelyColors.accent)),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _lines.isEmpty
                        ? Center(
                            child: Text('No logs available',
                                style: KubelyTypography.body
                                    .copyWith(color: KubelyColors.textDim)),
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.all(12),
                            itemCount: _lines.length,
                            itemBuilder: (context, index) {
                              final line = _lines[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 1),
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(
                                      width: 28,
                                      child: Text('${index + 1}',
                                          textAlign: TextAlign.right,
                                          style: KubelyTypography
                                              .monoTerminal
                                              .copyWith(
                                                  color: KubelyColors
                                                      .textFaint,
                                                  fontSize: 10)),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: SelectableText(line,
                                          style: KubelyTypography
                                              .monoTerminal
                                              .copyWith(
                                            color: line
                                                        .toLowerCase()
                                                        .contains('error') ||
                                                    line
                                                        .toLowerCase()
                                                        .contains('fatal')
                                                ? KubelyColors.criticalText
                                                : line
                                                        .toLowerCase()
                                                        .contains('warn')
                                                    ? KubelyColors
                                                        .warningText
                                                    : KubelyColors
                                                        .textSecondary,
                                            fontSize: 11,
                                          )),
                                    ),
                                  ],
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
