/// Native fallback for [webNavigatorOnLine]. `navigator.onLine` only exists in
/// a browser; on native platforms the `dart:io` HttpClient probe inside
/// [verifyInternetConnectivity] is the real authority, so we report online and
/// never short-circuit that probe.
library;

/// Always true on native — real verification is done by the HTTP probe.
bool webNavigatorOnLine() => true;
