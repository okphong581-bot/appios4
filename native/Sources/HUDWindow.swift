import UIKit

class HUDWindow: UIWindow {
    
    // Override methods to identify as a secure system window
    @objc func _isSystemWindow() -> Bool { return true }
    @objc func _isWindowServerHostingManaged() -> Bool { return false }
    @objc func _isSecure() -> Bool { return true }
    @objc func _shouldCreateContextAsSecure() -> Bool { return true }
    
    // Allow touch passthrough for empty spaces
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hitView = super.hitTest(point, with: event)
        // Ignore touches on the window itself or the root view controller's view
        if hitView == self || hitView == self.rootViewController?.view {
            return nil
        }
        return hitView
    }
}
