import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:file_picker/file_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'dart:io';
import '../../../core/theme/kubely_colors.dart';
import '../../../core/theme/kubely_typography.dart';
import '../../../core/theme/kubely_shadows.dart';
import '../../../core/constants/spacing.dart';
import '../../../data/repositories/kubeconfig_parser.dart';
import '../../../data/models/cluster.dart';
import '../../../state/providers/cluster_provider.dart';
import '../../shared/provider_badge.dart';
import '../../shared/auth_credentials_sheet.dart';
import '../../shared/gke_auth_sheet.dart';
import '../../../data/services/secure_storage_service.dart';
import '../../../data/services/aws_auth.dart';
import '../../../data/services/kubernetes_auth.dart';
import '../cluster_switcher/cluster_switcher_sheet.dart';

class AddClusterScreen extends ConsumerStatefulWidget {
  const AddClusterScreen({super.key});

  @override
  ConsumerState<AddClusterScreen> createState() => _AddClusterScreenState();
}

class _AddClusterScreenState extends ConsumerState<AddClusterScreen> {
  int _methodIndex = 0;
  int _selectedContext = 0;
  final _yamlController = TextEditingController();
  KubeconfigResult? _parsed;
  String? _parseError;

  static const _methods = ['Paste', 'File', 'QR'];


  @override
  void initState() {
    super.initState();
    _yamlController.addListener(_onYamlChanged);
  }

  void _onYamlChanged() {
    _tryParse(_yamlController.text);
  }

  @override
  void dispose() {
    _yamlController.removeListener(_onYamlChanged);
    _yamlController.dispose();
    super.dispose();
  }

  void _tryParse(String yaml) {
    if (yaml.trim().isEmpty) {
      setState(() {
        _parsed = null;
        _parseError = null;
      });
      return;
    }
    try {
      final result = KubeconfigParser.parse(yaml);
      setState(() {
        _parsed = result;
        _parseError = null;
        _selectedContext = 0;
      });
    } catch (e) {
      setState(() {
        _parsed = null;
        _parseError = e.toString();
      });
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );
    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      final content = await file.readAsString();
      _yamlController.text = content;
      _tryParse(content);
      setState(() => _methodIndex = 0);
    }
  }

  String _detectProvider(String contextName, String server) {
    final combined = '$contextName $server'.toLowerCase();
    if (combined.contains('eks') || combined.contains('.eks.amazonaws.com')) {
      return 'EKS';
    }
    if (combined.contains('gke') || combined.contains('google')) return 'GKE';
    return 'SELF';
  }

  String _detectRegion(String server) {
    final eksMatch = RegExp(r'\.(\w+-\w+-\d+)\.eks').firstMatch(server);
    if (eksMatch != null) return eksMatch.group(1)!;
    final gkeMatch = RegExp(r'\.(\w+-\w+\d?)\.').firstMatch(server);
    if (gkeMatch != null) return gkeMatch.group(1)!;
    return 'unknown';
  }

  Future<void> _connectCluster() async {
    if (_parsed == null || _parsed!.contexts.isEmpty) return;

    final ctx = _parsed!.contexts[_selectedContext];

    // Find matching cluster and user with proper types
    KubeCluster? matchedCluster;
    for (final c in _parsed!.clusters) {
      if (c.name == ctx.clusterName) {
        matchedCluster = c;
        break;
      }
    }
    KubeUser? matchedUser;
    for (final u in _parsed!.users) {
      if (u.name == ctx.userName) {
        matchedUser = u;
        break;
      }
    }

    final server = matchedCluster?.server ?? '';
    final provider = _detectProvider(ctx.name, server);
    final region = _detectRegion(server);

    // Prompt for credentials based on detected provider.
    // Static tokens and client certs work without prompting.
    // EKS and GKE need explicit credentials from the user.
    final hasStaticAuth = (matchedUser?.token ?? '').isNotEmpty ||
        matchedUser?.clientCertificateData != null;

    AwsCredentials? awsCreds;
    if (provider == 'EKS' && !hasStaticAuth) {
      if (!mounted) return;
      awsCreds = await AwsCredentialsSheet.show(context);
      if (awsCreds == null || !mounted) return;
    } else if (provider == 'GKE' && !hasStaticAuth) {
      if (!mounted) return;
      final token = await GkeAuthSheet.show(context);
      if (token == null || !mounted) return;
    }

    // Store kubeconfig YAML and credentials
    final storage = SecureStorageService();
    await storage.storeRawKubeconfig(ctx.name, _yamlController.text);
    if (awsCreds != null) {
      final savedCluster = SavedCluster(
        context: ctx,
        cluster: matchedCluster!,
        user: matchedUser ?? const KubeUser(name: ''),
      );
      final auth = KubernetesAuth(cluster: savedCluster);
      await auth.saveAwsCredentials(awsCreds);
    }

    ref.read(clusterProvider.notifier).addCluster(
          ClusterOption(
            name: ctx.name,
            provider: provider,
            region: region,
          ),
        );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connected to ${ctx.name}'),
          backgroundColor: KubelyColors.running,
          behavior: SnackBarBehavior.floating,
        ),
      );
      context.go('/vitals');
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final contexts = _parsed?.contexts ?? [];

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
                  Text('Add cluster', style: KubelyTypography.appBarTitle),
                ],
              ),
            ),
          ),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                  horizontal: KubelySpacing.screenPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),

                  // Method tabs
                  Row(
                    children: List.generate(_methods.length, (i) {
                      final active = i == _methodIndex;
                      return Padding(
                        padding: EdgeInsets.only(right: i < 2 ? 10 : 0),
                        child: GestureDetector(
                          onTap: () {
                            if (i == 1) {
                              _pickFile();
                            } else {
                              setState(() => _methodIndex = i);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 18, vertical: 9),
                            decoration: BoxDecoration(
                              color: active
                                  ? KubelyColors.accent
                                  : KubelyColors.surface,
                              border: Border.all(
                                color: active
                                    ? KubelyColors.accent
                                    : KubelyColors.hairline,
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (i == 1)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: Icon(LucideIcons.file,
                                        size: 14,
                                        color: active
                                            ? KubelyColors.ink
                                            : KubelyColors.textMuted),
                                  ),
                                if (i == 2)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: Icon(LucideIcons.qrCode,
                                        size: 14,
                                        color: active
                                            ? KubelyColors.ink
                                            : KubelyColors.textMuted),
                                  ),
                                Text(
                                  _methods[i],
                                  style:
                                      KubelyTypography.sectionLabel.copyWith(
                                    color: active
                                        ? KubelyColors.ink
                                        : KubelyColors.textMuted,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ),

                  const SizedBox(height: 16),

                  // QR tab
                  if (_methodIndex == 2) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: SizedBox(
                        height: 300,
                        child: Stack(
                          children: [
                            MobileScanner(
                              onDetect: (capture) {
                                final barcodes = capture.barcodes;
                                if (barcodes.isNotEmpty) {
                                  final value = barcodes.first.rawValue;
                                  if (value != null && value.contains('apiVersion')) {
                                    _yamlController.text = value;
                                    _tryParse(value);
                                    setState(() => _methodIndex = 0);
                                  }
                                }
                              },
                            ),
                            // Viewfinder overlay
                            Center(
                              child: Container(
                                width: 200,
                                height: 200,
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: KubelyColors.accent.withValues(alpha: 0.5),
                                    width: 2,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                            // Bottom label
                            Positioned(
                              bottom: 16,
                              left: 0,
                              right: 0,
                              child: Text(
                                'Scan kubeconfig QR code',
                                textAlign: TextAlign.center,
                                style: KubelyTypography.body.copyWith(color: Colors.white70),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  // Paste / File tab content
                  if (_methodIndex != 2) ...[
                  // Kubeconfig editor
                  Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxHeight: 280),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: KubelyColors.inkDeep,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: KubelyColors.hairline),
                    ),
                    child: TextField(
                      controller: _yamlController,
                      maxLines: null,
                      style: KubelyTypography.monoTerminal.copyWith(
                        fontSize: 11,
                        height: 1.6,
                        color: KubelyColors.textSecondary,
                      ),
                      decoration: InputDecoration(
                        hintText:
                            'Paste your kubeconfig YAML here...\n\n'
                            'apiVersion: v1\n'
                            'kind: Config\n'
                            'clusters:\n'
                            '- cluster:\n'
                            '    server: https://...',
                        hintStyle: KubelyTypography.monoTerminal.copyWith(
                          fontSize: 11,
                          height: 1.6,
                          color: KubelyColors.textFaint,
                        ),
                        hintMaxLines: 8,
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Parse error
                  if (_parseError != null)
                    Container(
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: KubelyColors.critical.withValues(alpha: 0.08),
                        border: Border.all(color: KubelyColors.criticalBorder),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(LucideIcons.alertCircle,
                              size: 14, color: KubelyColors.critical),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text('Invalid YAML',
                                style: KubelyTypography.caption.copyWith(
                                    color: KubelyColors.criticalText)),
                          ),
                        ],
                      ),
                    ),

                  // Detected contexts
                  if (contexts.isNotEmpty) ...[
                    Row(
                      children: [
                        Icon(LucideIcons.checkCircle,
                            size: 16, color: KubelyColors.running),
                        const SizedBox(width: 7),
                        Text('Detected ',
                            style: KubelyTypography.body
                                .copyWith(color: KubelyColors.textMuted)),
                        Text('${contexts.length} contexts',
                            style: KubelyTypography.sectionLabel),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Context rows
                    ...List.generate(contexts.length, (i) {
                      final ctx = contexts[i];
                      final selected = i == _selectedContext;
                      String server = '';
                      for (final c in _parsed!.clusters) {
                        if (c.name == ctx.clusterName) {
                          server = c.server;
                          break;
                        }
                      }
                      final provider =
                          _detectProvider(ctx.name, server);
                      final region = _detectRegion(server);

                      return Padding(
                        padding: EdgeInsets.only(
                            bottom: i < contexts.length - 1 ? 8 : 0),
                        child: GestureDetector(
                          onTap: () =>
                              setState(() => _selectedContext = i),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: KubelyColors.surface,
                              border: Border.all(
                                color: selected
                                    ? KubelyColors.accent
                                    : KubelyColors.hairline,
                              ),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 18,
                                  height: 18,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: selected
                                          ? KubelyColors.accent
                                          : KubelyColors.textFaint,
                                      width: selected ? 5 : 2,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(ctx.name,
                                                style: KubelyTypography
                                                    .monoBody,
                                                overflow:
                                                    TextOverflow.ellipsis),
                                          ),
                                          const SizedBox(width: 8),
                                          ProviderBadge(
                                              provider: provider),
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      Text('$provider · $region',
                                          style:
                                              KubelyTypography.caption),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                  ], // end if (_methodIndex != 2)
                ],
              ),
            ),
          ),

          // Pinned footer
          Container(
            padding: EdgeInsets.only(
              left: KubelySpacing.screenPadding,
              right: KubelySpacing.screenPadding,
              top: 14,
              bottom: bottomPadding + 16,
            ),
            decoration: BoxDecoration(
              color: KubelyColors.ink,
              border:
                  Border(top: BorderSide(color: KubelyColors.hairline)),
            ),
            child: Column(
              children: [
                Text(
                  'Stored only on this device · never uploaded',
                  style: KubelyTypography.caption.copyWith(fontSize: 11),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: contexts.isNotEmpty
                          ? KubelyColors.accent
                          : KubelyColors.textDim,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: contexts.isNotEmpty
                          ? KubelyShadows.accentButtonGlow
                          : null,
                    ),
                    child: TextButton(
                      onPressed:
                          contexts.isNotEmpty ? _connectCluster : null,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(LucideIcons.zap,
                              size: 18, color: KubelyColors.ink),
                          const SizedBox(width: 8),
                          Text('Connect cluster',
                              style: KubelyTypography.buttonText),
                        ],
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
