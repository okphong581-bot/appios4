import Foundation
import UIKit

struct OverlayError {
    let code: String
    let message: String
}

class OverlayWindowManager {
    static let shared = OverlayWindowManager()
    
    private var overlayWindow: HUDWindow?
    
    private let kPositionX = "ha_overlay_position_x"
    private let kPositionY = "ha_overlay_position_y"
    
    var isOverlayVisible: Bool {
        return overlayWindow != nil && !overlayWindow!.isHidden
    }
    
    private init() {
    }
    
    func showOverlay(completion: @escaping (Bool, OverlayError?) -> Void) {
        guard overlayWindow == nil else {
            completion(true, nil)
            return
        }
        
        // Kích hoạt audio chạy ngầm để giữ app không bị iOS đình chỉ (suspend)
        BackgroundAudioPlayer.shared.start()
        
        // Sử dụng một cửa sổ toàn màn hình để chứa cả menu kéo thả và các nét vẽ ESP sau này
        let window = HUDWindow(frame: UIScreen.main.bounds)
        window.backgroundColor = .clear
        
        // CHÚ Ý: KHÔNG gán windowScene cho overlayWindow để tránh bị ẩn khi app chính vào background.
        // Quyền 'com.apple.springboard.accessibility-window-hosting' sẽ tự vẽ đè lên hệ thống ở background.
        window.windowLevel = UIWindow.Level(rawValue: 10_000_010)
        window.rootViewController = OverlayViewController()
        window.isUserInteractionEnabled = true
        window.isHidden = false
        
        // Làm cửa sổ trở thành key window để nhận bàn phím/touch tốt hơn
        window.makeKeyAndVisible()
        window.makeKey()
        
        self.overlayWindow = window
        
        print("[HUDManager] Đã hiển thị overlay trực tiếp từ App chính với Background Audio.")
        completion(true, nil)
    }
    
    func hideOverlay(completion: @escaping (Bool, OverlayError?) -> Void) {
        guard let window = overlayWindow else {
            completion(true, nil)
            return
        }
        
        window.isHidden = true
        self.overlayWindow = nil
        
        // Dừng phát âm thanh chạy ngầm
        BackgroundAudioPlayer.shared.stop()
        
        print("[HUDManager] Đã ẩn overlay và dừng Background Audio.")
        completion(true, nil)
    }
    
    func toggleOverlay(completion: @escaping (Bool, OverlayError?) -> Void) {
        if isOverlayVisible {
            hideOverlay { success, error in
                completion(!success, error)
            }
        } else {
            showOverlay { success, error in
                completion(success, error)
            }
        }
    }
    
    func savePositionIfNeeded() {
        if let vc = overlayWindow?.rootViewController as? OverlayViewController,
           let menuButton = vc.view.subviews.first(where: { $0 is DraggableView }) {
            savePosition(menuButton.frame.origin)
        }
    }
    
    func syncOverlayState() {
        if isOverlayVisible {
            BackgroundAudioPlayer.shared.start()
        }
    }
    
    func savePosition(_ point: CGPoint) {
        UserDefaults.standard.set(Double(point.x), forKey: kPositionX)
        UserDefaults.standard.set(Double(point.y), forKey: kPositionY)
        UserDefaults.standard.synchronize()
    }
    
    func loadPosition() -> CGPoint {
        let screen = UIScreen.main.bounds
        let defaultX = (screen.width - 70) / 2
        let defaultY: CGFloat = 120.0
        
        let savedX = UserDefaults.standard.double(forKey: kPositionX)
        let savedY = UserDefaults.standard.double(forKey: kPositionY)
        
        if savedX > 0 && savedY > 0 {
            let finalX = min(CGFloat(savedX), screen.width - 70)
            let finalY = min(CGFloat(savedY), screen.height - 50)
            return CGPoint(x: max(0, finalX), y: max(0, finalY))
        }
        return CGPoint(x: defaultX, y: defaultY)
    }
}
