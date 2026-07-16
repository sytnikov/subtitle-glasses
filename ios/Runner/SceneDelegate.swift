import Flutter
import UIKit

/// Forwards inbound URL contexts (the Meta AI registration callback,
/// `finnishsubtitles://...`) to `meta_wearables_dat_flutter` via a
/// well-known NSNotification, since `FlutterSceneDelegate` does not
/// auto-forward URLs to plugins on scene-based apps.
class SceneDelegate: FlutterSceneDelegate {

  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    forward(urlContexts: connectionOptions.urlContexts)
  }

  override func scene(
    _ scene: UIScene,
    openURLContexts URLContexts: Set<UIOpenURLContext>
  ) {
    super.scene(scene, openURLContexts: URLContexts)
    forward(urlContexts: URLContexts)
  }

  private func forward(urlContexts: Set<UIOpenURLContext>) {
    for context in urlContexts {
      NotificationCenter.default.post(
        name: Notification.Name("MetaWearablesDatHandleURL"),
        object: nil,
        userInfo: ["url": context.url],
      )
    }
  }
}
