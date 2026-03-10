// lib/src/adapters/manual_adapter.dart
import '../http_record.dart';
import '../inspector_store.dart';
import 'base_adapter.dart';

/// Adapter for any HTTP client — dart:io, GraphQL, Retrofit, custom wrappers.
/// Use [HttpInspector.log] to manually track each request.
class ManualAdapter extends BaseInspectorAdapter {
  @override
  String get adapterName => 'Manual';

  @override
  void attach() {
    // No automatic hooking — developer uses HttpInspector.log() per request
  }
}

/// Handle returned by [HttpInspector.log].
/// Call [complete] or [error] after your request finishes.
///
/// ```dart
/// final log = HttpInspector.log('GET', 'https://api.example.com/users');
/// try {
///   final res = await myRequest();
///   log.complete(statusCode: res.statusCode, responseBody: res.body);
/// } catch (e) {
///   log.error(e.toString());
/// }
/// ```
class InspectorLogHandle {
  final String _id;
  final DateTime _startTime;
  final InspectorStore _store;

  InspectorLogHandle._(this._id, this._startTime, this._store);

  factory InspectorLogHandle.start({
    required String method,
    required String url,
    Map<String, dynamic>? headers,
    dynamic body,
    Map<String, String>? queryParameters,
    InspectorStore? store,
  }) {
    final id = '${DateTime.now().millisecondsSinceEpoch}_manual';
    final storeInstance = store ?? InspectorStore();

    storeInstance.addRecord(HttpRecord(
      id: id,
      timestamp: DateTime.now(),
      method: method.toUpperCase(),
      url: url.split('?').first,
      requestHeaders: headers ?? {},
      requestBody: body,
      queryParameters: queryParameters,
    ));

    return InspectorLogHandle._(id, DateTime.now(), storeInstance);
  }

  /// Call when the request returns any HTTP response (success or error status).
  void complete({
    required int statusCode,
    dynamic responseBody,
    Map<String, dynamic>? responseHeaders,
  }) {
    _store.updateRecord(
      _id,
      statusCode: statusCode,
      responseBody: responseBody,
      responseHeaders: responseHeaders,
      duration: DateTime.now().difference(_startTime),
      errorMessage: statusCode >= 400 ? 'HTTP $statusCode' : null,
    );
  }

  /// Call when the request throws an exception (network error, timeout, etc.)
  void error(String message, {String? errorType, int? statusCode}) {
    _store.updateRecord(
      _id,
      statusCode: statusCode,
      duration: DateTime.now().difference(_startTime),
      errorMessage: message,
      errorType: errorType,
    );
  }
}
