// lib/src/inspector_store.dart
import 'package:flutter/foundation.dart';
import 'http_record.dart';

/// Singleton in-memory store holding all captured HTTP records.
class InspectorStore extends ChangeNotifier {
  static final InspectorStore _instance = InspectorStore._internal();
  factory InspectorStore() => _instance;
  InspectorStore._internal();

  final List<HttpRecord> _records = [];
  int _maxRecords = 100;

  List<HttpRecord> get records => List.unmodifiable(_records);
  int get totalCount => _records.length;
  int get errorCount => _records.where((r) => r.isError).length;
  int get pendingCount => _records.where((r) => r.isLoading).length;

  void setMaxRecords(int max) => _maxRecords = max;

  void addRecord(HttpRecord record) {
    _records.insert(0, record);
    if (_records.length > _maxRecords) _records.removeLast();
    notifyListeners();
  }

  void updateRecord(
    String id, {
    int? statusCode,
    dynamic responseBody,
    Map<String, dynamic>? responseHeaders,
    Duration? duration,
    String? errorMessage,
    String? errorType,
  }) {
    final index = _records.indexWhere((r) => r.id == id);
    if (index == -1) return;
    final r = _records[index];
    r.isLoading = false;
    if (statusCode != null) r.statusCode = statusCode;
    if (responseBody != null) r.responseBody = responseBody;
    if (responseHeaders != null) r.responseHeaders = responseHeaders;
    if (duration != null) r.duration = duration;
    if (errorMessage != null) r.errorMessage = errorMessage;
    if (errorType != null) r.errorType = errorType;
    notifyListeners();
  }

  void clearAll() {
    _records.clear();
    notifyListeners();
  }

  HttpRecord? findById(String id) {
    try {
      return _records.firstWhere((r) => r.id == id);
    } catch (_) {
      return null;
    }
  }
}
