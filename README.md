# flutter_http_inspector

A Flutter developer tool that adds a **floating debug overlay** to your app — inspect HTTP requests, view errors, and copy cURL commands without leaving your app.

---

## ✨ Features

- 🟣 **Floating button** — draggable, shows live request count + error badge
- 📋 **Request list** — method, status code, URL, duration
- 🔍 **Request detail** — full headers, body, response, and error info
- 📎 **Copy as cURL** — one tap copies a ready-to-run cURL command
- 📤 **FormData/Multipart support** — parses fields and file names automatically
- ⚡ **Error highlighting** — failed requests flagged in red instantly
- 🔄 **Real-time** — updates live as requests happen
- 🛠 **Debug-only safe** — pass `enabled: kDebugMode` to auto-hide in production

---

## 📦 Installation

```yaml
dependencies:
  flutter_http_inspector:
    git:
      url: https://github.com/InfinitieParasgiri/flutter_http_inspector.git
```

```bash
flutter pub get
```

---

## 🚀 Setup — 1 line in `main.dart`, nothing else

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter_http_inspector/flutter_http_inspector.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  HttpInspector.setup(); // ← catches ALL HTTP traffic automatically

  runApp(
    HttpInspectorOverlay(
      enabled: kDebugMode, // auto-hides in release builds
      child: MyApp(),
    ),
  );
}
```

**No changes needed in any API file.** Works automatically with `http` package, `Dio`, `retrofit`, `chopper`, `graphql_flutter`, `supabase`, raw `dart:io`, or any package built on top of these.

---

## ⚠️ If your project already uses `HttpOverrides`

Many projects set a custom `HttpOverrides` to bypass SSL errors. You **must** set it **before** `HttpInspector.setup()`, otherwise it will overwrite the inspector.

```dart
// ❌ Wrong — inspector gets replaced
HttpInspector.setup();
HttpOverrides.global = MyHttpOverrides(); // kills inspector!

// ✅ Correct — inspector wraps on top of your override
HttpOverrides.global = MyHttpOverrides(); // 1. your override first
HttpInspector.setup();                    // 2. inspector chains on top ✓
```

---

## 🎛 HttpInspectorOverlay Options

| Parameter | Type | Default | Description |
|---|---|---|---|
| `child` | `Widget` | required | Your root app widget |
| `enabled` | `bool` | `true` | Show/hide overlay. Use `kDebugMode` |
| `initialOffset` | `Offset` | `Offset(20, 100)` | Starting position of the button |
| `buttonColor` | `Color?` | auto | Override the button color |

---

## � Troubleshooting

**Inspector shows "No requests yet"**
1. Check the `HttpOverrides` order (see section above) — this is the most common cause.
2. Make sure `HttpInspector.setup()` is called **before** `runApp()`.
3. Do a **full restart** (not hot reload) after adding setup.

**"No Directionality widget found" error**
Place `HttpInspectorOverlay` inside `MaterialApp`'s `builder`:
```dart
MaterialApp(
  builder: (context, child) => HttpInspectorOverlay(
    enabled: kDebugMode,
    child: child!,
  ),
)
```

**Still not working after everything**
```bash
flutter clean && flutter pub get && flutter run
```

---

## 📄 License

MIT © [Infinitie Parasgiri](https://github.com/InfinitieParasgiri)
