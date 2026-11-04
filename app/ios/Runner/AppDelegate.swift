import Flutter
import UIKit
import UserNotifications
import flutter_local_notifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Medicine reminders: show them while the app is open too, and let the
    // Taken / Snooze buttons run without opening the app.
    UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { registry in
      GeneratedPluginRegistrant.register(with: registry)
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "UsraFiles") {
      registerFilesChannel(messenger: registrar.messenger())
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "UsraClock") {
      registerClockChannel(messenger: registrar.messenger())
    }
  }

  /// The app lock measures time away with this: CLOCK_MONOTONIC on iOS keeps
  /// counting while the phone sleeps and can't be changed in Settings.
  private func registerClockChannel(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "usra/clock", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      guard call.method == "elapsedRealtime" else {
        result(FlutterMethodNotImplemented)
        return
      }
      result(Int(clock_gettime_nsec_np(CLOCK_MONOTONIC) / 1_000_000))
    }
  }

  /// Keeps private folders (insurance card photos) out of iCloud backup.
  private func registerFilesChannel(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "usra/files", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      guard call.method == "excludeFromBackup", let path = call.arguments as? String else {
        result(FlutterMethodNotImplemented)
        return
      }
      do {
        var url = URL(fileURLWithPath: path, isDirectory: true)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try url.setResourceValues(values)
        result(nil)
      } catch {
        result(FlutterError(code: "exclude_failed", message: error.localizedDescription, details: nil))
      }
    }
  }
}
