class K8sEvent {
  const K8sEvent({
    required this.type,
    required this.reason,
    required this.object,
    required this.message,
    this.age,
    this.count = 1,
  });

  final String type;
  final String reason;
  final String object;
  final String message;
  final String? age;
  final int count;

  bool get isWarning => type == 'Warning';
  bool get isNormal => type == 'Normal';
}
