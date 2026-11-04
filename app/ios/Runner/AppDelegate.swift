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
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "UsraPrivacy") {
      registerPrivacyChannels(messenger: registrar.messenger())
    }
  }

  /// The app-switcher cover (SceneDelegate) and the text a hidden
  /// notification preview shows. Screenshots can't be blocked on iOS, so
  /// `setSecure` isn't handled.
  private func registerPrivacyChannels(messenger: FlutterBinaryMessenger) {
    FlutterMethodChannel(name: "usra/screen_privacy", binaryMessenger: messenger)
      .setMethodCallHandler { call, result in
        switch call.method {
        case "coverUntilReady":
          let on = call.arguments as? Bool ?? false
          SceneDelegate.current?.coverUntilReady = on
          if !on { SceneDelegate.current?.uncover() }
          result(nil)
        case "uncover":
          SceneDelegate.current?.uncover()
          result(nil)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    // The lock screen hides previews by default ("When Unlocked"); this
    // replaces "Notification" with generic reminder text there.
    FlutterMethodChannel(name: "usra/notification_privacy", binaryMessenger: messenger)
      .setMethodCallHandler { call, result in
        guard call.method == "setHiddenPreviewText", let text = call.arguments as? String else {
          result(FlutterMethodNotImplemented)
          return
        }
        let center = UNUserNotificationCenter.current()
        center.getNotificationCategories { categories in
          let replaced = categories.map {
            UNNotificationCategory(
              identifier: $0.identifier,
              actions: $0.actions,
              intentIdentifiers: $0.intentIdentifiers,
              hiddenPreviewsBodyPlaceholder: text,
              options: $0.options)
          }
          center.setNotificationCategories(Set(replaced))
          DispatchQueue.main.async { result(nil) }
        }
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
