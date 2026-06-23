import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'core/theme/kubely_theme.dart';
import 'state/providers/cluster_provider.dart';
import 'ui/shell/app_shell.dart';
import 'ui/screens/vitals/home_wrapper.dart';
import 'ui/screens/workloads/workloads_screen.dart';
import 'ui/screens/events/events_screen.dart';
import 'ui/screens/exec_shell/exec_screen.dart';
import 'ui/screens/more/more_screen.dart';
import 'ui/screens/add_cluster/add_cluster_screen.dart';
import 'ui/screens/pod_detail/pod_detail_screen.dart';
import 'ui/screens/pod_detail/logs_screen.dart';
import 'ui/screens/network/network_screen.dart';
import 'ui/screens/storage/storage_screen.dart';
import 'ui/screens/helm/helm_screen.dart';
import 'ui/screens/nodes/nodes_screen.dart';
import 'ui/screens/config_editor/config_editor_screen.dart';
import 'ui/screens/config_editor/config_list_screen.dart';
import 'ui/screens/more/about_screen.dart';
import 'ui/screens/workloads/deployment_detail_screen.dart';
import 'ui/screens/helm/helm_detail_screen.dart';
import 'ui/screens/network/service_detail_screen.dart';
import 'core/utils/page_transitions.dart';
import 'ui/screens/splash/splash_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final _router = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/vitals',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          AppShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/vitals',
              builder: (context, state) => const HomeWrapper(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/workloads',
              builder: (context, state) => const WorkloadsScreen(),
              routes: [
                GoRoute(
                  path: 'pod/:name',
                  parentNavigatorKey: _rootNavigatorKey,
                  pageBuilder: (context, state) => slideTransitionPage(
                    key: state.pageKey,
                    child: PodDetailScreen(
                      podName: state.pathParameters['name'] ?? '',
                    ),
                  ),
                ),
                GoRoute(
                  path: 'pod/:name/logs',
                  parentNavigatorKey: _rootNavigatorKey,
                  pageBuilder: (context, state) => slideTransitionPage(
                    key: state.pageKey,
                    child: LogsScreen(
                      podName: state.pathParameters['name'] ?? '',
                    ),
                  ),
                ),
                GoRoute(
                  path: 'deploy/:name',
                  parentNavigatorKey: _rootNavigatorKey,
                  pageBuilder: (context, state) {
                    final extra =
                        state.extra as Map<String, dynamic>? ?? {};
                    return slideTransitionPage(
                      key: state.pageKey,
                      child: DeploymentDetailScreen(
                        name: state.pathParameters['name'] ?? '',
                        namespace:
                            extra['namespace'] as String? ?? 'default',
                        ready: extra['ready'] as int? ?? 0,
                        desired: extra['desired'] as int? ?? 0,
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/events',
              builder: (context, state) => const EventsScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/shell',
              builder: (context, state) => const ExecScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/more',
              builder: (context, state) => const MoreScreen(),
              routes: [
                GoRoute(
                  path: 'network',
                  parentNavigatorKey: _rootNavigatorKey,
                  pageBuilder: (context, state) => slideTransitionPage(
                    key: state.pageKey,
                    child: const NetworkScreen(),
                  ),
                  routes: [
                    GoRoute(
                      path: 'svc/:name',
                      parentNavigatorKey: _rootNavigatorKey,
                      pageBuilder: (context, state) {
                        final extra = state.extra as Map<String, dynamic>? ?? {};
                        return slideTransitionPage(
                          key: state.pageKey,
                          child: ServiceDetailScreen(
                            serviceName: state.pathParameters['name'] ?? '',
                            namespace: extra['namespace'] as String? ?? 'default',
                          ),
                        );
                      },
                    ),
                  ],
                ),
                GoRoute(
                  path: 'storage',
                  parentNavigatorKey: _rootNavigatorKey,
                  pageBuilder: (context, state) => slideTransitionPage(
                    key: state.pageKey,
                    child: const StorageScreen(),
                  ),
                ),
                GoRoute(
                  path: 'helm',
                  parentNavigatorKey: _rootNavigatorKey,
                  pageBuilder: (context, state) => slideTransitionPage(
                    key: state.pageKey,
                    child: const HelmScreen(),
                  ),
                  routes: [
                    GoRoute(
                      path: ':name',
                      parentNavigatorKey: _rootNavigatorKey,
                      pageBuilder: (context, state) {
                        final extra =
                            state.extra as Map<String, dynamic>? ?? {};
                        return slideTransitionPage(
                          key: state.pageKey,
                          child: HelmDetailScreen(
                            releaseName:
                                state.pathParameters['name'] ?? '',
                            namespace:
                                extra['namespace'] as String? ?? 'default',
                          ),
                        );
                      },
                    ),
                  ],
                ),
                GoRoute(
                  path: 'nodes',
                  parentNavigatorKey: _rootNavigatorKey,
                  pageBuilder: (context, state) => slideTransitionPage(
                    key: state.pageKey,
                    child: const NodesScreen(),
                  ),
                ),
                GoRoute(
                  path: 'config',
                  parentNavigatorKey: _rootNavigatorKey,
                  pageBuilder: (context, state) => slideTransitionPage(
                    key: state.pageKey,
                    child: const ConfigListScreen(),
                  ),
                  routes: [
                    GoRoute(
                      path: ':name',
                      parentNavigatorKey: _rootNavigatorKey,
                      pageBuilder: (context, state) {
                        final extra =
                            state.extra as Map<String, dynamic>? ?? {};
                        return slideTransitionPage(
                          key: state.pageKey,
                          child: ConfigEditorScreen(
                            configName:
                                state.pathParameters['name'] ?? 'config',
                            namespace:
                                extra['namespace'] as String? ?? 'default',
                            isSecret: extra['isSecret'] as bool? ?? false,
                          ),
                        );
                      },
                    ),
                  ],
                ),
                GoRoute(
                  path: 'about',
                  parentNavigatorKey: _rootNavigatorKey,
                  pageBuilder: (context, state) => slideTransitionPage(
                    key: state.pageKey,
                    child: const AboutScreen(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/add-cluster',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (context, state) => fadeTransitionPage(
        key: state.pageKey,
        child: const AddClusterScreen(),
      ),
    ),
  ],
);

class KubelyApp extends ConsumerStatefulWidget {
  const KubelyApp({super.key});

  @override
  ConsumerState<KubelyApp> createState() => _KubelyAppState();
}

class _KubelyAppState extends ConsumerState<KubelyApp> {
  bool _showSplash = true;

  @override
  void initState() {
    super.initState();
    _waitForLoad();
  }

  Future<void> _waitForLoad() async {
    // Show splash for at least 2s, but wait for cluster storage to load
    await Future.delayed(const Duration(milliseconds: 2000));
    // Poll until cluster provider finishes loading (max 5s total)
    for (var i = 0; i < 30; i++) {
      if (!mounted) return;
      if (ref.read(clusterProvider).loaded) break;
      await Future.delayed(const Duration(milliseconds: 100));
    }
    if (!mounted) return;
    setState(() => _showSplash = false);
    final state = ref.read(clusterProvider);
    if (state.clusters.isEmpty) {
      _router.go('/add-cluster');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Kubely',
      debugShowCheckedModeBanner: false,
      theme: KubelyTheme.dark,
      routerConfig: _router,
      builder: (context, child) {
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
          child: _showSplash
              ? const SplashScreen(key: ValueKey('splash'))
              : KeyedSubtree(key: const ValueKey('app'), child: child!),
        );
      },
    );
  }
}
