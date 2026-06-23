class Pod {
  const Pod({
    required this.name,
    required this.namespace,
    required this.status,
    this.nodeName,
    this.restartCount = 0,
    this.age,
    this.containers = const [],
    this.cpuUsage,
    this.memoryUsage,
  });

  final String name;
  final String namespace;
  final String status;
  final String? nodeName;
  final int restartCount;
  final String? age;
  final List<ContainerInfo> containers;
  final String? cpuUsage;
  final String? memoryUsage;

  bool get isHealthy =>
      status == 'Running' || status == 'Succeeded' || status == 'Completed';
  bool get isError =>
      status == 'CrashLoopBackOff' ||
      status == 'Error' ||
      status == 'Failed' ||
      status == 'ImagePullBackOff';
  bool get isPending => status == 'Pending';
}

class ContainerInfo {
  const ContainerInfo({
    required this.name,
    required this.image,
    this.ready = false,
    this.state = 'waiting',
    this.cpuUsage,
    this.cpuLimit,
    this.memoryUsage,
    this.memoryLimit,
  });

  final String name;
  final String image;
  final bool ready;
  final String state;
  final String? cpuUsage;
  final String? cpuLimit;
  final String? memoryUsage;
  final String? memoryLimit;
}
