// lib/src/adapters/http_adapter.dart
import 'package:http/http.dart' as http;
import '../http_record.dart';
import '../inspector_store.dart';
import 'base_adapter.dart';

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
      body = '[Multipart Form Data]';
    }

    _store.addRecord(HttpRecord(
      id: id,
      timestamp: DateTime.now(),
      method: request.method.toUpperCase(),
      url: request.url.toString().split('?').first,
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
