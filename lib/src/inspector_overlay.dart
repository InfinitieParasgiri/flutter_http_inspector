// lib/src/inspector_overlay.dart
import 'package:flutter/material.dart';
import 'inspector_store.dart';
import 'screens/request_list_screen.dart';

/// Wrap your root app widget with this to show the floating inspector button.
///
/// ```dart
/// void main() {
///   runApp(
///     HttpInspectorOverlay(
///       enabled: kDebugMode,
///       child: MyApp(),
///     ),
///   );
/// }
/// ```
class HttpInspectorOverlay extends StatefulWidget {
  final Widget child;

  /// Set to false to completely hide the overlay (e.g. in release builds).
  /// Tip: use `enabled: kDebugMode` to auto-hide in production.
  final bool enabled;

  /// Where the floating button starts on screen.
  final Offset initialOffset;

  /// Custom button color. If null, color changes based on request state.
  final Color? buttonColor;

  const HttpInspectorOverlay({
    super.key,
    required this.child,
    this.enabled = true,
    this.initialOffset = const Offset(20, 100),
    this.buttonColor,
  });

  @override
  State<HttpInspectorOverlay> createState() => _HttpInspectorOverlayState();
}

class _HttpInspectorOverlayState extends State<HttpInspectorOverlay>
    with SingleTickerProviderStateMixin {
  final _store = InspectorStore();
  late Offset _offset;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _offset = widget.initialOffset;
    _store.addListener(_onStoreChanged);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.18).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _store.removeListener(_onStoreChanged);
    _pulseController.dispose();
    super.dispose();
  }

  void _onStoreChanged() {
    if (!mounted) return;
    setState(() {});
    if (_store.records.isNotEmpty && _store.records.first.isError) {
      _pulseController.forward(from: 0).then((_) => _pulseController.reverse());
    }
  }

  void _openInspector() {
    // Since this might be above MaterialApp, Navigator.of(context) might fail if
    // not used with MaterialApp.builder.

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Inspector',
      barrierColor: Colors.black54,
      pageBuilder: (context, anim, __) => Directionality(
        textDirection: TextDirection.ltr,
        child: Material(
          type: MaterialType.transparency,
          child: const _InspectorModal(),
        ),
      ),
      transitionBuilder: (context, anim, __, child) => SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 1),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        textDirection: TextDirection.ltr,
        children: [
          widget.child,
          _OverlayPositioned(
            initialOffset: _offset,
            onOffsetChanged: (newOffset) => setState(() => _offset = newOffset),
            onTap: _openInspector,
            pulseAnimation: _pulseAnimation,
            store: _store,
            buttonColor: widget.buttonColor,
          ),
        ],
      ),
    );
  }
}

class _OverlayPositioned extends StatefulWidget {
  final Offset initialOffset;
  final ValueChanged<Offset> onOffsetChanged;
  final VoidCallback onTap;
  final Animation<double> pulseAnimation;
  final InspectorStore store;
  final Color? buttonColor;

  const _OverlayPositioned({
    required this.initialOffset,
    required this.onOffsetChanged,
    required this.onTap,
    required this.pulseAnimation,
    required this.store,
    this.buttonColor,
  });

  @override
  State<_OverlayPositioned> createState() => _OverlayPositionedState();
}

class _OverlayPositionedState extends State<_OverlayPositioned> {
  late Offset _offset;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _offset = widget.initialOffset;
  }

  @override
  Widget build(BuildContext context) {
    // Attempt to get size from MediaQuery if available, else use full screen
    final size = MediaQuery.maybeOf(context)?.size ??
        const Size(1000, 2000); // Fallback to large size if no context

    return Positioned(
      left: _offset.dx,
      top: _offset.dy,
      child: GestureDetector(
        onPanStart: (_) => setState(() => _isDragging = true),
        onPanUpdate: (d) {
          setState(() {
            _offset += d.delta;
            _offset = Offset(
              _offset.dx.clamp(0, size.width - 60),
              _offset.dy.clamp(0, size.height - 60),
            );
            widget.onOffsetChanged(_offset);
          });
        },
        onPanEnd: (_) => setState(() => _isDragging = false),
        onTap: _isDragging ? null : widget.onTap,
        child: ScaleTransition(
          scale: widget.pulseAnimation,
          child: _FloatingButton(
            errorCount: widget.store.errorCount,
            totalCount: widget.store.totalCount,
            pendingCount: widget.store.pendingCount,
            isDragging: _isDragging,
            color: widget.buttonColor,
          ),
        ),
      ),
    );
  }
}

class _FloatingButton extends StatelessWidget {
  final int errorCount, totalCount, pendingCount;
  final bool isDragging;
  final Color? color;

  const _FloatingButton({
    required this.errorCount,
    required this.totalCount,
    required this.pendingCount,
    required this.isDragging,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final hasErrors = errorCount > 0;
    final isPending = pendingCount > 0;
    final btnColor = color ??
        (hasErrors
            ? Colors.red.shade700
            : isPending
                ? Colors.orange.shade700
                : const Color(0xFF6C63FF));

    return Material(
      elevation: isDragging ? 14 : 6,
      borderRadius: BorderRadius.circular(30),
      color: Colors.transparent,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: btnColor,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: btnColor.withOpacity(0.45),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isPending ? Icons.sync : Icons.network_check,
                  color: Colors.white,
                  size: 20,
                ),
                Text(
                  '$totalCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            if (hasErrors)
              Positioned(
                top: 5,
                right: 5,
                child: Container(
                  width: 17,
                  height: 17,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    errorCount > 9 ? '9+' : '$errorCount',
                    style: TextStyle(
                      color: Colors.red.shade700,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _InspectorModal extends StatelessWidget {
  const _InspectorModal();

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        height: size.height * 0.88,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F0F0F) : const Color(0xFFF5F5F5),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 8, bottom: 4),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade600,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Expanded(child: RequestListScreen()),
            ],
          ),
        ),
      ),
    );
  }
}
