import UIKit

class HUDWindow: UIWindow {
    
    // Override các hàm private để iOS hiểu đây là cửa sổ hệ thống (không bị ẩn)
    @objc func _isSystemWindow() -> Bool { return true }
    @objc func _isWindowServerHostingManaged() -> Bool { return false }
    @objc func _isSecure() -> Bool { return true }
    @objc func _shouldCreateContextAsSecure() -> Bool { return true }
    
    // Cho phép click xuyên qua những khoảng trống (không có UI)
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if let vc = self.rootViewController as? OverlayViewController {
            vc.updateDebugText("hitTest called at:\n X: \(Int(point.x)), Y: \(Int(point.y))\nEvent: \(String(describing: event))")
        }
        
        let hitView = super.hitTest(point, with: event)
        // Nếu hitView là chính window (tức là chạm vào chỗ trống), cho xuyên qua
        if hitView == self {
            return nil
        }
        return hitView
    }
}
