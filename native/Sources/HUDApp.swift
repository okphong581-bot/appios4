import UIKit

class HUDApp: UIApplication {
    // Tùy chỉnh UIApplication cho chế độ daemon
}

class HUDAppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        // Khởi tạo cửa sổ overlay nổi
        let overlayWindow = HUDWindow(frame: UIScreen.main.bounds)
        
        // Cần đảm bảo KHÔNG gắn windowScene
        // overlayWindow.windowScene = nil
        
        overlayWindow.rootViewController = OverlayViewController()
        overlayWindow.windowLevel = UIWindow.Level(rawValue: 1_000_000_000)
        overlayWindow.backgroundColor = .clear
        overlayWindow.isUserInteractionEnabled = true
        overlayWindow.isHidden = false
        
        self.window = overlayWindow
        
        return true
    }
}
