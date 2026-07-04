import UIKit

class HUDWindow: UIWindow {
    
    // Override các hàm private để iOS hiểu đây là cửa sổ hệ thống
    @objc func _isSystemWindow() -> Bool { return true }
    @objc func _isWindowServerHostingManaged() -> Bool { return false }
    @objc func _isSecure() -> Bool { return true }
    @objc func _shouldCreateContextAsSecure() -> Bool { return true }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hitView = super.hitTest(point, with: event)
        
        // Nếu đang ở chế độ ghi điểm (recording), cho phép bắt tất cả touches
        if let vc = self.rootViewController as? OverlayViewController, vc.isRecordingMode {
            // Bỏ qua menu button và panel để chúng vẫn hoạt động bình thường
            if let hit = hitView, hit != self, hit != vc.view {
                return hit
            }
            // Trả về view chính để bắt touches khi chạm vào vùng trống
            return vc.view
        }
        
        // Chế độ bình thường: cho xuyên qua vùng trống
        if hitView == self || hitView == self.rootViewController?.view {
            return nil
        }
        
        return hitView
    }
}
