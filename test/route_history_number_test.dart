import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vrouter/vrouter.dart';

const _signedState = {'signed': '-7', 'phase': 'framework-entry'};

Future<VRouterState> _mountRouter(
  WidgetTester tester,
  Future<void> Function(VRedirector redirector) beforeEnter,
) async {
  final key = GlobalKey<VRouterState>();
  await tester.pumpWidget(VRouter(
    key: key,
    initialUrl: '/home',
    logs: VLogs.none,
    transitionDuration: Duration.zero,
    reverseTransitionDuration: Duration.zero,
    routes: [
      VWidget(path: '/home', widget: const SizedBox()),
      VGuard(
        beforeEnter: beforeEnter,
        stackedRoutes: [VWidget(path: '/blocked', widget: const SizedBox())],
      ),
    ],
  ));
  await tester.pumpAndSettle();
  expect(key.currentState!.url, '/home');
  return key.currentState!;
}

RouteInformation _frameworkRoute(Object? historyIndex) => RouteInformation(
      uri: Uri.parse('/blocked'),
      state: <String, dynamic>{'historyIndex': historyIndex, 'app': _signedState},
    );

void main() {
  for (final entry in <String, Object?>{
    'null': null,
    'integer zero': 0,
    'double zero': 0.0,
    'integer': 1,
    'integral double': 1.0,
    'negative integer': -3,
    'negative integral double': -3.0,
  }.entries) {
    testWidgets('framework ${entry.key} index still runs the blocking guard', (tester) async {
      var guardCalls = 0;
      final router = await _mountRouter(tester, (redirector) async {
        guardCalls++;
        expect(redirector.fromUrl, '/home');
        expect(redirector.toUrl, '/blocked');
        expect(redirector.newVRouterData!.historyState, _signedState);
        redirector.stopRedirection();
      });

      await router.vRouterDelegate.setNewRoutePath(_frameworkRoute(entry.value));
      await tester.pumpAndSettle();

      expect(guardCalls, 1);
      expect(router.url, '/home');
      expect(router.historyState, isEmpty);
    });
  }

  for (final index in [1.5, -3.5]) {
    testWidgets('fractional framework index $index fails before the guard', (tester) async {
      var guardCalls = 0;
      final router = await _mountRouter(tester, (redirector) async {
        guardCalls++;
        redirector.stopRedirection();
      });

      await expectLater(
        router.vRouterDelegate.setNewRoutePath(_frameworkRoute(index)),
        throwsFormatException,
      );

      expect(guardCalls, 0);
      expect(router.url, '/home');
      expect(router.historyState, isEmpty);
    });
  }

  for (final index in <Object>['1', true]) {
    testWidgets('nonnumeric framework index $index fails before the guard', (tester) async {
      var guardCalls = 0;
      final router = await _mountRouter(tester, (redirector) async {
        guardCalls++;
        redirector.stopRedirection();
      });

      await expectLater(
        router.vRouterDelegate.setNewRoutePath(_frameworkRoute(index)),
        throwsA(isA<TypeError>()),
      );

      expect(guardCalls, 0);
      expect(router.url, '/home');
      expect(router.historyState, isEmpty);
    });
  }
}
