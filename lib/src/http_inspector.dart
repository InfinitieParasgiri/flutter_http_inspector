// lib/src/http_inspector.dart
import 'adapters/base_adapter.dart';
import 'adapters/dio_adapter.dart';
import 'adapters/http_adapter.dart';
import 'adapters/manual_adapter.dart';

/// Main entry point for flutter_http_inspector.
///
/// Call [setup] once in your main() and the right adapter is chosen
/// automatically based on what you pass.
///
/// Then wrap your app with [HttpInspectorOverlay] — done.
class HttpInspector {
  HttpInspector._();

  static BaseInspectorAdapter? _activeAdapter;

  /// Currently active adapter name — e.g. "Dio", "http", "Manual"
  static String get activeAdapterName =>
      _activeAdapter?.adapterName ?? 'None';

  // ──────────────────────────────────────────────────────────
  // SETUP — auto-selects adapter from what you pass
  // ──────────────────────────────────────────────────────────

  /// Universal setup. Pass what your project uses:
  ///
  /// ```dart
  /// // Dio:
  /// HttpInspector.setup(dio: myDio);
  ///
  /// // Manual (dart:io / GraphQL / custom):
  /// HttpInspector.setup();
  /// ```
  ///
  /// For the `http` package, use [setupHttp] instead — it returns
  /// the wrapped client directly.
  static BaseInspectorAdapter setup({dynamic dio}) {
    late BaseInspectorAdapter adapter;

    if (dio != null) {
      adapter = DioAdapter(dio);
      _log('✅ Dio adapter attached');
    } else {
      adapter = ManualAdapter();
      _log('✅ Manual adapter active — use HttpInspector.log() per request');
    }

    adapter.attach();
    _activeAdapter = adapter;
    return adapter;
  }

  /// Setup for the `http` package.
  ///
  /// Returns an [InspectorHttpClient] — a drop-in [http.Client] replacement.
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
  // MANUAL LOGGING — for dart:io / GraphQL / anything else
  // ──────────────────────────────────────────────────────────

  /// Start tracking a request manually.
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

  /// Detach the adapter. Call this when your app is disposed.
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
