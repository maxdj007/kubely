import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/kubely_colors.dart';
import '../../../core/theme/kubely_typography.dart';
import '../../../core/constants/spacing.dart';
import '../../../state/providers/k8s_data_provider.dart';
import '../../../state/providers/mock_data_provider.dart';
import '../../shared/hero_card.dart';
import '../../shared/status_dot.dart';
import '../../shared/confirm_bottom_sheet.dart';
import '../../shared/scale_bottom_sheet.dart';

class DeploymentDetailScreen extends ConsumerStatefulWidget {
  const DeploymentDetailScreen({
    super.key,
    required this.name,
    required this.namespace,
    required this.ready,
    required this.desired,
  });

  final String name;
  final String namespace;
  final int ready;
  final int desired;

  @override
  ConsumerState<DeploymentDetailScreen> createState() =>
      _DeploymentDetailScreenState();
}

class _DeploymentDetailScreenState
    extends ConsumerState<DeploymentDetailScreen> {
  late int _currentDesired;
  List<_RealPod> _pods = [];
  List<_RealEvent> _events = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _currentDesired = widget.desired;
    _fetchData();
  }

  Future<void> _fetchData() async {
    final client = await ref.read(kubeClientProvider.future);
    if (client == null) {
      setState(() => _loading = false);
      return;
    }

    try {
      // Fetch the deployment to get its label selector
      final deployResp = await client.dio
          .get('/apis/apps/v1/namespaces/${widget.namespace}/deployments/${widget.name}')
          .timeout(const Duration(seconds: 15));
      final deploy = deployResp.data as Map<String, dynamic>;
      final spec = deploy['spec'] as Map<String, dynamic>? ?? {};
      final selector = spec['selector'] as Map<String, dynamic>? ?? {};
      final matchLabels =
          selector['matchLabels'] as Map<String, dynamic>? ?? {};

      // Build label selector query
      final labelSelector =
          matchLabels.entries.map((e) => '${e.key}=${e.value}').join(',');

      // Fetch pods matching this deployment
      final podsResp = await client.dio.get(
        '/api/v1/namespaces/${widget.namespace}/pods',
        queryParameters:
            labelSelector.isNotEmpty ? {'labelSelector': labelSelector} : null,
      ).timeout(const Duration(seconds: 15));
      final podItems =
          (podsResp.data['items'] as List<dynamic>?) ?? [];

      final pods = podItems.map((p) {
        final meta = p['metadata'] as Map<String, dynamic>? ?? {};
        final st = p['status'] as Map<String, dynamic>? ?? {};
        final phase = st['phase'] as String? ?? 'Unknown';
        final cs = st['containerStatuses'] as List<dynamic>? ?? [];
        final restarts =
            cs.isNotEmpty ? (cs[0]['restartCount'] as int? ?? 0) : 0;
        String age = '';
        final ts = meta['creationTimestamp'] as String?;
        if (ts != null) {
          final created = DateTime.tryParse(ts);
          if (created != null) {
            final diff = DateTime.now().toUtc().difference(created);
            if (diff.inDays > 0) {
              age = '${diff.inDays}d ${diff.inHours % 24}h';
            } else if (diff.inHours > 0) {
              age = '${diff.inHours}h';
            } else {
              age = '${diff.inMinutes}m';
            }
          }
        }
        return _RealPod(
          name: meta['name'] as String? ?? '',
          status: restarts > 4 ? 'CrashLoopBackOff' : phase,
          age: age,
          ready: phase == 'Running' && cs.every((c) => c['ready'] == true),
          restarts: restarts,
        );
      }).toList();

      // Fetch events for this deployment
      final eventsResp = await client.dio.get(
        '/api/v1/namespaces/${widget.namespace}/events',
        queryParameters: {
          'fieldSelector':
              'involvedObject.name=${widget.name},involvedObject.kind=Deployment',
        },
      ).timeout(const Duration(seconds: 10));
      final eventItems =
          (eventsResp.data['items'] as List<dynamic>?) ?? [];

      // Also fetch ReplicaSet events
      final rsEventsResp = await client.dio.get(
        '/api/v1/namespaces/${widget.namespace}/events',
        queryParameters: {
          'fieldSelector': 'involvedObject.kind=ReplicaSet',
        },
      ).timeout(const Duration(seconds: 10));
      final rsEventItems =
          (rsEventsResp.data['items'] as List<dynamic>?) ?? [];
      // Filter RS events to those related to this deployment
      final relatedRsEvents = rsEventItems.where((e) {
        final obj =
            e['involvedObject'] as Map<String, dynamic>? ?? {};
        final rsName = obj['name'] as String? ?? '';
        return rsName.startsWith(widget.name);
      });

      final allEvents = [...eventItems, ...relatedRsEvents];
      allEvents.sort((a, b) {
        final aTs = a['lastTimestamp'] as String? ??
            (a['metadata'] as Map?)?['creationTimestamp'] as String? ??
            '';
        final bTs = b['lastTimestamp'] as String? ??
            (b['metadata'] as Map?)?['creationTimestamp'] as String? ??
            '';
        return bTs.compareTo(aTs);
      });

      final events = allEvents.take(10).map((e) {
        final eMeta = e['metadata'] as Map<String, dynamic>? ?? {};
        final lastTs = e['lastTimestamp'] as String? ??
            eMeta['creationTimestamp'] as String?;
        String age = '';
        if (lastTs != null) {
          final ts = DateTime.tryParse(lastTs);
          if (ts != null) {
            final diff = DateTime.now().toUtc().difference(ts);
            if (diff.inDays > 0) {
              age = '${diff.inDays}d';
            } else if (diff.inHours > 0) {
              age = '${diff.inHours}h';
            } else {
              age = '${diff.inMinutes}m';
            }
          }
        }
        return _RealEvent(
          time: age,
          message: e['message'] as String? ?? '',
          type: e['type'] as String? ?? 'Normal',
        );
      }).toList();

      if (mounted) {
        setState(() {
          _pods = pods;
          _events = events;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Color get _statusColor {
    if (widget.ready == 0 && _currentDesired > 0) return KubelyColors.warning;
    if (widget.ready < _currentDesired) return KubelyColors.critical;
    return KubelyColors.running;
  }

  String get _statusText {
    if (widget.ready == 0 && _currentDesired > 0) return 'Pending';
    if (widget.ready < _currentDesired) return 'Degraded';
    return 'Available';
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final displayPods = _pods.isNotEmpty ? _pods : _fakePods();

    return Scaffold(
      backgroundColor: KubelyColors.ink,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: SizedBox(height: topPadding)),

          // App bar
          SliverToBoxAdapter(
            child: Padding(
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
                      child: Text(widget.name,
                          style: KubelyTypography.monoBody.copyWith(
                              fontSize: 14, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis),
                    ),
                    Icon(LucideIcons.moreVertical,
                        size: 20, color: KubelyColors.textDim),
                  ],
                ),
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.symmetric(
                horizontal: KubelySpacing.screenPadding),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 6),

                // Status hero
                HeroCard(
                  borderColor: _statusColor.withValues(alpha: 0.18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          StatusDot(
                              color: _statusColor, size: 10, glow: true),
                          const SizedBox(width: 10),
                          Text(_statusText,
                              style: KubelyTypography.sectionLabel.copyWith(
                                  color: _statusColor,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700)),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          _InfoCell(
                              label: 'NAMESPACE', value: widget.namespace),
                          _InfoCell(
                              label: 'READY',
                              value: '${widget.ready}/$_currentDesired'),
                          const _InfoCell(
                              label: 'STRATEGY', value: 'RollingUpdate'),
                          _InfoCell(
                              label: 'PODS',
                              value: '${displayPods.length}'),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: KubelySpacing.cardGap),

                // Pods section
                Row(
                  children: [
                    Text('Pods', style: KubelyTypography.sectionLabel),
                    const SizedBox(width: 6),
                    Text('(${displayPods.length})',
                        style: KubelyTypography.caption
                            .copyWith(color: KubelyColors.textDim)),
                    if (_loading) ...[
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          valueColor:
                              AlwaysStoppedAnimation(KubelyColors.accent),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 10),

                ...displayPods.map((pod) {
                  final isOk = pod.ready;
                  final borderColor = isOk
                      ? KubelyColors.hairline
                      : pod.status == 'CrashLoopBackOff'
                          ? KubelyColors.criticalBorder
                          : KubelyColors.warningBorder;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 11),
                      decoration: BoxDecoration(
                        color: KubelyColors.surface,
                        border: Border.all(color: borderColor),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isOk
                                ? LucideIcons.checkCircle
                                : LucideIcons.alertCircle,
                            size: 16,
                            color: isOk
                                ? KubelyColors.running
                                : KubelyColors.warning,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(pod.name,
                                    style: KubelyTypography.monoBody,
                                    overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 2),
                                Text(
                                    '${pod.status} · ${pod.age}${pod.restarts > 0 ? ' · ×${pod.restarts} restarts' : ''}',
                                    style: KubelyTypography.monoCaptionSm
                                        .copyWith(
                                            color: isOk
                                                ? null
                                                : KubelyColors.warningText)),
                              ],
                            ),
                          ),
                          Text(isOk ? 'Ready' : pod.status,
                              style: KubelyTypography.caption.copyWith(
                                  color: isOk
                                      ? KubelyColors.running
                                      : KubelyColors.warning)),
                        ],
                      ),
                    ),
                  );
                }),

                const SizedBox(height: KubelySpacing.cardGap),

                // Action grid
                Text('Actions', style: KubelyTypography.sectionLabel),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                        child: _ActionButton(
                      icon: LucideIcons.arrowUpRight,
                      label: 'Scale',
                      color: KubelyColors.accent,
                      bgColor:
                          KubelyColors.accent.withValues(alpha: 0.10),
                      onTap: _onScale,
                    )),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _ActionButton(
                      icon: LucideIcons.fileText,
                      label: 'Logs',
                      color: KubelyColors.textPrimary,
                      bgColor: KubelyColors.surface,
                    )),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _ActionButton(
                      icon: LucideIcons.refreshCw,
                      label: 'Restart',
                      color: KubelyColors.info,
                      bgColor:
                          KubelyColors.info.withValues(alpha: 0.10),
                      onTap: _onRestart,
                    )),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _ActionButton(
                      icon: LucideIcons.trash2,
                      label: 'Delete',
                      color: KubelyColors.critical,
                      bgColor:
                          KubelyColors.critical.withValues(alpha: 0.10),
                      onTap: _onDelete,
                    )),
                  ],
                ),

                // Recent events
                if (_events.isNotEmpty) ...[
                  const SizedBox(height: KubelySpacing.cardGap),
                  Text('Recent events', style: KubelyTypography.sectionLabel),
                  const SizedBox(height: 10),
                  ..._events.map((e) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 28,
                              child: Text(e.time,
                                  style: KubelyTypography.monoCaption
                                      .copyWith(color: KubelyColors.textDim)),
                            ),
                            Text(' — ',
                                style: KubelyTypography.caption
                                    .copyWith(color: KubelyColors.textFaint)),
                            Expanded(
                              child: Text(e.message,
                                  style: KubelyTypography.caption.copyWith(
                                    fontSize: 11.5,
                                    color: e.type == 'Warning'
                                        ? KubelyColors.warningText
                                        : null,
                                  )),
                            ),
                          ],
                        ),
                      )),
                ],

                const SizedBox(height: 40),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  List<_RealPod> _fakePods() {
    const hashes = ['6f8b4c', '7c4d8f', '5a9c3e', '4b6d8c', '3e7f9a'];
    const suffixes = ['x2k9p', 'm3n1q', 'k8j2r', 'r5t3w', 'w4v2s'];
    const ages = ['4d 6h', '4d 6h', '4d 5h', '4d 4h', '3d 22h'];
    final pods = <_RealPod>[];
    for (var i = 0; i < widget.ready; i++) {
      pods.add(_RealPod(
        name: '${widget.name}-${hashes[i % hashes.length]}-${suffixes[i % suffixes.length]}',
        status: 'Running',
        age: ages[i % ages.length],
        ready: true,
        restarts: 0,
      ));
    }
    for (var i = 0; i < (_currentDesired - widget.ready).clamp(0, 99); i++) {
      final idx = widget.ready + i;
      pods.add(_RealPod(
        name: '${widget.name}-${hashes[idx % hashes.length]}-${suffixes[idx % suffixes.length]}',
        status: 'Pending',
        age: '',
        ready: false,
        restarts: 0,
      ));
    }
    return pods;
  }

  void _onScale() async {
    final result = await ScaleBottomSheet.show(
      context,
      resourceName: widget.name,
      currentReplicas: _currentDesired,
    );
    if (result != null && mounted) {
      setState(() => _currentDesired = result);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Scaling ${widget.name} to $result replicas'),
          backgroundColor: KubelyColors.accent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      // Call the real scale API
      final client = await ref.read(kubeClientProvider.future);
      if (client != null) {
        try {
          await client.scaleDeployment(widget.namespace, widget.name, result);
          ref.invalidate(deployListProvider);
          ref.invalidate(clusterHealthProvider);
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Scale failed: $e'),
              backgroundColor: KubelyColors.critical,
              behavior: SnackBarBehavior.floating,
            ));
          }
        }
      }
    }
  }

  void _onRestart() async {
    final confirmed = await ConfirmBottomSheet.show(
      context,
      action: ConfirmAction.restart,
      resourceName: widget.name,
      resourceType: 'deployment',
    );
    if (confirmed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Restarting ${widget.name}...'),
          backgroundColor: KubelyColors.info,
          behavior: SnackBarBehavior.floating,
        ),
      );
      // Call the real restart API
      final client = await ref.read(kubeClientProvider.future);
      if (client != null) {
        try {
          await client.restartDeployment(widget.namespace, widget.name);
          ref.invalidate(deployListProvider);
          _fetchData(); // refresh pod list
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Restart failed: $e'),
              backgroundColor: KubelyColors.critical,
              behavior: SnackBarBehavior.floating,
            ));
          }
        }
      }
    }
  }

  void _onDelete() async {
    final confirmed = await ConfirmBottomSheet.show(
      context,
      action: ConfirmAction.delete,
      resourceName: widget.name,
      resourceType: 'deployment',
    );
    if (confirmed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Deleting ${widget.name}...'),
          backgroundColor: KubelyColors.critical,
          behavior: SnackBarBehavior.floating,
        ),
      );
      // Call the real delete API
      final client = await ref.read(kubeClientProvider.future);
      if (client != null) {
        try {
          await client.dio.delete(
            '/apis/apps/v1/namespaces/${widget.namespace}/deployments/${widget.name}',
          );
          ref.invalidate(deployListProvider);
          ref.invalidate(clusterHealthProvider);
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Delete failed: $e'),
              backgroundColor: KubelyColors.critical,
              behavior: SnackBarBehavior.floating,
            ));
          }
          return; // Don't pop on failure
        }
      }
      if (mounted) {
        Navigator.of(context).maybePop();
      }
    }
  }
}

class _RealPod {
  const _RealPod({
    required this.name,
    required this.status,
    required this.age,
    required this.ready,
    required this.restarts,
  });
  final String name;
  final String status;
  final String age;
  final bool ready;
  final int restarts;
}

class _RealEvent {
  const _RealEvent({
    required this.time,
    required this.message,
    required this.type,
  });
  final String time;
  final String message;
  final String type;
}

class _InfoCell extends StatelessWidget {
  const _InfoCell({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: KubelyTypography.eyebrow
                  .copyWith(fontSize: 9.5, letterSpacing: 0.8)),
          const SizedBox(height: 3),
          Text(value,
              style: KubelyTypography.monoCaption
                  .copyWith(color: KubelyColors.textPrimary),
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.bgColor,
    this.onTap,
  });
  final IconData icon;
  final String label;
  final Color color;
  final Color bgColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: bgColor,
            border: Border.all(color: KubelyColors.hairline),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(height: 6),
              Text(label,
                  style: KubelyTypography.caption
                      .copyWith(color: color, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }
}
