/// Conditional facade: re-exports [webNavigatorOnLine] from the platform
/// implementation. On Flutter web this consults the browser's `navigator.onLine`
/// (an instant, authoritative offline signal); on native platforms it falls
/// back to a stub because `navigator.onLine` is a browser-only concept (the
/// real `dart:io` HttpClient probe in [verifyInternetConnectivity] remains
/// authoritative there).
library;

export 'web_online_io.dart' if (dart.library.js_interop) 'web_online_web.dart';
