class Node {
  const Node({
    required this.name,
    required this.status,
    this.instanceType,
    this.cpuCapacity,
    this.memoryCapacity,
    this.cpuUsagePercent = 0,
    this.memoryUsagePercent = 0,
    this.podCount = 0,
    this.isCordoned = false,
  });

  final String name;
  final String status;
  final String? instanceType;
  final String? cpuCapacity;
  final String? memoryCapacity;
  final double cpuUsagePercent;
  final double memoryUsagePercent;
  final int podCount;
  final bool isCordoned;

  bool get isReady => status == 'Ready' && !isCordoned;
}
