import UIKit

var globalSBSController: NSObject?

class HUDApp: UIApplication {
}

class HUDAppDelegate: UIResponder, UIApplicationDelegate {
    var espWindow: HUDWindow?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        let bundle = Bundle(path: "/System/Library/PrivateFrameworks/SpringBoardServices.framework")
        bundle?.load()
        
        // Use a single full-screen window. Touches are handled by hitTest and ImGuiViewController.
        let espWin = HUDWindow(frame: UIScreen.main.bounds)
        self.espWindow = espWin
        espWin.rootViewController = ImGuiViewController()
        espWin.windowLevel = UIWindow.Level(rawValue: 10_000_010)
        espWin.backgroundColor = .clear
        espWin.isUserInteractionEnabled = true // Must be true to receive touches
        espWin.isHidden = false
        espWin.makeKeyAndVisible()
        
        // Register with SpringBoard
        if let sbsClass = NSClassFromString("SBSAccessibilityWindowHostingController") as? NSObject.Type {
            let selector = NSSelectorFromString("registerWindowWithContextID:atLevel:")
            typealias RegisterFunc = @convention(c) (AnyObject, Selector, UInt32, Double) -> Void
            
            let espController = sbsClass.init()
            if let espCtx = espWin.value(forKey: "_contextId") as? UInt32 {
                let espImp = espController.method(for: selector)
                let espFunc = unsafeBitCast(espImp, to: RegisterFunc.self)
                espFunc(espController, selector, espCtx, 10_000_010.0)
            }
            
            globalSBSController = espController
        }
        
        return true
    }
}
