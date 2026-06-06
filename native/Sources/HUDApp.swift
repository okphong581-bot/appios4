import UIKit

var globalSBSController: NSObject?

class HUDApp: UIApplication {
    // Tùy chỉnh UIApplication cho chế độ daemon
}

class HUDAppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        // Load SpringBoardServices framework
        let bundle = Bundle(path: "/System/Library/PrivateFrameworks/SpringBoardServices.framework")
        bundle?.load()
        
        // Khởi tạo cửa sổ overlay nổi full màn hình để dễ xoay
        let overlayWindow = HUDWindow(frame: UIScreen.main.bounds)
        
        overlayWindow.rootViewController = OverlayViewController()
        overlayWindow.windowLevel = UIWindow.Level(rawValue: 10_000_010)
        overlayWindow.backgroundColor = .clear
        overlayWindow.isUserInteractionEnabled = true
        overlayWindow.isHidden = false
        overlayWindow.makeKeyAndVisible()
        
        self.window = overlayWindow
        
        // Đăng ký cửa sổ với SpringBoard để hiển thị toàn cục
        if let sbsClass = NSClassFromString("SBSAccessibilityWindowHostingController") as? NSObject.Type {
            let controller = sbsClass.init()
            
            // Lấy _contextId
            if let contextId = overlayWindow.value(forKey: "_contextId") as? UInt32 {
                let windowLevel = Double(overlayWindow.windowLevel.rawValue)
                let selector = NSSelectorFromString("registerWindowWithContextID:atLevel:")
                
                typealias RegisterFunc = @convention(c) (AnyObject, Selector, UInt32, Double) -> Void
                let imp = controller.method(for: selector)
                let registerWindow = unsafeBitCast(imp, to: RegisterFunc.self)
                registerWindow(controller, selector, contextId, windowLevel)
                
                // Lưu lại instance để không bị giải phóng
                globalSBSController = controller
            }
        }
        
        return true
    }
}
