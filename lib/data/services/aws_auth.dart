import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Generates a K8s-compatible bearer token for EKS clusters using AWS SigV4.
class AwsEksAuth {
  AwsEksAuth({
    required this.accessKeyId,
    required this.secretAccessKey,
    this.sessionToken,
    required this.clusterName,
    this.region = 'us-east-1',
  });

  final String accessKeyId;
  final String secretAccessKey;
  final String? sessionToken;
  final String clusterName;
  final String region;

  static const _service = 'sts';
  static const _tokenPrefix = 'k8s-aws-v1.';

  String get _stsHost => 'sts.$region.amazonaws.com';

  String generateToken() {
    final now = DateTime.now().toUtc();
    final dateStamp = _fmtDate(now);
    final amzDate = _fmtAmzDate(now);
    final credential = '$accessKeyId/$dateStamp/$region/$_service/aws4_request';
    const signedHeaders = 'host;x-k8s-aws-id';

    // Build query parameters — values must be URI-encoded per SigV4 spec.
    // Parameters are sorted by key for the canonical query string.
    final params = <String, String>{
      'Action': 'GetCallerIdentity',
      'Version': '2011-06-15',
      'X-Amz-Algorithm': 'AWS4-HMAC-SHA256',
      'X-Amz-Credential': credential,
      'X-Amz-Date': amzDate,
      'X-Amz-Expires': '60',
      'X-Amz-SignedHeaders': signedHeaders,
    };
    if (sessionToken != null && sessionToken!.isNotEmpty) {
      params['X-Amz-Security-Token'] = sessionToken!;
    }

    // Canonical query string: key=uri_encode(value), sorted by key
    final sortedKeys = params.keys.toList()..sort();
    final canonicalQs = sortedKeys
        .map((k) => '${Uri.encodeComponent(k)}=${Uri.encodeComponent(params[k]!)}')
        .join('&');

    // Canonical headers (lowercase, sorted, each ends with \n)
    final canonicalHeaders = 'host:$_stsHost\nx-k8s-aws-id:$clusterName\n';

    // Canonical request
    final canonicalRequest = 'GET\n/\n$canonicalQs\n$canonicalHeaders\n$signedHeaders\n${_sha256Hex('')}';

    // String to sign
    final credentialScope = '$dateStamp/$region/$_service/aws4_request';
    final stringToSign =
        'AWS4-HMAC-SHA256\n$amzDate\n$credentialScope\n${_sha256Hex(canonicalRequest)}';

    // Signing key
    final signingKey = _deriveKey(secretAccessKey, dateStamp, region, _service);

    // Signature
    final signature = _hmacHex(signingKey, stringToSign);

    // Presigned URL — use the same canonical query string + signature
    final presignedUrl =
        'https://$_stsHost/?$canonicalQs&X-Amz-Signature=$signature';

    // Encode as K8s token
    final encoded = base64Url.encode(utf8.encode(presignedUrl)).replaceAll('=', '');
    return '$_tokenPrefix$encoded';
  }

  bool get hasCredentials =>
      accessKeyId.isNotEmpty && secretAccessKey.isNotEmpty;

  // ── Helpers ──

  static String _fmtDate(DateTime dt) =>
      '${dt.year}${_p(dt.month)}${_p(dt.day)}';

  static String _fmtAmzDate(DateTime dt) =>
      '${_fmtDate(dt)}T${_p(dt.hour)}${_p(dt.minute)}${_p(dt.second)}Z';

  static String _p(int n) => n.toString().padLeft(2, '0');

  static String _sha256Hex(String data) =>
      sha256.convert(utf8.encode(data)).toString();

  static List<int> _hmac(List<int> key, String data) =>
      Hmac(sha256, key).convert(utf8.encode(data)).bytes;

  static String _hmacHex(List<int> key, String data) =>
      Hmac(sha256, key).convert(utf8.encode(data)).toString();

  static List<int> _deriveKey(
      String secret, String date, String region, String service) {
    final kDate = _hmac(utf8.encode('AWS4$secret'), date);
    final kRegion = _hmac(kDate, region);
    final kService = _hmac(kRegion, service);
    return _hmac(kService, 'aws4_request');
  }
}

class AwsCredentials {
  const AwsCredentials({
    required this.accessKeyId,
    required this.secretAccessKey,
    this.sessionToken,
  });

  final String accessKeyId;
  final String secretAccessKey;
  final String? sessionToken;

  bool get isValid => accessKeyId.isNotEmpty && secretAccessKey.isNotEmpty;

  Map<String, String> toJson() => {
        'accessKeyId': accessKeyId,
        'secretAccessKey': secretAccessKey,
        if (sessionToken != null) 'sessionToken': sessionToken!,
      };

  factory AwsCredentials.fromJson(Map<String, dynamic> json) =>
      AwsCredentials(
        accessKeyId: json['accessKeyId'] as String? ?? '',
        secretAccessKey: json['secretAccessKey'] as String? ?? '',
        sessionToken: json['sessionToken'] as String?,
      );
}
