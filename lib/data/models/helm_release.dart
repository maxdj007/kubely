class HelmRelease {
  const HelmRelease({
    required this.name,
    required this.namespace,
    required this.chart,
    this.appVersion,
    required this.revision,
    required this.status,
    this.updated,
  });

  final String name;
  final String namespace;
  final String chart;
  final String? appVersion;
  final int revision;
  final String status;
  final String? updated;

  bool get isDeployed => status == 'deployed';
}
