abstract final class AppConfig {
  static const String appName = 'حصاد';
  static const String appVersion = '2.0';
  static const String appFooterNote = 'الإصدار 2.0 — البيانات محفوظة محلياً';
  // Single source of truth for the backend endpoint. The connectivity probe
  // (`core/network/connectivity_service.dart`) builds its health-check URL from
  // these, so they MUST honor the same --dart-define overrides that
  // `data/supabase_client.dart` passes to `Supabase.initialize`.
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://sxasnunzspkuwbxiddqd.supabase.co',
  );
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN4YXNudW56c3BrdXdieGlkZHFkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODg3MDYyNDIsImV4cCI6MjEwNDI4MjI0Mn0.6zYdwBewK7t4P7w7w_-BYTXI1rolSeb0Zd6jteyJsUk',
  );

  /// Unauthenticated, CORS-readable health endpoint on the backend the app
  /// actually depends on. Probing a third-party host (e.g. Google's
  /// `generate_204`) is unusable on web: a cross-origin response without
  /// `Access-Control-Allow-Origin` is blocked by the browser, so the probe
  /// always throws and the app reports a false "offline". This endpoint
  /// answers the preflight and reflects the caller's origin.
  static Uri get supabaseHealthUri =>
      Uri.parse('$supabaseUrl/auth/v1/health');

  static const double sidebarCollapsedWidth = 72;
  static const double sidebarExpandedWidth = 260;
  static const double breakpointNarrow = 700;
  static const double breakpointDesktop = 1100;

  // Card system metrics (DESIGN_SYSTEM §4/§5/§8) — wide, comfortable cards.
  static const double cardRadius = 16;
  static const double cardRadiusSmall = 12;
  static const double cardPadding = 20;
  static const double cardPaddingSmall = 16;
  static const double cardGap = 16;
  static const double sectionGap = 24;
  static const double pageGutter = 24;
  static const double pageGutterNarrow = 16;
  static const double controlRadius = 10;
  static const double maxContentWidth = 1560;
}
