import 'dart:convert';
import 'dart:io';

class HelmRelease {
  final String name;
  final String namespace;
  final String chart;
  final String? appVersion;
  final int revision;
  final String status;

  const HelmRelease({
    required this.name,
    required this.namespace,
    required this.chart,
    this.appVersion,
    required this.revision,
    required this.status,
  });
}

class HelmDecoder {
  /// Decode a Helm release from a K8s Secret's data field.
  /// Helm stores releases as: base64 → gzip → base64 → JSON
  static HelmRelease? decode(Map<String, dynamic> secretData) {
    try {
      final releaseData = secretData['release'] as String?;
      if (releaseData == null) return null;

      // Step 1: base64 decode the secret value
      final step1 = base64Decode(releaseData);

      // Step 2: base64 decode again (Helm double-encodes)
      final step2 = base64Decode(utf8.decode(step1));

      // Step 3: gzip decompress
      final decompressed = gzip.decode(step2);

      // Step 4: parse JSON
      final json = jsonDecode(utf8.decode(decompressed)) as Map<String, dynamic>;

      final name = json['name'] as String? ?? '';
      final namespace = json['namespace'] as String? ?? '';
      final version = json['version'] as int? ?? 1;
      final info = json['info'] as Map<String, dynamic>? ?? {};
      final status = info['status'] as String? ?? 'unknown';
      final chart = json['chart'] as Map<String, dynamic>? ?? {};
      final metadata = chart['metadata'] as Map<String, dynamic>? ?? {};
      final chartName = metadata['name'] as String? ?? '';
      final chartVersion = metadata['version'] as String? ?? '';
      final appVersion = metadata['appVersion'] as String?;

      return HelmRelease(
        name: name,
        namespace: namespace,
        chart: '$chartName-$chartVersion',
        appVersion: appVersion,
        revision: version,
        status: status,
      );
    } catch (_) {
      return null;
    }
  }

  /// Decode all Helm releases from a list of K8s Secrets
  static List<HelmRelease> decodeAll(List<Map<String, dynamic>> secrets) {
    final releases = <HelmRelease>[];
    for (final secret in secrets) {
      final data = secret['data'] as Map<String, dynamic>?;
      if (data == null) continue;
      final release = decode(data);
      if (release != null) releases.add(release);
    }
    return releases;
  }
}
