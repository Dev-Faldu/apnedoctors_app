/// Public configuration. The Supabase URL and publishable key are public by design (row-level
/// security protects the data); every secret lives in Supabase secrets, never in the app.
abstract final class Env {
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://yljfnbudjdijwjshqaba.supabase.co',
  );
  static const supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_pGrEpGT8AXMufKOXy9HunQ_en7KRst8',
  );
}
