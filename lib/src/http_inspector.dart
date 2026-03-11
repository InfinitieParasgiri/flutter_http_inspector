// lib/src/http_inspector.dart
import 'adapters/base_adapter.dart';
import 'adapters/dio_adapter.dart';
import 'adapters/http_adapter.dart';
import 'adapters/io_adapter.dart';
import 'adapters/manual_adapter.dart';

/// Main entry point for flutter_http_inspector.
///
/// ## Zero-config setup (recommended) — works for `http`, `Dio`, `dart:io`
///
/// ```dart
/// void main() {
///   HttpInspector.setup(); // ← ONE line, no other changes needed
///   runApp(
///     HttpInspectorOverlay(enabled: kDebugMode, child: MyApp()),
///   );
/// }
/// ```
///
/// This patches [dart:io] globally so ALL HTTP traffic is captured
/// automatically — no changes in any API helper file.
///
/// ## Attach to a specific Dio instance
///
/// ```dart
/// HttpInspector.setup(dio: myDio);
/// ```
class HttpInspector {
  HttpInspector._();

  static BaseInspectorAdapter? _activeAdapter;

  /// Currently active adapter name — e.g. "IO (global)", "Dio", "Manual"
  static String get activeAdapterName => _activeAdapter?.adapterName ?? 'None';

  // ──────────────────────────────────────────────────────────
  // SETUP
  // ──────────────────────────────────────────────────────────

  /// Universal setup.
  ///
  /// **No args** (default) → patches `dart:io` globally via [HttpOverrides].
  /// Every request in the app — `http` package, `Dio`, raw `dart:io` —
  /// is captured automatically. No changes needed in API helper files.
  ///
  /// **Pass `dio:`** → attaches an interceptor to that specific `Dio` instance
  /// only. Use this if you want to limit inspection to one Dio client.
  ///
  /// ```dart
  /// // Recommended: catch everything
  /// HttpInspector.setup();
  ///
  /// // Dio-only mode
  /// HttpInspector.setup(dio: myDio);
  /// ```
  static BaseInspectorAdapter setup({dynamic dio}) {
    late BaseInspectorAdapter adapter;

    if (dio != null) {
      adapter = DioAdapter(dio);
      _log('✅ Dio adapter attached');
    } else {
      // Default: global dart:io override — zero config, catches everything
      adapter = IoAdapter();
      _log('✅ IO (global) adapter attached — all HTTP traffic captured');
    }

    adapter.attach();
    _activeAdapter = adapter;
    return adapter;
  }

  /// **Advanced / legacy** — wraps a specific `http.Client` instance.
  ///
  /// Prefer [setup] (no args) for zero-config global interception.
  /// Only use this if you need to inspect a specific client in isolation.
  ///
  /// ```dart
  /// final client = HttpInspector.setupHttp(http.Client());
  /// final res = await client.get(Uri.parse('https://api.example.com'));
  /// ```
  static InspectorHttpClient setupHttp(dynamic httpClient) {
    final adapter = HttpAdapter(httpClient);
    adapter.attach();
    _activeAdapter = adapter;
    _log('✅ http adapter attached');
    return adapter.client;
  }

  // ──────────────────────────────────────────────────────────
  // MANUAL LOGGING — for GraphQL / custom wrapper / anything else
  // ──────────────────────────────────────────────────────────

  /// Manually track a single request — useful for GraphQL or custom clients.
  ///
  /// ```dart
  /// final log = HttpInspector.log(
  ///   'POST', 'https://api.example.com/login',
  ///   headers: {'Content-Type': 'application/json'},
  ///   body: jsonEncode({'email': 'a@b.com', 'password': '123'}),
  /// );
  ///
  /// try {
  ///   final res = await myClient.post('/login', body: payload);
  ///   log.complete(statusCode: res.statusCode, responseBody: res.body);
  /// } catch (e) {
  ///   log.error(e.toString(), errorType: e.runtimeType.toString());
  /// }
  /// ```
  static InspectorLogHandle log(
    String method,
    String url, {
    Map<String, dynamic>? headers,
    dynamic body,
    Map<String, String>? queryParameters,
  }) {
    return InspectorLogHandle.start(
      method: method,
      url: url,
      headers: headers,
      body: body,
      queryParameters: queryParameters,
    );
  }

  // ──────────────────────────────────────────────────────────
  // CLEANUP
  // ──────────────────────────────────────────────────────────

  /// Detach the active adapter. Call this when your app is disposed.
  static void dispose() {
    _activeAdapter?.detach();
    _activeAdapter = null;
  }

  static void _log(String msg) {
    assert(() {
      // ignore: avoid_print
      print('[HttpInspector] $msg');
      return true;
    }());
  }
}
