class Service {
  const Service({
    required this.name,
    required this.namespace,
    required this.type,
    this.clusterIp,
    this.ports = const [],
    this.externalIp,
  });

  final String name;
  final String namespace;
  final String type;
  final String? clusterIp;
  final List<ServicePort> ports;
  final String? externalIp;

  String get portsText => ports.map((p) => '${p.port}/${p.protocol}').join(', ');
}

class ServicePort {
  const ServicePort({
    required this.port,
    this.targetPort,
    this.protocol = 'TCP',
    this.name,
  });

  final int port;
  final int? targetPort;
  final String protocol;
  final String? name;
}

class Ingress {
  const Ingress({
    required this.name,
    required this.namespace,
    this.rules = const [],
  });

  final String name;
  final String namespace;
  final List<IngressRule> rules;
}

class IngressRule {
  const IngressRule({
    required this.host,
    required this.backend,
    this.path = '/',
  });

  final String host;
  final String backend;
  final String path;
}
