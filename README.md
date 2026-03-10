# flutter_http_inspector

A Flutter developer tool that adds a **floating debug overlay** to your app for inspecting HTTP requests, viewing errors, and copying cURL commands — all without leaving your app.

Works with **Dio**, **http package**, or **any custom HTTP client**.

---

## ✨ Features

- 🔴 **Floating button** — draggable, shows request count + error badge. **Closes with a Close icon** when the inspector is open!
- 📋 **Request list** — all API calls with method, status, URL, duration.
- 🔍 **Request detail** — full headers, body, response, error info.
- � **FormData Support** — Automatically parses multipart forms so you can see exactly which fields and files were sent (e.g., in "Add Product").
- �📎 **Copy as cURL** — one tap copies the complete ready-to-run cURL command.
- 🛠 **Zero Config UI** — Uses its own context and navigation so it won't crash your app or interfere with your `MaterialApp`.
- ⚡ **Error highlighting** — failed requests are instantly flagged.
- 🔄 **Real-time** — live tracking as requests happen.
- 🌙 **Dark mode** support.
- 🛠 **Debug-only** — pass `enabled: kDebugMode` to hide in release builds.

---

## 📦 Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  flutter_http_inspector:
    git:
      url: https://github.com/InfinitieParasgiri/flutter_http_inspector.git
```

---

## 🚀 Setup

### Step 1 — Setup your HTTP client

**Dio (Recommended)**
```dart
import 'package:flutter_http_inspector/flutter_http_inspector.dart';

final dio = Dio();
HttpInspector.setup(dio: dio); // That's it!
```

**Standard http package**
```dart
import 'package:http/http.dart' as http;

// Returns an InspectorHttpClient — a drop-in replace for http.Client
final client = HttpInspector.setupHttp(http.Client());

// Use 'client' for all your calls
await client.get(Uri.parse('https://example.com'));
```

### Step 2 — Wrap your app
Put this at the very top of your widget tree (usually in `runApp`).

```dart
void main() {
  runApp(
    HttpInspectorOverlay(
      enabled: kDebugMode, // Only shows in debug builds
      child: MyApp(),
    ),
  );
}
```

---

## 💡 Pro Tips

### Capturing FormData
If you use `api_base_helper` style classes, make sure to use a **static** Dio instance initialized once. The inspector will automatically parse `FormData` into a human-readable list:
- `product_name: "Apple iPhone 14"`
- `image: [File: cover.jpg, Size: 1024 bytes]`

### Capturing Query Parameters
As of the latest version, the inspector records the **Full URL** including all search parameters (e.g., `?page=1&per_page=15`).

---

## 🔧 Troubleshooting

### "Undefined name 'HttpInspector'"
If you get this error when adding `HttpInspector.setup()` to your class:
1. Ensure you have the **import** at the top of the file.
2. Ensure you are calling it inside a **method** or a **constructor**, not just naked inside the class.

```dart
class MyApi {
  static final dio = Dio();
  
  static void init() {
    HttpInspector.setup(dio: dio); // Correct placement
  }
}
```

---

## 📄 License

MIT
