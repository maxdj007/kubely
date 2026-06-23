class PersistentVolumeClaim {
  const PersistentVolumeClaim({
    required this.name,
    required this.namespace,
    required this.capacity,
    required this.storageClass,
    required this.status,
    this.accessModes = const [],
    this.usagePercent = 0,
  });

  final String name;
  final String namespace;
  final String capacity;
  final String storageClass;
  final String status;
  final List<String> accessModes;
  final double usagePercent;

  bool get isBound => status == 'Bound';
}
