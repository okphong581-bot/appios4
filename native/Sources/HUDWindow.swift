import UIKit

class HUDWindow: UIWindow {
    
    // Cho phép click xuyên qua những khoảng trống (không có UI)
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if let vc = self.rootViewController as? OverlayViewController {
            vc.updateDebugText("hitTest called at:\n X: \(Int(point.x)), Y: \(Int(point.y))\nEvent: \(String(describing: event))")
        }
        
        let hitView = super.hitTest(point, with: event)
        
        // Nếu hitView là chính window hoặc view nền của root view controller (tức là chạm vào chỗ trống), cho xuyên qua
        if hitView == self || hitView == self.rootViewController?.view {
            return nil
        }
        
        return hitView
    }
}
