// lib/src/screens/request_detail_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../http_record.dart';
import '../widgets/status_badge.dart';

class RequestDetailScreen extends StatefulWidget {
  final HttpRecord record;
  const RequestDetailScreen({super.key, required this.record});

  @override
  State<RequestDetailScreen> createState() => _RequestDetailScreenState();
}

class _RequestDetailScreenState extends State<RequestDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _copy(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.check_circle, color: Colors.white, size: 16),
        const SizedBox(width: 8),
        Text('$label copied!'),
      ]),
      backgroundColor: Colors.green,
      duration: const Duration(seconds: 2),
    ));
  }

  String _pretty(dynamic data) {
    if (data == null) return 'null';
    try {
      final decoded = data is String ? jsonDecode(data) : data;
      return const JsonEncoder.withIndent('  ').convert(decoded);
    } catch (_) {
      return data.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.record;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0F0F0F) : const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              MethodBadge(method: r.method),
              const SizedBox(width: 8),
              StatusBadge(record: r),
              if (r.duration != null) ...[
                const SizedBox(width: 8),
                Text('${r.duration!.inMilliseconds}ms',
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade500)),
              ],
            ]),
            const SizedBox(height: 2),
            Text(
              Uri.tryParse(r.url)?.path ?? r.url,
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ElevatedButton.icon(
              onPressed: () => _copy(r.toCurl(), 'cURL'),
              icon: const Icon(Icons.terminal, size: 16),
              label: const Text('Copy cURL'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                textStyle: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: const Color(0xFF6C63FF),
          labelColor: const Color(0xFF6C63FF),
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: 'Request'),
            Tab(text: 'Response'),
            Tab(text: 'cURL'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _RequestTab(record: r, pretty: _pretty, copy: _copy),
          _ResponseTab(record: r, pretty: _pretty, copy: _copy),
          _CurlTab(record: r, onCopy: () => _copy(r.toCurl(), 'cURL')),
        ],
      ),
    );
  }
}

// ── Request Tab ──────────────────────────────────────────
class _RequestTab extends StatelessWidget {
  final HttpRecord record;
  final String Function(dynamic) pretty;
  final void Function(String, String) copy;

  const _RequestTab(
      {required this.record, required this.pretty, required this.copy});

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(16), children: [
      _InfoCard(title: 'URL', children: [
        _Row('Full URL', record.url, copy),
        _Row('Method', record.method, copy),
        _Row('Time', record.timestamp.toString(), copy),
      ]),
      if (record.queryParameters?.isNotEmpty == true)
        _InfoCard(
          title: 'Query Parameters',
          children: record.queryParameters!.entries
              .map((e) => _Row(e.key, e.value, copy))
              .toList(),
        ),
      _InfoCard(
        title: 'Request Headers',
        children: record.requestHeaders.entries
            .map((e) => _Row(e.key, e.value.toString(), copy))
            .toList(),
      ),
      if (record.requestBody != null)
        _CodeCard(
            title: 'Request Body',
            code: pretty(record.requestBody),
            copy: copy),
    ]);
  }
}

// ── Response Tab ─────────────────────────────────────────
class _ResponseTab extends StatelessWidget {
  final HttpRecord record;
  final String Function(dynamic) pretty;
  final void Function(String, String) copy;

  const _ResponseTab(
      {required this.record, required this.pretty, required this.copy});

  @override
  Widget build(BuildContext context) {
    if (record.isLoading) {
      return const Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        CircularProgressIndicator(),
        SizedBox(height: 12),
        Text('Waiting for response…'),
      ]));
    }

    return ListView(padding: const EdgeInsets.all(16), children: [
      if (record.errorMessage != null)
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.red.shade900.withOpacity(0.25),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.red.shade700),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.error_outline,
                  color: Colors.red.shade400, size: 18),
              const SizedBox(width: 6),
              Text(
                'Error: ${record.errorType ?? "Unknown"}',
                style: TextStyle(
                    color: Colors.red.shade400,
                    fontWeight: FontWeight.bold),
              ),
            ]),
            const SizedBox(height: 6),
            Text(record.errorMessage!,
                style: const TextStyle(color: Colors.white70)),
          ]),
        ),
      _InfoCard(title: 'Status', children: [
        _Row('Status Code', record.statusLabel, copy),
        if (record.duration != null)
          _Row('Duration', '${record.duration!.inMilliseconds}ms', copy),
      ]),
      if (record.responseHeaders != null)
        _InfoCard(
          title: 'Response Headers',
          children: record.responseHeaders!.entries
              .map((e) => _Row(e.key, e.value.toString(), copy))
              .toList(),
        ),
      if (record.responseBody != null)
        _CodeCard(
            title: 'Response Body',
            code: pretty(record.responseBody),
            copy: copy),
    ]);
  }
}

// ── cURL Tab ─────────────────────────────────────────────
class _CurlTab extends StatelessWidget {
  final HttpRecord record;
  final VoidCallback onCopy;

  const _CurlTab({required this.record, required this.onCopy});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade800),
              ),
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: SelectableText(
                  record.toCurl(),
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                    color: Color(0xFFD4D4D4),
                    height: 1.6,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: onCopy,
            icon: const Icon(Icons.copy),
            label: const Text('Copy cURL Command'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C63FF),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              textStyle: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared widgets ────────────────────────────────────────
class _InfoCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _InfoCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          child: Text(title,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade500,
                  letterSpacing: 1)),
        ),
        const Divider(height: 1),
        ...children,
      ]),
    );
  }
}

class _Row extends StatelessWidget {
  final String label, value;
  final void Function(String, String) copy;

  const _Row(this.label, this.value, this.copy);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => copy(value, label),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: 130,
            child: Text(label,
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                    fontFamily: 'monospace')),
          ),
          Expanded(
            child: Text(value,
                style:
                    const TextStyle(fontSize: 12, fontFamily: 'monospace')),
          ),
          Icon(Icons.copy, size: 14, color: Colors.grey.shade600),
        ]),
      ),
    );
  }
}

class _CodeCard extends StatelessWidget {
  final String title, code;
  final void Function(String, String) copy;

  const _CodeCard(
      {required this.title, required this.code, required this.copy});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade800),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 4, 8),
          child: Row(children: [
            Text(title,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade500,
                    letterSpacing: 1)),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.copy, size: 14),
              color: Colors.grey.shade500,
              onPressed: () => copy(code, title),
              padding: EdgeInsets.zero,
              constraints:
                  const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ]),
        ),
        const Divider(height: 1, color: Color(0xFF333333)),
        Padding(
          padding: const EdgeInsets.all(12),
          child: SelectableText(code,
              style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: Color(0xFFD4D4D4),
                  height: 1.5)),
        ),
      ]),
    );
  }
}
