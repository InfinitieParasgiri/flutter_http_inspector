import 'package:flutter/material.dart';
import 'inspector_store.dart';
import 'io_interceptor.dart';
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

    // ── Auto-intercept ALL HTTP traffic — no setup needed in the project ──
    if (widget.enabled) {
      installHttpOverrides();
    }

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

  bool _isModalOpen = false;

  void _openInspector() {
    setState(() => _isModalOpen = true);
  }

  void _closeInspector() {
    setState(() {
      _isModalOpen = false;
    });
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
          if (_isModalOpen) ...[
            // Barrier
            GestureDetector(
              onTap: _closeInspector,
              child: Container(color: Colors.black54),
            ),
            // Modal Content
            _InspectorInternalModal(
              onClose: _closeInspector,
            ),
          ],
          _OverlayPositioned(
            initialOffset: _offset,
            onOffsetChanged: (newOffset) => setState(() => _offset = newOffset),
            onTap: _isModalOpen ? _closeInspector : _openInspector,
            pulseAnimation: _pulseAnimation,
            store: _store,
            buttonColor: widget.buttonColor,
            isModalOpen: _isModalOpen,
          ),
        ],
      ),
    );
  }
}

class _InspectorInternalModal extends StatelessWidget {
  final VoidCallback onClose;

  const _InspectorInternalModal({
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.maybeOf(context)?.size ?? const Size(1000, 2000);
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
              // Handle
              GestureDetector(
                onVerticalDragUpdate: (details) {
                  if (details.delta.dy > 10) onClose();
                },
                child: Container(
                  color: Colors.transparent, // Padding for better drag target
                  width: double.infinity,
                  padding: const EdgeInsets.only(top: 8, bottom: 4),
                  child: Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade600,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: MaterialApp(
                  debugShowCheckedModeBanner: false,
                  theme: Theme.of(context),
                  darkTheme: ThemeData.dark(),
                  home: const RequestListScreen(),
                ),
              ),
            ],
          ),
        ),
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
  final bool isModalOpen;

  const _OverlayPositioned({
    required this.initialOffset,
    required this.onOffsetChanged,
    required this.onTap,
    required this.pulseAnimation,
    required this.store,
    this.buttonColor,
    required this.isModalOpen,
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
            isCloseIcon: widget.isModalOpen,
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
  final bool isCloseIcon;

  const _FloatingButton({
    required this.errorCount,
    required this.totalCount,
    required this.pendingCount,
    required this.isDragging,
    this.color,
    this.isCloseIcon = false,
  });

  @override
  Widget build(BuildContext context) {
    final hasErrors = errorCount > 0;
    final isPending = pendingCount > 0;
    final btnColor = isCloseIcon
        ? Colors.grey.shade800
        : (color ??
            (hasErrors
                ? Colors.red.shade700
                : isPending
                    ? Colors.orange.shade700
                    : const Color(0xFF6C63FF)));

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
            if (isCloseIcon)
              const Icon(Icons.close, color: Colors.white, size: 28)
            else
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
            if (hasErrors && !isCloseIcon)
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

// Deleted old _InspectorModal as it is now integrated into _InspectorInternalModal
