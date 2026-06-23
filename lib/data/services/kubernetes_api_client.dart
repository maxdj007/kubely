import 'package:dio/dio.dart';
import '../models/cluster.dart';

class KubernetesApiClient {
  KubernetesApiClient({required this.cluster}) {
    _dio = Dio(BaseOptions(
      baseUrl: cluster.cluster.server,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      headers: _buildAuthHeaders(),
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onError: (error, handler) {
        final code = error.response?.statusCode;
        if (code != null) {
          String? hint;
          switch (code) {
            case 401:
              hint = 'Unauthorized — token may have expired';
            case 403:
              hint = 'Forbidden — check RBAC permissions';
            case 404:
              hint = 'Not found — resource may have been deleted';
            case 409:
              hint = 'Conflict — resource was modified by another client';
            case 422:
              hint = 'Invalid request — check resource spec';
            case 429:
              hint = 'Rate limited — try again shortly';
            case 503:
              hint = 'Service unavailable — API server may be overloaded';
          }
          if (hint != null) {
            handler.next(DioException(
              requestOptions: error.requestOptions,
              response: error.response,
              type: error.type,
              error: hint,
            ));
            return;
          }
        }
        handler.next(error);
      },
    ));
  }

  final SavedCluster cluster;
  late final Dio _dio;
  Dio get dio => _dio;

  Map<String, String> _buildAuthHeaders() {
    final headers = <String, String>{
      'Accept': 'application/json',
    };
    if (cluster.user.token != null) {
      headers['Authorization'] = 'Bearer ${cluster.user.token}';
    }
    return headers;
  }

  // ── Health / Version ──

  Future<Map<String, dynamic>> getVersion() async {
    final response = await _dio.get('/version');
    return response.data as Map<String, dynamic>;
  }

  Future<bool> checkHealth() async {
    try {
      final response = await _dio.get('/healthz');
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ── Namespaces ──

  Future<List<String>> getNamespaces() async {
    final response = await _dio.get('/api/v1/namespaces');
    final items = (response.data['items'] as List<dynamic>?) ?? [];
    return items
        .map((ns) => ns['metadata']['name'] as String)
        .toList()
      ..sort();
  }

  // ── Pods ──

  Future<List<Map<String, dynamic>>> getPods(String namespace) async {
    final response =
        await _dio.get('/api/v1/namespaces/$namespace/pods');
    return List<Map<String, dynamic>>.from(
        (response.data['items'] as List<dynamic>?) ?? []);
  }

  Future<Map<String, dynamic>> getPod(
      String namespace, String name) async {
    final response =
        await _dio.get('/api/v1/namespaces/$namespace/pods/$name');
    return response.data as Map<String, dynamic>;
  }

  Future<void> deletePod(String namespace, String name) async {
    await _dio.delete('/api/v1/namespaces/$namespace/pods/$name');
  }

  // ── Deployments ──

  Future<List<Map<String, dynamic>>> getDeployments(
      String namespace) async {
    final response =
        await _dio.get('/apis/apps/v1/namespaces/$namespace/deployments');
    return List<Map<String, dynamic>>.from(
        (response.data['items'] as List<dynamic>?) ?? []);
  }

  Future<void> scaleDeployment(
      String namespace, String name, int replicas) async {
    await _dio.patch(
      '/apis/apps/v1/namespaces/$namespace/deployments/$name/scale',
      data: {
        'spec': {'replicas': replicas},
      },
      options: Options(contentType: 'application/merge-patch+json'),
    );
  }

  Future<void> restartDeployment(String namespace, String name) async {
    await _dio.patch(
      '/apis/apps/v1/namespaces/$namespace/deployments/$name',
      data: {
        'spec': {
          'template': {
            'metadata': {
              'annotations': {
                'kubectl.kubernetes.io/restartedAt':
                    DateTime.now().toUtc().toIso8601String(),
              },
            },
          },
        },
      },
      options: Options(contentType: 'application/strategic-merge-patch+json'),
    );
  }

  // ── Services ──

  Future<List<Map<String, dynamic>>> getServices(
      String namespace) async {
    final response =
        await _dio.get('/api/v1/namespaces/$namespace/services');
    return List<Map<String, dynamic>>.from(
        (response.data['items'] as List<dynamic>?) ?? []);
  }

  // ── Nodes ──

  Future<List<Map<String, dynamic>>> getNodes() async {
    final response = await _dio.get('/api/v1/nodes');
    return List<Map<String, dynamic>>.from(
        (response.data['items'] as List<dynamic>?) ?? []);
  }

  Future<void> cordonNode(String name) async {
    await _dio.patch(
      '/api/v1/nodes/$name',
      data: {
        'spec': {'unschedulable': true},
      },
      options: Options(contentType: 'application/merge-patch+json'),
    );
  }

  Future<void> uncordonNode(String name) async {
    await _dio.patch(
      '/api/v1/nodes/$name',
      data: {
        'spec': {'unschedulable': false},
      },
      options: Options(contentType: 'application/merge-patch+json'),
    );
  }

  // ── Events ──

  Future<List<Map<String, dynamic>>> getEvents(String namespace) async {
    final response =
        await _dio.get('/api/v1/namespaces/$namespace/events');
    return List<Map<String, dynamic>>.from(
        (response.data['items'] as List<dynamic>?) ?? []);
  }

  // ── PVCs ──

  Future<List<Map<String, dynamic>>> getPVCs(String namespace) async {
    final response = await _dio
        .get('/api/v1/namespaces/$namespace/persistentvolumeclaims');
    return List<Map<String, dynamic>>.from(
        (response.data['items'] as List<dynamic>?) ?? []);
  }

  // ── Helm Releases (stored as secrets) ──

  Future<List<Map<String, dynamic>>> getHelmSecrets(
      {String? namespace}) async {
    final path = namespace != null && namespace != 'all'
        ? '/api/v1/namespaces/$namespace/secrets'
        : '/api/v1/secrets';
    final response = await _dio.get(path,
        queryParameters: {'labelSelector': 'owner=helm'});
    return List<Map<String, dynamic>>.from(
        (response.data['items'] as List<dynamic>?) ?? []);
  }

  // ── Metrics ──

  Future<List<Map<String, dynamic>>> getNodeMetrics() async {
    final response =
        await _dio.get('/apis/metrics.k8s.io/v1beta1/nodes');
    return List<Map<String, dynamic>>.from(
        (response.data['items'] as List<dynamic>?) ?? []);
  }

  Future<List<Map<String, dynamic>>> getPodMetrics(
      String namespace) async {
    final response = await _dio
        .get('/apis/metrics.k8s.io/v1beta1/namespaces/$namespace/pods');
    return List<Map<String, dynamic>>.from(
        (response.data['items'] as List<dynamic>?) ?? []);
  }

  // ── ConfigMaps ──

  Future<List<Map<String, dynamic>>> getConfigMaps(
      String namespace) async {
    final response =
        await _dio.get('/api/v1/namespaces/$namespace/configmaps');
    return List<Map<String, dynamic>>.from(
        (response.data['items'] as List<dynamic>?) ?? []);
  }

  Future<void> updateConfigMap(
      String namespace, String name, Map<String, String> data) async {
    await _dio.patch(
      '/api/v1/namespaces/$namespace/configmaps/$name',
      data: {'data': data},
      options: Options(contentType: 'application/merge-patch+json'),
    );
  }

  // ── Ingresses ──

  Future<List<Map<String, dynamic>>> getIngresses(
      String namespace) async {
    final response = await _dio
        .get('/apis/networking.k8s.io/v1/namespaces/$namespace/ingresses');
    return List<Map<String, dynamic>>.from(
        (response.data['items'] as List<dynamic>?) ?? []);
  }

  void dispose() {
    _dio.close();
  }
}
