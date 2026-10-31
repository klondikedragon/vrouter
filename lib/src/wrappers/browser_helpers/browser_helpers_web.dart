import 'dart:js_interop';

import 'package:vrouter/src/vrouter_core.dart';
import 'package:vrouter/src/vrouter_scope.dart';
import 'package:web/web.dart' as web;

/// List of static methods to interact with the browser
/// Only one is implemented for mobile: pushExternal

class BrowserHelpers {
  /// Gets every part of the url apart from the hostname
  /// If we are in hash mode, we remove the # as well
  /// Always starts with '/'
  ///
  /// Note that this is the url of the browser, which might not be always
  /// in sync with [VRouterSailor.url]
  static String getPathAndQuery({required VRouterMode routerMode}) {
    // If the mode is hash, it's easy we just take whatever is after the hash
    if (routerMode == VRouterMode.hash) {
      return web.window.location.hash.isEmpty
          ? ''
          : web.window.location.hash.substring(1);
    }

    // else, we have to be careful with the basePath

    // Get the entire url (http...)
    final entireUrl = _getEntireUrl();

    // Remove the basePath
    final basePath = _getBasePath();
    final pathAndQuery = (basePath.length <
            entireUrl.length) // This might happen during first app startup
        ? entireUrl.substring(basePath.length)
        : '';

    return pathAndQuery.startsWith('/') ? pathAndQuery : '/$pathAndQuery';
  }

  /// Allows us to tell the browser to navigate in the browser history
  static void browserGo(int delta) => web.window.history.go(delta);

  /// Fires an event when the url changes
  static Stream<web.PopStateEvent> get onBrowserPopState =>
      web.window.onPopState;

  /// Fires an event when a page will be unloaded
  ///
  /// This mainly occurs when a user types a url in the browser on closes the browser
  static Stream<web.Event> get onBrowserBeforeUnload =>
      web.EventStreamProviders.beforeUnloadEvent.forTarget(web.window);

  /// Pushes a url which is from another website
  ///
  /// If [openNewTab] is true, this url in opened in a new tab
  static Future<void> pushExternal(String url,
      {required bool openNewTab}) async {
    final targetUrl = url.startsWith('http') ? url : 'http://$url';
    if (openNewTab) {
      web.window.open(targetUrl, '_blank');
    } else {
      web.window.location.href = targetUrl;
    }
  }

  /// This pushes a url to the browser
  ///
  ///
  ///
  /// Note that the new route WONT be reported back to flutter
  static void pushUrl(
    String url, {
    required VRouterMode routerMode,
    required bool isReplacement,
  }) {
    final historyState = web.window.history.state;
    final targetUrl = _getBasePath() +
        ((routerMode == VRouterMode.hash) ? '#/' : '') +
        (url.startsWith('/') ? url.substring(1) : url);
    if (isReplacement) {
      web.window.history.replaceState(historyState, 'flutter', targetUrl);
    } else {
      web.window.history.pushState(historyState, 'flutter', targetUrl);
    }
  }

  /// Returns the base path (ending with a '/')
  ///
  /// The base path is:
  ///   protocol + '//' + host + basePath (uri from the first `<base>` tag)
  static String _getBasePath() {
    final baseTags = web.document.getElementsByTagName('base');

    return baseTags.length == 0 ? '/' : baseTags.item(0)!.baseURI;
  }

  /// Returns the entire url
  static String _getEntireUrl() => web.window.location.href;

  /// Get the number of history entries for this app
  ///
  ///
  /// Note that this is NOT the history length of the browser
  static int getHistoryLength({required int applicationInstanceId}) {
    final String? historyLengthString =
        web.window.localStorage.getItem('$applicationInstanceId');

    if (historyLengthString == null) {
      throw Exception('Tried to get historyLength but it has not been set');
    }

    return int.parse(historyLengthString);
  }

  /// Set the number of history entries for this app
  ///
  ///
  /// Note that this is NOT the history length of the browser
  static void setHistoryLength({
    required int applicationInstanceId,
    required int historyLength,
  }) {
    web.window.localStorage
        .setItem('$applicationInstanceId', '$historyLength');
  }

  /// This replace the current history state by the new given one
  ///
  /// Note that flutter uses a map in the browser history and that
  /// only 'state' should be changed
  static void setAppHistoryState(Map<String, String> state) {
    final historyState = _getHistoryState();
    historyState.app = state.jsify();
    _setHistoryState(historyState);
  }

  static Map<String, String> getAppHistoryState() {
    final Map<String, String>? appHistoryState =
        (_getHistoryState().app.dartify() as Map<dynamic, dynamic>?)?.map(
      (key, value) => MapEntry(
        key.toString(),
        // WASM dartify returns doubles; retain the browser's number spelling.
        value is num ? _jsString(value.jsify()) : value.toString(),
      ),
    );

    if (appHistoryState == null) {
      throw Exception('Tried to get appHistoryState but it has not been set');
    }

    return appHistoryState;
  }

  static void setHistoryIndex(int historyIndex) {
    final historyState = _getHistoryState();
    historyState.historyIndex = historyIndex;
    _setHistoryState(historyState);
  }

  /// We use a custom state entry called 'historyIndex'
  /// This is used by this plugin to keep track of where we are
  /// in the browser history
  static int getHistoryIndex() => _getHistoryState().historyIndex ?? 0;

  static void setApplicationInstanceId(int applicationInstanceId) {
    final historyState = _getHistoryState();
    historyState.applicationInstanceId = applicationInstanceId;
    _setHistoryState(historyState);
  }

  static int getApplicationInstanceId() {
    final int? applicationInstanceId =
        _getHistoryState().applicationInstanceId;

    if (applicationInstanceId == null) {
      throw Exception(
          'Tried to get applicationInstanceId but it has not been set');
    }
    return applicationInstanceId;
  }

  static _HistoryState _getHistoryState() {
    final globalState = web.window.history.state;

    if (globalState == null) {
      return _HistoryState(JSObject());
    }

    final historyState = _HistoryState(globalState as JSObject);
    // Flutter wraps router state after restoring browser history.
    // Hot reload can leave the router state at the top level instead.
    if (!_hasOwnProperty(historyState, 'state') || historyState.state == null) {
      return _copyHistoryState(historyState);
    }

    return _copyHistoryState(historyState.state as JSObject);
  }

  static void _setHistoryState(_HistoryState historyState) {
    final globalState = web.window.history.state;

    if (globalState == null ||
        !_hasOwnProperty(globalState as JSObject, 'state')) {
      web.window.history.replaceState(historyState, 'flutter', null);
      return;
    }

    // Retain Flutter's wrapper and unrelated structured-clone values.
    final flutterState = _HistoryState(globalState);
    flutterState.state = historyState;
    flutterState.serialCount = 0;
    web.window.history.replaceState(flutterState, 'flutter', null);
  }
}

// Copy the map layer without converting unrelated values or creating a cycle
// when Flutter's wrapper contains a null state.
_HistoryState _copyHistoryState(JSObject state) =>
    _HistoryState(_assignObject(_createObject(null), state));

@JS('String')
external String _jsString(JSAny? value);

@JS('Object.assign')
external JSObject _assignObject(JSObject target, JSObject source);

@JS('Object.create')
external JSObject _createObject(JSAny? prototype);

@JS('Object.prototype.hasOwnProperty.call')
external bool _hasOwnProperty(JSObject object, String property);

extension type _HistoryState(JSObject _) implements JSObject {
  external JSAny? get state;
  external set state(JSAny? value);
  external JSAny? get app;
  external set app(JSAny? value);
  external int? get historyIndex;
  external set historyIndex(int? value);
  external int? get applicationInstanceId;
  external set applicationInstanceId(int? value);
  external set serialCount(int value);
}
