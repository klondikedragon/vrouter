# VRouter source

Source: [saleh-aleid/vrouter](https://github.com/saleh-aleid/vrouter), revision [e8d7b7030684ae454f096d93a0c7eb22df802e88](https://github.com/saleh-aleid/vrouter/commit/e8d7b7030684ae454f096d93a0c7eb22df802e88).
Copied lib/, pubspec.yaml and LICENSE from the app's pinned fork.
LICENSE retains the original MIT notice.

Local changes:

- Select browser/platform implementations with dart.library.js_interop.
- Use package:web/static JS interop for browser helpers, retaining history state, URL and unload behavior.
- Invoke browser history push/replace directly; external interop method tear-offs are unsupported by both web compilers.
- Declare Dart >=3.4, web ^1.1.1 and official url_strategy ^0.3.0.
- Declare route/sailor bases as abstract mixin classes for Dart 3, retaining extends and with usage.
- Remove the unused WidgetsVRouter inspector-selection hook removed by the current Flutter SDK.
- Keep native platform flags as static forwards without extending final dart:io.Platform.
- Match nullable JS getter/setter types and remove casts made unnecessary by Dart flow promotion.
- Accept integral browser history indices represented as Dart doubles under WASM, rejecting lossy integer conversions.
- Add browser helper regression coverage, including signed state values, in test/browser_helpers_web_test.dart.

Local changed files relative to the pinned source:

- lib/src/core/vrouter_delegate.dart
- lib/src/core/vroute_element.dart
- lib/src/core/vrouter_sailor/vrouter_sailor.dart
- lib/src/vroute_elements/vroute_element_single_subroute.dart
- lib/src/widgets/router_app/widgets_vrouter.dart
- lib/src/wrappers/browser_helpers/browser_helpers.dart
- lib/src/wrappers/browser_helpers/browser_helpers_web.dart
- lib/src/wrappers/move_to_background.dart
- lib/src/wrappers/platform/platform.dart
- lib/src/wrappers/platform/platform_io.dart
- pubspec.yaml
- test/browser_helpers_web_test.dart (new)
- test/route_history_number_test.dart (new)
- UPSTREAM.md (new)

Browser tests stay here because the app's VM bundle generator rejects browser-only file annotations and imports.
After resolving the app's local package path, run them explicitly from the app root with flutter test --platform chrome third_party/vrouter/test/browser_helpers_web_test.dart, once as is and once with --wasm.
The release-build routing/history/unload check (a router fixture app driven by headless Chrome, JS and WASM) is not in this repository: it lives in the workspace's local scratch area and is run by hand before a vrouter or Flutter change ships.

Revisit before the next Flutter/dependency upgrade or fork refresh.
Compare upstream changes, preserve the required fork behavior, and remove this copy when an upstream release/revision passes the app's JS and WASM routing/history/unload gates.
