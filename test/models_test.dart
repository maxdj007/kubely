import 'package:flutter_test/flutter_test.dart';
import 'package:kubely/data/models/cluster.dart';
import 'package:kubely/data/models/pod.dart';
import 'package:kubely/data/models/deployment.dart';

void main() {
  group('KubeCluster', () {
    test('serializes to JSON', () {
      const cluster = KubeCluster(
        name: 'test',
        server: 'https://example.com',
        certificateAuthorityData: 'abc123',
      );
      final json = cluster.toJson();
      expect(json['name'], 'test');
      expect(json['server'], 'https://example.com');
      expect(json['certificateAuthorityData'], 'abc123');
    });

    test('deserializes from JSON', () {
      final cluster = KubeCluster.fromJson({
        'name': 'prod',
        'server': 'https://k8s.example.com',
        'insecureSkipTlsVerify': true,
      });
      expect(cluster.name, 'prod');
      expect(cluster.insecureSkipTlsVerify, true);
      expect(cluster.certificateAuthorityData, isNull);
    });
  });

  group('KubeUser', () {
    test('serializes exec config', () {
      const user = KubeUser(
        name: 'aws-user',
        exec: KubeExec(
          command: 'aws-iam-authenticator',
          args: ['token', '-i', 'my-cluster'],
          apiVersion: 'client.authentication.k8s.io/v1beta1',
        ),
      );
      final json = user.toJson();
      expect(json['exec']['command'], 'aws-iam-authenticator');
      expect(json['exec']['args'], hasLength(3));
    });

    test('deserializes token auth', () {
      final user = KubeUser.fromJson({
        'name': 'token-user',
        'token': 'secret',
      });
      expect(user.token, 'secret');
      expect(user.exec, isNull);
    });
  });

  group('SavedCluster', () {
    test('detects EKS provider', () {
      const saved = SavedCluster(
        context: KubeContext(
            name: 'prod', clusterName: 'eks', userName: 'admin'),
        cluster: KubeCluster(
            name: 'eks',
            server: 'https://A1B2.us-east-1.eks.amazonaws.com'),
        user: KubeUser(name: 'admin', token: 'tok'),
      );
      expect(saved.detectedProvider, ClusterProvider.eks);
      expect(saved.providerLabel, 'EKS');
    });

    test('detects GKE provider from exec command', () {
      const saved = SavedCluster(
        context:
            KubeContext(name: 'gke', clusterName: 'gke', userName: 'gke-user'),
        cluster: KubeCluster(name: 'gke', server: 'https://34.120.0.1'),
        user: KubeUser(
          name: 'gke-user',
          exec: KubeExec(command: 'gcloud', args: ['container', 'clusters']),
        ),
      );
      expect(saved.detectedProvider, ClusterProvider.gke);
    });

    test('defaults to self-hosted', () {
      const saved = SavedCluster(
        context: KubeContext(
            name: 'local', clusterName: 'mk', userName: 'mk'),
        cluster:
            KubeCluster(name: 'mk', server: 'https://192.168.49.2:8443'),
        user: KubeUser(name: 'mk', token: 'tok'),
      );
      expect(saved.detectedProvider, ClusterProvider.selfHosted);
      expect(saved.providerLabel, 'SELF');
    });
  });

  group('Pod', () {
    test('isHealthy for running pod', () {
      const pod = Pod(name: 'test', namespace: 'default', status: 'Running');
      expect(pod.isHealthy, true);
      expect(pod.isError, false);
      expect(pod.isPending, false);
    });

    test('isError for CrashLoopBackOff', () {
      const pod = Pod(
          name: 'broken', namespace: 'default', status: 'CrashLoopBackOff');
      expect(pod.isHealthy, false);
      expect(pod.isError, true);
    });

    test('isPending', () {
      const pod =
          Pod(name: 'waiting', namespace: 'default', status: 'Pending');
      expect(pod.isPending, true);
    });
  });

  group('Deployment', () {
    test('isHealthy when all replicas ready', () {
      const dep = Deployment(
        name: 'web',
        namespace: 'default',
        readyReplicas: 3,
        desiredReplicas: 3,
      );
      expect(dep.isHealthy, true);
      expect(dep.isDegraded, false);
      expect(dep.readyText, '3/3');
    });

    test('isDegraded when partially ready', () {
      const dep = Deployment(
        name: 'api',
        namespace: 'default',
        readyReplicas: 1,
        desiredReplicas: 3,
      );
      expect(dep.isHealthy, false);
      expect(dep.isDegraded, true);
    });
  });
}
