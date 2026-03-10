// lib/src/screens/request_list_screen.dart
import 'package:flutter/material.dart';
import '../http_record.dart';
import '../inspector_store.dart';
import '../widgets/status_badge.dart';
import 'request_detail_screen.dart';

class RequestListScreen extends StatefulWidget {
  const RequestListScreen({super.key});

  @override
  State<RequestListScreen> createState() => _RequestListScreenState();
}

class _RequestListScreenState extends State<RequestListScreen> {
  final _store = InspectorStore();
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _store.addListener(_rebuild);
  }

  @override
  void dispose() {
    _store.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() => setState(() {});

  List<HttpRecord> get _filtered {
    switch (_filter) {
      case 'errors':
        return _store.records.where((r) => r.isError).toList();
      case 'pending':
        return _store.records.where((r) => r.isLoading).toList();
      default:
        return _store.records;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final records = _filtered;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0F0F0F) : const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        elevation: 0,
        title: const Text('🔍 HTTP Inspector',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          _FilterChip(
            label: '${_store.errorCount} errors',
            color: _store.errorCount > 0 ? Colors.red : Colors.grey,
            active: _filter == 'errors',
            onTap: () =>
                setState(() => _filter = _filter == 'errors' ? 'all' : 'errors'),
          ),
          const SizedBox(width: 6),
          if (_store.pendingCount > 0)
            _FilterChip(
              label: '${_store.pendingCount} pending',
              color: Colors.orange,
              active: _filter == 'pending',
              onTap: () => setState(
                  () => _filter = _filter == 'pending' ? 'all' : 'pending'),
            ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Clear all',
            onPressed: () => showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Clear all requests?'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel')),
                  TextButton(
                    onPressed: () {
                      _store.clearAll();
                      Navigator.pop(ctx);
                    },
                    child: const Text('Clear',
                        style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(
              height: 1,
              color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
        ),
      ),
      body: records.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.wifi_off_rounded,
                      size: 64, color: Colors.grey.shade600),
                  const SizedBox(height: 16),
                  Text(
                    _filter == 'all'
                        ? 'No requests yet'
                        : 'No $_filter requests',
                    style: TextStyle(
                        color: Colors.grey.shade500, fontSize: 16),
                  ),
                  if (_filter != 'all')
                    TextButton(
                      onPressed: () => setState(() => _filter = 'all'),
                      child: const Text('Show all'),
                    ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(8),
              itemCount: records.length,
              separatorBuilder: (_, __) => const SizedBox(height: 4),
              itemBuilder: (context, i) => _RequestTile(
                record: records[i],
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RequestDetailScreen(record: records[i]),
                  ),
                ),
              ),
            ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool active;
  final VoidCallback onTap;

  const _FilterChip(
      {required this.label,
      required this.color,
      required this.active,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: active ? color.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: active ? color : Colors.transparent),
        ),
        child: Text(label,
            style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class _RequestTile extends StatelessWidget {
  final HttpRecord record;
  final VoidCallback onTap;

  const _RequestTile({required this.record, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final uri = Uri.tryParse(record.url);
    final path = uri?.path.isEmpty == true ? '/' : (uri?.path ?? record.url);
    final host = uri?.host ?? '';

    Color borderColor = Colors.transparent;
    if (record.isError) borderColor = Colors.red.shade700.withOpacity(0.5);
    if (record.isLoading) borderColor = Colors.orange.withOpacity(0.3);

    return Material(
      color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderColor, width: 1.5),
          ),
          child: Row(
            children: [
              Column(
                children: [
                  MethodBadge(method: record.method, compact: true),
                  const SizedBox(height: 4),
                  StatusBadge(record: record, compact: true),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      path,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'monospace'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(host,
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                            fontFamily: 'monospace'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    if (record.errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '⚠ ${record.errorMessage}',
                          style: TextStyle(
                              fontSize: 11, color: Colors.red.shade400),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (record.duration != null)
                    Text(
                      '${record.duration!.inMilliseconds}ms',
                      style: TextStyle(
                        fontSize: 11,
                        color: record.duration!.inMilliseconds > 1000
                            ? Colors.orange
                            : Colors.grey.shade500,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Icon(Icons.chevron_right,
                      size: 16, color: Colors.grey.shade500),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
