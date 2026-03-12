// lib/src/adapters/io_adapter.dart
//
// Global dart:io HttpOverrides adapter.
// Hooks into dart:io at the process level so ALL HTTP traffic
// (http package, Dio, raw dart:io) is intercepted automatically.
// Developer only needs ONE call: HttpInspector.setup() in main.dart.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import '../http_record.dart';
import '../inspector_store.dart';
import 'base_adapter.dart';

/// Adapter that patches dart:io globally via [HttpOverrides.global].
///
/// All HTTP traffic (http package, Dio, raw dart:io) is intercepted
/// with zero changes at the call-site. Just call [attach] once at app start.
class IoAdapter extends BaseInspectorAdapter {
  HttpOverrides? _previous;

  @override
  String get adapterName => 'IO (global)';

  @override
  void attach() {
    _previous = HttpOverrides.current;
    HttpOverrides.global = _InspectorHttpOverrides(_previous);
  }

  @override
  void detach() {
    HttpOverrides.global = _previous;
    _previous = null;
  }
}

// ─────────────────────────────────────────────────────────
// HttpOverrides implementation
// ─────────────────────────────────────────────────────────

class _InspectorHttpOverrides extends HttpOverrides {
  final HttpOverrides? _parent;
  _InspectorHttpOverrides(this._parent);

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final inner = _parent != null
        ? _parent!.createHttpClient(context)
        : super.createHttpClient(context);
    return _InspectorIOClient(inner);
  }
}

// ─────────────────────────────────────────────────────────
// Wraps dart:io HttpClient — intercepts open/openUrl calls
// ─────────────────────────────────────────────────────────

class _InspectorIOClient implements HttpClient {
  final HttpClient _inner;
  _InspectorIOClient(this._inner);

  Future<HttpClientRequest> _wrap(
      Future<HttpClientRequest> reqFuture, String method, Uri url) async {
    final req = await reqFuture;
    return _InspectorIORequest(req, method, url);
  }

  @override
  Future<HttpClientRequest> open(
          String method, String host, int port, String path) =>
      _wrap(_inner.open(method, host, port, path), method.toUpperCase(),
          Uri(scheme: 'https', host: host, port: port, path: path));

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) =>
      _wrap(_inner.openUrl(method, url), method.toUpperCase(), url);

  @override
  Future<HttpClientRequest> get(String host, int port, String path) =>
      open('GET', host, port, path);

  @override
  Future<HttpClientRequest> getUrl(Uri url) => openUrl('GET', url);

  @override
  Future<HttpClientRequest> post(String host, int port, String path) =>
      open('POST', host, port, path);

  @override
  Future<HttpClientRequest> postUrl(Uri url) => openUrl('POST', url);

  @override
  Future<HttpClientRequest> put(String host, int port, String path) =>
      open('PUT', host, port, path);

  @override
  Future<HttpClientRequest> putUrl(Uri url) => openUrl('PUT', url);

  @override
  Future<HttpClientRequest> delete(String host, int port, String path) =>
      open('DELETE', host, port, path);

  @override
  Future<HttpClientRequest> deleteUrl(Uri url) => openUrl('DELETE', url);

  @override
  Future<HttpClientRequest> patch(String host, int port, String path) =>
      open('PATCH', host, port, path);

  @override
  Future<HttpClientRequest> patchUrl(Uri url) => openUrl('PATCH', url);

  @override
  Future<HttpClientRequest> head(String host, int port, String path) =>
      open('HEAD', host, port, path);

  @override
  Future<HttpClientRequest> headUrl(Uri url) => openUrl('HEAD', url);

  // ── Delegate configuration ────────────────────────────────────────

  @override
  bool get autoUncompress => _inner.autoUncompress;
  @override
  set autoUncompress(bool v) => _inner.autoUncompress = v;

  @override
  Duration? get connectionTimeout => _inner.connectionTimeout;
  @override
  set connectionTimeout(Duration? v) => _inner.connectionTimeout = v;

  @override
  Duration get idleTimeout => _inner.idleTimeout;
  @override
  set idleTimeout(Duration v) => _inner.idleTimeout = v;

  @override
  int? get maxConnectionsPerHost => _inner.maxConnectionsPerHost;
  @override
  set maxConnectionsPerHost(int? v) => _inner.maxConnectionsPerHost = v;

  @override
  String? get userAgent => _inner.userAgent;
  @override
  set userAgent(String? v) => _inner.userAgent = v;

  @override
  void addCredentials(
          Uri url, String realm, HttpClientCredentials credentials) =>
      _inner.addCredentials(url, realm, credentials);

  @override
  void addProxyCredentials(
          String host, int port, String realm, HttpClientCredentials creds) =>
      _inner.addProxyCredentials(host, port, realm, creds);

  @override
  set authenticate(Future<bool> Function(Uri, String, String?)? f) =>
      _inner.authenticate = f;

  @override
  set authenticateProxy(
          Future<bool> Function(String, int, String, String?)? f) =>
      _inner.authenticateProxy = f;

  @override
  set badCertificateCallback(bool Function(X509Certificate, String, int)? cb) =>
      _inner.badCertificateCallback = cb;

  @override
  set findProxy(String Function(Uri)? f) => _inner.findProxy = f;

  @override
  void close({bool force = false}) => _inner.close(force: force);

  @override
  set connectionFactory(
          Future<ConnectionTask<Socket>> Function(
                  Uri url, String? proxyHost, int? proxyPort)?
              f) =>
      _inner.connectionFactory = f;

  @override
  set keyLog(Function(String line)? callback) => _inner.keyLog = callback;
}

// ─────────────────────────────────────────────────────────
// Wraps dart:io HttpClientRequest
// Records on close() — the moment the request is actually sent
// ─────────────────────────────────────────────────────────

class _InspectorIORequest implements HttpClientRequest {
  final HttpClientRequest _inner;
  final String _method;
  final Uri _url;
  final InspectorStore _store = InspectorStore();
  final DateTime _startTime = DateTime.now();
  final String _id;
  final List<int> _bodyBytes = [];

  _InspectorIORequest(this._inner, this._method, this._url)
      : _id = '${DateTime.now().millisecondsSinceEpoch}_io';

  // ── body capture ─────────────────────────────────────────────────

  @override
  void add(List<int> data) {
    _bodyBytes.addAll(data);
    _inner.add(data);
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) =>
      _inner.addError(error, stackTrace);

  @override
  Future addStream(Stream<List<int>> stream) {
    final wrapped = stream.map((chunk) {
      _bodyBytes.addAll(chunk);
      return chunk;
    });
    return _inner.addStream(wrapped);
  }

  // ── interception point: called when request is sent ──────────────

  @override
  Future<HttpClientResponse> close() async {
    // Parse request body
    String? requestBodyStr;
    if (_bodyBytes.isNotEmpty) {
      try {
        requestBodyStr = utf8.decode(_bodyBytes, allowMalformed: true);
      } catch (_) {
        requestBodyStr = '[Binary: ${_bodyBytes.length} bytes]';
      }
    }

    // Collect request headers
    final reqHeaders = <String, dynamic>{};
    _inner.headers.forEach((name, values) {
      reqHeaders[name] = values.join(', ');
    });

    // Add pending record to store immediately (shows request in-flight)
    _store.addRecord(HttpRecord(
      id: _id,
      timestamp: _startTime,
      method: _method,
      url: _url.toString().split('?').first,
      requestHeaders: reqHeaders,
      requestBody: requestBodyStr,
      queryParameters:
          _url.queryParameters.isNotEmpty ? _url.queryParameters : null,
    ));

    try {
      final response = await _inner.close();
      final duration = DateTime.now().difference(_startTime);

      // Collect response headers
      final respHeaders = <String, dynamic>{};
      response.headers.forEach((name, values) {
        respHeaders[name] = values.join(', ');
      });

      // Buffer the response body so both we and the caller can read it
      final bytes = <int>[];
      await for (final chunk in response) {
        bytes.addAll(chunk);
      }

      String? responseBodyStr;
      try {
        responseBodyStr = utf8.decode(bytes, allowMalformed: true);
      } catch (_) {
        responseBodyStr = '[Binary: ${bytes.length} bytes]';
      }

      _store.updateRecord(
        _id,
        statusCode: response.statusCode,
        responseBody: responseBodyStr,
        responseHeaders: respHeaders,
        duration: duration,
        errorMessage:
            response.statusCode >= 400 ? 'HTTP ${response.statusCode}' : null,
      );

      // Return a replay response so the real caller can still read it
      return _ReplayHttpClientResponse(response, Uint8List.fromList(bytes));
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

  // ── delegate remaining members ───────────────────────────────────

  @override
  void abort([Object? exception, StackTrace? stackTrace]) =>
      _inner.abort(exception, stackTrace);

  @override
  bool get bufferOutput => _inner.bufferOutput;
  @override
  set bufferOutput(bool v) => _inner.bufferOutput = v;

  @override
  int get contentLength => _inner.contentLength;
  @override
  set contentLength(int v) => _inner.contentLength = v;

  @override
  Encoding get encoding => _inner.encoding;
  @override
  set encoding(Encoding v) => _inner.encoding = v;

  @override
  bool get followRedirects => _inner.followRedirects;
  @override
  set followRedirects(bool v) => _inner.followRedirects = v;

  @override
  int get maxRedirects => _inner.maxRedirects;
  @override
  set maxRedirects(int v) => _inner.maxRedirects = v;

  @override
  bool get persistentConnection => _inner.persistentConnection;
  @override
  set persistentConnection(bool v) => _inner.persistentConnection = v;

  @override
  HttpConnectionInfo? get connectionInfo => _inner.connectionInfo;

  @override
  List<Cookie> get cookies => _inner.cookies;

  @override
  Future<HttpClientResponse> get done => _inner.done;

  @override
  HttpHeaders get headers => _inner.headers;

  @override
  String get method => _inner.method;

  @override
  Uri get uri => _inner.uri;

  @override
  Future flush() => _inner.flush();

  @override
  void write(Object? object) => _inner.write(object);

  @override
  void writeln([Object? object = '']) => _inner.writeln(object);

  @override
  void writeAll(Iterable objects, [String separator = '']) =>
      _inner.writeAll(objects, separator);

  @override
  void writeCharCode(int charCode) => _inner.writeCharCode(charCode);
}

// ─────────────────────────────────────────────────────────
// Replay response — wraps already-consumed bytes so the
// caller can still read the body after we buffered it
// ─────────────────────────────────────────────────────────

class _ReplayHttpClientResponse extends Stream<List<int>>
    implements HttpClientResponse {
  final HttpClientResponse _original;
  final List<int> _bytes;

  _ReplayHttpClientResponse(this._original, this._bytes);

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream.fromIterable([_bytes]).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  X509Certificate? get certificate => _original.certificate;

  @override
  HttpClientResponseCompressionState get compressionState =>
      _original.compressionState;

  @override
  HttpConnectionInfo? get connectionInfo => _original.connectionInfo;

  @override
  int get contentLength => _bytes.length;

  @override
  List<Cookie> get cookies => _original.cookies;

  @override
  Future<Socket> detachSocket() => _original.detachSocket();

  @override
  HttpHeaders get headers => _original.headers;

  @override
  bool get isRedirect => _original.isRedirect;

  @override
  bool get persistentConnection => _original.persistentConnection;

  @override
  String get reasonPhrase => _original.reasonPhrase;

  @override
  Future<HttpClientResponse> redirect([
    String? method,
    Uri? url,
    bool? followLoops,
  ]) =>
      _original.redirect(method, url, followLoops);

  @override
  List<RedirectInfo> get redirects => _original.redirects;

  @override
  int get statusCode => _original.statusCode;
}
