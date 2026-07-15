import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../models/cluster.dart';
import 'kubernetes_api_client.dart';

/// The demo cluster lets anyone evaluate Kubelly without a real Kubernetes
/// cluster — and lets App Review test the app, which would otherwise be
/// impossible (a reviewer has no kubeconfig).
///
/// It is a *visible* feature, reachable from a "Try Demo Cluster" button. It is
/// deliberately not a hidden debug flag: App Store Guideline 2.3.1 prohibits
/// hidden or undocumented functionality.
///
/// Rather than mocking each screen, the demo swaps Dio's transport for
/// [_DemoApiAdapter], which answers Kubernetes API requests from canned
/// fixtures. Every screen therefore works unchanged — pod detail, node list,
/// live log streaming — because they all already talk to the same API client.
const kDemoClusterName = 'demo-cluster';

bool isDemoCluster(String? clusterName) => clusterName == kDemoClusterName;

/// A [SavedCluster] for the demo. The server URL is never dialled — the adapter
/// intercepts every request before it reaches the network.
SavedCluster buildDemoSavedCluster() => const SavedCluster(
      context: KubeContext(
        name: kDemoClusterName,
        clusterName: kDemoClusterName,
        userName: 'demo-user',
        namespace: 'default',
      ),
      cluster: KubeCluster(
        name: kDemoClusterName,
        server: 'https://demo.kubelly.invalid',
      ),
      user: KubeUser(name: 'demo-user', token: 'demo'),
    );

/// An API client backed entirely by fixtures. No network traffic leaves the
/// device — the adapter short-circuits every request.
KubernetesApiClient buildDemoApiClient() {
  final client = KubernetesApiClient(cluster: buildDemoSavedCluster());
  client.dio.httpClientAdapter = _DemoApiAdapter();
  return client;
}

// ─────────────────────────────────────────────────────────────────────────────
// Transport
// ─────────────────────────────────────────────────────────────────────────────

class _DemoApiAdapter implements HttpClientAdapter {
  final _rand = Random(42); // fixed seed → stable, reproducible demo data

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    // A little latency so loading states are exercised rather than skipped.
    await Future<void>.delayed(const Duration(milliseconds: 180));

    final path = options.uri.path;
    final query = options.uri.queryParameters;

    // Log streaming is the one endpoint that returns a byte stream rather than
    // a JSON document.
    final logMatch = RegExp(r'^/api/v1/namespaces/([^/]+)/pods/([^/]+)/log$')
        .firstMatch(path);
    if (logMatch != null) {
      return ResponseBody(
        _logStream(logMatch.group(2)!),
        200,
        headers: {
          Headers.contentTypeHeader: ['text/plain'],
        },
      );
    }

    final body = _route(path, query, options.method);
    if (body == null) {
      return ResponseBody.fromString(
        jsonEncode(_status(404, 'the server could not find the requested resource')),
        404,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }

    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}

  Map<String, dynamic>? _route(
      String path, Map<String, String> query, String method) {
    // Writes (scale, restart, cordon, delete) succeed and echo the object back,
    // so the UI's optimistic flows behave exactly as against a real cluster.
    if (method != 'GET') return {'status': 'Success'};

    if (path == '/version') return _version;
    if (path == '/healthz') return {'status': 'ok'};
    if (path == '/api/v1/namespaces') return _list('NamespaceList', _namespaces());
    if (path == '/api/v1/nodes') return _list('NodeList', _nodes());
    if (path == '/apis/metrics.k8s.io/v1beta1/nodes') {
      return _list('NodeMetricsList', _nodeMetrics());
    }

    // Cluster-wide collections.
    if (path == '/api/v1/pods') return _list('PodList', _pods());
    if (path == '/apis/apps/v1/deployments') {
      return _list('DeploymentList', _deployments());
    }
    if (path == '/api/v1/services') return _list('ServiceList', _services());
    if (path == '/api/v1/events') return _list('EventList', _events());
    if (path == '/api/v1/configmaps') return _list('ConfigMapList', _configMaps());
    if (path == '/api/v1/persistentvolumeclaims') {
      return _list('PersistentVolumeClaimList', _pvcs());
    }
    if (path == '/apis/networking.k8s.io/v1/ingresses') {
      return _list('IngressList', _ingresses());
    }
    if (path == '/api/v1/secrets') {
      final helmOnly = query['labelSelector']?.contains('owner=helm') ?? false;
      return _list('SecretList', helmOnly ? _helmSecrets() : _secrets());
    }

    // Namespaced collections and single objects.
    final ns = RegExp(r'^/api/v1/namespaces/([^/]+)/([^/]+)(?:/([^/]+))?$')
        .firstMatch(path);
    if (ns != null) {
      final namespace = ns.group(1)!;
      final kind = ns.group(2)!;
      final name = ns.group(3);
      switch (kind) {
        case 'pods':
          final pods = _inNamespace(_pods(), namespace);
          if (name != null) return _byName(pods, name);
          return _list('PodList', pods);
        case 'services':
          return _list('ServiceList', _inNamespace(_services(), namespace));
        case 'events':
          return _list('EventList', _inNamespace(_events(), namespace));
        case 'configmaps':
          final cms = _inNamespace(_configMaps(), namespace);
          if (name != null) return _byName(cms, name);
          return _list('ConfigMapList', cms);
        case 'persistentvolumeclaims':
          return _list(
              'PersistentVolumeClaimList', _inNamespace(_pvcs(), namespace));
        case 'secrets':
          final helmOnly = query['labelSelector']?.contains('owner=helm') ?? false;
          return _list('SecretList',
              _inNamespace(helmOnly ? _helmSecrets() : _secrets(), namespace));
      }
    }

    final apps = RegExp(
            r'^/apis/apps/v1/namespaces/([^/]+)/deployments(?:/([^/]+))?(?:/scale)?$')
        .firstMatch(path);
    if (apps != null) {
      final deploys = _inNamespace(_deployments(), apps.group(1)!);
      final name = apps.group(2);
      if (name != null) return _byName(deploys, name);
      return _list('DeploymentList', deploys);
    }

    final ing = RegExp(
            r'^/apis/networking\.k8s\.io/v1/namespaces/([^/]+)/ingresses$')
        .firstMatch(path);
    if (ing != null) {
      return _list('IngressList', _inNamespace(_ingresses(), ing.group(1)!));
    }

    final podMetrics = RegExp(
            r'^/apis/metrics\.k8s\.io/v1beta1/namespaces/([^/]+)/pods$')
        .firstMatch(path);
    if (podMetrics != null) {
      return _list('PodMetricsList',
          _inNamespace(_podMetrics(), podMetrics.group(1)!));
    }

    return null;
  }

  /// Emits a burst of recent lines, then keeps trickling so the log viewer
  /// demonstrably streams rather than just rendering a static blob.
  Stream<Uint8List> _logStream(String pod) async* {
    final paths = ['/api/v1/products', '/api/v1/cart', '/healthz', '/api/v1/orders'];
    var seq = 1;

    final backlog = StringBuffer();
    for (var i = 0; i < 60; i++) {
      backlog.writeln(_logLine(pod, paths[_rand.nextInt(paths.length)], seq++));
    }
    yield Uint8List.fromList(utf8.encode(backlog.toString()));

    while (true) {
      await Future<void>.delayed(const Duration(milliseconds: 900));
      final line =
          '${_logLine(pod, paths[_rand.nextInt(paths.length)], seq++)}\n';
      yield Uint8List.fromList(utf8.encode(line));
    }
  }

  String _logLine(String pod, String path, int seq) {
    final ts = DateTime.now().toUtc().toIso8601String();
    // Roughly one in eight lines is a warning, so the viewer's severity styling
    // has something to render.
    if (seq % 8 == 0) {
      return '$ts level=warn msg="upstream slow" path=$path '
          'duration_ms=${600 + _rand.nextInt(400)} pod=$pod';
    }
    return '$ts level=info msg="request handled" path=$path status=200 '
        'duration_ms=${10 + _rand.nextInt(90)} seq=$seq';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

Map<String, dynamic> _list(String kind, List<Map<String, dynamic>> items) => {
      'kind': kind,
      'apiVersion': 'v1',
      'metadata': {'resourceVersion': '1'},
      'items': items,
    };

Map<String, dynamic> _status(int code, String message) => {
      'kind': 'Status',
      'apiVersion': 'v1',
      'status': 'Failure',
      'message': message,
      'code': code,
    };

List<Map<String, dynamic>> _inNamespace(
    List<Map<String, dynamic>> items, String namespace) {
  if (namespace == 'all' || namespace.isEmpty) return items;
  return items
      .where((i) => (i['metadata'] as Map)['namespace'] == namespace)
      .toList();
}

Map<String, dynamic>? _byName(List<Map<String, dynamic>> items, String name) {
  for (final i in items) {
    if ((i['metadata'] as Map)['name'] == name) return i;
  }
  return null;
}

String _ago(Duration d) =>
    DateTime.now().toUtc().subtract(d).toIso8601String().split('.').first + 'Z';

Map<String, dynamic> _meta(
  String name,
  String namespace, {
  Duration age = const Duration(hours: 6),
  Map<String, String>? labels,
}) =>
    {
      'name': name,
      'namespace': namespace,
      'uid': 'demo-$namespace-$name',
      'creationTimestamp': _ago(age),
      if (labels != null) 'labels': labels,
    };

const _version = {
  'major': '1',
  'minor': '31',
  'gitVersion': 'v1.31.4',
  'platform': 'linux/arm64',
};

// ─────────────────────────────────────────────────────────────────────────────
// Fixtures
// ─────────────────────────────────────────────────────────────────────────────

List<Map<String, dynamic>> _namespaces() => [
      for (final n in ['default', 'infra', 'data', 'kube-system'])
        {
          'metadata': _meta(n, '', age: const Duration(days: 40)),
          'status': {'phase': 'Active'},
        }
    ];

List<Map<String, dynamic>> _nodes() {
  Map<String, dynamic> node(String name, String zone, bool ready,
      {String cpu = '4', String mem = '16311764Ki'}) {
    return {
      'metadata': _meta(name, '',
          age: const Duration(days: 40),
          labels: {
            'topology.kubernetes.io/zone': zone,
            'node.kubernetes.io/instance-type': 'm6g.xlarge',
          }),
      'spec': {'unschedulable': false},
      'status': {
        'capacity': {'cpu': cpu, 'memory': mem, 'pods': '58'},
        'allocatable': {'cpu': cpu, 'memory': mem, 'pods': '58'},
        'conditions': [
          {
            'type': 'Ready',
            'status': ready ? 'True' : 'False',
            'reason': ready ? 'KubeletReady' : 'KubeletNotReady',
            'lastTransitionTime': _ago(const Duration(days: 12)),
          }
        ],
        'nodeInfo': {
          'kubeletVersion': 'v1.31.4',
          'osImage': 'Amazon Linux 2023',
          'architecture': 'arm64',
          'containerRuntimeVersion': 'containerd://1.7.22',
        },
        'addresses': [
          {'type': 'InternalIP', 'address': '10.0.${name.hashCode % 5 + 1}.20'},
          {'type': 'Hostname', 'address': name},
        ],
      },
    };
  }

  return [
    node('ip-10-0-1-23', 'us-east-1a', true),
    node('ip-10-0-2-47', 'us-east-1b', true),
    node('ip-10-0-3-88', 'us-east-1c', true),
  ];
}

List<Map<String, dynamic>> _nodeMetrics() => [
      {
        'metadata': _meta('ip-10-0-1-23', ''),
        'usage': {'cpu': '1240m', 'memory': '6242304Ki'},
      },
      {
        'metadata': _meta('ip-10-0-2-47', ''),
        'usage': {'cpu': '2980m', 'memory': '11534336Ki'},
      },
      {
        'metadata': _meta('ip-10-0-3-88', ''),
        'usage': {'cpu': '640m', 'memory': '3145728Ki'},
      },
    ];

/// A pod in a realistic shape: running, pending, or crash-looping. The unhealthy
/// ones matter — they give the health dashboard, alerts and events something
/// meaningful to show instead of an all-green screen.
Map<String, dynamic> _pod(
  String name,
  String namespace,
  String phase, {
  int restarts = 0,
  String node = 'ip-10-0-1-23',
  Duration age = const Duration(hours: 9),
  String? waitingReason,
  String app = 'app',
  String image = 'registry.k8s.io/demo:1.4.2',
}) {
  final running = phase == 'Running';
  return {
    'metadata': _meta(name, namespace, age: age, labels: {'app': app}),
    'spec': {
      'nodeName': node,
      'containers': [
        {
          'name': app,
          'image': image,
          'resources': {
            'requests': {'cpu': '100m', 'memory': '128Mi'},
            'limits': {'cpu': '500m', 'memory': '512Mi'},
          },
          'ports': [
            {'containerPort': 8080, 'protocol': 'TCP'}
          ],
        }
      ],
    },
    'status': {
      'phase': phase,
      'podIP': '10.244.${namespace.length}.${name.hashCode.abs() % 250 + 1}',
      'hostIP': '10.0.1.20',
      'startTime': _ago(age),
      'conditions': [
        {
          'type': 'Ready',
          'status': running ? 'True' : 'False',
          'lastTransitionTime': _ago(age),
        }
      ],
      'containerStatuses': [
        {
          'name': app,
          'image': image,
          'ready': running,
          'restartCount': restarts,
          'started': running,
          'state': running
              ? {
                  'running': {'startedAt': _ago(age)}
                }
              : {
                  'waiting': {
                    'reason': waitingReason ?? 'ContainerCreating',
                    'message': waitingReason == 'CrashLoopBackOff'
                        ? 'back-off 5m0s restarting failed container'
                        : 'waiting to start',
                  }
                },
        }
      ],
    },
  };
}

List<Map<String, dynamic>> _pods() => [
      _pod('checkout-6f8b4c9d7-2xk4p', 'default', 'Running', app: 'checkout'),
      _pod('checkout-6f8b4c9d7-9mzqr', 'default', 'Running', app: 'checkout',
          node: 'ip-10-0-2-47'),
      _pod('checkout-6f8b4c9d7-fk8wt', 'default', 'Running', app: 'checkout',
          node: 'ip-10-0-3-88'),
      _pod('web-7c4d8f6b2-lm3np', 'default', 'Running', app: 'web'),
      _pod('web-7c4d8f6b2-qr7vd', 'default', 'Running', app: 'web',
          node: 'ip-10-0-2-47'),
      _pod('payments-5b9c7d4f8-t2kx9', 'default', 'Running',
          app: 'payments', restarts: 2, node: 'ip-10-0-3-88'),
      _pod('api-gateway-7d9f4c8b6-hx4mq', 'infra', 'Running',
          app: 'api-gateway'),
      _pod('api-gateway-7d9f4c8b6-vn8zt', 'infra', 'CrashLoopBackOff',
          app: 'api-gateway',
          restarts: 14,
          waitingReason: 'CrashLoopBackOff',
          node: 'ip-10-0-2-47',
          age: const Duration(minutes: 42)),
      _pod('cache-redis-0', 'infra', 'Running', app: 'redis',
          image: 'redis:7.2-alpine', age: const Duration(days: 6)),
      _pod('search-indexer-8c6d5b3a9-w4rjc', 'data', 'Running',
          app: 'search-indexer', node: 'ip-10-0-3-88'),
      _pod('search-indexer-8c6d5b3a9-zp6lh', 'data', 'Running',
          app: 'search-indexer'),
      _pod('worker-batch-2b1c7f9e4-d8gks', 'data', 'Pending',
          app: 'worker-batch',
          waitingReason: 'Unschedulable',
          age: const Duration(minutes: 3)),
      _pod('coredns-5d78c9869d-4tbxn', 'kube-system', 'Running',
          app: 'coredns',
          image: 'registry.k8s.io/coredns:1.11.3',
          age: const Duration(days: 40)),
    ];

List<Map<String, dynamic>> _podMetrics() => [
      for (final p in _pods())
        {
          'metadata': _meta(
              (p['metadata'] as Map)['name'] as String,
              (p['metadata'] as Map)['namespace'] as String),
          'containers': [
            {
              'name': 'app',
              'usage': {
                'cpu': '${40 + (p['metadata'] as Map)['name'].hashCode.abs() % 200}m',
                'memory': '${80 + (p['metadata'] as Map)['name'].hashCode.abs() % 300}Mi',
              },
            }
          ],
        }
    ];

Map<String, dynamic> _deployment(
    String name, String namespace, int ready, int desired,
    {String image = 'registry.k8s.io/demo:1.4.2'}) {
  return {
    'metadata': _meta(name, namespace,
        age: const Duration(days: 9), labels: {'app': name}),
    'spec': {
      'replicas': desired,
      'selector': {
        'matchLabels': {'app': name}
      },
      'template': {
        'metadata': {
          'labels': {'app': name}
        },
        'spec': {
          'containers': [
            {'name': name, 'image': image}
          ]
        },
      },
    },
    'status': {
      'replicas': desired,
      'readyReplicas': ready,
      'availableReplicas': ready,
      'updatedReplicas': desired,
      'conditions': [
        {
          'type': 'Available',
          'status': ready >= desired ? 'True' : 'False',
          'reason': ready >= desired ? 'MinimumReplicasAvailable' : 'MinimumReplicasUnavailable',
          'lastTransitionTime': _ago(const Duration(hours: 3)),
        }
      ],
    },
  };
}

List<Map<String, dynamic>> _deployments() => [
      _deployment('checkout', 'default', 3, 3, image: 'demo/checkout:1.18.2'),
      _deployment('web', 'default', 2, 2, image: 'demo/web:3.2.0'),
      _deployment('payments', 'default', 1, 1, image: 'demo/payments:0.9.4'),
      _deployment('api-gateway', 'infra', 1, 2, image: 'demo/gateway:2.1.0'),
      _deployment('search-indexer', 'data', 2, 2, image: 'demo/indexer:4.0.1'),
      _deployment('worker-batch', 'data', 0, 1, image: 'demo/worker:1.0.0'),
    ];

Map<String, dynamic> _service(
    String name, String namespace, String type, String clusterIp, int port) {
  return {
    'metadata': _meta(name, namespace, age: const Duration(days: 9)),
    'spec': {
      'type': type,
      'clusterIP': clusterIp,
      'selector': {'app': name},
      'ports': [
        {
          'name': 'http',
          'port': port,
          'targetPort': 8080,
          'protocol': 'TCP',
        }
      ],
    },
    'status': type == 'LoadBalancer'
        ? {
            'loadBalancer': {
              'ingress': [
                {'hostname': 'a1b2c3-demo.elb.us-east-1.amazonaws.com'}
              ]
            }
          }
        : {'loadBalancer': <String, dynamic>{}},
  };
}

List<Map<String, dynamic>> _services() => [
      _service('checkout', 'default', 'ClusterIP', '10.96.42.15', 8080),
      _service('web', 'default', 'LoadBalancer', '10.96.1.200', 443),
      _service('payments', 'default', 'ClusterIP', '10.96.17.9', 8080),
      _service('api-gateway', 'infra', 'LoadBalancer', '10.96.1.201', 443),
      _service('cache-redis', 'infra', 'ClusterIP', '10.96.88.3', 6379),
      _service('search-indexer', 'data', 'ClusterIP', '10.96.55.7', 9200),
    ];

List<Map<String, dynamic>> _events() {
  Map<String, dynamic> event(String type, String reason, String obj,
      String message, String namespace, Duration age) {
    return {
      'metadata': _meta('$obj.${reason.toLowerCase()}', namespace, age: age),
      'type': type,
      'reason': reason,
      'message': message,
      'count': type == 'Warning' ? 6 : 1,
      'lastTimestamp': _ago(age),
      'firstTimestamp': _ago(age),
      'involvedObject': {
        'kind': 'Pod',
        'name': obj,
        'namespace': namespace,
      },
    };
  }

  return [
    event('Warning', 'BackOff', 'api-gateway-7d9f4c8b6-vn8zt',
        'Back-off restarting failed container gateway', 'infra',
        const Duration(minutes: 4)),
    event('Warning', 'FailedScheduling', 'worker-batch-2b1c7f9e4-d8gks',
        '0/3 nodes are available: insufficient cpu.', 'data',
        const Duration(minutes: 3)),
    event('Normal', 'Pulled', 'checkout-6f8b4c9d7-2xk4p',
        'Successfully pulled image "demo/checkout:1.18.2"', 'default',
        const Duration(minutes: 14)),
    event('Normal', 'Scaled', 'checkout', 'Scaled up replica set to 3',
        'default', const Duration(minutes: 18)),
    event('Normal', 'Started', 'web-7c4d8f6b2-lm3np', 'Started container web',
        'default', const Duration(minutes: 26)),
    event('Normal', 'Created', 'cache-redis-0', 'Created container redis',
        'infra', const Duration(hours: 2)),
  ];
}

List<Map<String, dynamic>> _pvcs() {
  Map<String, dynamic> pvc(String name, String namespace, String size,
      {String phase = 'Bound', String storageClass = 'gp3'}) {
    return {
      'metadata': _meta(name, namespace, age: const Duration(days: 9)),
      'spec': {
        'accessModes': ['ReadWriteOnce'],
        'storageClassName': storageClass,
        'volumeName': 'pvc-${name.hashCode.abs()}',
        'resources': {
          'requests': {'storage': size}
        },
      },
      'status': {
        'phase': phase,
        'accessModes': ['ReadWriteOnce'],
        'capacity': {'storage': size},
      },
    };
  }

  return [
    pvc('redis-data', 'infra', '8Gi'),
    pvc('search-index', 'data', '50Gi'),
    pvc('checkout-assets', 'default', '1Gi'),
    pvc('worker-scratch', 'data', '20Gi', phase: 'Pending'),
  ];
}

List<Map<String, dynamic>> _configMaps() {
  Map<String, dynamic> cm(
          String name, String namespace, Map<String, String> data) =>
      {
        'metadata': _meta(name, namespace, age: const Duration(days: 9)),
        'data': data,
      };

  return [
    cm('checkout-config', 'default', {
      'LOG_LEVEL': 'info',
      'FEATURE_CHECKOUT_V2': 'true',
      'UPSTREAM_TIMEOUT': '30s',
    }),
    cm('web-config', 'default', {
      'API_BASE_URL': 'https://api.demo.internal',
      'CDN_HOST': 'cdn.demo.internal',
    }),
    cm('gateway-routes', 'infra', {
      'routes.yaml':
          'routes:\n  - path: /api/v1/checkout\n    upstream: checkout:8080\n  - path: /api/v1/payments\n    upstream: payments:8080\n',
    }),
    cm('indexer-settings', 'data', {
      'BATCH_SIZE': '500',
      'SHARDS': '4',
    }),
  ];
}

List<Map<String, dynamic>> _secrets() => [
      {
        'metadata': _meta('checkout-tls', 'default', age: const Duration(days: 9)),
        'type': 'kubernetes.io/tls',
        'data': <String, String>{},
      },
    ];

/// Helm stores each release revision as a Secret labelled `owner=helm`. The list
/// screen reads the labels, so only those need to be faithful.
List<Map<String, dynamic>> _helmSecrets() {
  Map<String, dynamic> rel(String name, String namespace, String chart,
      int version, String status) {
    return {
      'metadata': _meta(
        'sh.helm.release.v1.$name.v$version',
        namespace,
        age: Duration(days: 9 - version),
        labels: {
          'owner': 'helm',
          'name': name,
          'version': '$version',
          'status': status,
          'chart': chart,
        },
      ),
      'type': 'helm.sh/release.v1',
      'data': <String, String>{},
    };
  }

  return [
    rel('checkout', 'default', 'checkout-1.18.2', 1, 'superseded'),
    rel('checkout', 'default', 'checkout-1.18.2', 2, 'deployed'),
    rel('web', 'default', 'web-3.2.0', 1, 'deployed'),
    rel('redis', 'infra', 'redis-19.6.4', 1, 'superseded'),
    rel('redis', 'infra', 'redis-20.1.0', 2, 'deployed'),
    rel('ingress-nginx', 'infra', 'ingress-nginx-4.11.3', 1, 'deployed'),
  ];
}

List<Map<String, dynamic>> _ingresses() => [
      {
        'metadata': _meta('web', 'default', age: const Duration(days: 9)),
        'spec': {
          'ingressClassName': 'nginx',
          'rules': [
            {
              'host': 'shop.demo.internal',
              'http': {
                'paths': [
                  {
                    'path': '/',
                    'pathType': 'Prefix',
                    'backend': {
                      'service': {
                        'name': 'web',
                        'port': {'number': 443}
                      }
                    },
                  }
                ]
              },
            }
          ],
        },
        'status': {
          'loadBalancer': {
            'ingress': [
              {'hostname': 'a1b2c3-demo.elb.us-east-1.amazonaws.com'}
            ]
          }
        },
      },
      {
        'metadata': _meta('api-gateway', 'infra', age: const Duration(days: 9)),
        'spec': {
          'ingressClassName': 'nginx',
          'rules': [
            {
              'host': 'api.demo.internal',
              'http': {
                'paths': [
                  {
                    'path': '/api',
                    'pathType': 'Prefix',
                    'backend': {
                      'service': {
                        'name': 'api-gateway',
                        'port': {'number': 443}
                      }
                    },
                  }
                ]
              },
            }
          ],
        },
        'status': {
          'loadBalancer': {'ingress': <Map<String, dynamic>>[]}
        },
      },
    ];
