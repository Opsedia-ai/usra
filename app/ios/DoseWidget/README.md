# Dose widget (iOS)

`DoseWidget.swift` is the WidgetKit extension for the home-screen widget
that shows the next three doses today. It has **not been built yet**: there
was no Xcode where it was written (it only type-checks against the macOS
SDK). Until the steps below are done, the iOS app builds and runs as before
and simply has no widget.

The app writes the snapshot through `home_widget`
(`HomeWidgetSnapshotPublisher` in `lib/features/medicines/dose_widget.dart`)
to the App Group `group.com.opsedia.usra`, key `dose_widget_snapshot`.

## One-time Xcode steps

1. Open `ios/Runner.xcworkspace`.
2. **File → New → Target… → Widget Extension.** Product name `DoseWidget`,
   untick *Include Live Activity* and *Include Configuration App Intent*,
   embed in `Runner`. When Xcode asks to activate the scheme, choose
   *Cancel* (keep the Runner scheme).
3. Delete the Swift files Xcode generated in the new `DoseWidget` group and
   add this folder's `DoseWidget.swift` to the `DoseWidget` target only.
   Keep the generated `Info.plist` and `Assets.xcassets`.
4. Set the `DoseWidget` target's *Minimum Deployments* to iOS 15.5 (same as
   Runner) and its bundle id to `com.opsedia.usra.DoseWidget`.
5. **Signing & Capabilities → + Capability → App Groups** on *both* the
   `Runner` and `DoseWidget` targets, and tick `group.com.opsedia.usra`
   (create it in the developer account if it doesn't exist). This adds
   `Runner.entitlements` and `DoseWidget.entitlements`.
6. In **Build Phases** of `Runner`, drag *Embed Foundation Extensions* (or
   *Embed App Extensions*) above *Thin Binary* / *Run Script*; otherwise
   Flutter's build fails with a dependency cycle.
7. Build and run on a phone or simulator, add the widget (long-press the
   home screen → +), mark a dose in the app and check the widget updates;
   tap it and check the Medicines tab opens.

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
