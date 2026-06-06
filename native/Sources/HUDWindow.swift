import UIKit

class HUDWindow: UIWindow {
    
    // Override các hàm private để iOS hiểu đây là cửa sổ hệ thống (không bị ẩn)
    @objc func _isSystemWindow() -> Bool { return true }
    @objc func _isWindowServerHostingManaged() -> Bool { return false }
    @objc func _isSecure() -> Bool { return true }
    @objc func _shouldCreateContextAsSecure() -> Bool { return true }
    
    // Cho phép click xuyên qua những khoảng trống (không có UI)
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        // Mặc định UIWindow sẽ chặn touch nếu point nằm ngoài bounds của nó.
        // Trong chế độ daemon, toạ độ touch có thể bị lộn ngược do xoay màn hình, 
        // khiến point nằm ngoài bounds của UIWindow gốc.
        // Giải pháp: Duyệt qua tất cả các view con để tìm view có thể nhận touch.
        
        guard let root = self.rootViewController?.view else {
            return nil
        }
        
        // Chuyển point sang toạ độ của root view
        let rootPoint = self.convert(point, to: root)
        
        if let hitView = root.hitTest(rootPoint, with: event) {
            // Nếu chạm vào chính root view (trong suốt) thì bỏ qua
            if hitView == root {
                return nil
            }
            return hitView
        }
        
        return nil
    }
}
