/// flutter_http_inspector
///
/// A developer overlay for Flutter apps that captures HTTP requests,
/// shows errors, and generates cURL commands.
///
/// Supports Dio, http package, and any custom HTTP client.
library flutter_http_inspector;

// Overlay widget — wrap your app with this
export 'src/inspector_overlay.dart' show HttpInspectorOverlay;

// Main factory — call HttpInspector.setup() once at app start
export 'src/http_inspector.dart' show HttpInspector;

// Adapters
export 'src/adapters/base_adapter.dart' show BaseInspectorAdapter;
export 'src/adapters/dio_adapter.dart' show DioAdapter;
export 'src/adapters/http_adapter.dart'
    show HttpAdapter, InspectorHttpClient, InspectorMultipartRequest;
export 'src/adapters/io_adapter.dart' show IoAdapter;
export 'src/adapters/manual_adapter.dart'
    show ManualAdapter, InspectorLogHandle;

// Screens (if you want to push them manually)
export 'src/screens/request_list_screen.dart' show RequestListScreen;
export 'src/screens/request_detail_screen.dart' show RequestDetailScreen;

// Data
export 'src/inspector_store.dart' show InspectorStore;
export 'src/http_record.dart' show HttpRecord;

// Legacy — direct Dio interceptor still works
export 'src/http_inspector_interceptor.dart' show HttpInspectorInterceptor;
