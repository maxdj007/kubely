class ConfigMap {
  const ConfigMap({
    required this.name,
    required this.namespace,
    required this.data,
  });

  final String name;
  final String namespace;
  final Map<String, String> data;

  int get keyCount => data.length;
}

class Secret {
  const Secret({
    required this.name,
    required this.namespace,
    required this.type,
    required this.dataKeys,
  });

  final String name;
  final String namespace;
  final String type;
  final List<String> dataKeys;

  int get keyCount => dataKeys.length;
}
