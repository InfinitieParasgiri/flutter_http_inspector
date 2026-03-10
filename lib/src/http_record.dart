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

  bool get isSuccess =>
      !isError && statusCode != null && statusCode! < 400;

  String get statusLabel {
    if (isLoading) return 'PENDING';
    if (errorMessage != null && statusCode == null) return 'ERROR';
    return statusCode?.toString() ?? 'UNKNOWN';
  }

  /// Generates a ready-to-run cURL command for this request.
  String toCurl() {
    final buffer = StringBuffer();
    buffer.write('curl -X $method');

    requestHeaders.forEach((key, value) {
      final escaped = value.toString().replaceAll("'", "'\\''");
      buffer.write(" \\\n  -H '$key: $escaped'");
    });

    if (requestBody != null) {
      final bodyStr = requestBody is String
          ? requestBody as String
          : requestBody.toString();
      final escaped = bodyStr.replaceAll("'", "'\\''");
      buffer.write(" \\\n  -d '$escaped'");
    }

    String fullUrl = url;
    if (queryParameters != null && queryParameters!.isNotEmpty) {
      final query = queryParameters!.entries
          .map((e) =>
              '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
          .join('&');
      fullUrl = '$url?$query';
    }

    buffer.write(" \\\n  '$fullUrl'");
    return buffer.toString();
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
