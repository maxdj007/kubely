import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/cluster.dart';
import 'aws_auth.dart';
import 'gcp_auth.dart';

enum AuthMethod { token, clientCert, eks, gke, unknown }

class KubernetesAuth {
  KubernetesAuth({required this.cluster});

  final SavedCluster cluster;

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // Cached tokens
  String? _currentToken;
  DateTime? _tokenExpiry;

  /// Detect the auth method from the kubeconfig user entry.
  AuthMethod get method {
    final user = cluster.user;
    if (user.token != null && user.token!.isNotEmpty) return AuthMethod.token;
    if (user.clientCertificateData != null) return AuthMethod.clientCert;
    if (user.exec != null) {
      final cmd = user.exec!.command;
      if (cmd.contains('aws') || cmd.contains('iam-authenticator')) {
        return AuthMethod.eks;
      }
      if (cmd.contains('gcloud') || cmd.contains('gke-gcloud-auth-plugin')) {
        return AuthMethod.gke;
      }
    }
    return AuthMethod.unknown;
  }

  /// Get a valid bearer token, refreshing if needed.
  Future<String?> getToken() async {
    switch (method) {
      case AuthMethod.token:
        return cluster.user.token;

      case AuthMethod.eks:
        return _getEksToken();

      case AuthMethod.gke:
        return _getGkeToken();

      case AuthMethod.clientCert:
      case AuthMethod.unknown:
        return null;
    }
  }

  /// Configure Dio options with the appropriate auth.
  Future<void> configureDio(Dio dio) async {
    dev.log('[kubely-auth] Configuring auth, method: $method');
    switch (method) {
      case AuthMethod.token:
      case AuthMethod.eks:
      case AuthMethod.gke:
        final token = await getToken();
        if (token != null) {
          dev.log('[kubely-auth] Token set (${token.length} chars)');
          dio.options.headers['Authorization'] = 'Bearer $token';
        } else {
          dev.log('[kubely-auth] WARNING: No token generated!');
        }

      case AuthMethod.clientCert:
        // Client cert auth is configured at the HttpClientAdapter level
        final certData = cluster.user.clientCertificateData;
        final keyData = cluster.user.clientKeyData;
        if (certData != null && keyData != null) {
          dio.httpClientAdapter = IOHttpClientAdapter(
            createHttpClient: () {
              final context = SecurityContext();
              context.useCertificateChainBytes(base64Decode(certData));
              context.usePrivateKeyBytes(base64Decode(keyData));

              final caData = cluster.cluster.certificateAuthorityData;
              if (caData != null) {
                context.setTrustedCertificatesBytes(base64Decode(caData));
              }

              final client = HttpClient(context: context);
              if (cluster.cluster.insecureSkipTlsVerify || caData == null) {
                client.badCertificateCallback = (cert, host, port) {
                  if (cluster.cluster.insecureSkipTlsVerify) return true;
                  return host == Uri.parse(cluster.cluster.server).host;
                };
              }
              return client;
            },
          );
        }

      case AuthMethod.unknown:
        break;
    }

    // Configure TLS for non-client-cert methods
    if (method != AuthMethod.clientCert) {
      final caData = cluster.cluster.certificateAuthorityData;
      dio.httpClientAdapter = IOHttpClientAdapter(
        createHttpClient: () {
          HttpClient client;
          if (caData != null && caData.length > 20) {
            try {
              final context = SecurityContext();
              context.setTrustedCertificatesBytes(base64Decode(caData));
              client = HttpClient(context: context);
            } catch (_) {
              // CA decode failed — fall back to system certs + permissive
              client = HttpClient();
              client.badCertificateCallback = (cert, host, port) {
                // Trust the K8s API server host from the kubeconfig
                return host == Uri.parse(cluster.cluster.server).host;
              };
            }
          } else {
            // No CA data — use system defaults + trust the configured host
            client = HttpClient();
            client.badCertificateCallback = (cert, host, port) {
              return host == Uri.parse(cluster.cluster.server).host;
            };
          }
          if (cluster.cluster.insecureSkipTlsVerify) {
            client.badCertificateCallback = (_, __, ___) => true;
          }
          return client;
        },
      );
    }
  }

  /// Dio interceptor that refreshes tokens before expiry.
  /// Retries 401s once with a fresh token — no recursive loops.
  Interceptor refreshInterceptorFor(Dio configuredDio) {
    bool retrying = false;
    return InterceptorsWrapper(
      onRequest: (options, handler) async {
        if (_tokenExpiry != null &&
            DateTime.now()
                .isAfter(_tokenExpiry!.subtract(const Duration(seconds: 30)))) {
          _currentToken = null;
          final token = await getToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401 && !retrying) {
          retrying = true;
          _currentToken = null;
          final token = await getToken();
          retrying = false;
          if (token != null) {
            error.requestOptions.headers['Authorization'] = 'Bearer $token';
            try {
              final retryResponse =
                  await configuredDio.fetch(error.requestOptions);
              return handler.resolve(retryResponse);
            } catch (e) {
              return handler.next(error);
            }
          }
        }
        handler.next(error);
      },
    );
  }

  Future<String?> _getEksToken() async {
    if (_currentToken != null &&
        _tokenExpiry != null &&
        DateTime.now().isBefore(_tokenExpiry!)) {
      dev.log('[kubely-auth] Using cached EKS token');
      return _currentToken;
    }

    final creds = await _loadAwsCredentials();
    if (creds == null) {
      dev.log('[kubely-auth] No AWS credentials found for ${cluster.displayName}');
      return null;
    }
    dev.log('[kubely-auth] AWS creds loaded, accessKeyId: ${creds.accessKeyId.substring(0, 4)}...');

    final clusterName = _extractEksClusterName();
    final region = _extractEksRegion();
    dev.log('[kubely-auth] EKS cluster: $clusterName, region: $region');

    final auth = AwsEksAuth(
      accessKeyId: creds.accessKeyId,
      secretAccessKey: creds.secretAccessKey,
      sessionToken: creds.sessionToken,
      clusterName: clusterName,
      region: region,
    );

    _currentToken = auth.generateToken();
    _tokenExpiry = DateTime.now().add(const Duration(seconds: 50));
    dev.log('[kubely-auth] EKS token generated (${_currentToken!.length} chars)');
    return _currentToken;
  }

  Future<String?> _getGkeToken() async {
    if (_currentToken != null &&
        _tokenExpiry != null &&
        DateTime.now().isBefore(_tokenExpiry!)) {
      return _currentToken;
    }

    // Try to load saved token
    final savedToken = await _loadGkeToken();
    if (savedToken != null && !savedToken.isExpired) {
      _currentToken = savedToken.accessToken;
      _tokenExpiry = savedToken.expiresAt;
      return _currentToken;
    }

    // Try refresh
    if (savedToken?.refreshToken != null) {
      try {
        final gcp = GcpDeviceAuth(clientId: _gkeClientId);
        final refreshed =
            await gcp.refreshAccessToken(savedToken!.refreshToken!);
        _currentToken = refreshed.accessToken;
        _tokenExpiry = refreshed.expiresAt;
        await _saveGkeToken(refreshed);
        return _currentToken;
      } catch (_) {
        // Refresh failed — user needs to re-auth
      }
    }

    return null;
  }

  String _extractEksClusterName() {
    // Try to extract from exec args
    final args = cluster.user.exec?.args ?? [];
    for (var i = 0; i < args.length - 1; i++) {
      if (args[i] == '-i' ||
          args[i] == '--cluster-id' ||
          args[i] == '--cluster-name') {
        return args[i + 1];
      }
    }
    // Fallback: extract from ARN (arn:aws:eks:region:account:cluster/NAME)
    final contextName = cluster.context.clusterName;
    if (contextName.contains('/')) {
      return contextName.split('/').last;
    }
    return contextName;
  }

  String _extractEksRegion() {
    final server = cluster.cluster.server;
    final match = RegExp(r'\.(\w+-\w+-\d+)\.eks').firstMatch(server);
    return match?.group(1) ?? 'us-east-1';
  }

  Future<AwsCredentials?> _loadAwsCredentials() async {
    final raw =
        await _storage.read(key: 'aws_creds_${cluster.displayName}');
    if (raw == null) return null;
    return AwsCredentials.fromJson(
        jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> saveAwsCredentials(AwsCredentials creds) async {
    await _storage.write(
      key: 'aws_creds_${cluster.displayName}',
      value: jsonEncode(creds.toJson()),
    );
    _currentToken = null; // force regeneration
  }

  Future<GcpTokenResponse?> _loadGkeToken() async {
    final raw =
        await _storage.read(key: 'gke_token_${cluster.displayName}');
    if (raw == null) return null;
    return GcpTokenResponse.fromJson(
        jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> _saveGkeToken(GcpTokenResponse token) async {
    await _storage.write(
      key: 'gke_token_${cluster.displayName}',
      value: jsonEncode(token.toJson()),
    );
  }

  Future<void> saveGkeToken(GcpTokenResponse token) async {
    _currentToken = token.accessToken;
    _tokenExpiry = token.expiresAt;
    await _saveGkeToken(token);
  }

  // Default GKE OAuth client ID (Google's public CLI client)
  static const _gkeClientId =
      '764086051850-6qr4p6gpi6hn506pt8ejuq83di341hur.apps.googleusercontent.com';

  /// Whether this auth method requires user-provided credentials.
  bool get needsCredentials => method == AuthMethod.eks || method == AuthMethod.gke;

  /// Human-readable auth method description.
  String get methodDescription {
    switch (method) {
      case AuthMethod.token:
        return 'Bearer token';
      case AuthMethod.clientCert:
        return 'Client certificate';
      case AuthMethod.eks:
        return 'AWS IAM (EKS)';
      case AuthMethod.gke:
        return 'Google OAuth (GKE)';
      case AuthMethod.unknown:
        return 'Unknown';
    }
  }
}
