class Deployment {
  const Deployment({
    required this.name,
    required this.namespace,
    required this.readyReplicas,
    required this.desiredReplicas,
    this.age,
    this.image,
  });

  final String name;
  final String namespace;
  final int readyReplicas;
  final int desiredReplicas;
  final String? age;
  final String? image;

  bool get isHealthy => readyReplicas == desiredReplicas && desiredReplicas > 0;
  bool get isDegraded => readyReplicas < desiredReplicas && readyReplicas > 0;
  String get readyText => '$readyReplicas/$desiredReplicas';
}
