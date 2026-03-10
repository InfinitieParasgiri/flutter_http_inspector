// lib/src/http_inspector_interceptor.dart
import 'package:dio/dio.dart';
import 'http_record.dart';
import 'inspector_store.dart';

/// Dio interceptor that captures all requests, responses, and errors.
/// Added automatically when you call HttpInspector.setup(dio: myDio).
class HttpInspectorInterceptor extends Interceptor {
  final InspectorStore _store;
  final _startTimes = <String, DateTime>{};

  HttpInspectorInterceptor({InspectorStore? store})
      : _store = store ?? InspectorStore();

  String _generateId() =>
      '${DateTime.now().millisecondsSinceEpoch}_${_startTimes.length}';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final id = _generateId();
    options.extra['inspector_id'] = id;
    _startTimes[id] = DateTime.now();

    final headers = <String, dynamic>{};
    options.headers.forEach((k, v) => headers[k] = v);
    if (options.data != null && !headers.containsKey('Content-Type')) {
      headers['Content-Type'] = options.contentType ?? 'application/json';
    }

    _store.addRecord(HttpRecord(
      id: id,
      timestamp: DateTime.now(),
      method: options.method.toUpperCase(),
      url: options.uri.toString().split('?').first,
      requestHeaders: headers,
      requestBody: options.data,
      queryParameters:
          options.queryParameters.map((k, v) => MapEntry(k, v.toString())),
    ));

    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final id = response.requestOptions.extra['inspector_id'] as String?;
    if (id != null) {
      final responseHeaders = <String, dynamic>{};
      response.headers.map.forEach((k, v) => responseHeaders[k] = v.join(', '));
      _store.updateRecord(
        id,
        statusCode: response.statusCode,
        responseBody: response.data,
        responseHeaders: responseHeaders,
        duration: _calcDuration(id),
      );
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final id = err.requestOptions.extra['inspector_id'] as String?;
    if (id != null) {
      _store.updateRecord(
        id,
        statusCode: err.response?.statusCode,
        responseBody: err.response?.data,
        duration: _calcDuration(id),
        errorMessage: _getErrorMessage(err),
        errorType: err.type.name,
      );
    }
    handler.next(err);
  }

  Duration? _calcDuration(String id) {
    final start = _startTimes.remove(id);
    return start == null ? null : DateTime.now().difference(start);
  }

  String _getErrorMessage(DioException err) {
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
        return 'Connection timed out';
      case DioExceptionType.sendTimeout:
        return 'Send timed out';
      case DioExceptionType.receiveTimeout:
        return 'Receive timed out';
      case DioExceptionType.badResponse:
        return 'Bad response: ${err.response?.statusCode}';
      case DioExceptionType.cancel:
        return 'Request cancelled';
      case DioExceptionType.connectionError:
        return 'Connection error: ${err.message}';
      default:
        return err.message ?? 'Unknown error';
    }
  }
}
