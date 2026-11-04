/// Where the optional cloud lives, from `--dart-define=SUPABASE_URL=...`
/// and `--dart-define=SUPABASE_ANON_KEY=...`. Without both, accounts are
/// hidden and the app never talks to the network.
class SupabaseConfig {
  const SupabaseConfig({required this.url, required this.anonKey});

  static const fromEnvironment = SupabaseConfig(
    url: String.fromEnvironment('SUPABASE_URL'),
    anonKey: String.fromEnvironment('SUPABASE_ANON_KEY'),
  );

  static const none = SupabaseConfig(url: '', anonKey: '');

  final String url;

  /// The public anon key; row-level security decides what it can reach.
  final String anonKey;

  bool get isConfigured =>
      anonKey.isNotEmpty && (Uri.tryParse(url)?.hasAuthority ?? false);
}
