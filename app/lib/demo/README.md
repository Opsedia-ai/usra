# Demo family

`demo_family.dart` creates a made-up family for screenshots, UI tests
(`test/ui/`), on-device journeys (`integration_test/`) and usability
sessions (`docs/usability-test-plan.md`).

To open the app with it on a simulator or test phone (debug builds only;
the database must be empty, e.g. a fresh install):

```bash
flutter run --dart-define=USRA_DEMO=true
```

Release builds never run it: `main.dart` checks `kDebugMode` first.
