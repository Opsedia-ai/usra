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
- No Pods: the widget only uses WidgetKit, SwiftUI and `UserDefaults`.

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
- No Taken button on iOS: an App Intent runs in the extension, which can't
  reach the app's dose inbox (it lives in the app's private folder, not the
  App Group). Tapping the widget opens the Medicines tab instead.
