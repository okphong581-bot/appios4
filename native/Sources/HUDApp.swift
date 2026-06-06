import UIKit

var globalSBSController: NSObject?
var globalSBSMenuController: NSObject?

class HUDApp: UIApplication {
    // Tùy chỉnh UIApplication cho chế độ daemon
}

class HUDAppDelegate: UIResponder, UIApplicationDelegate {
    var espWindow: HUDWindow?
    var menuWindow: HUDWindow?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        let bundle = Bundle(path: "/System/Library/PrivateFrameworks/SpringBoardServices.framework")
        bundle?.load()
        
        // 1. ESP Window (Full screen, no touches)
        let espWin = HUDWindow(frame: UIScreen.main.bounds)
        self.espWindow = espWin
        espWin.rootViewController = ESPViewController()
        espWin.windowLevel = UIWindow.Level(rawValue: 10_000_010)
        espWin.backgroundColor = .clear
        espWin.isUserInteractionEnabled = false // KHÔNG nhận touch
        espWin.isHidden = false
        espWin.makeKeyAndVisible()
        
        // 2. Menu Window (Small size, draggable, receives touches)
        let menuWin = HUDWindow(frame: CGRect(x: 40, y: 100, width: 70, height: 50))
        self.menuWindow = menuWin
        let menuVC = MenuViewController()
        menuWin.rootViewController = menuVC
        menuWin.windowLevel = UIWindow.Level(rawValue: 10_000_011) // Nằm trên ESP
        menuWin.backgroundColor = .clear
        menuWin.isUserInteractionEnabled = true // Nhận touch
        menuWin.isHidden = false
        menuWin.makeKeyAndVisible()
        
        // Gắn reference để MenuVC có thể bật tắt ESP
        menuVC.espViewController = espWin.rootViewController as? ESPViewController
        
        // Đăng ký với SpringBoard
        if let sbsClass = NSClassFromString("SBSAccessibilityWindowHostingController") as? NSObject.Type {
            let selector = NSSelectorFromString("registerWindowWithContextID:atLevel:")
            typealias RegisterFunc = @convention(c) (AnyObject, Selector, UInt32, Double) -> Void
            
            // Đăng ký ESP
            let espController = sbsClass.init()
            if let espCtx = espWin.value(forKey: "_contextId") as? UInt32 {
                let imp = espController.method(for: selector)
                let registerWindow = unsafeBitCast(imp, to: RegisterFunc.self)
                registerWindow(espController, selector, espCtx, Double(espWin.windowLevel.rawValue))
                globalSBSController = espController
            }
            
            // Đăng ký Menu
            let menuController = sbsClass.init()
            if let menuCtx = menuWin.value(forKey: "_contextId") as? UInt32 {
                let imp = menuController.method(for: selector)
                let registerWindow = unsafeBitCast(imp, to: RegisterFunc.self)
                registerWindow(menuController, selector, menuCtx, Double(menuWin.windowLevel.rawValue))
                globalSBSMenuController = menuController
            }
        }
        
        return true
    }
}
