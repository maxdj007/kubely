import 'package:yaml/yaml.dart';
import '../models/cluster.dart';

class KubeconfigParser {
  static KubeconfigResult parse(String yamlString) {
    final doc = loadYaml(yamlString);
    if (doc is! YamlMap) {
      throw FormatException('Invalid kubeconfig: root must be a YAML map');
    }

    final clusters = <KubeCluster>[];
    final users = <KubeUser>[];
    final contexts = <KubeContext>[];

    // Parse clusters
    final clusterList = doc['clusters'];
    if (clusterList is YamlList) {
      for (final c in clusterList) {
        final clusterData = c['cluster'] as YamlMap?;
        clusters.add(KubeCluster(
          name: c['name'] as String? ?? '',
          server: clusterData?['server'] as String? ?? '',
          certificateAuthorityData:
              clusterData?['certificate-authority-data'] as String?,
          insecureSkipTlsVerify:
              clusterData?['insecure-skip-tls-verify'] as bool? ?? false,
        ));
      }
    }

    // Parse users
    final userList = doc['users'];
    if (userList is YamlList) {
      for (final u in userList) {
        final userData = u['user'] as YamlMap?;
        KubeExec? exec;
        final execData = userData?['exec'] as YamlMap?;
        if (execData != null) {
          exec = KubeExec(
            command: execData['command'] as String? ?? '',
            args: (execData['args'] as YamlList?)
                    ?.map((e) => e.toString())
                    .toList() ??
                [],
            apiVersion: execData['apiVersion'] as String?,
          );
        }

        users.add(KubeUser(
          name: u['name'] as String? ?? '',
          token: userData?['token'] as String?,
          clientCertificateData:
              userData?['client-certificate-data'] as String?,
          clientKeyData: userData?['client-key-data'] as String?,
          exec: exec,
        ));
      }
    }

    // Parse contexts
    final contextList = doc['contexts'];
    if (contextList is YamlList) {
      for (final ctx in contextList) {
        final ctxData = ctx['context'] as YamlMap?;
        contexts.add(KubeContext(
          name: ctx['name'] as String? ?? '',
          clusterName: ctxData?['cluster'] as String? ?? '',
          userName: ctxData?['user'] as String? ?? '',
          namespace: ctxData?['namespace'] as String?,
        ));
      }
    }

    final currentContext = doc['current-context'] as String?;

    return KubeconfigResult(
      clusters: clusters,
      users: users,
      contexts: contexts,
      currentContext: currentContext,
    );
  }

  static SavedCluster? buildSavedCluster(
      KubeconfigResult result, KubeContext context) {
    final cluster = result.clusters.cast<KubeCluster?>().firstWhere(
          (c) => c!.name == context.clusterName,
          orElse: () => null,
        );
    final user = result.users.cast<KubeUser?>().firstWhere(
          (u) => u!.name == context.userName,
          orElse: () => null,
        );
    if (cluster == null || user == null) return null;

    return SavedCluster(
      context: context,
      cluster: cluster,
      user: user,
    );
  }
}

class KubeconfigResult {
  const KubeconfigResult({
    required this.clusters,
    required this.users,
    required this.contexts,
    this.currentContext,
  });

  final List<KubeCluster> clusters;
  final List<KubeUser> users;
  final List<KubeContext> contexts;
  final String? currentContext;
}
