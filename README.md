# flutter_http_inspector

A Flutter developer tool that adds a **floating debug overlay** to your app for inspecting HTTP requests, viewing errors, and copying cURL commands — all without leaving your app.

Works with **Dio**, **http package**, or **any custom HTTP client**.

---

## ✨ Features

- 🔴 **Floating button** — draggable, shows request count + error badge
- 📋 **Request list** — all API calls with method, status, URL, duration
- 🔍 **Request detail** — full headers, body, response, error info
- 📎 **Copy as cURL** — one tap copies the complete ready-to-run cURL command
- ⚡ **Error highlighting** — failed requests are instantly flagged
- 🔄 **Real-time** — live tracking as requests happen
- 🌙 **Dark mode** support
- 🛠 **Debug-only** — pass `enabled: kDebugMode` to hide in release builds

---

## 📦 Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  flutter_http_inspector:
    git:
      url: https://github.com/yourusername/flutter_http_inspector.git
```

---

## 🚀 Setup (pick one based on your project)

### Step 1 — Setup your HTTP client

```dart
import 'package:flutter_http_inspector/flutter_http_inspector.dart';

// 🔵 Using Dio?
HttpInspector.setup(dio: myDio);

// 🟢 Using http package?
final client = HttpInspector.setupHttp(http.Client());

// 🟡 Using dart:io / GraphQL / anything else?
HttpInspector.setup(); // then call HttpInspector.log() per request
```

### Step 2 — Wrap your app

```dart
void main() {
  runApp(
    HttpInspectorOverlay(
      enabled: kDebugMode,   // hides automatically in release builds
      child: MyApp(),
    ),
  );
}
```

That's it! A floating button appears. Tap it to open the inspector.

---

## 📖 Full Usage Examples

### 🔵 Dio

```dart
import 'package:dio/dio.dart';
import 'package:flutter_http_inspector/flutter_http_inspector.dart';

final dio = Dio();
HttpInspector.setup(dio: dio);

// All Dio requests are now tracked automatically
final response = await dio.get('https://api.example.com/users');
```

### 🟢 http package

```dart
import 'package:http/http.dart' as http;
import 'package:flutter_http_inspector/flutter_http_inspector.dart';

// Returns an InspectorHttpClient — drop-in replacement for http.Client
final client = HttpInspector.setupHttp(http.Client());

// Use exactly like a normal http.Client
final response = await client.get(Uri.parse('https://api.example.com/users'));
```

### 🟡 Manual (dart:io, GraphQL, Retrofit, custom)

```dart
import 'package:flutter_http_inspector/flutter_http_inspector.dart';

HttpInspector.setup(); // once at app start

// Then wrap each request:
Future<void> fetchUsers() async {
  final log = HttpInspector.log(
    'GET',
    'https://api.example.com/users',
    headers: {'Authorization': 'Bearer $token'},
    queryParameters: {'page': '1'},
  );

  try {
    final response = await myHttpClient.get('/users');
    log.complete(
      statusCode: response.statusCode,
      responseBody: response.body,
    );
  } catch (e) {
    log.error(e.toString(), errorType: e.runtimeType.toString());
  }
}
```

---

## 🎛 Configuration

### HttpInspectorOverlay

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `child` | `Widget` | required | Your app widget |
| `enabled` | `bool` | `true` | Show/hide overlay |
| `initialOffset` | `Offset` | `Offset(20, 100)` | Starting position of button |
| `buttonColor` | `Color?` | auto | Custom button color |

### Floating button colors
- 🟣 **Purple** — normal state
- 🟠 **Orange** — requests pending
- 🔴 **Red** — errors detected (badge shows count)

---

## 📁 Package Structure

```
flutter_http_inspector/
├── lib/
│   ├── flutter_http_inspector.dart       ← Public API
│   └── src/
│       ├── http_inspector.dart           ← Factory (main entry point)
│       ├── http_record.dart              ← Data model + cURL generator
│       ├── inspector_store.dart          ← State (ChangeNotifier singleton)
│       ├── http_inspector_interceptor.dart ← Dio interceptor
│       ├── inspector_overlay.dart        ← Floating button + modal
│       ├── adapters/
│       │   ├── base_adapter.dart         ← Shared interface
│       │   ├── dio_adapter.dart          ← Dio support
│       │   ├── http_adapter.dart         ← http package support
│       │   └── manual_adapter.dart       ← Manual / any client
│       ├── screens/
│       │   ├── request_list_screen.dart  ← All requests list
│       │   └── request_detail_screen.dart← Detail + cURL tab
│       └── widgets/
│           └── status_badge.dart         ← Method/status badges
└── example/
    └── lib/main.dart                     ← Demo app (all 3 adapters)
```

---

## 🤝 Contributing

PRs welcome! Planned features:
- [ ] `http` package adapter auto-inject
- [ ] Filter by method / status code
- [ ] Export all logs as JSON file
- [ ] Search by URL
- [ ] Timeline / waterfall view

---

## 📄 License

MIT
