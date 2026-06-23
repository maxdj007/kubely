class KubeCluster {
  const KubeCluster({
    required this.name,
    required this.server,
    this.certificateAuthorityData,
    this.insecureSkipTlsVerify = false,
  });

  final String name;
  final String server;
  final String? certificateAuthorityData;
  final bool insecureSkipTlsVerify;

  Map<String, dynamic> toJson() => {
        'name': name,
        'server': server,
        if (certificateAuthorityData != null)
          'certificateAuthorityData': certificateAuthorityData,
        'insecureSkipTlsVerify': insecureSkipTlsVerify,
      };

  factory KubeCluster.fromJson(Map<String, dynamic> json) => KubeCluster(
        name: json['name'] as String,
        server: json['server'] as String,
        certificateAuthorityData: json['certificateAuthorityData'] as String?,
        insecureSkipTlsVerify:
            json['insecureSkipTlsVerify'] as bool? ?? false,
      );
}

class KubeUser {
  const KubeUser({
    required this.name,
    this.token,
    this.clientCertificateData,
    this.clientKeyData,
    this.exec,
  });

  final String name;
  final String? token;
  final String? clientCertificateData;
  final String? clientKeyData;
  final KubeExec? exec;

  Map<String, dynamic> toJson() => {
        'name': name,
        if (token != null) 'token': token,
        if (clientCertificateData != null)
          'clientCertificateData': clientCertificateData,
        if (clientKeyData != null) 'clientKeyData': clientKeyData,
        if (exec != null) 'exec': exec!.toJson(),
      };

  factory KubeUser.fromJson(Map<String, dynamic> json) => KubeUser(
        name: json['name'] as String,
        token: json['token'] as String?,
        clientCertificateData: json['clientCertificateData'] as String?,
        clientKeyData: json['clientKeyData'] as String?,
        exec: json['exec'] != null
            ? KubeExec.fromJson(json['exec'] as Map<String, dynamic>)
            : null,
      );
}

class KubeExec {
  const KubeExec({
    required this.command,
    this.args = const [],
    this.apiVersion,
  });

  final String command;
  final List<String> args;
  final String? apiVersion;

  Map<String, dynamic> toJson() => {
        'command': command,
        'args': args,
        if (apiVersion != null) 'apiVersion': apiVersion,
      };

  factory KubeExec.fromJson(Map<String, dynamic> json) => KubeExec(
        command: json['command'] as String,
        args: (json['args'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
        apiVersion: json['apiVersion'] as String?,
      );
}

class KubeContext {
  const KubeContext({
    required this.name,
    required this.clusterName,
    required this.userName,
    this.namespace,
  });

  final String name;
  final String clusterName;
  final String userName;
  final String? namespace;

  Map<String, dynamic> toJson() => {
        'name': name,
        'clusterName': clusterName,
        'userName': userName,
        if (namespace != null) 'namespace': namespace,
      };

  factory KubeContext.fromJson(Map<String, dynamic> json) => KubeContext(
        name: json['name'] as String,
        clusterName: json['clusterName'] as String,
        userName: json['userName'] as String,
        namespace: json['namespace'] as String?,
      );
}

enum ClusterProvider { eks, gke, selfHosted }

class SavedCluster {
  const SavedCluster({
    required this.context,
    required this.cluster,
    required this.user,
    this.provider = ClusterProvider.selfHosted,
    this.isActive = false,
  });

  final KubeContext context;
  final KubeCluster cluster;
  final KubeUser user;
  final ClusterProvider provider;
  final bool isActive;

  String get displayName => context.name;
  String get server => cluster.server;

  ClusterProvider get detectedProvider {
    if (cluster.server.contains('.eks.amazonaws.com')) return ClusterProvider.eks;
    if (cluster.server.contains('.gke.')) return ClusterProvider.gke;
    if (user.exec?.command.contains('gcloud') == true) return ClusterProvider.gke;
    if (user.exec?.command.contains('aws') == true) return ClusterProvider.eks;
    return ClusterProvider.selfHosted;
  }

  String get providerLabel {
    switch (detectedProvider) {
      case ClusterProvider.eks:
        return 'EKS';
      case ClusterProvider.gke:
        return 'GKE';
      case ClusterProvider.selfHosted:
        return 'SELF';
    }
  }
}
