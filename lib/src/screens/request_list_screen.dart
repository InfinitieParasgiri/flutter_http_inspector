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
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _store.addListener(_rebuild);
  }

  @override
  void dispose() {
    _store.removeListener(_rebuild);
    _searchController.dispose();
    super.dispose();
  }

  void _rebuild() => setState(() {});

  List<HttpRecord> get _filtered {
    List<HttpRecord> records;
    switch (_filter) {
      case 'errors':
        records = _store.records.where((r) => r.isError).toList();
        break;
      case 'pending':
        records = _store.records.where((r) => r.isLoading).toList();
        break;
      default:
        records = _store.records;
    }

    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return records;

    return records.where((r) {
      final uri = Uri.tryParse(r.url);
      return (uri?.host ?? '').toLowerCase().contains(q) ||
          (uri?.path ?? r.url).toLowerCase().contains(q) ||
          r.url.toLowerCase().contains(q) ||
          r.method.toLowerCase().contains(q) ||
          (r.statusCode?.toString() ?? '').contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final records = _filtered;
    final hasQuery = _searchQuery.trim().isNotEmpty;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0F0F0F) : const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        elevation: 0,
        title: const Text('HTTP Inspector',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          _FilterChip(
            label: '${_store.errorCount} errors',
            color: _store.errorCount > 0 ? Colors.red : Colors.grey,
            active: _filter == 'errors',
            onTap: () => setState(
                () => _filter = _filter == 'errors' ? 'all' : 'errors'),
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
          const SizedBox(width: 4),
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
      ),
      body: Column(
        children: [
          Container(
            color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search URL, method, status code...',
                hintStyle:
                    TextStyle(fontSize: 13, color: Colors.grey.shade500),
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: hasQuery
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () => setState(() {
                          _searchQuery = '';
                          _searchController.clear();
                        }),
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                filled: true,
                fillColor: isDark
                    ? const Color(0xFF2A2A2A)
                    : Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: isDark
                        ? Colors.blue.shade400
                        : Colors.blue.shade300,
                    width: 1.5,
                  ),
                ),
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
          Divider(
              height: 1,
              color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
          if (hasQuery)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              color: isDark ? const Color(0xFF1A1A1A) : Colors.grey.shade50,
              child: Text(
                '${records.length} result${records.length == 1 ? '' : 's'} for "$_searchQuery"',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            ),
          Expanded(
            child: records.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          hasQuery ? Icons.manage_search : Icons.wifi_off_rounded,
                          size: 64,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          hasQuery
                              ? 'No results for "$_searchQuery"'
                              : _filter == 'all'
                                  ? 'No requests yet'
                                  : 'No $_filter requests',
                          style: TextStyle(
                              color: Colors.grey.shade500, fontSize: 16),
                        ),
                        if (hasQuery)
                          TextButton(
                            onPressed: () => setState(() {
                              _searchQuery = '';
                              _searchController.clear();
                            }),
                            child: const Text('Clear search'),
                          )
                        else if (_filter != 'all')
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
                      searchQuery: _searchQuery,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RequestDetailScreen(record: records[i]),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
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
                color: color, fontSize: 11, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class _RequestTile extends StatelessWidget {
  final HttpRecord record;
  final VoidCallback onTap;
  final String searchQuery;

  const _RequestTile({
    required this.record,
    required this.onTap,
    this.searchQuery = '',
  });

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
                    _HighlightText(
                      text: path,
                      query: searchQuery,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'monospace'),
                    ),
                    const SizedBox(height: 2),
                    _HighlightText(
                      text: host,
                      query: searchQuery,
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                          fontFamily: 'monospace'),
                    ),
                    if (record.errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '\u26a0 ${record.errorMessage}',
                          style:
                              TextStyle(fontSize: 11, color: Colors.red.shade400),
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

class _HighlightText extends StatelessWidget {
  final String text;
  final String query;
  final TextStyle style;
  final int maxLines;

  const _HighlightText({
    required this.text,
    required this.query,
    required this.style,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final q = query.trim().toLowerCase();

    if (q.isEmpty) {
      return Text(text,
          style: style, maxLines: maxLines, overflow: TextOverflow.ellipsis);
    }

    final lower = text.toLowerCase();
    final spans = <TextSpan>[];
    int cursor = 0;

    while (cursor < text.length) {
      final hit = lower.indexOf(q, cursor);
      if (hit == -1) {
        spans.add(TextSpan(text: text.substring(cursor), style: style));
        break;
      }
      if (hit > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, hit), style: style));
      }
      spans.add(TextSpan(
        text: text.substring(hit, hit + q.length),
        style: style.copyWith(
          backgroundColor:
              isDark ? Colors.yellow.shade800 : Colors.yellow.shade200,
          color: isDark ? Colors.yellow.shade100 : Colors.black87,
          fontWeight: FontWeight.bold,
        ),
      ));
      cursor = hit + q.length;
    }

    return Text.rich(
      TextSpan(children: spans),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
    );
  }
}
