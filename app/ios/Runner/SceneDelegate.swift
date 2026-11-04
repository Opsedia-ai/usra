import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  private var cover: UIView?
  private var observers: [NSObjectProtocol] = []

  override init() {
    super.init()
    // Health records must not show in the app switcher: iOS snapshots the
    // window once the app goes inactive, so cover it then (the launch
    // screen) and uncover when it's active again. Notifications rather than
    // overriding the scene callbacks, which FlutterSceneDelegate needs.
    let center = NotificationCenter.default
    observers = [
      center.addObserver(
        forName: UIScene.willDeactivateNotification, object: nil, queue: .main
      ) { [weak self] note in
        self?.ifOwnScene(note) { $0.showCover() }
      },
      center.addObserver(
        forName: UIScene.didActivateNotification, object: nil, queue: .main
      ) { [weak self] note in
        self?.ifOwnScene(note) { $0.hideCover() }
      },
    ]
  }

  deinit {
    for observer in observers {
      NotificationCenter.default.removeObserver(observer)
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
