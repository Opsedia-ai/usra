import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  /// The scene showing the app, for the `usra/screen_privacy` channel
  /// (registered in AppDelegate).
  static weak var current: SceneDelegate?

  /// The app lock is on: the cover stays once active until Dart has drawn
  /// the lock (or decided there's none) and calls `uncover`.
  var coverUntilReady = false

  private var cover: UIView?
  private var active = false
  private var observers: [NSObjectProtocol] = []

  override init() {
    super.init()
    SceneDelegate.current = self
    // Health records must not show in the app switcher: iOS snapshots the
    // window once the app goes inactive, so cover it then (the launch
    // screen) and uncover when it's active again. Notifications rather than
    // overriding the scene callbacks, which FlutterSceneDelegate needs.
    // Also shows behind system alerts (permission prompts, Face ID).
    let center = NotificationCenter.default
    observers = [
      center.addObserver(
        forName: UIScene.willDeactivateNotification, object: nil, queue: .main
      ) { [weak self] note in
        self?.ifOwnScene(note) {
          $0.active = false
          $0.showCover()
        }
      },
      center.addObserver(
        forName: UIScene.didActivateNotification, object: nil, queue: .main
      ) { [weak self] note in
        self?.ifOwnScene(note) {
          $0.active = true
          if $0.coverUntilReady {
            $0.uncoverSoon()
          } else {
            $0.hideCover()
          }
        }
      },
    ]
  }

  deinit {
    for observer in observers {
      NotificationCenter.default.removeObserver(observer)
    }
  }

  /// Dart is ready (the lock is drawn, or there is none).
  func uncover() {
    if active { hideCover() }
  }

  /// Never stuck: Dart normally uncovers within a frame or two.
  private func uncoverSoon() {
    DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
      self?.uncover()
    }
  }

  private func ifOwnScene(_ note: Notification, _ action: (SceneDelegate) -> Void) {
    guard let scene = note.object as? UIWindowScene, scene === window?.windowScene else { return }
    action(self)
  }

  private func showCover() {
    guard cover == nil, let window = window else { return }
    let view =
      UIStoryboard(name: "LaunchScreen", bundle: nil).instantiateInitialViewController()?.view
      ?? UIView()
    view.backgroundColor = view.backgroundColor ?? .systemBackground
    view.frame = window.bounds
    view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    window.addSubview(view)
    cover = view
  }

  private func hideCover() {
    cover?.removeFromSuperview()
    cover = nil
  }
}
