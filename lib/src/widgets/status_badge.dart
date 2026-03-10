// lib/src/widgets/status_badge.dart
import 'package:flutter/material.dart';
import '../http_record.dart';

class StatusBadge extends StatelessWidget {
  final HttpRecord record;
  final bool compact;

  const StatusBadge({super.key, required this.record, this.compact = false});

  Color get _color {
    if (record.isLoading) return Colors.grey;
    if (record.errorMessage != null && record.statusCode == null) {
      return Colors.red.shade700;
    }
    final code = record.statusCode ?? 0;
    if (code >= 500) return Colors.red.shade700;
    if (code >= 400) return Colors.orange.shade700;
    if (code >= 300) return Colors.blue.shade600;
    if (code >= 200) return Colors.green.shade600;
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: _color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        record.statusLabel,
        style: TextStyle(
          color: Colors.white,
          fontSize: compact ? 10 : 12,
          fontWeight: FontWeight.bold,
          fontFamily: 'monospace',
        ),
      ),
    );
  }
}

class MethodBadge extends StatelessWidget {
  final String method;
  final bool compact;

  const MethodBadge({super.key, required this.method, this.compact = false});

  Color get _color {
    switch (method.toUpperCase()) {
      case 'GET':
        return Colors.teal.shade600;
      case 'POST':
        return Colors.blue.shade600;
      case 'PUT':
        return Colors.orange.shade600;
      case 'PATCH':
        return Colors.purple.shade600;
      case 'DELETE':
        return Colors.red.shade600;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 5 : 7,
        vertical: compact ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: _color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        method.toUpperCase(),
        style: TextStyle(
          color: Colors.white,
          fontSize: compact ? 9 : 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
