# flutter_http_inspector

A Flutter developer tool that adds a **floating debug overlay** to your app — inspect HTTP requests, view errors, and copy cURL commands without leaving your app.

Works with **Dio**, **http package**, **dart:io HttpClient**, or **any custom HTTP client**.

---

## ✨ Features

- 🟣 **Floating button** — draggable, shows live request count + error badge
- ❌ **Close icon** — button turns into X when inspector panel is open
- 📋 **Request list** — all API calls with method, status code, URL, duration
- 🔍 **Request detail** — full request headers, body, response, and error info
- 📎 **Copy as cURL** — one tap copies a ready-to-run cURL command
- 📤 **FormData support** — parses multipart fields and file names automatically
- ⚡ **Error highlighting** — failed requests flagged instantly in red
- 🔄 **Real-time** — updates live as requests happen
- 🌙 **Dark mode** support
- 🛠 **Debug-only safe** — pass `enabled: kDebugMode` to auto-hide in release builds

---

## 📦 Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  flutter_http_inspector:
    git:
      url: https://github.com/InfinitieParasgiri/flutter_http_inspector.git
```

Then run:

```bash
flutter pub get
```

---

## 🚀 Quick Start — find your HTTP client below

> **Not sure which one your project uses?**
> Search your project for these imports:
> - `import 'package:dio/dio.dart'` → follow **Option 1**
> - `import 'package:http/http.dart'` → follow **Option 2**
> - `HttpClient()` with no package → follow **Option 3**
> - GraphQL / custom wrapper → follow **Option 4**

---

## 🔵 Option 1 — Dio

**Changes needed: 1 line**

### Step 1 — Make sure you have a shared static Dio instance

The inspector must be attached to the same `Dio` instance your methods use.
If your methods each create `Dio()` locally, move it to a static field first.

```dart
import 'package:flutter_http_inspector/flutter_http_inspector.dart';

class ApiBaseHelper {

  // ✅ Shared static Dio instance
  static final dio = Dio();

  // ✅ Call this once at app start
  static void initInspector() {
    HttpInspector.setup(dio: dio);
  }

  Future<dynamic> getUsers() async {
    // Use the static dio — NOT a new Dio() every time
    final response = await dio.get('/users');
    return response.data;
  }
}
```

> ⚠️ **Common mistake** — if your methods do `final dio = Dio()` locally,
> the inspector cannot see those requests. Move Dio to a static field.

### Step 2 — Call `initInspector()` in `main.dart`

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ApiBaseHelper.initInspector(); // ← add this one line

  runApp(
    HttpInspectorOverlay(
      enabled: kDebugMode,
      child: MyApp(),
    ),
  );
}
```

---

## 🟢 Option 2 — `http` package with `MultipartRequest`

**Changes needed: replace class name in 1–2 places only**

Use `InspectorMultipartRequest` as a drop-in replacement for `http.MultipartRequest`.
Only the class name changes — all your fields, files, headers, and `.send()` stay exactly the same.

### Step 1 — Add import

```dart
import 'package:flutter_http_inspector/flutter_http_inspector.dart';
```

### Step 2 — Replace `http.MultipartRequest` with `InspectorMultipartRequest`

```dart
// ❌ Before
var request = http.MultipartRequest('POST', url);

// ✅ After — one word change, everything else stays the same
var request = InspectorMultipartRequest('POST', url);
```

Full method example — only the first line changes:

```dart
Future<dynamic> postAPICall(Uri url, Map param) async {
  // ✅ Only this line changes
  var request = InspectorMultipartRequest('POST', url);

  request.headers.addAll(await ApiUtils.getHeaders());

  param.forEach((key, value) {
    if (value is File) {
      request.files.add(MultipartFile(
        key,
        value.readAsBytes().asStream(),
        value.lengthSync(),
        filename: value.path.split('/').last,
      ));
    } else {
      request.fields[key] = value.toString();
    }
  });

  // ✅ .send() stays exactly as-is — no changes here
  var streamedResponse = await request.send().timeout(
    const Duration(seconds: 30),
  );
  var response = await Response.fromStream(streamedResponse);
  return jsonDecode(response.body);
}
```

If you have multiple methods using `MultipartRequest`, replace each one:

```dart
// postAPICallRegister
// ❌ var request = http.MultipartRequest('POST', url);
// ✅ var request = InspectorMultipartRequest('POST', url);

// postAPICall
// ❌ var request = MultipartRequest('POST', url);
// ✅ var request = InspectorMultipartRequest('POST', url);
```

### Step 3 — Wrap your app

```dart
void main() {
  runApp(
    HttpInspectorOverlay(
      enabled: kDebugMode,
      child: MyApp(),
    ),
  );
}
```

> **FormData fields and files** are automatically parsed and displayed
> (e.g. `product_name: "iPhone"`, `image: [File: photo.jpg, Size: 204800 bytes]`).

---

## 🟡 Option 3 — `dart:io` HttpClient (no package)

**Changes needed: zero ✅**

If your project uses `dart:io` `HttpClient` directly, the inspector hooks in
automatically. Just wrap your app — nothing else needed.

```dart
// main.dart — this is ALL you need
void main() {
  runApp(
    HttpInspectorOverlay(
      enabled: kDebugMode,
      child: MyApp(),
    ),
  );
}
```

All requests made via `dart:io HttpClient` are captured automatically on all platforms.

---

## 🟠 Option 4 — GraphQL / Custom client / Manual logging

**Changes needed: wrap each request with a log handle**

If your project uses GraphQL, a custom REST wrapper, Retrofit, or anything that
doesn't use Dio or `http` package directly, use `HttpInspector.log()` to manually
track each request.

### Step 1 — Wrap your app

```dart
void main() {
  runApp(
    HttpInspectorOverlay(
      enabled: kDebugMode,
      child: MyApp(),
    ),
  );
}
```

### Step 2 — Wrap each API call

```dart
import 'package:flutter_http_inspector/flutter_http_inspector.dart';

Future<dynamic> fetchUsers() async {
  // 1. Start the log before sending
  final log = HttpInspector.log(
    'GET',
    'https://api.example.com/users',
    headers: {'Authorization': 'Bearer $token'},
    queryParameters: {'page': '1', 'limit': '20'},
  );

  try {
    final res = await myCustomClient.get('/users');

    // 2. Complete when response arrives
    log.complete(
      statusCode: res.statusCode,
      responseBody: res.body,
    );
    return res.data;
  } catch (e) {
    // 3. Log the error if it throws
    log.error(e.toString(), errorType: e.runtimeType.toString());
    rethrow;
  }
}
```

POST example:

```dart
Future<dynamic> login(String email, String password) async {
  final log = HttpInspector.log(
    'POST',
    'https://api.example.com/login',
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'email': email, 'password': password}),
  );

  try {
    final res = await myCustomClient.post('/login');
    log.complete(statusCode: res.statusCode, responseBody: res.body);
    return res.data;
  } catch (e) {
    log.error(e.toString());
    rethrow;
  }
}
```

---

## 📊 Setup Summary Table

| HTTP Client | Changes in your code | Changes in `main.dart` |
|---|---|---|
| **Dio** | Static Dio instance + `HttpInspector.setup(dio: dio)` | Add `HttpInspectorOverlay` |
| **http `MultipartRequest`** | `http.MultipartRequest` → `InspectorMultipartRequest` | Add `HttpInspectorOverlay` |
| **dart:io HttpClient** | ✅ Nothing at all | Add `HttpInspectorOverlay` |
| **GraphQL / Custom** | Wrap each call with `HttpInspector.log()` | Add `HttpInspectorOverlay` |

---

## 🎛 HttpInspectorOverlay Options

| Parameter | Type | Default | Description |
|---|---|---|---|
| `child` | `Widget` | required | Your root app widget |
| `enabled` | `bool` | `true` | Show/hide the overlay. Use `kDebugMode` |
| `initialOffset` | `Offset` | `Offset(20, 100)` | Starting position of floating button |
| `buttonColor` | `Color?` | auto | Override button color |

```dart
HttpInspectorOverlay(
  enabled: kDebugMode,
  initialOffset: const Offset(16, 200),
  buttonColor: Colors.indigo,
  child: MyApp(),
)
```

---

## 🔴 Floating Button States

| State | Meaning |
|---|---|
| 🟣 Purple | Idle — ready, no errors |
| 🟠 Orange | Pending — a request is in flight |
| 🔴 Red + badge | Error — one or more requests failed |
| ⬛ Grey with ✕ | Panel is open — tap to close |

---

## 🔧 Troubleshooting

### Inspector shows "No requests yet" with Dio

Your methods are probably creating a new `Dio()` each time:

```dart
// ❌ Problem — local Dio instance, inspector can't see it
Future<dynamic> getUsers() async {
  final dio = Dio(); // new instance every call
  return await dio.get('/users');
}

// ✅ Fix — use a shared static instance
class ApiBaseHelper {
  static final dio = Dio();

  static void initInspector() {
    HttpInspector.setup(dio: dio);
  }

  Future<dynamic> getUsers() async {
    return await dio.get('/users'); // uses the shared instance ✅
  }
}
```

### Inspector shows "No requests yet" with http package

Make sure you replaced `http.MultipartRequest` with `InspectorMultipartRequest`
and added the import. The overlay alone is not enough for the `http` package.

### "Undefined name 'InspectorMultipartRequest'"

Add the import at the top of the file:

```dart
import 'package:flutter_http_inspector/flutter_http_inspector.dart';
```

### "No Directionality widget found" error

Place `HttpInspectorOverlay` inside `MaterialApp`'s `builder` instead of above it:

```dart
// ✅ Safe placement
MaterialApp(
  builder: (context, child) => HttpInspectorOverlay(
    enabled: kDebugMode,
    child: child!,
  ),
)
```

### Changes not taking effect

Clear Flutter's cache and restart:

```bash
flutter clean
flutter pub get
flutter run
```

---

## 📄 License

MIT © [Infinitie Parasgiri](https://github.com/InfinitieParasgiri)
