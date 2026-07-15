import 'dart:developer' as dev;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/services/demo_cluster.dart';
import 'cluster_provider.dart';
import 'k8s_data_provider.dart';

class ClusterHealth {
  const ClusterHealth({
    required this.status,
    required this.percent,
    required this.podCount,
    required this.deployCount,
    required this.nodeCount,
    required this.cpuPercent,
    required this.memPercent,
    required this.cpuDetail,
    required this.memDetail,
    required this.alerts,
  });

  final String status;
  final double percent;
  final int podCount;
  final int deployCount;
  final int nodeCount;
  final double cpuPercent;
  final double memPercent;
  final String cpuDetail;
  final String memDetail;
  final List<AlertData> alerts;

  bool get isHealthy => status == 'Healthy';
  bool get isWarning => status == 'Warning';
  bool get isDegraded => status == 'Degraded';
  bool get isCritical => status == 'Critical';
}

class AlertData {
  const AlertData({
    required this.name,
    required this.status,
    required this.detail,
  });
  final String name;
  final String status;
  final String detail;
}

class PodData {
  const PodData({
    required this.name,
    required this.status,
    required this.age,
    this.namespace = 'default',
    this.sparkline = const [0.3, 0.4, 0.35, 0.5, 0.45, 0.6, 0.55],
  });
  final String name;
  final String status;
  final String age;
  final String namespace;
  final List<double> sparkline;
}

class DeployData {
  const DeployData({
    required this.name,
    required this.namespace,
    required this.ready,
    required this.desired,
  });
  final String name;
  final String namespace;
  final int ready;
  final int desired;
}

const _emptyHealth = ClusterHealth(
  status: 'Unknown',
  percent: 0,
  podCount: 0,
  deployCount: 0,
  nodeCount: 0,
  cpuPercent: 0,
  memPercent: 0,
  cpuDetail: '— / —',
  memDetail: '— / —',
  alerts: [],
);

/// True when the active cluster has data available (demo mock or real API).
/// Returns true for demo clusters and for any cluster with a stored kubeconfig.
final hasMockDataProvider = Provider<bool>((ref) {
  final state = ref.watch(clusterProvider);
  if (state.clusters.isEmpty) return false;
  // Any connected cluster has data — demo uses mock, real uses API
  return true;
});

/// True when no cluster is connected at all.
final hasNoClustersProvider = Provider<bool>((ref) {
  final state = ref.watch(clusterProvider);
  return state.clusters.isEmpty && state.loaded;
});

final clusterHealthProvider = FutureProvider<ClusterHealth>((ref) async {
  ref.watch(clusterProvider); // refetch when the active cluster changes

  // Real cluster — delegate to realClusterHealthProvider
  return ref.watch(realClusterHealthProvider.future);
});

final podListProvider = FutureProvider<List<PodData>>((ref) async {
  ref.watch(clusterProvider); // refetch when the active cluster changes

  // Real cluster — fetch from API
  final client = await ref.watch(kubeClientProvider.future);
  if (client == null) return const [];
  try {
    final resp = await client.dio.get('/api/v1/pods')
        .timeout(const Duration(seconds: 15));
    final items = (resp.data['items'] as List<dynamic>?) ?? [];
    return items.map((pod) {
      final meta = pod['metadata'] as Map<String, dynamic>? ?? {};
      final st = pod['status'] as Map<String, dynamic>? ?? {};
      final phase = st['phase'] as String? ?? 'Unknown';
      final cs = st['containerStatuses'] as List<dynamic>? ?? [];
      final restarts = cs.isNotEmpty ? (cs[0]['restartCount'] as int? ?? 0) : 0;
      return PodData(
        name: meta['name'] as String? ?? '',
        namespace: meta['namespace'] as String? ?? 'default',
        status: restarts > 4 ? 'CrashLoopBackOff' : phase,
        age: _calcAge(meta['creationTimestamp'] as String?),
      );
    }).toList();
  } catch (_) {
    return const [];
  }
});

final deployListProvider = FutureProvider<List<DeployData>>((ref) async {
  ref.watch(clusterProvider); // refetch when the active cluster changes

  final client = await ref.watch(kubeClientProvider.future);
  if (client == null) return const [];
  try {
    final resp = await client.dio.get('/apis/apps/v1/deployments')
        .timeout(const Duration(seconds: 15));
    final items = (resp.data['items'] as List<dynamic>?) ?? [];
    return items.map((d) {
      final meta = d['metadata'] as Map<String, dynamic>? ?? {};
      final st = d['status'] as Map<String, dynamic>? ?? {};
      final spec = d['spec'] as Map<String, dynamic>? ?? {};
      return DeployData(
        name: meta['name'] as String? ?? '',
        namespace: meta['namespace'] as String? ?? '',
        ready: st['readyReplicas'] as int? ?? 0,
        desired: spec['replicas'] as int? ?? 0,
      );
    }).toList();
  } catch (_) {
    return const [];
  }
});

String _calcAge(String? timestamp) {
  if (timestamp == null) return '';
  final created = DateTime.tryParse(timestamp);
  if (created == null) return '';
  final diff = DateTime.now().toUtc().difference(created);
  if (diff.inDays > 0) return '${diff.inDays}d';
  if (diff.inHours > 0) return '${diff.inHours}h';
  return '${diff.inMinutes}m';
}

// ── Activity data ──

class ActivityData {
  const ActivityData({
    required this.text,
    required this.highlight,
    this.suffix = '',
    required this.time,
    required this.type,
  });
  final String text;
  final String highlight;
  final String suffix;
  final String time;
  final String type; // 'scale', 'restart', 'create', 'delete'
}

/// The activity feed has no Kubernetes API equivalent (it would need an audit
/// log), so it stays empty for real clusters and is populated only for the demo.
final activityProvider = Provider<List<ActivityData>>((ref) {
  final name = ref.watch(clusterProvider).activeName;
  if (!isDemoCluster(name)) return const [];
  return const [
    ActivityData(text: 'Scaled ', highlight: 'checkout', suffix: ' to 3 replicas', time: '2m', type: 'scale'),
    ActivityData(text: 'Rollout restarted on ', highlight: 'web', time: '18m', type: 'restart'),
  ];
});

// ── Event data ──

class EventData {
  const EventData({
    required this.type,
    required this.reason,
    required this.object,
    required this.message,
    required this.age,
    this.namespace = 'default',
  });
  final String type;
  final String reason;
  final String object;
  final String namespace;
  final String message;
  final String age;
}

final eventListProvider = FutureProvider<List<EventData>>((ref) async {
  ref.watch(clusterProvider); // refetch when the active cluster changes
  final client = await ref.watch(kubeClientProvider.future);
  if (client == null) return const [];
  try {
    final resp = await client.dio.get('/api/v1/events').timeout(const Duration(seconds: 15));
    final items = (resp.data['items'] as List<dynamic>?) ?? [];
    return items.map((e) {
      final meta = e['metadata'] as Map<String, dynamic>? ?? {};
      final obj = e['involvedObject'] as Map<String, dynamic>? ?? {};
      return EventData(
        type: e['type'] as String? ?? 'Normal',
        reason: e['reason'] as String? ?? '',
        object: '${obj['kind'] ?? ''}/${obj['name'] ?? ''}',
        namespace: obj['namespace'] as String? ?? meta['namespace'] as String? ?? 'default',
        message: e['message'] as String? ?? '',
        age: _calcAge(e['lastTimestamp'] as String? ?? meta['creationTimestamp'] as String?),
      );
    }).toList();
  } catch (_) { return const []; }
});

// ── Service data ──

class ServiceData {
  const ServiceData({
    required this.name,
    required this.type,
    required this.clusterIp,
    required this.port,
    this.namespace = 'default',
  });
  final String name;
  final String type;
  final String clusterIp;
  final String port;
  final String namespace;
}

final serviceListProvider = FutureProvider<List<ServiceData>>((ref) async {
  ref.watch(clusterProvider); // refetch when the active cluster changes
  final client = await ref.watch(kubeClientProvider.future);
  if (client == null) return const [];
  try {
    final resp = await client.dio.get('/api/v1/services').timeout(const Duration(seconds: 15));
    final items = (resp.data['items'] as List<dynamic>?) ?? [];
    return items.map((s) {
      final meta = s['metadata'] as Map<String, dynamic>? ?? {};
      final spec = s['spec'] as Map<String, dynamic>? ?? {};
      final ports = spec['ports'] as List<dynamic>? ?? [];
      final portStr = ports.isNotEmpty ? '${ports[0]['port']}' : '';
      return ServiceData(
        name: meta['name'] as String? ?? '',
        namespace: meta['namespace'] as String? ?? 'default',
        type: spec['type'] as String? ?? 'ClusterIP',
        clusterIp: spec['clusterIP'] as String? ?? '',
        port: portStr,
      );
    }).toList();
  } catch (_) { return const []; }
});

// ── Ingress data ──

class IngressData {
  const IngressData({required this.name, required this.namespace, required this.host, required this.backend});
  final String name;
  final String namespace;
  final String host;
  final String backend;
}

final ingressListProvider = FutureProvider<List<IngressData>>((ref) async {
  final client = await ref.watch(kubeClientProvider.future);
  if (client == null) return const [];
  try {
    final resp = await client.dio.get('/apis/networking.k8s.io/v1/ingresses').timeout(const Duration(seconds: 15));
    final items = (resp.data['items'] as List<dynamic>?) ?? [];
    return items.expand((ing) {
      final meta = ing['metadata'] as Map<String, dynamic>? ?? {};
      final spec = ing['spec'] as Map<String, dynamic>? ?? {};
      final rules = spec['rules'] as List<dynamic>? ?? [];
      return rules.map((r) {
        final host = r['host'] as String? ?? '';
        final paths = (r['http']?['paths'] as List<dynamic>?) ?? [];
        final backend = paths.isNotEmpty
            ? '${paths[0]['backend']?['service']?['name'] ?? ''}:${paths[0]['backend']?['service']?['port']?['number'] ?? ''}'
            : '';
        return IngressData(name: meta['name'] as String? ?? '', namespace: meta['namespace'] as String? ?? '', host: host, backend: backend);
      });
    }).toList();
  } catch (_) { return const []; }
});

// ── PVC data ──

class PvcData {
  const PvcData({required this.name, required this.namespace, required this.capacity, required this.storageClass, required this.status});
  final String name;
  final String namespace;
  final String capacity;
  final String storageClass;
  final String status;
}

final pvcListProvider = FutureProvider<List<PvcData>>((ref) async {
  final client = await ref.watch(kubeClientProvider.future);
  if (client == null) return const [];
  try {
    final resp = await client.dio.get('/api/v1/persistentvolumeclaims').timeout(const Duration(seconds: 15));
    final items = (resp.data['items'] as List<dynamic>?) ?? [];
    return items.map((pvc) {
      final meta = pvc['metadata'] as Map<String, dynamic>? ?? {};
      final spec = pvc['spec'] as Map<String, dynamic>? ?? {};
      final st = pvc['status'] as Map<String, dynamic>? ?? {};
      final cap = st['capacity'] as Map<String, dynamic>? ?? spec['resources']?['requests'] as Map<String, dynamic>? ?? {};
      return PvcData(
        name: meta['name'] as String? ?? '',
        namespace: meta['namespace'] as String? ?? '',
        capacity: cap['storage'] as String? ?? '—',
        storageClass: spec['storageClassName'] as String? ?? '—',
        status: st['phase'] as String? ?? 'Pending',
      );
    }).toList();
  } catch (_) { return const []; }
});

// ── ConfigMap/Secret data ──

class ConfigItemData {
  const ConfigItemData({required this.name, required this.namespace, required this.keyCount, required this.type});
  final String name;
  final String namespace;
  final int keyCount;
  final String type;
}

final configMapListProvider = FutureProvider<List<ConfigItemData>>((ref) async {
  final client = await ref.watch(kubeClientProvider.future);
  if (client == null) return const [];
  try {
    final resp = await client.dio.get('/api/v1/configmaps').timeout(const Duration(seconds: 15));
    final items = (resp.data['items'] as List<dynamic>?) ?? [];
    return items.map((cm) {
      final meta = cm['metadata'] as Map<String, dynamic>? ?? {};
      final data = cm['data'] as Map<String, dynamic>? ?? {};
      return ConfigItemData(name: meta['name'] as String? ?? '', namespace: meta['namespace'] as String? ?? '', keyCount: data.length, type: 'ConfigMap');
    }).toList();
  } catch (_) { return const []; }
});

final secretListProvider = FutureProvider<List<ConfigItemData>>((ref) async {
  final client = await ref.watch(kubeClientProvider.future);
  if (client == null) return const [];
  try {
    final resp = await client.dio.get('/api/v1/secrets').timeout(const Duration(seconds: 15));
    final items = (resp.data['items'] as List<dynamic>?) ?? [];
    return items.map((s) {
      final meta = s['metadata'] as Map<String, dynamic>? ?? {};
      final data = s['data'] as Map<String, dynamic>? ?? {};
      return ConfigItemData(name: meta['name'] as String? ?? '', namespace: meta['namespace'] as String? ?? '', keyCount: data.length, type: s['type'] as String? ?? 'Opaque');
    }).toList();
  } catch (_) { return const []; }
});

// ── Helm release data ──

class HelmReleaseData {
  const HelmReleaseData({required this.name, required this.namespace, required this.chart, required this.revision, required this.status});
  final String name;
  final String namespace;
  final String chart;
  final int revision;
  final String status;
}

final helmReleaseListProvider = FutureProvider<List<HelmReleaseData>>((ref) async {
  final client = await ref.watch(kubeClientProvider.future);
  if (client == null) return const [];
  try {
    final resp = await client.dio.get('/api/v1/secrets', queryParameters: {'labelSelector': 'owner=helm'}).timeout(const Duration(seconds: 15));
    final items = (resp.data['items'] as List<dynamic>?) ?? [];

    // Parse all revisions
    final allRevisions = <HelmReleaseData>[];
    for (final s in items) {
      final meta = s['metadata'] as Map<String, dynamic>? ?? {};
      final labels = meta['labels'] as Map<String, dynamic>? ?? {};
      allRevisions.add(HelmReleaseData(
        name: labels['name'] as String? ?? meta['name'] as String? ?? '',
        namespace: meta['namespace'] as String? ?? '',
        chart: labels['chart'] as String? ?? '',
        revision: int.tryParse(labels['version'] as String? ?? '') ?? 1,
        status: labels['status'] as String? ?? 'unknown',
      ));
    }

    // Group by name+namespace, keep only the latest revision per release
    final latest = <String, HelmReleaseData>{};
    for (final r in allRevisions) {
      final key = '${r.namespace}/${r.name}';
      if (!latest.containsKey(key) || r.revision > latest[key]!.revision) {
        latest[key] = r;
      }
    }

    return latest.values.toList()..sort((a, b) => a.name.compareTo(b.name));
  } catch (_) { return const []; }
});

/// All revisions for a specific release — for the detail page.
final helmRevisionListProvider = FutureProvider.family<List<HelmReleaseData>, String>((ref, releaseKey) async {
  final client = await ref.watch(kubeClientProvider.future);
  if (client == null) return const [];
  final parts = releaseKey.split('/');
  if (parts.length < 2) return const [];
  final namespace = parts[0];
  final name = parts[1];
  try {
    final resp = await client.dio.get(
      '/api/v1/namespaces/$namespace/secrets',
      queryParameters: {'labelSelector': 'owner=helm,name=$name'},
    ).timeout(const Duration(seconds: 15));
    final items = (resp.data['items'] as List<dynamic>?) ?? [];
    final revisions = items.map((s) {
      final meta = s['metadata'] as Map<String, dynamic>? ?? {};
      final labels = meta['labels'] as Map<String, dynamic>? ?? {};
      return HelmReleaseData(
        name: labels['name'] as String? ?? '',
        namespace: meta['namespace'] as String? ?? '',
        chart: labels['chart'] as String? ?? '',
        revision: int.tryParse(labels['version'] as String? ?? '') ?? 1,
        status: labels['status'] as String? ?? 'unknown',
      );
    }).toList();
    revisions.sort((a, b) => b.revision.compareTo(a.revision));
    return revisions;
  } catch (_) { return const []; }
});

// ── Notification/alert data ──

class NotificationData {
  const NotificationData({
    required this.title,
    required this.resource,
    required this.message,
    required this.severity,
    required this.time,
  });
  final String title;
  final String resource;
  final String message;
  final String severity;
  final String time;
}

final notificationProvider = Provider<List<NotificationData>>((ref) {
  final healthAsync = ref.watch(clusterHealthProvider);
  final health = healthAsync.valueOrNull;
  if (health == null) return const [];
  return health.alerts.map((a) => NotificationData(
    title: a.status,
    resource: a.name,
    message: a.detail,
    severity: a.status.contains('Crash') ? 'critical' : 'warning',
    time: 'now',
  )).toList();
});

// ── Real data providers (call K8s API, parse into screen-ready types) ──

/// Pods from the real K8s API, parsed into PodData.
final realPodListProvider =
    FutureProvider.family<List<PodData>, String>((ref, namespace) async {
  final raw = await ref.watch(realPodsProvider(namespace).future);
  return raw.map((pod) {
    final metadata = pod['metadata'] as Map<String, dynamic>? ?? {};
    final status = pod['status'] as Map<String, dynamic>? ?? {};
    final phase = status['phase'] as String? ?? 'Unknown';
    final name = metadata['name'] as String? ?? '';
    final containerStatuses =
        status['containerStatuses'] as List<dynamic>? ?? [];
    final restarts = containerStatuses.isNotEmpty
        ? (containerStatuses[0]['restartCount'] as int? ?? 0)
        : 0;

    String age = '';
    final creationStr = metadata['creationTimestamp'] as String?;
    if (creationStr != null) {
      final created = DateTime.tryParse(creationStr);
      if (created != null) {
        final diff = DateTime.now().toUtc().difference(created);
        if (diff.inDays > 0) {
          age = '${diff.inDays}d';
        } else if (diff.inHours > 0) {
          age = '${diff.inHours}h';
        } else {
          age = '${diff.inMinutes}m';
        }
      }
    }

    return PodData(
      name: name,
      status: restarts > 4 ? 'CrashLoopBackOff' : phase,
      age: age,
    );
  }).toList();
});

/// Deployments from the real K8s API.
final realDeployListProvider =
    FutureProvider.family<List<DeployData>, String>((ref, namespace) async {
  final raw = await ref.watch(realDeploymentsProvider(namespace).future);
  return raw.map((dep) {
    final metadata = dep['metadata'] as Map<String, dynamic>? ?? {};
    final status = dep['status'] as Map<String, dynamic>? ?? {};
    final spec = dep['spec'] as Map<String, dynamic>? ?? {};
    return DeployData(
      name: metadata['name'] as String? ?? '',
      namespace: metadata['namespace'] as String? ?? namespace,
      ready: status['readyReplicas'] as int? ?? 0,
      desired: spec['replicas'] as int? ?? 0,
    );
  }).toList();
});

/// Events from the real K8s API.
final realEventListProvider =
    FutureProvider.family<List<EventData>, String>((ref, namespace) async {
  final raw = await ref.watch(realEventsProvider(namespace).future);
  return raw.map((evt) {
    final metadata = evt['metadata'] as Map<String, dynamic>? ?? {};
    final involvedObj =
        evt['involvedObject'] as Map<String, dynamic>? ?? {};
    String age = '';
    final lastTs = evt['lastTimestamp'] as String? ??
        metadata['creationTimestamp'] as String?;
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
    return EventData(
      type: evt['type'] as String? ?? 'Normal',
      reason: evt['reason'] as String? ?? '',
      object:
          '${involvedObj['kind'] ?? ''}/${involvedObj['name'] ?? ''}',
      message: evt['message'] as String? ?? '',
      age: age,
    );
  }).toList();
});

/// Cluster health from the real API — aggregates pods, nodes, metrics.
final realClusterHealthProvider =
    FutureProvider<ClusterHealth>((ref) async {
  dev.log('[kubely] realClusterHealthProvider: waiting for client...');
  final client = await ref.watch(kubeClientProvider.future);
  if (client == null) {
    dev.log('[kubely] realClusterHealthProvider: client is null');
    return _emptyHealth;
  }

  dev.log('[kubely] realClusterHealthProvider: client ready, fetching data from ${client.cluster.cluster.server}');
  try {
    // Use checkHealth first as a quick connectivity test
    dev.log('[kubely] Testing connectivity with /version...');
    final version = await client.getVersion()
        .timeout(const Duration(seconds: 15));
    dev.log('[kubely] Cluster version: $version');

    dev.log('[kubely] Fetching pods (all namespaces)...');
    final pods = await client.dio.get('/api/v1/pods')
        .timeout(const Duration(seconds: 15));
    final podItems = (pods.data['items'] as List<dynamic>?) ?? [];
    dev.log('[kubely] Got ${podItems.length} pods');
    dev.log('[kubely] Fetching deployments (all namespaces)...');
    final deploys = await client.dio.get('/apis/apps/v1/deployments')
        .timeout(const Duration(seconds: 15));
    final deployItems = (deploys.data['items'] as List<dynamic>?) ?? [];
    dev.log('[kubely] Got ${deployItems.length} deployments');
    dev.log('[kubely] Fetching nodes...');
    final nodeItems = await client.getNodes()
        .timeout(const Duration(seconds: 15));
    dev.log('[kubely] Got ${nodeItems.length} nodes');

    final podCount = podItems.length;
    final deployCount = deployItems.length;
    final nodeCount = nodeItems.length;

    int runningPods = 0;
    final alerts = <AlertData>[];
    for (final pod in podItems) {
      final status = pod['status'] as Map<String, dynamic>? ?? {};
      final phase = status['phase'] as String? ?? '';
      final name =
          (pod['metadata'] as Map<String, dynamic>?)?['name'] as String? ?? '';
      if (phase == 'Running') runningPods++;
      if (phase == 'Failed' || phase == 'Unknown') {
        alerts.add(AlertData(
            name: name, status: phase, detail: '$phase pod'));
      }
      final containers =
          status['containerStatuses'] as List<dynamic>? ?? [];
      for (final c in containers) {
        final restarts = c['restartCount'] as int? ?? 0;
        if (restarts > 4) {
          alerts.add(AlertData(
              name: name,
              status: 'CrashLoopBackOff',
              detail: 'CrashLoopBackOff · restarts ×$restarts'));
        }
      }
    }

    final healthPercent =
        podCount > 0 ? runningPods / podCount : 0.0;

    // Multi-tier health status based on industry SRE practices:
    //
    // "Healthy"   — >=95% pods running AND no critical alerts (CrashLoop/Failed)
    // "Warning"   — >=80% pods running OR only non-critical alerts (Pending pods)
    // "Degraded"  — >=50% pods running OR critical alerts present
    // "Critical"  — <50% pods running OR no nodes available
    //
    // Alert severity matters: CrashLoopBackOff and Failed are critical,
    // Pending/Unknown are warnings. A few warnings shouldn't tank the status.
    final criticalAlerts = alerts.where((a) =>
        a.status == 'CrashLoopBackOff' || a.status == 'Failed').toList();
    final criticalRatio = podCount > 0 ? criticalAlerts.length / podCount : 0.0;

    String healthStatus;
    if (nodeCount == 0 || healthPercent < 0.50) {
      healthStatus = 'Critical';
    } else if (criticalRatio > 0.10 || healthPercent < 0.80) {
      healthStatus = 'Degraded';
    } else if (criticalAlerts.isNotEmpty || healthPercent < 0.95) {
      healthStatus = 'Warning';
    } else {
      healthStatus = 'Healthy';
    }

    // Try to fetch CPU/MEM metrics from metrics-server
    double cpuPercent = 0;
    double memPercent = 0;
    String cpuDetail = '— / —';
    String memDetail = '— / —';
    try {
      final metricsResp = await client.dio.get('/apis/metrics.k8s.io/v1beta1/nodes')
          .timeout(const Duration(seconds: 10));
      final metricItems = (metricsResp.data['items'] as List<dynamic>?) ?? [];
      int totalCpuNanos = 0;
      int totalMemBytes = 0;
      for (final m in metricItems) {
        final usage = m['usage'] as Map<String, dynamic>? ?? {};
        final cpuStr = usage['cpu'] as String? ?? '0';
        final memStr = usage['memory'] as String? ?? '0';
        // Parse cpu: "250m" or "1234n"
        if (cpuStr.endsWith('n')) {
          totalCpuNanos += int.tryParse(cpuStr.replaceAll('n', '')) ?? 0;
        } else if (cpuStr.endsWith('m')) {
          totalCpuNanos += (int.tryParse(cpuStr.replaceAll('m', '')) ?? 0) * 1000000;
        }
        // Parse memory: "1234Ki"
        if (memStr.endsWith('Ki')) {
          totalMemBytes += (int.tryParse(memStr.replaceAll('Ki', '')) ?? 0) * 1024;
        } else if (memStr.endsWith('Mi')) {
          totalMemBytes += (int.tryParse(memStr.replaceAll('Mi', '')) ?? 0) * 1024 * 1024;
        }
      }
      // Estimate capacity from node count (rough: 4 vCPU, 16Gi per node)
      final estCpuCores = nodeCount * 4;
      final estMemGi = nodeCount * 16;
      final usedCpuCores = totalCpuNanos / 1000000000;
      final usedMemGi = totalMemBytes / (1024 * 1024 * 1024);
      cpuPercent = estCpuCores > 0 ? (usedCpuCores / estCpuCores).clamp(0.0, 1.0) : 0;
      memPercent = estMemGi > 0 ? (usedMemGi / estMemGi).clamp(0.0, 1.0) : 0;
      cpuDetail = '${usedCpuCores.toStringAsFixed(1)} / $estCpuCores vCPU';
      memDetail = '${usedMemGi.toStringAsFixed(1)} / $estMemGi GiB';
    } catch (_) {
      // metrics-server not available — leave at 0
    }

    return ClusterHealth(
      status: healthStatus,
      percent: healthPercent,
      podCount: podCount,
      deployCount: deployCount,
      nodeCount: nodeCount,
      cpuPercent: cpuPercent,
      memPercent: memPercent,
      cpuDetail: cpuDetail,
      memDetail: memDetail,
      alerts: alerts,
    );
  } catch (e, st) {
    dev.log('[kubely] realClusterHealthProvider ERROR: $e\n$st');
    return ClusterHealth(
      status: 'Error',
      percent: 0,
      podCount: 0,
      deployCount: 0,
      nodeCount: 0,
      cpuPercent: 0,
      memPercent: 0,
      cpuDetail: e.toString(),
      memDetail: '',
      alerts: [AlertData(name: 'Connection', status: 'Error', detail: '$e')],
    );
  }
});

/// Full pod detail — fetches single pod spec + events from API.
class PodDetailData {
  const PodDetailData({
    required this.name,
    required this.namespace,
    required this.status,
    required this.age,
    required this.nodeName,
    required this.restartCount,
    required this.containers,
    required this.events,
  });
  final String name;
  final String namespace;
  final String status;
  final String age;
  final String nodeName;
  final int restartCount;
  final List<ContainerData> containers;
  final List<PodEventData> events;
}

class ContainerData {
  const ContainerData({
    required this.name,
    required this.image,
    required this.ready,
    required this.state,
    this.cpuUsage,
    this.cpuLimit,
    this.memUsage,
    this.memLimit,
  });
  final String name;
  final String image;
  final bool ready;
  final String state;
  final String? cpuUsage;
  final String? cpuLimit;
  final String? memUsage;
  final String? memLimit;
}

class PodEventData {
  const PodEventData({required this.time, required this.message, required this.reason, required this.type});
  final String time;
  final String message;
  final String reason;
  final String type;
}

/// Fetches full pod detail from the K8s API for a specific pod (by "namespace/name" key).
final podDetailProvider =
    FutureProvider.family<PodDetailData?, String>((ref, podKey) async {
  final client = await ref.watch(kubeClientProvider.future);
  if (client == null) return null;

  // podKey is "namespace/podName" or just "podName" (defaults to searching all)
  String namespace;
  String podName;
  if (podKey.contains('/')) {
    final parts = podKey.split('/');
    namespace = parts[0];
    podName = parts[1];
  } else {
    // Find namespace from the pod list
    podName = podKey;
    namespace = 'default';
    try {
      final allPodsResp = await client.dio.get('/api/v1/pods').timeout(const Duration(seconds: 10));
      final allItems = (allPodsResp.data['items'] as List<dynamic>?) ?? [];
      for (final p in allItems) {
        final meta = p['metadata'] as Map<String, dynamic>? ?? {};
        if (meta['name'] == podName) {
          namespace = meta['namespace'] as String? ?? 'default';
          break;
        }
      }
    } catch (_) {}
  }

  try {
    final podResp = await client.dio.get('/api/v1/namespaces/$namespace/pods/$podName')
        .timeout(const Duration(seconds: 15));
    final pod = podResp.data as Map<String, dynamic>;
    final meta = pod['metadata'] as Map<String, dynamic>? ?? {};
    final spec = pod['spec'] as Map<String, dynamic>? ?? {};
    final st = pod['status'] as Map<String, dynamic>? ?? {};

    final phase = st['phase'] as String? ?? 'Unknown';
    final nodeName = spec['nodeName'] as String? ?? '—';
    final age = _calcAge(meta['creationTimestamp'] as String?);

    // Parse containers
    final containerStatuses = st['containerStatuses'] as List<dynamic>? ?? [];
    final containerSpecs = spec['containers'] as List<dynamic>? ?? [];
    int totalRestarts = 0;
    final containers = <ContainerData>[];

    for (final cs in containerSpecs) {
      final cName = cs['name'] as String? ?? '';
      final image = cs['image'] as String? ?? '';
      final resources = cs['resources'] as Map<String, dynamic>? ?? {};
      final limits = resources['limits'] as Map<String, dynamic>? ?? {};
      final requests = resources['requests'] as Map<String, dynamic>? ?? {};

      // Find matching status
      Map<String, dynamic>? cStatus;
      for (final s in containerStatuses) {
        if (s['name'] == cName) {
          cStatus = s as Map<String, dynamic>;
          break;
        }
      }

      final ready = cStatus?['ready'] as bool? ?? false;
      final restarts = cStatus?['restartCount'] as int? ?? 0;
      totalRestarts += restarts;

      String state = 'Unknown';
      final stateMap = cStatus?['state'] as Map<String, dynamic>? ?? {};
      if (stateMap.containsKey('running')) {
        state = 'Running';
      } else if (stateMap.containsKey('waiting')) {
        state = (stateMap['waiting'] as Map<String, dynamic>?)?['reason'] as String? ?? 'Waiting';
      } else if (stateMap.containsKey('terminated')) {
        state = (stateMap['terminated'] as Map<String, dynamic>?)?['reason'] as String? ?? 'Terminated';
      }

      containers.add(ContainerData(
        name: cName,
        image: image,
        ready: ready,
        state: state,
        cpuUsage: requests['cpu'] as String?,
        cpuLimit: limits['cpu'] as String?,
        memUsage: requests['memory'] as String?,
        memLimit: limits['memory'] as String?,
      ));
    }

    // Fetch events for this pod
    final eventsResp = await client.dio.get(
      '/api/v1/namespaces/$namespace/events',
      queryParameters: {'fieldSelector': 'involvedObject.name=$podName'},
    ).timeout(const Duration(seconds: 10));
    final eventItems = (eventsResp.data['items'] as List<dynamic>?) ?? [];
    final events = eventItems.map((e) {
      final eMeta = e['metadata'] as Map<String, dynamic>? ?? {};
      final lastTs = e['lastTimestamp'] as String? ?? eMeta['creationTimestamp'] as String?;
      return PodEventData(
        time: _calcAge(lastTs),
        message: e['message'] as String? ?? '',
        reason: e['reason'] as String? ?? '',
        type: e['type'] as String? ?? 'Normal',
      );
    }).toList();

    return PodDetailData(
      name: podName,
      namespace: namespace,
      status: totalRestarts > 4 ? 'CrashLoopBackOff' : phase,
      age: age,
      nodeName: nodeName,
      restartCount: totalRestarts,
      containers: containers,
      events: events,
    );
  } catch (e) {
    dev.log('[kubely] podDetailProvider error: $e');
    return null;
  }
});
