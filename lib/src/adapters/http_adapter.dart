// lib/src/adapters/http_adapter.dart
import 'package:http/http.dart' as http;
import '../http_record.dart';
import '../inspector_store.dart';
import 'base_adapter.dart';

/// Drop-in replacement for [http.MultipartRequest] that auto-logs to inspector.
///
/// Just replace [http.MultipartRequest] with [InspectorMultipartRequest] —
/// no other changes needed in your project.
///
/// ```dart
/// // ❌ Before
/// var request = http.MultipartRequest('POST', url);
///
/// // ✅ After — one word change, everything else stays the same
/// var request = InspectorMultipartRequest('POST', url);
/// ```
class InspectorMultipartRequest extends http.MultipartRequest {
  final InspectorStore _store = InspectorStore();
  final DateTime _startTime = DateTime.now();
  late final String _id;

  InspectorMultipartRequest(super.method, super.url) {
    _id = '${DateTime.now().millisecondsSinceEpoch}_multipart';
  }

  @override
  Future<http.StreamedResponse> send() async {
    // Build readable body from fields + files
    final body = <String, dynamic>{};
    fields.forEach((k, v) => body[k] = v);
    for (final file in files) {
      body[file.field] =
          '[File: ${file.filename ?? file.field}, Size: ${file.length} bytes]';
    }

    // Build headers map
    final hdrs = <String, dynamic>{};
    headers.forEach((k, v) => hdrs[k] = v);

    _store.addRecord(HttpRecord(
      id: _id,
      timestamp: _startTime,
      method: method.toUpperCase(),
      url: url.toString().split('?').first,
      requestHeaders: hdrs,
      requestBody: body,
      queryParameters: url.queryParameters,
    ));

    try {
      final response = await super.send();
      final duration = DateTime.now().difference(_startTime);

      final responseHeaders = <String, dynamic>{};
      response.headers.forEach((k, v) => responseHeaders[k] = v);

      // Buffer stream so we can read body AND still return it
      final bytes = await response.stream.toBytes();
      String? responseBody;
      try {
        responseBody = String.fromCharCodes(bytes);
      } catch (_) {
        responseBody = '[Binary: ${bytes.length} bytes]';
      }

      _store.updateRecord(
        _id,
        statusCode: response.statusCode,
        responseBody: responseBody,
        responseHeaders: responseHeaders,
        duration: duration,
        errorMessage:
            response.statusCode >= 400 ? 'HTTP ${response.statusCode}' : null,
      );

      return http.StreamedResponse(
        http.ByteStream.fromBytes(bytes),
        response.statusCode,
        headers: response.headers,
        reasonPhrase: response.reasonPhrase,
        request: response.request,
        contentLength: response.contentLength,
        isRedirect: response.isRedirect,
        persistentConnection: response.persistentConnection,
      );
    } catch (e) {
      _store.updateRecord(
        _id,
        duration: DateTime.now().difference(_startTime),
        errorMessage: e.toString(),
        errorType: e.runtimeType.toString(),
      );
      rethrow;
    }
  }
}

/// Adapter for the `http` package.
/// Wraps any [http.Client] with an [InspectorHttpClient].
class HttpAdapter extends BaseInspectorAdapter {
  final http.Client _inner;
  late final InspectorHttpClient _client;

  HttpAdapter(this._inner);

  /// The wrapped client — use this in place of your original http.Client.
  InspectorHttpClient get client => _client;

  @override
  String get adapterName => 'http';

  @override
  void attach() {
    _client = InspectorHttpClient(_inner);
  }

  @override
  void detach() {
    _client.close();
  }
}

/// Drop-in replacement for [http.Client] that logs all requests to
/// [InspectorStore]. Use via [HttpInspector.setupHttp].
class InspectorHttpClient extends http.BaseClient {
  final http.Client _inner;
  final InspectorStore _store;

  InspectorHttpClient(this._inner, {InspectorStore? store})
      : _store = store ?? InspectorStore();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final id = '${DateTime.now().millisecondsSinceEpoch}';
    final startTime = DateTime.now();

    final headers = <String, dynamic>{};
    request.headers.forEach((k, v) => headers[k] = v);

    dynamic body;
    if (request is http.Request) {
      body = request.body.isNotEmpty ? request.body : null;
    } else if (request is http.MultipartRequest) {
      // Parse multipart fields into readable map
      final data = <String, dynamic>{};
      request.fields.forEach((k, v) => data[k] = v);
      for (final file in request.files) {
        data[file.field] =
            '[File: ${file.filename ?? file.field}, Size: ${file.length} bytes]';
      }
      body = data;
    }

    _store.addRecord(HttpRecord(
      id: id,
      timestamp: DateTime.now(),
      method: request.method.toUpperCase(),
      url: request.url.toString(),
      requestHeaders: headers,
      requestBody: body,
      queryParameters: request.url.queryParameters,
    ));

    try {
      final response = await _inner.send(request);
      final duration = DateTime.now().difference(startTime);

      final responseHeaders = <String, dynamic>{};
      response.headers.forEach((k, v) => responseHeaders[k] = v);

      // Buffer stream so we can both read body AND return it
      final bytes = await response.stream.toBytes();
      String? responseBody;
      try {
        responseBody = String.fromCharCodes(bytes);
      } catch (_) {
        responseBody = '[Binary data: ${bytes.length} bytes]';
      }

      _store.updateRecord(
        id,
        statusCode: response.statusCode,
        responseBody: responseBody,
        responseHeaders: responseHeaders,
        duration: duration,
        errorMessage:
            response.statusCode >= 400 ? 'HTTP ${response.statusCode}' : null,
      );

      return http.StreamedResponse(
        http.ByteStream.fromBytes(bytes),
        response.statusCode,
        headers: response.headers,
        reasonPhrase: response.reasonPhrase,
        request: response.request,
        contentLength: response.contentLength,
        isRedirect: response.isRedirect,
        persistentConnection: response.persistentConnection,
      );
    } catch (e) {
      _store.updateRecord(
        id,
        duration: DateTime.now().difference(startTime),
        errorMessage: e.toString(),
        errorType: e.runtimeType.toString(),
      );
      rethrow;
    }
  }
}
