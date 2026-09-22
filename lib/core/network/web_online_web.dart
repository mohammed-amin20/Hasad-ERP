/// Web-only navigator.onLine source. On native platforms `navigator.onLine`
/// does not exist, so we fall back to `true` (the heartbeat probe is the real
/// authority on native).
library;

import 'package:web/web.dart' as web;

/// True when the browser reports an online connection (web only).
bool webNavigatorOnLine() => web.window.navigator.onLine;
