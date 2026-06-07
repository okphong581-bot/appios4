import UIKit

class HUDWindow: UIWindow {
    
    // Override các hàm private để iOS hiểu đây là cửa sổ hệ thống (không bị ẩn)
    @objc func _isSystemWindow() -> Bool { return true }
    @objc func _isWindowServerHostingManaged() -> Bool { return false }
    @objc func _isSecure() -> Bool { return true }
    override var canBecomeKey: Bool {
        return true
    }
    
    @objc func _ignoresHitTest() -> Bool {
        return false
    }

    // Xác định điểm chạm có nằm trong khu vực tương tác hay không
    override func pointInside(_ point: CGPoint, with event: UIEvent?) -> Bool {
        if let vc = self.rootViewController as? OverlayViewController {
            vc.updateDebugText("pointInside called at:\n X: \(Int(point.x)), Y: \(Int(point.y))")
        }
        
        let inside = super.pointInside(point, with: event)
        return inside
    }

    // Trả về View thực sự bắt sự kiện
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if let vc = self.rootViewController as? OverlayViewController {
            vc.updateDebugText("hitTest called at:\n X: \(Int(point.x)), Y: \(Int(point.y))\nEvent: \(event?.type.rawValue ?? -1)")
        }
        
        let hitView = super.hitTest(point, with: event)
        
        // Nếu điểm chạm rơi vào chính Window hoặc View gốc có nền trong suốt -> Bỏ qua để xuyên qua Game
        if hitView == self || hitView == self.rootViewController?.view {
            return nil
        }
        
        return hitView
    }
}
