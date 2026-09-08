/// Static app-wide configuration.
///
/// The Supabase URL and anon/publishable key are public by design (safe in
/// git). Never put the service_role key here.
abstract final class AppConfig {
  static const String appName = 'حصاد';
  static const String appVersion = '2.0';
  static const String appFooterNote = 'الإصدار 2.0 — البيانات محفوظة محلياً';
  static const String supabaseUrl = 'https://sxasnunzspkuwbxiddqd.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN4YXNudW56c3BrdXdieGlkZHFkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODg3MDYyNDIsImV4cCI6MjEwNDI4MjI0Mn0.6zYdwBewK7t4P7w7w_-BYTXI1rolSeb0Zd6jteyJsUk';

  static const double sidebarCollapsedWidth = 72;
  static const double sidebarExpandedWidth = 260;
  static const double breakpointNarrow = 700;
  static const double breakpointDesktop = 1100;
}