// lib/src/adapters/dio_adapter.dart
import 'package:dio/dio.dart';
import '../http_inspector_interceptor.dart';
import 'base_adapter.dart';

/// Adapter for Dio. Attaches [HttpInspectorInterceptor] automatically.
class DioAdapter extends BaseInspectorAdapter {
  final Dio dio;

  DioAdapter(this.dio);

  @override
  String get adapterName => 'Dio';

  @override
  void attach() {
    // Remove any existing inspector interceptor to avoid duplicates
    dio.interceptors.removeWhere((i) => i is HttpInspectorInterceptor);
    dio.interceptors.add(HttpInspectorInterceptor());
  }

  @override
  void detach() {
    dio.interceptors.removeWhere((i) => i is HttpInspectorInterceptor);
  }
}
