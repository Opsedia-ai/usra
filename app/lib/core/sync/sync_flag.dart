/// Family sync is built behind this flag (docs/sync-design.md section 17,
/// Phase 0). It is off unless an internal build passes
/// `--dart-define=USRA_SYNC=true`, and always off in store builds
/// (`USRA_RELEASE`) until the founder decides to turn it on.
const bool syncEnabled =
    bool.fromEnvironment('USRA_SYNC') && !bool.fromEnvironment('USRA_RELEASE');
