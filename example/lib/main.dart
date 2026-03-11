// example/lib/main.dart
//
// Demo showing all 3 adapter types.
// In a real project you only need ONE setup call.

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_http_inspector/flutter_http_inspector.dart';

// ── Dio instance ───────────────────────────────────────────
final dio = Dio(BaseOptions(baseUrl: 'https://jsonplaceholder.typicode.com'));

void main() {
  // ── OPTION A: Dio ──────────────────────────────────────
  HttpInspector.setup(dio: dio);

  // ── OPTION B: http package ─────────────────────────────
  // final client = HttpInspector.setupHttp(http.Client());

  // ── OPTION C: Manual (dart:io / GraphQL / custom) ──────
  // HttpInspector.setup();
  // Then wrap each call with:
  //   final log = HttpInspector.log('GET', url);
  //   log.complete(statusCode: 200, responseBody: body);

  runApp(
    HttpInspectorOverlay(
      enabled: kDebugMode, // ← auto-hides in release builds
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'HTTP Inspector Demo',
        theme: ThemeData.dark(useMaterial3: true),
        home: const HomeScreen(),
      );
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  // Dio calls
  Future<void> _dioGet() async {
    try {
      await dio.get('/posts/1');
    } catch (_) {}
  }

  Future<void> _dioPost() async {
    try {
      await dio.post('/posts', data: {'title': 'Hello', 'userId': 1});
    } catch (_) {}
  }

  Future<void> _dio404() async {
    try {
      await dio.get('/not-found-page-404');
    } catch (_) {}
  }

  Future<void> _dioTimeout() async {
    try {
      await Dio(BaseOptions(
        baseUrl: 'https://jsonplaceholder.typicode.com',
        connectTimeout: const Duration(milliseconds: 1),
      )).get('/posts');
    } catch (_) {}
  }

  // http package call (shows how to use setupHttp inline)
  Future<void> _httpGet() async {
    final client = HttpInspector.setupHttp(http.Client());
    try {
      await client
          .get(Uri.parse('https://jsonplaceholder.typicode.com/users/1'));
    } catch (_) {
    } finally {
      client.close();
    }
  }

  // Manual logging calls
  Future<void> _manualSuccess() async {
    final log = HttpInspector.log(
      'GET',
      'https://api.myapp.com/products',
      headers: {'Authorization': 'Bearer eyJhbGciOiJIUzI1NiJ9...'},
      queryParameters: {'page': '1', 'limit': '20'},
    );
    await Future.delayed(const Duration(milliseconds: 450));
    log.complete(
      statusCode: 200,
      responseBody: jsonEncode({'items': [], 'total': 0}),
      responseHeaders: {'content-type': 'application/json'},
    );
  }

  Future<void> _manualError() async {
    final log = HttpInspector.log(
      'POST',
      'https://api.myapp.com/login',
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': 'user@example.com', 'password': '***'}),
    );
    await Future.delayed(const Duration(milliseconds: 300));
    log.error('Connection refused', errorType: 'SocketException');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('HTTP Inspector Demo')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Tap the floating button to open the inspector.\nTry different requests to see them captured.',
              style: TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            _Section(
              icon: '🔵',
              title: 'Dio Adapter',
              code: 'HttpInspector.setup(dio: myDio)',
              buttons: [
                _Btn('GET /posts/1', Colors.teal, _dioGet),
                _Btn('POST /posts', Colors.blue, _dioPost),
                _Btn('404 Error', Colors.orange, _dio404),
                _Btn('Timeout', Colors.deepOrange, _dioTimeout),
              ],
            ),
            const SizedBox(height: 20),
            _Section(
              icon: '🟢',
              title: 'http Package Adapter',
              code: 'HttpInspector.setupHttp(http.Client())',
              buttons: [
                _Btn('GET /users/1', Colors.green, _httpGet),
              ],
            ),
            const SizedBox(height: 20),
            _Section(
              icon: '🟡',
              title: 'Manual Adapter',
              code: 'HttpInspector.log(method, url)',
              buttons: [
                _Btn('Manual 200', Colors.purple, _manualSuccess),
                _Btn('Manual Error', Colors.red, _manualError),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String icon, title, code;
  final List<Widget> buttons;

  const _Section({
    required this.icon,
    required this.title,
    required this.code,
    required this.buttons,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$icon $title',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        Text(code,
            style: const TextStyle(
                fontSize: 11, color: Colors.grey, fontFamily: 'monospace')),
        const SizedBox(height: 10),
        Wrap(spacing: 10, runSpacing: 10, children: buttons),
      ],
    );
  }
}

class _Btn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onPressed;

  const _Btn(this.label, this.color, this.onPressed);

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
      child: Text(label, style: const TextStyle(fontSize: 13)),
    );
  }
}
