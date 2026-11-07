# Dose widget (iOS)

`DoseWidget.swift` is the WidgetKit extension for the home-screen widget
that shows the next three doses today. It is the `DoseWidget` app extension
target in `Runner.xcodeproj` (bundle id `com.opsedia.usra.DoseWidget`, iOS
15.5 like Runner), embedded in `Runner.app/PlugIns/` by Runner's *Embed
Foundation Extensions* phase. CI (`build-ios`) checks the `.appex` is there.

The app writes the snapshot through `home_widget`
(`HomeWidgetSnapshotPublisher` in `lib/features/medicines/dose_widget.dart`)
to the App Group `group.com.opsedia.usra`, key `dose_widget_snapshot`. Both
targets claim the group in their `.entitlements`.

## Files

- `Info.plist`: the extension point; version and build number come from
  Flutter's `Generated.xcconfig` through `DoseWidget.xcconfig`, so they
  always match the app's (App Store Connect rejects a mismatch).
- `DoseWidget.entitlements`, `../Runner/Runner.entitlements`: the App Group.
- No Pods: the widget only uses WidgetKit, SwiftUI, App Intents and the App
  Group's `UserDefaults` and folder.

## Before the first signed build

Create the App Group `group.com.opsedia.usra` and the App ID
`com.opsedia.usra.DoseWidget` (App Groups capability on both App IDs) in
the developer account; the provisioning profiles must include the group.

## Changing the target

The target was added with the `xcodeproj` gem, not the Xcode GUI. Keep the
*Embed Foundation Extensions* phase above *Thin Binary* in Runner's build
phases, or Flutter's build fails with a dependency cycle.

`Runner/Info.plist` already registers the `usra` URL scheme the widget opens
the app with (`usra://widget/medicines?homeWidget`).

## What it does and doesn't

- Shows up to three doses due today that aren't marked taken or skipped,
  including ones due up to an hour ago; redraws when a dose drops off and at
  midnight. After the end of tomorrow without the app being opened, it asks
  to open Usra.
- Big text (`.title3`), right to left when the app is in Arabic, light and
  dark from the system.
- Taken button on iOS 17+, on a dose that's due and that the app allows
  (`t` in the snapshot: with names always, in discreet mode only if no other
  dose is still due within an hour). An App Intent runs in the extension, which
  can't reach the app's private folder, so it writes the same line as the
  notification's Taken to `dose_actions.jsonl` in the App Group, hides the
  row (`dose_widget_taken` in the App Group's defaults) until a later snapshot,
  and the app saves it when it next runs. Tapping anywhere else, and on iOS
  15.5 to 16, opens the Medicines tab behind the app lock. The widget is only on
  the home screen, so the phone is already unlocked.
