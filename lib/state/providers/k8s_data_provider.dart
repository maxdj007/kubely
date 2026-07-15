import 'dart:developer' as dev;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/services/kubernetes_api_client.dart';
import '../../data/services/demo_cluster.dart';
import '../../data/services/secure_storage_service.dart';
import '../../data/services/kubernetes_auth.dart';
import '../../data/repositories/kubeconfig_parser.dart';
import '../../data/models/cluster.dart';
import 'cluster_provider.dart';

/// Builds a real KubernetesApiClient from the stored kubeconfig + credentials.
final kubeClientProvider = FutureProvider<KubernetesApiClient?>((ref) async {
  final state = ref.watch(clusterProvider);
  final active = state.active;
  if (active == null) return null;

  // The demo cluster is served entirely from local fixtures — no kubeconfig,
  // no network. Every screen works because it goes through the same client.
  if (isDemoCluster(active.name)) {
    dev.log('[kubely] Building demo client (fixtures, no network)');
    return buildDemoApiClient();
  }

  dev.log('[kubely] Building client for: ${active.name}');

  final storage = SecureStorageService();
  final rawYaml = await storage.getRawKubeconfig(active.name);
  if (rawYaml == null || rawYaml.isEmpty) {
    dev.log('[kubely] No stored kubeconfig for ${active.name}');
    return null;
  }

  dev.log('[kubely] Kubeconfig found, parsing...');

  try {
    final parsed = KubeconfigParser.parse(rawYaml);
    dev.log('[kubely] Parsed ${parsed.contexts.length} contexts, ${parsed.clusters.length} clusters, ${parsed.users.length} users');

    // Find matching context
    KubeContext? ctx;
    for (final c in parsed.contexts) {
      if (c.name == active.name) {
        ctx = c;
        break;
      }
    }
    if (ctx == null && parsed.contexts.isNotEmpty) {
      ctx = parsed.contexts.first;
    }
    if (ctx == null) {
      dev.log('[kubely] No matching context found');
      return null;
    }

    dev.log('[kubely] Using context: ${ctx.name} -> cluster: ${ctx.clusterName}, user: ${ctx.userName}');

    final savedCluster =
        KubeconfigParser.buildSavedCluster(parsed, ctx);
    if (savedCluster == null) {
      dev.log('[kubely] Failed to build SavedCluster (cluster or user not found)');
      return null;
    }

    dev.log('[kubely] Server: ${savedCluster.server}');
    dev.log('[kubely] Auth method: ${KubernetesAuth(cluster: savedCluster).method}');

    final client = KubernetesApiClient(cluster: savedCluster);

    // Configure auth (tokens, TLS)
    final auth = KubernetesAuth(cluster: savedCluster);
    await auth.configureDio(client.dio);
    client.dio.interceptors.add(auth.refreshInterceptorFor(client.dio));

    dev.log('[kubely] Client ready, server: ${savedCluster.server}');
    return client;
  } catch (e, st) {
    dev.log('[kubely] Error building client: $e\n$st');
    rethrow; // Let the FutureProvider show the error state
  }
});

/// Namespace list — pulls from real cluster when available.
final namespacesProvider = FutureProvider<List<String>>((ref) async {
  final client = await ref.watch(kubeClientProvider.future);
  if (client == null) {
    return [
      'default', 'kube-system', 'kube-public', 'infra',
      'monitoring', 'cert-manager', 'jobs', 'data',
    ];
  }
  try {
    return await client.getNamespaces();
  } catch (_) {
    return ['default'];
  }
});

/// Check if the cluster is reachable.
final clusterReachableProvider = FutureProvider<bool>((ref) async {
  final clientAsync = ref.watch(kubeClientProvider);
  final client = clientAsync.valueOrNull;
  if (client == null) return false;
  try {
    return await client.checkHealth();
  } catch (_) {
    return false;
  }
});

/// Raw pods from the real cluster.
final realPodsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, namespace) async {
  final clientAsync = ref.watch(kubeClientProvider);
  final client = clientAsync.valueOrNull;
  if (client == null) return [];
  try {
    return await client.getPods(namespace);
  } catch (_) {
    return [];
  }
});

/// Raw deployments from the real cluster.
final realDeploymentsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, namespace) async {
  final clientAsync = ref.watch(kubeClientProvider);
  final client = clientAsync.valueOrNull;
  if (client == null) return [];
  try {
    return await client.getDeployments(namespace);
  } catch (_) {
    return [];
  }
});

/// Raw services from the real cluster.
final realServicesProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, namespace) async {
  final clientAsync = ref.watch(kubeClientProvider);
  final client = clientAsync.valueOrNull;
  if (client == null) return [];
  try {
    return await client.getServices(namespace);
  } catch (_) {
    return [];
  }
});

/// Raw events from the real cluster.
final realEventsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, namespace) async {
  final clientAsync = ref.watch(kubeClientProvider);
  final client = clientAsync.valueOrNull;
  if (client == null) return [];
  try {
    return await client.getEvents(namespace);
  } catch (_) {
    return [];
  }
});

/// Raw nodes from the real cluster.
final realNodesProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final clientAsync = ref.watch(kubeClientProvider);
  final client = clientAsync.valueOrNull;
  if (client == null) return [];
  try {
    return await client.getNodes();
  } catch (_) {
    return [];
  }
});

/// Raw node metrics from metrics-server.
final realNodeMetricsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final clientAsync = ref.watch(kubeClientProvider);
  final client = clientAsync.valueOrNull;
  if (client == null) return [];
  try {
    return await client.getNodeMetrics();
  } catch (_) {
    return [];
  }
});

/// Pod counts per node.
final podCountPerNodeProvider =
    FutureProvider<Map<String, int>>((ref) async {
  final clientAsync = ref.watch(kubeClientProvider);
  final client = clientAsync.valueOrNull;
  if (client == null) return {};
  try {
    final resp = await client.dio.get('/api/v1/pods').timeout(const Duration(seconds: 15));
    final items = (resp.data['items'] as List<dynamic>?) ?? [];
    final counts = <String, int>{};
    for (final pod in items) {
      final spec = pod['spec'] as Map<String, dynamic>? ?? {};
      final nodeName = spec['nodeName'] as String?;
      if (nodeName != null) {
        counts[nodeName] = (counts[nodeName] ?? 0) + 1;
      }
    }
    return counts;
  } catch (_) {
    return {};
  }
});
