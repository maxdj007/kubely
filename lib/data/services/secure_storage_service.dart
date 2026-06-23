import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/cluster.dart';

class SecureStorageService {
  static const _clustersKey = 'kubely_clusters';
  static const _activeClusterKey = 'kubely_active_cluster';

  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  Future<List<SavedCluster>> loadClusters() async {
    final raw = await _storage.read(key: _clustersKey);
    if (raw == null || raw.isEmpty) return [];

    final list = jsonDecode(raw) as List<dynamic>;
    return list.map((item) {
      final map = item as Map<String, dynamic>;
      return SavedCluster(
        context: KubeContext.fromJson(map['context'] as Map<String, dynamic>),
        cluster: KubeCluster.fromJson(map['cluster'] as Map<String, dynamic>),
        user: KubeUser.fromJson(map['user'] as Map<String, dynamic>),
      );
    }).toList();
  }

  Future<void> saveClusters(List<SavedCluster> clusters) async {
    final list = clusters.map((c) => {
          'context': c.context.toJson(),
          'cluster': c.cluster.toJson(),
          'user': c.user.toJson(),
        }).toList();
    await _storage.write(key: _clustersKey, value: jsonEncode(list));
  }

  Future<void> addCluster(SavedCluster cluster) async {
    final clusters = await loadClusters();
    clusters.removeWhere((c) => c.displayName == cluster.displayName);
    clusters.add(cluster);
    await saveClusters(clusters);
  }

  Future<void> removeCluster(String contextName) async {
    final clusters = await loadClusters();
    clusters.removeWhere((c) => c.displayName == contextName);
    await saveClusters(clusters);
  }

  Future<String?> getActiveClusterName() async {
    return _storage.read(key: _activeClusterKey);
  }

  Future<void> setActiveCluster(String contextName) async {
    await _storage.write(key: _activeClusterKey, value: contextName);
  }

  Future<void> storeRawKubeconfig(String name, String yaml) async {
    await _storage.write(key: 'kubeconfig_$name', value: yaml);
  }

  Future<String?> getRawKubeconfig(String name) async {
    return _storage.read(key: 'kubeconfig_$name');
  }
}
