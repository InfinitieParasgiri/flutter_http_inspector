// lib/src/adapters/base_adapter.dart

/// Base class all HTTP client adapters implement.
abstract class BaseInspectorAdapter {
  /// Human-readable adapter name shown in debug logs.
  String get adapterName;

  /// Attach the adapter to the HTTP client. Called once on setup.
  void attach();

  /// Detach / cleanup. Called on dispose.
  void detach() {}
}
