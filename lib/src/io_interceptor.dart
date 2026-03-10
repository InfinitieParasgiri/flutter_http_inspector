// lib/src/io_interceptor.dart
import 'dart:async';
import 'dart:io';
import 'http_record.dart';
import 'inspector_store.dart';

/// Installs a global [HttpOverrides] that intercepts every HTTP request
/// in the app — regardless of whether the project uses Dio, http, dart:io,
/// or any other client.
///
/// Called automatically inside [HttpInspectorOverlay.initState].
/// The developer does NOT need to call anything.
void installHttpOverrides() {
  HttpOverrides.global = _InspectorHttpOverrides(
    previous: HttpOverrides.current,
  );
}

class _InspectorHttpOverrides extends HttpOverrides {
  final HttpOverrides? previous;
  _InspectorHttpOverrides({this.previous});

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final inner = previous != null
        ? previous!.createHttpClient(context)
        : super.createHttpClient(context);
    return _InspectorHttpClient(inner);
  }
}

/// Wraps [HttpClient] to intercept every request/response.
class _InspectorHttpClient implements HttpClient {
  final HttpClient _inner;
  final InspectorStore _store = InspectorStore();

  _InspectorHttpClient(this._inner);

  // ── Intercept all open methods ───────────────────────────

  @override
  Future<HttpClientRequest> open(
      String method, String host, int port, String path) async {
    final req = await _inner.open(method, host, port, path);
    return _InspectorRequest(req, _store);
  }

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    final req = await _inner.openUrl(method, url);
    return _InspectorRequest(req, _store);
  }

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

  // ── Delegate all config to inner ────────────────────────

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
  void addProxyCredentials(String host, int port, String realm,
          HttpClientCredentials credentials) =>
      _inner.addProxyCredentials(host, port, realm, credentials);

  @override
  set authenticate(
          Future<bool> Function(Uri url, String scheme, String? realm)? f) =>
      _inner.authenticate = f;

  @override
  set authenticateProxy(
          Future<bool> Function(
                  String host, int port, String scheme, String? realm)?
              f) =>
      _inner.authenticateProxy = f;

  @override
  set badCertificateCallback(
          bool Function(X509Certificate cert, String host, int port)?
              callback) =>
      _inner.badCertificateCallback = callback;

  @override
  set findProxy(String Function(Uri url)? f) => _inner.findProxy = f;

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

/// Wraps [HttpClientRequest] to capture the body and intercept the response.
class _InspectorRequest implements HttpClientRequest {
  final HttpClientRequest _inner;
  final InspectorStore _store;
  final String _id;
  final DateTime _startTime = DateTime.now();

  _InspectorRequest(this._inner, this._store)
      : _id = '${DateTime.now().millisecondsSinceEpoch}_io';

  @override
  Future<HttpClientResponse> close() async {
    // Record the request
    final headers = <String, dynamic>{};
    _inner.headers.forEach((name, values) {
      headers[name] = values.join(', ');
    });

    _store.addRecord(HttpRecord(
      id: _id,
      timestamp: _startTime,
      method: _inner.method,
      url: _inner.uri.toString().split('?').first,
      requestHeaders: headers,
      queryParameters: _inner.uri.queryParameters,
    ));

    try {
      final response = await _inner.close();
      final duration = DateTime.now().difference(_startTime);

      // Read response headers
      final responseHeaders = <String, dynamic>{};
      response.headers.forEach((name, values) {
        responseHeaders[name] = values.join(', ');
      });

      // Buffer the response body
      final bytes = await response.fold<List<int>>(
        [],
        (prev, chunk) => prev..addAll(chunk),
      );

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
        errorMessage: response.statusCode >= 400
            ? 'HTTP ${response.statusCode}'
            : null,
      );

      // Return a replay-able response
      return _ReplayResponse(response, bytes);
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

  // ── Delegate everything else to inner ───────────────────

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
  HttpHeaders get headers => _inner.headers;

  @override
  String get method => _inner.method;

  @override
  Uri get uri => _inner.uri;

  @override
  void add(List<int> data) => _inner.add(data);

  @override
  void addError(Object error, [StackTrace? stackTrace]) =>
      _inner.addError(error, stackTrace);

  @override
  Future addStream(Stream<List<int>> stream) => _inner.addStream(stream);

  @override
  Future<void> flush() => _inner.flush();

  @override
  Future abort([Object? exception, StackTrace? stackTrace]) =>
      _inner.abort(exception, stackTrace);

  @override
  HttpConnectionInfo? get connectionInfo => _inner.connectionInfo;

  @override
  List<Cookie> get cookies => _inner.cookies;

  @override
  Future<HttpClientResponse> get done => _inner.done;

  @override
  void write(Object? obj) => _inner.write(obj);

  @override
  void writeAll(Iterable objects, [String separator = '']) =>
      _inner.writeAll(objects, separator);

  @override
  void writeCharCode(int charCode) => _inner.writeCharCode(charCode);

  @override
  void writeln([Object? obj = '']) => _inner.writeln(obj);
}

/// A [HttpClientResponse] that replays already-buffered bytes.
class _ReplayResponse extends Stream<List<int>> implements HttpClientResponse {
  final HttpClientResponse _original;
  final List<int> _bytes;

  _ReplayResponse(this._original, this._bytes);

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

  // Delegate everything to original response
  @override int get statusCode => _original.statusCode;
  @override String get reasonPhrase => _original.reasonPhrase;
  @override int get contentLength => _original.contentLength;
  @override HttpHeaders get headers => _original.headers;
  @override bool get isRedirect => _original.isRedirect;
  @override bool get persistentConnection => _original.persistentConnection;
  @override List<Cookie> get cookies => _original.cookies;
  @override HttpConnectionInfo? get connectionInfo => _original.connectionInfo;
  @override Future<Socket> detachSocket() => _original.detachSocket();
  @override Future<HttpClientResponse> redirect([String? method, Uri? url, bool? followLoops]) =>
      _original.redirect(method, url, followLoops);
  @override List<RedirectInfo> get redirects => _original.redirects;
  @override X509Certificate? get certificate => _original.certificate;
  @override
  Future<bool> any(bool Function(List<int> element) test) => _original.any(test);
  @override
  Stream<List<int>> asBroadcastStream({void Function(StreamSubscription<List<int>> subscription)? onListen, void Function(StreamSubscription<List<int>> subscription)? onCancel}) =>
      _original.asBroadcastStream(onListen: onListen, onCancel: onCancel);
  @override
  Stream<E> asyncExpand<E>(Stream<E>? Function(List<int> event) convert) => _original.asyncExpand(convert);
  @override
  Stream<E> asyncMap<E>(FutureOr<E> Function(List<int> event) convert) => _original.asyncMap(convert);
  @override
  Stream<R> cast<R>() => _original.cast<R>();
  @override
  Future<bool> contains(Object? needle) => _original.contains(needle);
  @override
  Stream<List<int>> distinct([bool Function(List<int> previous, List<int> next)? equals]) => _original.distinct(equals);
  @override
  Future<E> drain<E>([E? futureValue]) => _original.drain(futureValue);
  @override
  Future<List<int>> elementAt(int index) => _original.elementAt(index);
  @override
  Future<bool> every(bool Function(List<int> element) test) => _original.every(test);
  @override
  Stream<S> expand<S>(Iterable<S> Function(List<int> element) convert) => _original.expand(convert);
  @override
  Future<List<int>> get first => _original.first;
  @override
  Future<List<int>> firstWhere(bool Function(List<int> element) test, {List<int> Function()? orElse}) =>
      _original.firstWhere(test, orElse: orElse);
  @override
  Future<S> fold<S>(S initialValue, S Function(S previous, List<int> element) combine) =>
      _original.fold(initialValue, combine);
  @override
  Future<void> forEach(void Function(List<int> element) action) => _original.forEach(action);
  @override
  Stream<List<int>> handleError(Function onError, {bool Function(dynamic error)? test}) =>
      _original.handleError(onError, test: test);
  @override
  bool get isBroadcast => _original.isBroadcast;
  @override
  Future<bool> get isEmpty => _original.isEmpty;
  @override
  Future<String> join([String separator = '']) => _original.join(separator);
  @override
  Future<List<int>> get last => _original.last;
  @override
  Future<List<int>> lastWhere(bool Function(List<int> element) test, {List<int> Function()? orElse}) =>
      _original.lastWhere(test, orElse: orElse);
  @override
  Future<int> get length => _original.length;
  @override
  Stream<S> map<S>(S Function(List<int> event) convert) => _original.map(convert);
  @override
  Future<dynamic> pipe(StreamConsumer<List<int>> streamConsumer) => _original.pipe(streamConsumer);
  @override
  Future<List<int>> reduce(List<int> Function(List<int> previous, List<int> element) combine) =>
      _original.reduce(combine);
  @override
  Future<List<int>> get single => _original.single;
  @override
  Future<List<int>> singleWhere(bool Function(List<int> element) test, {List<int> Function()? orElse}) =>
      _original.singleWhere(test, orElse: orElse);
  @override
  Stream<List<int>> skip(int count) => _original.skip(count);
  @override
  Stream<List<int>> skipWhile(bool Function(List<int> element) test) => _original.skipWhile(test);
  @override
  Stream<List<int>> take(int count) => _original.take(count);
  @override
  Stream<List<int>> takeWhile(bool Function(List<int> element) test) => _original.takeWhile(test);
  @override
  Stream<List<int>> timeout(Duration timeLimit, {void Function(EventSink<List<int>> sink)? onTimeout}) =>
      _original.timeout(timeLimit, onTimeout: onTimeout);
  @override
  Future<List<List<int>>> toList() => _original.toList();
  @override
  Future<Set<List<int>>> toSet() => _original.toSet();
  @override
  Stream<S> transform<S>(StreamTransformer<List<int>, S> streamTransformer) =>
      _original.transform(streamTransformer);
  @override
  Stream<List<int>> where(bool Function(List<int> event) test) => _original.where(test);
}
