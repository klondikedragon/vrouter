@TestOn('browser')
library;

import 'dart:js_interop';

import 'package:flutter_test/flutter_test.dart';
import 'package:vrouter/src/vrouter_scope.dart';
import 'package:vrouter/src/wrappers/browser_helpers/browser_helpers.dart';
import 'package:vrouter/src/wrappers/platform/platform.dart' as router_platform;
import 'package:web/web.dart' as web;

void main() {
  late String originalUrl;
  late JSAny? originalState;
  late web.HTMLBaseElement base;
  late String? originalBaseHref;
  late bool addedBase;

  setUp(() {
    originalUrl = web.window.location.href;
    originalState = web.window.history.state;
    final existingBase = web.document.querySelector('base');
    addedBase = existingBase == null;
    base = existingBase == null
        ? web.HTMLBaseElement()
        : existingBase as web.HTMLBaseElement;
    originalBaseHref = base.getAttribute('href');
    base.href = '${web.window.location.origin}/vrouter-test/';
    if (addedBase) web.document.head!.appendChild(base);
    web.window.history.replaceState(null, '', '${base.href}initial');
  });

  tearDown(() {
    web.window.history.replaceState(originalState, '', originalUrl);
    if (addedBase) {
      base.remove();
    } else if (originalBaseHref == null) {
      base.removeAttribute('href');
    } else {
      base.setAttribute('href', originalBaseHref!);
    }
  });

  test('web conditionals select browser helpers and platform', () {
    expect(router_platform.Platform.isWeb, isTrue);
    expect(router_platform.Platform.isAndroid, isFalse);
    expect(BrowserHelpers.getPathAndQuery(routerMode: VRouterMode.history),
        '/initial');
  });

  test('empty and flattened state preserve app, index and instance ID', () {
    expect(BrowserHelpers.getHistoryIndex(), 0);
    expect(BrowserHelpers.getAppHistoryState, throwsException);
    expect(BrowserHelpers.getApplicationInstanceId, throwsException);
    BrowserHelpers.setAppHistoryState({'path': '/a?b=1#c', 'unicode': '雪'});
    BrowserHelpers.setHistoryIndex(-3);
    expect(BrowserHelpers.getHistoryIndex(), -3);
    BrowserHelpers.setHistoryIndex(3);
    BrowserHelpers.setApplicationInstanceId(-19);
    expect(BrowserHelpers.getApplicationInstanceId(), -19);
    BrowserHelpers.setApplicationInstanceId(19);
    expect(BrowserHelpers.getAppHistoryState(),
        {'path': '/a?b=1#c', 'unicode': '雪'});
    expect(BrowserHelpers.getHistoryIndex(), 3);
    expect(BrowserHelpers.getApplicationInstanceId(), 19);
    expect(_hasOwnProperty(web.window.history.state as JSObject, 'state'),
        isFalse);
  });

  test('app state retains legacy string conversion', () {
    web.window.history.replaceState({
      'app': {'number': 7, 'bool': true, 'null': null}
    }.jsify(), '', null);
    expect(BrowserHelpers.getAppHistoryState(),
        {'number': '7', 'bool': 'true', 'null': 'null'});
  });

  test('wrapped state keeps unrelated structured-clone data', () {
    final cycle = _Cycle(JSObject());
    cycle.self = cycle;
    web.window.history.replaceState({
      'state': {
        'app': {'route': 'before'},
        'historyIndex': 2,
        'applicationInstanceId': 23,
        'timestamp': _Date(4567),
      },
      'serialCount': 9,
      'marker': 'flutter',
      'timestamp': _Date(1234),
      'cycle': cycle,
    }.jsify(), '', null);

    expect(BrowserHelpers.getAppHistoryState(), {'route': 'before'});
    BrowserHelpers.setAppHistoryState({'route': 'after'});
    BrowserHelpers.setHistoryIndex(4);
    BrowserHelpers.setApplicationInstanceId(29);
    final wrapper = _State(web.window.history.state as JSObject);
    final nested = _State(wrapper.state as JSObject);
    expect(wrapper.serialCount, 0);
    expect(wrapper.marker, 'flutter');
    expect(wrapper.timestamp!.getTime(), 1234);
    expect(nested.timestamp!.getTime(), 4567);
    final savedCycle = wrapper.cycle!;
    expect(_sameObject(savedCycle, savedCycle.self), isTrue);
    expect(BrowserHelpers.getAppHistoryState(), {'route': 'after'});
    expect(BrowserHelpers.getHistoryIndex(), 4);
    expect(BrowserHelpers.getApplicationInstanceId(), 29);
  });

  test('a null Flutter state keeps the flattened hot-reload state', () {
    web.window.history.replaceState({
      'state': null,
      'serialCount': 8,
      'historyIndex': 5,
      'app': {'route': 'old'},
    }.jsify(), '', null);
    expect(BrowserHelpers.getHistoryIndex(), 5);
    BrowserHelpers.setAppHistoryState({'route': 'saved'});
    final wrapper = _State(web.window.history.state as JSObject);
    final nested = _State(wrapper.state as JSObject);
    expect(wrapper.serialCount, 0);
    expect(nested.state, isNull);
    expect(nested.historyIndex, 5);
    expect(BrowserHelpers.getAppHistoryState(), {'route': 'saved'});
  });

  test('history and hash URLs keep base, query, fragment and state', () {
    BrowserHelpers.setAppHistoryState({'keep': 'state'});
    final historyLength = web.window.history.length;
    BrowserHelpers.pushUrl('/devices?sort=name#detail',
        routerMode: VRouterMode.history, isReplacement: true);
    expect(web.window.location.href, '${base.href}devices?sort=name#detail');
    expect(BrowserHelpers.getPathAndQuery(routerMode: VRouterMode.history),
        '/devices?sort=name#detail');
    expect(web.window.history.length, historyLength);
    BrowserHelpers.pushUrl('devices?sort=name#detail',
        routerMode: VRouterMode.hash, isReplacement: true);
    expect(web.window.location.href, '${base.href}#/devices?sort=name#detail');
    expect(BrowserHelpers.getPathAndQuery(routerMode: VRouterMode.hash),
        '/devices?sort=name#detail');
    expect(BrowserHelpers.getAppHistoryState(), {'keep': 'state'});
    expect(web.window.history.length, historyLength);
    web.window.history.replaceState(null, '', base.href);
    expect(BrowserHelpers.getPathAndQuery(routerMode: VRouterMode.hash), '');
  });

  test('push and browser back/forward restore URLs and app state', () async {
    BrowserHelpers.setAppHistoryState({'route': 'first'});
    BrowserHelpers.setHistoryIndex(1);
    final historyLength = web.window.history.length;
    BrowserHelpers.pushUrl('/second',
        routerMode: VRouterMode.history, isReplacement: false);
    BrowserHelpers.setAppHistoryState({'route': 'second'});
    BrowserHelpers.setHistoryIndex(2);
    expect(web.window.history.length, historyLength + 1);

    final back = BrowserHelpers.onBrowserPopState.first
        .timeout(const Duration(seconds: 5));
    BrowserHelpers.browserGo(-1);
    await back;
    expect(BrowserHelpers.getPathAndQuery(routerMode: VRouterMode.history),
        '/initial');
    expect(BrowserHelpers.getAppHistoryState(), {'route': 'first'});
    expect(BrowserHelpers.getHistoryIndex(), 1);

    final forward = BrowserHelpers.onBrowserPopState.first
        .timeout(const Duration(seconds: 5));
    BrowserHelpers.browserGo(1);
    await forward;
    expect(BrowserHelpers.getPathAndQuery(routerMode: VRouterMode.history),
        '/second');
    expect(BrowserHelpers.getAppHistoryState(), {'route': 'second'});
    expect(BrowserHelpers.getHistoryIndex(), 2);
  });

  test('local history length stores strings and retains missing/invalid errors', () {
    const instanceId = 2147483001;
    final key = '$instanceId';
    final originalValue = web.window.localStorage.getItem(key);
    addTearDown(() {
      if (originalValue == null) {
        web.window.localStorage.removeItem(key);
      } else {
        web.window.localStorage.setItem(key, originalValue);
      }
    });
    web.window.localStorage.removeItem(key);
    expect(() => BrowserHelpers.getHistoryLength(applicationInstanceId: instanceId),
        throwsException);
    BrowserHelpers.setHistoryLength(applicationInstanceId: instanceId, historyLength: 7);
    expect(web.window.localStorage.getItem(key), '7');
    expect(BrowserHelpers.getHistoryLength(applicationInstanceId: instanceId), 7);
    web.window.localStorage.setItem(key, 'invalid');
    expect(() => BrowserHelpers.getHistoryLength(applicationInstanceId: instanceId),
        throwsFormatException);
  });

  test('popstate delivery is synchronous, broadcast and cancelable', () async {
    final stream = BrowserHelpers.onBrowserPopState;
    expect(stream.isBroadcast, isTrue);
    var firstCount = 0;
    var secondCount = 0;
    final first = stream.listen((event) => firstCount++);
    final second = stream.listen((event) => secondCount++);
    web.window.dispatchEvent(web.PopStateEvent('popstate'));
    expect(firstCount, 1);
    expect(secondCount, 1);
    await first.cancel();
    web.window.dispatchEvent(web.PopStateEvent('popstate'));
    expect(firstCount, 1);
    expect(secondCount, 2);
    await second.cancel();
  });

  test('beforeunload delivery is synchronous and exposes the native event', () async {
    var callCount = 0;
    final stream = BrowserHelpers.onBrowserBeforeUnload;
    expect(stream.isBroadcast, isTrue);
    final subscription = stream.listen((event) {
      callCount++;
      event.preventDefault();
    });
    final event = web.Event('beforeunload', web.EventInit(cancelable: true));
    expect(web.window.dispatchEvent(event), isFalse);
    expect(callCount, 1);
    expect(event.defaultPrevented, isTrue);
    await subscription.cancel();
    web.window.dispatchEvent(web.Event('beforeunload'));
    expect(callCount, 1);
  });

  test('external new-tab navigation keeps scheme normalization and target', () async {
    final originalOpen = _windowOpen;
    String? openedUrl;
    String? openedTarget;
    _windowOpen = ((String url, String target) {
      openedUrl = url;
      openedTarget = target;
      return web.window;
    }).toJS;
    try {
      await BrowserHelpers.pushExternal('example.invalid/path', openNewTab: true);
      expect(openedUrl, 'http://example.invalid/path');
      expect(openedTarget, '_blank');
      await BrowserHelpers.pushExternal('https://example.invalid/path', openNewTab: true);
      expect(openedUrl, 'https://example.invalid/path');
    } finally {
      _windowOpen = originalOpen;
    }
  });

  test('external same-tab navigation assigns the requested URL', () async {
    final url = '${web.window.location.href}#external';
    await BrowserHelpers.pushExternal(url, openNewTab: false);
    expect(web.window.location.href, url);
  });
}

@JS('window.open')
external JSFunction get _windowOpen;

@JS('window.open')
external set _windowOpen(JSFunction value);

@JS('Object.prototype.hasOwnProperty.call')
external bool _hasOwnProperty(JSObject object, String property);

@JS('Object.is')
external bool _sameObject(JSAny? left, JSAny? right);

@JS('Date')
extension type _Date._(JSObject _) implements JSObject {
  external factory _Date(int value);
  external int getTime();
}

extension type _Cycle(JSObject _) implements JSObject {
  external JSAny? get self;
  external set self(JSAny? value);
}

extension type _State(JSObject _) implements JSObject {
  external JSAny? get state;
  external int? get serialCount;
  external int? get historyIndex;
  external String? get marker;
  external _Date? get timestamp;
  external _Cycle? get cycle;
}
