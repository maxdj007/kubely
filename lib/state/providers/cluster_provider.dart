import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../ui/screens/cluster_switcher/cluster_switcher_sheet.dart';

const _storageKey = 'kubely_clusters';
const _activeKey = 'kubely_active_index';

const _storage = FlutterSecureStorage(
  aOptions: AndroidOptions(encryptedSharedPreferences: true),
);

class ClusterState {
  const ClusterState({
    this.clusters = const [],
    this.activeIndex = 0,
    this.loaded = false,
  });

  final List<ClusterOption> clusters;
  final int activeIndex;
  final bool loaded;

  ClusterOption? get active =>
      clusters.isNotEmpty ? clusters[activeIndex] : null;
  String get activeName => active?.name ?? 'No cluster';
  bool get activeIsHealthy => active?.isReachable ?? false;

  ClusterState copyWith({
    List<ClusterOption>? clusters,
    int? activeIndex,
    bool? loaded,
  }) =>
      ClusterState(
        clusters: clusters ?? this.clusters,
        activeIndex: activeIndex ?? this.activeIndex,
        loaded: loaded ?? this.loaded,
      );
}

class ClusterNotifier extends StateNotifier<ClusterState> {
  ClusterNotifier() : super(const ClusterState()) {
    _load();
  }

  Future<void> _load() async {
    try {
      final raw = await _storage.read(key: _storageKey);
      final activeRaw = await _storage.read(key: _activeKey);

      if (raw != null && raw.isNotEmpty) {
        final allItems = (jsonDecode(raw) as List<dynamic>).map((item) {
          final m = item as Map<String, dynamic>;
          return ClusterOption(
            name: m['name'] as String,
            provider: m['provider'] as String,
            region: m['region'] as String? ?? '',
            isReachable: m['isReachable'] as bool? ?? true,
          );
        }).toList();

        // Strip old demo clusters that were seeded before
        const demoNames = {'prod-eks-use1', 'staging-gke', 'minikube-local'};
        final list = allItems
            .where((c) => !demoNames.contains(c.name))
            .toList();

        if (list.isEmpty) {
          state = const ClusterState(clusters: [], activeIndex: 0, loaded: true);
          await _persist();
        } else {
          final activeIdx = activeRaw != null ? int.tryParse(activeRaw) ?? 0 : 0;
          state = ClusterState(
            clusters: list,
            activeIndex: activeIdx.clamp(0, list.length - 1),
            loaded: true,
          );
          if (list.length != allItems.length) await _persist();
        }
      } else {
        state = const ClusterState(clusters: [], activeIndex: 0, loaded: true);
      }
    } catch (_) {
      state = state.copyWith(loaded: true);
    }
  }

  Future<void> _persist() async {
    final list = state.clusters
        .map((c) => {
              'name': c.name,
              'provider': c.provider,
              'region': c.region,
              'isReachable': c.isReachable,
            })
        .toList();
    await _storage.write(key: _storageKey, value: jsonEncode(list));
    await _storage.write(key: _activeKey, value: '${state.activeIndex}');
  }

  void setActive(int index) {
    if (index >= 0 && index < state.clusters.length) {
      state = state.copyWith(activeIndex: index);
      _persist();
    }
  }

  void addCluster(ClusterOption cluster) {
    final existing = state.clusters.indexWhere((c) => c.name == cluster.name);
    if (existing >= 0) {
      final updated = [...state.clusters];
      updated[existing] = cluster;
      state = state.copyWith(clusters: updated, activeIndex: existing);
    } else {
      final updated = [...state.clusters, cluster];
      state = state.copyWith(clusters: updated, activeIndex: updated.length - 1);
    }
    _persist();
  }

  void removeCluster(int index) {
    final updated = [...state.clusters]..removeAt(index);
    var newActive = state.activeIndex;
    if (newActive >= updated.length) newActive = updated.length - 1;
    if (newActive < 0) newActive = 0;
    state = state.copyWith(clusters: updated, activeIndex: newActive);
    _persist();
  }
}

final clusterProvider =
    StateNotifierProvider<ClusterNotifier, ClusterState>((ref) {
  return ClusterNotifier();
});
