import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/kubely_colors.dart';
import '../../../core/theme/kubely_typography.dart';
import '../../../core/constants/spacing.dart';
import '../../../data/models/cluster.dart';
import '../../../data/services/kubernetes_websocket.dart';
import '../../../data/services/kubernetes_auth.dart';
import '../../../data/repositories/kubeconfig_parser.dart';
import '../../../data/services/secure_storage_service.dart';
import '../../../state/providers/cluster_provider.dart';
import '../../../state/providers/k8s_data_provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class ExecScreen extends ConsumerStatefulWidget {
  const ExecScreen({super.key});

  @override
  ConsumerState<ExecScreen> createState() => _ExecScreenState();
}

class _ExecScreenState extends ConsumerState<ExecScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _commandHistory = <String>[];
  int _historyIndex = -1;
  bool _running = false;

  // Exec session state
  KubernetesExecSession? _execSession;
  StreamSubscription<String>? _stdoutSub;
  StreamSubscription<String>? _stderrSub;
  bool _execMode = false;
  String? _execPod;
  String? _execContainer;

  final _lines = <_TermLine>[
    _TermLine('Welcome to Kubely shell', _TermLineType.output),
    _TermLine('Type kubectl commands or use "exec <pod>" to open an interactive shell', _TermLineType.output),
    _TermLine('', _TermLineType.empty),
  ];

  static const _specialKeys = ['esc', 'tab', 'ctrl', '|', '~', '/', '-', '↑'];

  @override
  void dispose() {
    _disconnectExec();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _disconnectExec() {
    _stdoutSub?.cancel();
    _stderrSub?.cancel();
    _execSession?.dispose();
    _execSession = null;
    _stdoutSub = null;
    _stderrSub = null;
  }

  Future<void> _sendCommand() async {
    final cmd = _controller.text.trim();
    if (cmd.isEmpty) return;

    // In exec mode, send stdin to the WebSocket
    if (_execMode && _execSession != null && _execSession!.isConnected) {
      _commandHistory.add(cmd);
      _historyIndex = _commandHistory.length;
      _controller.clear();
      _execSession!.sendStdin('$cmd\n');
      return;
    }

    if (_running) return;
    _commandHistory.add(cmd);
    _historyIndex = _commandHistory.length;
    _controller.clear();

    setState(() {
      _lines.add(_TermLine('❯ $cmd', _TermLineType.command));
      _running = true;
    });
    _scrollDown();

    try {
      final result = await _executeCommand(cmd);
      setState(() {
        for (final line in result) {
          _lines.add(line);
        }
        _running = false;
      });
    } catch (e) {
      setState(() {
        _lines.add(_TermLine('Error: $e', _TermLineType.outputError));
        _running = false;
      });
    }
    _scrollDown();
  }

  Future<List<_TermLine>> _executeCommand(String cmd) async {
    final client = await ref.read(kubeClientProvider.future);
    if (client == null) {
      return [_TermLine('No cluster connected', _TermLineType.outputError)];
    }

    final parts = cmd.split(RegExp(r'\s+'));
    final args = parts.first == 'kubectl' ? parts.sublist(1) : parts;
    if (args.isEmpty) {
      return [_TermLine('Usage: get <resource> [name] [-n namespace]', _TermLineType.output)];
    }

    final verb = args[0];

    // Handle "exec" command — connect WebSocket
    if (verb == 'exec') {
      return await _handleExecCommand(args);
    }

    // Handle "exit" — disconnect exec session
    if (verb == 'exit' && _execMode) {
      _disconnectExec();
      setState(() => _execMode = false);
      return [_TermLine('[disconnected from $_execPod]', _TermLineType.output)];
    }

    String? resource = args.length > 1 ? args[1] : null;
    String? name;
    String namespace = 'default';

    for (var i = 0; i < args.length - 1; i++) {
      if (args[i] == '-n' || args[i] == '--namespace') {
        namespace = args[i + 1];
      }
    }

    if (resource != null && resource.contains('/')) {
      final split = resource.split('/');
      resource = split[0];
      name = split[1];
    } else if (args.length > 2 && !args[2].startsWith('-')) {
      name = args[2];
    }

    final allNs = args.contains('-A') || args.contains('--all-namespaces');

    try {
      switch (verb) {
        case 'get':
          return await _doGet(client, resource ?? '', name, allNs ? null : namespace);
        case 'describe':
          return await _doDescribe(client, resource ?? '', name, namespace);
        case 'delete':
          return await _doDelete(client, resource ?? '', name, namespace);
        case 'version':
          final v = await client.getVersion();
          return [_TermLine('Server Version: ${v['gitVersion']}', _TermLineType.outputGreen)];
        case 'cluster-info':
          return [_TermLine('Kubernetes control plane: ${client.cluster.cluster.server}', _TermLineType.outputGreen)];
        default:
          return [
            _TermLine('Unsupported command: $verb', _TermLineType.output),
            _TermLine('Supported: get, describe, delete, exec, version, cluster-info', _TermLineType.output),
          ];
      }
    } catch (e) {
      return [_TermLine('$e', _TermLineType.outputError)];
    }
  }

  Future<List<_TermLine>> _handleExecCommand(List<String> args) async {
    // Parse: exec <pod> [-n namespace] [-c container]
    String? podName;
    String namespace = 'default';
    String? container;

    for (var i = 1; i < args.length; i++) {
      if (args[i] == '-n' && i + 1 < args.length) {
        namespace = args[++i];
      } else if (args[i] == '-c' && i + 1 < args.length) {
        container = args[++i];
      } else if (args[i] == '-it' || args[i] == '--') {
        continue;
      } else if (!args[i].startsWith('-')) {
        podName = args[i];
      }
    }

    if (podName == null) {
      return [
        _TermLine('Usage: exec <pod> [-n namespace] [-c container]', _TermLineType.output),
        _TermLine('Opens an interactive shell in the pod', _TermLineType.output),
      ];
    }

    // Resolve namespace from pod if not specified
    final client = await ref.read(kubeClientProvider.future);
    if (client == null) {
      return [_TermLine('No cluster connected', _TermLineType.outputError)];
    }

    // If no container specified, find the first one
    if (container == null) {
      try {
        final podResp = await client.dio
            .get('/api/v1/namespaces/$namespace/pods/$podName')
            .timeout(const Duration(seconds: 10));
        final spec = podResp.data['spec'] as Map<String, dynamic>? ?? {};
        final containers = spec['containers'] as List<dynamic>? ?? [];
        if (containers.isNotEmpty) {
          container = containers.first['name'] as String?;
        }
      } catch (_) {}
    }
    container ??= podName;

    // Get the token for WebSocket auth
    final clusterState = ref.read(clusterProvider);
    final active = clusterState.active;
    if (active == null) {
      return [_TermLine('No active cluster', _TermLineType.outputError)];
    }

    String? token;
    try {
      final storage = SecureStorageService();
      final rawYaml = await storage.getRawKubeconfig(active.name);
      if (rawYaml != null) {
        final parsed = KubeconfigParser.parse(rawYaml);
        KubeContext? ctx;
        for (final c in parsed.contexts) {
          if (c.name == active.name) { ctx = c; break; }
        }
        ctx ??= parsed.contexts.isNotEmpty ? parsed.contexts.first : null;
        if (ctx != null) {
          final savedCluster = KubeconfigParser.buildSavedCluster(parsed, ctx);
          if (savedCluster != null) {
            final auth = KubernetesAuth(cluster: savedCluster);
            token = await auth.getToken();
          }
        }
      }
    } catch (_) {}

    final server = client.cluster.cluster.server;

    // Connect WebSocket
    _disconnectExec();
    _execSession = KubernetesExecSession(
      server: server,
      namespace: namespace,
      pod: podName,
      container: container,
      token: token,
    );

    try {
      await _execSession!.connect();
    } catch (e) {
      _disconnectExec();
      return [_TermLine('Failed to connect: $e', _TermLineType.outputError)];
    }

    if (!_execSession!.isConnected) {
      _disconnectExec();
      return [_TermLine('Connection failed', _TermLineType.outputError)];
    }

    _execPod = podName;
    _execContainer = container;
    setState(() => _execMode = true);

    _stdoutSub = _execSession!.stdout.listen((data) {
      if (mounted) {
        setState(() {
          for (final line in data.split('\n')) {
            if (line.isNotEmpty) {
              _lines.add(_TermLine(line, _TermLineType.output));
            }
          }
        });
        _scrollDown();
      }
    });

    _stderrSub = _execSession!.stderr.listen((data) {
      if (mounted) {
        setState(() {
          for (final line in data.split('\n')) {
            if (line.isNotEmpty) {
              _lines.add(_TermLine(line, _TermLineType.outputError));
            }
          }
        });
        _scrollDown();
      }
    });

    return [
      _TermLine('Connected to $podName/$container', _TermLineType.outputGreen),
      _TermLine('Type "exit" to disconnect', _TermLineType.output),
    ];
  }

  Future<List<_TermLine>> _doGet(dynamic client, String resource, String? name, String? namespace) async {
    String path;
    switch (resource) {
      case 'pods' || 'pod' || 'po':
        path = namespace != null ? '/api/v1/namespaces/$namespace/pods' : '/api/v1/pods';
      case 'deployments' || 'deployment' || 'deploy':
        path = namespace != null ? '/apis/apps/v1/namespaces/$namespace/deployments' : '/apis/apps/v1/deployments';
      case 'services' || 'service' || 'svc':
        path = namespace != null ? '/api/v1/namespaces/$namespace/services' : '/api/v1/services';
      case 'nodes' || 'node' || 'no':
        path = '/api/v1/nodes';
      case 'namespaces' || 'namespace' || 'ns':
        path = '/api/v1/namespaces';
      case 'events' || 'event' || 'ev':
        path = namespace != null ? '/api/v1/namespaces/$namespace/events' : '/api/v1/events';
      case 'configmaps' || 'configmap' || 'cm':
        path = namespace != null ? '/api/v1/namespaces/$namespace/configmaps' : '/api/v1/configmaps';
      case 'secrets' || 'secret':
        path = namespace != null ? '/api/v1/namespaces/$namespace/secrets' : '/api/v1/secrets';
      case 'ingresses' || 'ingress' || 'ing':
        path = namespace != null ? '/apis/networking.k8s.io/v1/namespaces/$namespace/ingresses' : '/apis/networking.k8s.io/v1/ingresses';
      case 'pvc' || 'persistentvolumeclaims':
        path = namespace != null ? '/api/v1/namespaces/$namespace/persistentvolumeclaims' : '/api/v1/persistentvolumeclaims';
      default:
        return [_TermLine('Unknown resource: $resource', _TermLineType.outputError)];
    }

    if (name != null) path += '/$name';
    final resp = await client.dio.get(path).timeout(const Duration(seconds: 15));
    final data = resp.data;

    if (name != null) {
      final meta = data['metadata'] as Map<String, dynamic>? ?? {};
      final lines = <_TermLine>[];
      lines.add(_TermLine('Name:       ${meta['name']}', _TermLineType.output));
      lines.add(_TermLine('Namespace:  ${meta['namespace'] ?? 'N/A'}', _TermLineType.output));
      if (data['status'] != null) {
        final status = data['status'];
        if (status is Map && status['phase'] != null) {
          lines.add(_TermLine('Status:     ${status['phase']}', _TermLineType.output));
        }
      }
      return lines;
    }

    final items = (data['items'] as List<dynamic>?) ?? [];
    if (items.isEmpty) {
      return [_TermLine('No resources found', _TermLineType.output)];
    }

    final lines = <_TermLine>[];
    lines.add(_TermLine(
        'NAME${' ' * 40}NAMESPACE${' ' * 6}STATUS'.substring(0, 60),
        _TermLineType.output));

    for (final item in items.take(50)) {
      final meta = item['metadata'] as Map<String, dynamic>? ?? {};
      final itemName = (meta['name'] as String? ?? '').padRight(44);
      final ns = (meta['namespace'] as String? ?? '—').padRight(15);
      String status = '';
      if (item['status'] is Map) {
        status = item['status']['phase'] as String? ?? '';
        if (status.isEmpty && item['status']['conditions'] is List) {
          final conds = item['status']['conditions'] as List;
          for (final c in conds) {
            if (c['type'] == 'Ready') {
              status = c['status'] == 'True' ? 'Ready' : 'NotReady';
              break;
            }
          }
        }
      }
      final line = '$itemName$ns$status';
      final type = status == 'Running' || status == 'Ready' || status == 'Active' || status == 'Bound'
          ? _TermLineType.output
          : status.contains('Error') || status.contains('Crash') || status == 'Failed'
              ? _TermLineType.outputError
              : _TermLineType.output;
      lines.add(_TermLine(line.trimRight(), type));
    }

    if (items.length > 50) {
      lines.add(_TermLine('... and ${items.length - 50} more', _TermLineType.output));
    }

    return lines;
  }

  Future<List<_TermLine>> _doDescribe(dynamic client, String resource, String? name, String namespace) async {
    if (name == null) {
      return [_TermLine('Usage: describe <resource> <name> [-n namespace]', _TermLineType.output)];
    }
    return _doGet(client, resource, name, namespace);
  }

  Future<List<_TermLine>> _doDelete(dynamic client, String resource, String? name, String namespace) async {
    if (name == null) {
      return [_TermLine('Usage: delete <resource> <name> [-n namespace]', _TermLineType.output)];
    }
    String path;
    switch (resource) {
      case 'pods' || 'pod' || 'po':
        path = '/api/v1/namespaces/$namespace/pods/$name';
      case 'deployments' || 'deployment' || 'deploy':
        path = '/apis/apps/v1/namespaces/$namespace/deployments/$name';
      case 'services' || 'service' || 'svc':
        path = '/api/v1/namespaces/$namespace/services/$name';
      default:
        return [_TermLine('Delete not supported for: $resource', _TermLineType.outputError)];
    }
    await client.dio.delete(path).timeout(const Duration(seconds: 15));
    return [_TermLine('$resource "$name" deleted', _TermLineType.outputGreen)];
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final clusterName = ref.watch(clusterProvider).activeName;
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return ColoredBox(
      color: KubelyColors.inkDeep,
      child: Column(
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
                  if (_execMode) ...[
                    Text('exec',
                        style: KubelyTypography.appBarTitle
                            .copyWith(color: KubelyColors.textMuted)),
                    const SizedBox(width: 6),
                    Text('·',
                        style: KubelyTypography.appBarTitle
                            .copyWith(color: KubelyColors.textDim)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(_execPod ?? '',
                          style: KubelyTypography.monoBody
                              .copyWith(color: KubelyColors.accent),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1),
                    ),
                    GestureDetector(
                      onTap: () {
                        _disconnectExec();
                        setState(() {
                          _execMode = false;
                          _lines.add(_TermLine('[disconnected]', _TermLineType.output));
                          _lines.add(_TermLine('', _TermLineType.empty));
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: KubelyColors.critical.withValues(alpha: 0.12),
                          border: Border.all(color: KubelyColors.critical.withValues(alpha: 0.3)),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Text('Disconnect',
                            style: KubelyTypography.caption.copyWith(
                              color: KubelyColors.critical,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                            )),
                      ),
                    ),
                  ] else ...[
                    Text('shell',
                        style: KubelyTypography.appBarTitle
                            .copyWith(color: KubelyColors.textMuted)),
                    const SizedBox(width: 6),
                    Text('·',
                        style: KubelyTypography.appBarTitle
                            .copyWith(color: KubelyColors.textDim)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(clusterName,
                          style: KubelyTypography.monoBody
                              .copyWith(color: KubelyColors.textPrimary),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1),
                    ),
                    GestureDetector(
                      onTap: () {
                        final allText = _lines
                            .where((l) => l.type != _TermLineType.empty)
                            .map((l) => l.text)
                            .join('\n');
                        Clipboard.setData(ClipboardData(text: allText));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Output copied'),
                            backgroundColor: KubelyColors.accent,
                            behavior: SnackBarBehavior.floating,
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      },
                      child: Icon(LucideIcons.copy,
                          size: 18, color: KubelyColors.textDim),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Connected indicator
          if (_execMode)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              color: KubelyColors.running.withValues(alpha: 0.08),
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: KubelyColors.running,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: KubelyColors.running.withValues(alpha: 0.5), blurRadius: 6)],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('Connected to ',
                      style: KubelyTypography.caption.copyWith(color: KubelyColors.textDim, fontSize: 10.5)),
                  Expanded(
                    child: Text('$_execPod/$_execContainer',
                        style: KubelyTypography.monoCaption.copyWith(color: KubelyColors.running),
                        overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ),

          // Terminal body
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(KubelySpacing.screenPadding),
              itemCount: _lines.length + 1,
              itemBuilder: (context, index) {
                if (index == _lines.length) {
                  if (_running) {
                    return Row(
                      children: [
                        SizedBox(
                          width: 12, height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            valueColor: AlwaysStoppedAnimation(KubelyColors.accent),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('Running...',
                            style: KubelyTypography.monoTerminal
                                .copyWith(color: KubelyColors.textDim)),
                      ],
                    );
                  }
                  if (_execMode) return const SizedBox.shrink();
                  final cursorBlock = Container(
                    width: 8,
                    height: 16,
                    color: KubelyColors.accent,
                  );
                  return Row(
                    children: [
                      Text('❯ ',
                          style: KubelyTypography.monoTerminal
                              .copyWith(color: KubelyColors.accent)),
                      if (reduceMotion)
                        cursorBlock
                      else
                        cursorBlock
                            .animate(onPlay: (c) => c.repeat())
                            .fadeOut(duration: 550.ms, curve: Curves.easeInCirc)
                            .then()
                            .fadeIn(duration: 550.ms, curve: Curves.easeOutCirc),
                    ],
                  );
                }
                final line = _lines[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: _buildLine(line),
                );
              },
            ),
          ),

          // Key accessory bar
          Container(
            height: 42,
            decoration: BoxDecoration(
              color: KubelyColors.surfaceStrip,
              border: Border(top: BorderSide(color: KubelyColors.hairline)),
            ),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              itemCount: _specialKeys.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (context, index) {
                final key = _specialKeys[index];
                final isTeal = '|~/'.contains(key);
                return GestureDetector(
                  onTap: () {
                    if (key == '↑') {
                      if (_commandHistory.isNotEmpty) {
                        _historyIndex = (_historyIndex - 1).clamp(0, _commandHistory.length - 1);
                        _controller.text = _commandHistory[_historyIndex];
                        _controller.selection = TextSelection.fromPosition(
                          TextPosition(offset: _controller.text.length),
                        );
                      }
                      return;
                    }
                    if (_execMode && _execSession != null && _execSession!.isConnected) {
                      // In exec mode, send special keys directly
                      switch (key) {
                        case 'esc':
                          _execSession!.sendStdin('\x1b');
                        case 'tab':
                          _execSession!.sendStdin('\t');
                        case 'ctrl':
                          break; // ctrl is a modifier, handled separately
                        default:
                          _controller.text += key;
                      }
                      return;
                    }
                    _controller.text += key == 'esc' ? '' : key == 'tab' ? '\t' : key == 'ctrl' ? '' : key;
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: KubelyColors.surfaceAlt,
                      border: Border.all(color: KubelyColors.hairline),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Text(key,
                        style: KubelyTypography.monoBody.copyWith(
                          color: isTeal ? KubelyColors.accent : KubelyColors.textPrimary,
                          fontSize: 13,
                        )),
                  ),
                );
              },
            ),
          ),

          // Input bar
          Container(
            padding: EdgeInsets.only(
              left: KubelySpacing.screenPadding,
              right: 10,
              top: 10,
              bottom: bottomPadding + KubelySpacing.tabBarHeight + 10,
            ),
            decoration: BoxDecoration(
              color: KubelyColors.ink,
              border: Border(top: BorderSide(color: KubelyColors.hairline)),
            ),
            child: Row(
              children: [
                Text(_execMode ? '\$' : '❯',
                    style: KubelyTypography.monoBody
                        .copyWith(color: KubelyColors.accent, fontSize: 16)),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: KubelyTypography.monoBody,
                    decoration: InputDecoration(
                      hintText: _execMode ? 'type a command…' : 'get pods -A',
                      hintStyle: KubelyTypography.monoBody
                          .copyWith(color: KubelyColors.textDim),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onSubmitted: (_) => _sendCommand(),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _sendCommand,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _running ? KubelyColors.textDim : KubelyColors.accent,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _running ? LucideIcons.loader : LucideIcons.arrowUp,
                      size: 20,
                      color: KubelyColors.ink,
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

  Widget _buildLine(_TermLine line) {
    Color color;
    switch (line.type) {
      case _TermLineType.command:
        return SelectableText.rich(
          TextSpan(children: [
            TextSpan(text: '❯ ', style: KubelyTypography.monoTerminal.copyWith(color: KubelyColors.accent)),
            TextSpan(text: line.text.replaceFirst('❯ ', ''), style: KubelyTypography.monoTerminal),
          ]),
        );
      case _TermLineType.output:
        color = KubelyColors.textDim;
      case _TermLineType.outputError:
        color = KubelyColors.criticalText;
      case _TermLineType.outputGreen:
        color = KubelyColors.running;
      case _TermLineType.empty:
        return const SizedBox(height: 12);
    }
    return SelectableText(line.text, style: KubelyTypography.monoTerminal.copyWith(color: color));
  }
}

enum _TermLineType { command, output, outputError, outputGreen, empty }

class _TermLine {
  const _TermLine(this.text, this.type);
  final String text;
  final _TermLineType type;
}
