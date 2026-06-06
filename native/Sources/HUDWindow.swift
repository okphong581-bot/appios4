import UIKit

class HUDWindow: UIWindow {
    
    // Override các hàm private d? iOS hi?u dây là c?a s? h? th?ng (không b? ?n)
    @objc func _isSystemWindow() -> Bool { return true }
    @objc func _isWindowServerHostingManaged() -> Bool { return false }
    @objc func _isSecure() -> Bool { return true }
    @objc func _shouldCreateContextAsSecure() -> Bool { return true }
    
    // Cho phép click xuyên qua nh?ng kho?ng tr?ng (không có UI)
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hitView = super.hitTest(point, with: event)
        // B? qua các s? ki?n touch vào background trong su?t c?a window
        if hitView == self || hitView == self.rootViewController?.view {
            return nil
        }
        return hitView
    }
}
