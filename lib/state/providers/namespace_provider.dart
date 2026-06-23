import 'package:flutter_riverpod/flutter_riverpod.dart';

class NamespaceState {
  const NamespaceState({
    this.selections = const {
      'workloads': 'default',
      'events': 'default',
      'network': 'default',
      'storage': 'default',
      'helm': 'all',
    },
    this.available = const [
      'default',
      'kube-system',
      'kube-public',
      'infra',
      'monitoring',
      'cert-manager',
      'jobs',
      'data',
    ],
  });

  final Map<String, String> selections;
  final List<String> available;

  String forScope(String scope) => selections[scope] ?? 'default';

  NamespaceState copyWith({
    Map<String, String>? selections,
    List<String>? available,
  }) =>
      NamespaceState(
        selections: selections ?? this.selections,
        available: available ?? this.available,
      );
}

class NamespaceNotifier extends StateNotifier<NamespaceState> {
  NamespaceNotifier() : super(const NamespaceState());

  void setNamespace(String scope, String namespace) {
    final updated = {...state.selections, scope: namespace};
    state = state.copyWith(selections: updated);
  }

  void setAvailable(List<String> namespaces) {
    state = state.copyWith(available: namespaces);
  }
}

final namespaceProvider =
    StateNotifierProvider<NamespaceNotifier, NamespaceState>((ref) {
  return NamespaceNotifier();
});
