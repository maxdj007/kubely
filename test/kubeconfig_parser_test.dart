import 'package:flutter_test/flutter_test.dart';
import 'package:kubely/data/repositories/kubeconfig_parser.dart';

const _sampleYaml = '''
apiVersion: v1
kind: Config
clusters:
- cluster:
    server: https://A1B2C3.gr7.us-east-1.eks.amazonaws.com
    certificate-authority-data: dGVzdA==
  name: prod-eks
- cluster:
    server: https://34.120.0.1
    insecure-skip-tls-verify: true
  name: staging-gke
contexts:
- context:
    cluster: prod-eks
    user: admin
    namespace: production
  name: prod-context
- context:
    cluster: staging-gke
    user: dev
  name: staging-context
users:
- name: admin
  user:
    token: my-secret-token
- name: dev
  user:
    client-certificate-data: Y2VydA==
    client-key-data: a2V5
current-context: prod-context
''';

void main() {
  group('KubeconfigParser', () {
    late KubeconfigResult result;

    setUpAll(() {
      result = KubeconfigParser.parse(_sampleYaml);
    });

    test('parses clusters', () {
      expect(result.clusters.length, 2);
      expect(result.clusters[0].name, 'prod-eks');
      expect(result.clusters[0].server,
          'https://A1B2C3.gr7.us-east-1.eks.amazonaws.com');
      expect(result.clusters[0].certificateAuthorityData, 'dGVzdA==');
      expect(result.clusters[0].insecureSkipTlsVerify, false);
      expect(result.clusters[1].name, 'staging-gke');
      expect(result.clusters[1].insecureSkipTlsVerify, true);
    });

    test('parses users', () {
      expect(result.users.length, 2);
      expect(result.users[0].name, 'admin');
      expect(result.users[0].token, 'my-secret-token');
      expect(result.users[1].name, 'dev');
      expect(result.users[1].clientCertificateData, 'Y2VydA==');
      expect(result.users[1].clientKeyData, 'a2V5');
    });

    test('parses contexts', () {
      expect(result.contexts.length, 2);
      expect(result.contexts[0].name, 'prod-context');
      expect(result.contexts[0].clusterName, 'prod-eks');
      expect(result.contexts[0].userName, 'admin');
      expect(result.contexts[0].namespace, 'production');
      expect(result.contexts[1].name, 'staging-context');
      expect(result.contexts[1].namespace, isNull);
    });

    test('parses current-context', () {
      expect(result.currentContext, 'prod-context');
    });

    test('buildSavedCluster returns valid cluster', () {
      final saved =
          KubeconfigParser.buildSavedCluster(result, result.contexts[0]);
      expect(saved, isNotNull);
      expect(saved!.displayName, 'prod-context');
      expect(saved.server, 'https://A1B2C3.gr7.us-east-1.eks.amazonaws.com');
      expect(saved.providerLabel, 'EKS');
    });

    test('buildSavedCluster returns null for missing cluster', () {
      final fakeContext = result.contexts[0];
      final badResult = KubeconfigResult(
        clusters: [],
        users: result.users,
        contexts: [fakeContext],
      );
      final saved = KubeconfigParser.buildSavedCluster(badResult, fakeContext);
      expect(saved, isNull);
    });

    test('throws on invalid YAML', () {
      expect(
          () => KubeconfigParser.parse('not: [valid: kubeconfig'),
          throwsA(anything));
    });

    test('handles empty clusters list', () {
      final empty = KubeconfigParser.parse('''
apiVersion: v1
kind: Config
clusters: []
contexts: []
users: []
''');
      expect(empty.clusters, isEmpty);
      expect(empty.contexts, isEmpty);
      expect(empty.users, isEmpty);
    });
  });
}
