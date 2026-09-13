/// Conditional import: the real database factory lives in the IO variant;
/// the web stub returns null so `flutter build web` (dev-only) stays green.
library;

export 'offline_factory_stub.dart'
    if (dart.library.io) 'offline_factory_io.dart';