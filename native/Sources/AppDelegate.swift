import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        let window = UIWindow(frame: UIScreen.main.bounds)
        let viewController = MainViewController()
        window.rootViewController = viewController
        window.makeKeyAndVisible()
        self.window = window
        
        return true
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        OverlayWindowManager.shared.savePositionIfNeeded()
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        OverlayWindowManager.shared.syncOverlayState()
    }
}
