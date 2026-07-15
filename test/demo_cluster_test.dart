import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kubely/data/services/demo_cluster.dart';

/// The demo cluster is what App Review uses to evaluate the app, so every screen
/// it can reach must return data. These tests drive the fake transport directly.
void main() {
  late Dio dio;

  setUp(() => dio = buildDemoApiClient().dio);

  Future<List<dynamic>> items(String path,
      {Map<String, dynamic>? query}) async {
    final resp = await dio.get(path, queryParameters: query);
    return (resp.data['items'] as List<dynamic>?) ?? [];
  }

  test('identifies the demo cluster by name', () {
    expect(isDemoCluster(kDemoClusterName), isTrue);
    expect(isDemoCluster('prod-eks-use1'), isFalse);
    expect(isDemoCluster(null), isFalse);
  });

  test('every list endpoint the app calls returns data', () async {
    expect(await items('/api/v1/namespaces'), isNotEmpty);
    expect(await items('/api/v1/nodes'), isNotEmpty);
    expect(await items('/api/v1/pods'), isNotEmpty);
    expect(await items('/apis/apps/v1/deployments'), isNotEmpty);
    expect(await items('/api/v1/services'), isNotEmpty);
    expect(await items('/api/v1/events'), isNotEmpty);
    expect(await items('/api/v1/configmaps'), isNotEmpty);
    expect(await items('/api/v1/persistentvolumeclaims'), isNotEmpty);
    expect(await items('/apis/networking.k8s.io/v1/ingresses'), isNotEmpty);
    expect(await items('/apis/metrics.k8s.io/v1beta1/nodes'), isNotEmpty);
  });

  test('namespaced endpoints filter by namespace', () async {
    final defaultPods = await items('/api/v1/namespaces/default/pods');
    expect(defaultPods, isNotEmpty);
    expect(
      defaultPods.every((p) => p['metadata']['namespace'] == 'default'),
      isTrue,
      reason: 'namespace filter leaked pods from other namespaces',
    );

    expect(await items('/api/v1/namespaces/infra/pods'), isNotEmpty);
    expect(await items('/apis/apps/v1/namespaces/default/deployments'),
        isNotEmpty);
    expect(await items('/api/v1/namespaces/default/services'), isNotEmpty);
    expect(await items('/api/v1/namespaces/default/configmaps'), isNotEmpty);
    expect(await items('/api/v1/namespaces/infra/persistentvolumeclaims'),
        isNotEmpty);
    expect(await items('/api/v1/namespaces/data/events'), isNotEmpty);
    expect(
        await items('/apis/metrics.k8s.io/v1beta1/namespaces/default/pods'),
        isNotEmpty);
  });

  // Tapping a pod is the flow most likely to dead-end, so assert it resolves.
  test('pod detail resolves for a pod from the list', () async {
    final pods = await items('/api/v1/namespaces/default/pods');
    final name = pods.first['metadata']['name'] as String;

    final resp = await dio.get('/api/v1/namespaces/default/pods/$name');
    expect(resp.data['metadata']['name'], name);
    expect(resp.data['spec']['containers'], isNotEmpty);
    expect(resp.data['status']['containerStatuses'], isNotEmpty);
  });

  test('deployment detail resolves', () async {
    final resp =
        await dio.get('/apis/apps/v1/namespaces/default/deployments/checkout');
    expect(resp.data['metadata']['name'], 'checkout');
    expect(resp.data['spec']['replicas'], isA<int>());
  });

  test('helm releases are labelled so the Helm screen can read them', () async {
    final secrets = await items('/api/v1/secrets',
        query: {'labelSelector': 'owner=helm'});
    expect(secrets, isNotEmpty);

    final labels = secrets.first['metadata']['labels'] as Map;
    // helmReleaseListProvider reads name/chart/version/status off the labels.
    expect(labels['owner'], 'helm');
    expect(labels['name'], isNotNull);
    expect(labels['chart'], isNotNull);
    expect(labels['version'], isNotNull);
    expect(labels['status'], isNotNull);
  });

  test('unhealthy pods exist so health, alerts and events are not all-green',
      () async {
    final pods = await items('/api/v1/pods');
    final phases = pods.map((p) => p['status']['phase']).toSet();
    expect(phases, contains('Running'));
    expect(phases.any((p) => p != 'Running'), isTrue,
        reason: 'demo cluster should show at least one unhealthy pod');

    final events = await items('/api/v1/events');
    expect(events.any((e) => e['type'] == 'Warning'), isTrue);
  });

  test('writes (scale, cordon, delete) succeed rather than erroring', () async {
    final scale = await dio.patch(
      '/apis/apps/v1/namespaces/default/deployments/checkout/scale',
      data: {
        'spec': {'replicas': 5}
      },
    );
    expect(scale.statusCode, 200);

    final del =
        await dio.delete('/api/v1/namespaces/default/pods/web-7c4d8f6b2-lm3np');
    expect(del.statusCode, 200);
  });

  test('log endpoint streams lines', () async {
    final resp = await dio.get<ResponseBody>(
      '/api/v1/namespaces/default/pods/web-7c4d8f6b2-lm3np/log',
      options: Options(responseType: ResponseType.stream),
    );

    final chunk = await resp.data!.stream.first.timeout(
      const Duration(seconds: 5),
    );
    final text = String.fromCharCodes(chunk);

    expect(text, contains('level='));
    expect(text.split('\n').where((l) => l.isNotEmpty).length, greaterThan(1),
        reason: 'log viewer expects a backlog of lines');
  });

  test('unknown paths return 404 rather than hanging', () async {
    await expectLater(
      dio.get('/apis/does.not/v1/nonsense'),
      throwsA(isA<DioException>()),
    );
  });
}
