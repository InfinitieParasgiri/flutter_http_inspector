// lib/src/http_record.dart

/// Represents a single HTTP request/response pair captured by the inspector.
class HttpRecord {
  final String id;
  final DateTime timestamp;
  final String method;
  final String url;
  final Map<String, dynamic> requestHeaders;
  final dynamic requestBody;
  final Map<String, String>? queryParameters;

  int? statusCode;
  dynamic responseBody;
  Map<String, dynamic>? responseHeaders;
  Duration? duration;
  String? errorMessage;
  String? errorType;
  bool isLoading;

  HttpRecord({
    required this.id,
    required this.timestamp,
    required this.method,
    required this.url,
    required this.requestHeaders,
    this.requestBody,
    this.queryParameters,
    this.statusCode,
    this.responseBody,
    this.responseHeaders,
    this.duration,
    this.errorMessage,
    this.errorType,
    this.isLoading = true,
  });

  bool get isError =>
      errorMessage != null || (statusCode != null && statusCode! >= 400);

  bool get isSuccess => !isError && statusCode != null && statusCode! < 400;

  String get statusLabel {
    if (isLoading) return 'PENDING';
    if (errorMessage != null && statusCode == null) return 'ERROR';
    return statusCode?.toString() ?? 'UNKNOWN';
  }

  /// Generates a ready-to-run cURL command for this request.
  String toCurl() {
    final buffer = StringBuffer();

    // ── Build full URL with query params ──────────────────────────────
    String fullUrl = url;
    if (queryParameters != null && queryParameters!.isNotEmpty) {
      final query = queryParameters!.entries
          .map((e) =>
              '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
          .join('&');
      fullUrl = '$url?$query';
    }

    // ── Detect multipart content-type ─────────────────────────────────
    final contentType = requestHeaders.entries
        .firstWhere(
          (e) => e.key.toLowerCase() == 'content-type',
          orElse: () => const MapEntry('', ''),
        )
        .value
        .toString()
        .toLowerCase();
    final isMultipart = contentType.contains('multipart/form-data');

    // ── Headers to skip (internal Dart/HTTP noise) ────────────────────
    const skipHeaders = {
      'user-agent',
      'content-length',
      'accept-encoding',
      'host',
    };

    // ── cURL line ─────────────────────────────────────────────────────
    buffer.write('curl "${_esc(fullUrl)}"');

    if (method != 'GET' && method != 'HEAD') {
      buffer.write(' \\\n  -X $method');
    }

    // ── Headers ───────────────────────────────────────────────────────
    requestHeaders.forEach((key, value) {
      final lk = key.toLowerCase();
      if (skipHeaders.contains(lk)) return;
      if (isMultipart && lk == 'content-type') return; // -F implies it
      buffer.write(' \\\n  -H "${_esc(key)}: ${_esc(value.toString())}"');
    });

    // ── Body ──────────────────────────────────────────────────────────
    if (isMultipart) {
      final fields =
          _parseMultipartFields(requestBody?.toString() ?? '', contentType);
      for (final e in fields.entries) {
        buffer.write(' \\\n  -F "${_esc(e.key)}=${_esc(e.value)}"');
      }
    } else if (requestBody != null) {
      final bodyStr = requestBody is String
          ? requestBody as String
          : requestBody.toString();
      if (bodyStr.isNotEmpty) {
        buffer.write(' \\\n  -d "${_esc(bodyStr)}"');
      }
    }

    return buffer.toString();
  }

  String _esc(String s) => s.replaceAll('"', r'\"');

  /// Parses raw multipart/form-data wire bytes back into a key→value map.
  Map<String, String> _parseMultipartFields(
      String rawBody, String contentType) {
    final boundaryMatch = RegExp(r'boundary=([^\s;]+)', caseSensitive: false)
        .firstMatch(contentType);
    if (boundaryMatch == null) return {};

    final boundary = '--${boundaryMatch.group(1)!}';
    final result = <String, String>{};

    final parts =
        rawBody.split(RegExp('${RegExp.escape(boundary)}(--)?\r?\n?'));
    for (final part in parts) {
      if (part.trim().isEmpty || part.trim() == '--') continue;

      // Split headers from body on blank line
      final sep = part.contains('\r\n\r\n')
          ? '\r\n\r\n'
          : (part.contains('\n\n') ? '\n\n' : null);
      if (sep == null) continue;

      final idx = part.indexOf(sep);
      final header = part.substring(0, idx);
      final value = part.substring(idx + sep.length).trim();

      final nameMatch = RegExp(r'name="([^"]+)"').firstMatch(header);
      final isFile = header.contains('filename=');
      if (nameMatch != null && !isFile && value.isNotEmpty) {
        result[nameMatch.group(1)!] = value;
      }
    }
    return result;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'method': method,
        'url': url,
        'requestHeaders': requestHeaders,
        'requestBody': requestBody?.toString(),
        'statusCode': statusCode,
        'responseBody': responseBody?.toString(),
        'duration': duration?.inMilliseconds,
        'errorMessage': errorMessage,
        'errorType': errorType,
      };
}
