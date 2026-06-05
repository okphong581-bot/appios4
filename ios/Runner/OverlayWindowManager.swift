import UIKit

/// Lỗi tuỳ chỉnh liên quan đến overlay.
struct OverlayError {
    let code: String
    let message: String
    let details: Any? = nil
}

/// OverlayWindowManager — Điều phối chính cho trạng thái, hiển thị và lưu trữ của cửa sổ nổi.
///
/// Trách nhiệm:
/// 1. Quản lý vòng đời của `UIWindow` đại diện cho overlay.
/// 2. Liên kết `UIWindow` với `UIWindowScene` hiện tại (bắt buộc từ iOS 13+).
/// 3. Lưu trữ tọa độ cuối cùng qua `UserDefaults` và tải lại khi hiển thị lại.
/// 4. Quản lý hiệu ứng fade-in (hiện) và fade-out (ẩn) mượt mà.
/// 5. Gọi `BackgroundAudioPlayer` để duy trì tiến trình chạy ngầm.
class OverlayWindowManager {
    
    static let shared = OverlayWindowManager()
    
    // ──────────────────────────────────────────────────────────────
    // Properties
    // ──────────────────────────────────────────────────────────────
    
    private var overlayWindow: UIWindow?
    private weak var activeScene: UIWindowScene?
    
    // Kích thước cố định cho widget "Hà Nhạy VIP"
    private let windowWidth: CGFloat = 136
    private let windowHeight: CGFloat = 46
    
    // Key để lưu UserDefaults
    private let kPositionX = "ha_overlay_position_x"
    private let kPositionY = "ha_overlay_position_y"
    
    /// Trạng thái hiển thị thực tế của overlay
    var isOverlayVisible: Bool {
        return overlayWindow != nil && !overlayWindow!.isHidden
    }
    
    private init() {}
    
    // ──────────────────────────────────────────────────────────────
    // Scene Management
    // ──────────────────────────────────────────────────────────────
    
    /// Lưu tham chiếu đến Window Scene hiện tại từ SceneDelegate
    func setScene(_ scene: UIWindowScene) {
        self.activeScene = scene
        // Nếu overlay đang hiển thị, cập nhật scene cho nó
        if let window = overlayWindow {
            window.windowScene = scene
        }
    }
    
    // ──────────────────────────────────────────────────────────────
    // Core Actions
    // ──────────────────────────────────────────────────────────────
    
    /// Hiển thị overlay với hiệu ứng fade-in.
    func showOverlay(completion: @escaping (Bool, OverlayError?) -> Void) {
        // Nếu đã hiện rồi thì báo thành công luôn
        guard overlayWindow == nil else {
            completion(true, nil)
            return
        }
        
        // Kích hoạt audio chạy ngầm để giữ app không bị iOS đình chỉ (suspend)
        BackgroundAudioPlayer.shared.start()
        
        // Tính toán toạ độ hiển thị (tải từ bộ nhớ hoặc vị trí mặc định)
        let savedPosition = loadPosition()
        let initialFrame = CGRect(
            origin: savedPosition,
            size: CGSize(width: windowWidth, height: windowHeight)
        )
        
        // Khởi tạo cửa sổ mới
        let window = UIWindow(frame: initialFrame)
        window.backgroundColor = .clear
        
        // Liên kết Window Scene
        if #available(iOS 13.0, *), let scene = activeScene {
            window.windowScene = scene
        }
        
        // Thiết lập cấp độ cửa sổ cao nhất (nằm trên cả status bar và các alert chuẩn)
        // Hệ thống sẽ cho phép nếu app có entitlement no-sandbox / TrollStore
        window.windowLevel = UIWindow.Level(rawValue: 1000000)
        
        // Gắn ViewController quản lý giao diện
        window.rootViewController = OverlayViewController()
        
        // Đảm bảo không bắt tương tác của phần màn hình nằm ngoài khung overlay
        window.isUserInteractionEnabled = true
        
        // Thiết lập alpha = 0 để làm hiệu ứng fade in
        window.alpha = 0.0
        window.isHidden = false
        
        self.overlayWindow = window
        
        // Animate fade-in
        UIView.animate(withDuration: 0.35, delay: 0, options: [.curveEaseOut], animations: {
            window.alpha = 1.0
        }) { _ in
            completion(true, nil)
        }
    }
    
    /// Ẩn overlay với hiệu ứng fade-out và tắt âm thanh nền.
    func hideOverlay(completion: @escaping (Bool, OverlayError?) -> Void) {
        guard let window = overlayWindow else {
            completion(true, nil)
            return
        }
        
        // Animate fade-out
        UIView.animate(withDuration: 0.3, delay: 0, options: [.curveEaseIn], animations: {
            window.alpha = 0.0
        }) { [weak self] _ in
            window.isHidden = true
            self?.overlayWindow = nil
            
            // Dừng phát âm thanh chạy ngầm để tiết kiệm pin
            BackgroundAudioPlayer.shared.stop()
            completion(true, nil)
        }
    }
    
    /// Bật/Tắt trạng thái overlay
    func toggleOverlay(completion: @escaping (Bool, OverlayError?) -> Void) {
        if isOverlayVisible {
            hideOverlay { success, error in
                completion(false, error)
            }
        } else {
            showOverlay { success, error in
                completion(true, error)
            }
        }
    }
    
    /// Lưu vị trí hiện tại của overlay nếu ứng dụng đóng đột ngột hoặc đi vào nền
    func savePositionIfNeeded() {
        if let window = overlayWindow {
            savePosition(window.frame.origin)
        }
    }
    
    /// Đồng bộ trạng thái overlay khi app mở lại
    func syncOverlayState() {
        // Tái khởi động background audio nếu cửa sổ đang mở
        if isOverlayVisible {
            BackgroundAudioPlayer.shared.start()
        }
    }
    
    // ──────────────────────────────────────────────────────────────
    // UserDefaults Persistence Helpers
    // ──────────────────────────────────────────────────────────────
    
    /// Lưu toạ độ x, y
    func savePosition(_ point: CGPoint) {
        UserDefaults.standard.set(Double(point.x), forKey: kPositionX)
        UserDefaults.standard.set(Double(point.y), forKey: kPositionY)
        UserDefaults.standard.synchronize()
    }
    
    /// Tải toạ độ x, y từ UserDefaults (trả về toạ độ mặc định ở góc trên nếu chưa lưu)
    private func loadPosition() -> CGPoint {
        let screen = UIScreen.main.bounds
        
        // Vị trí mặc định: Ở phía trên bên trái màn hình, cách tai thỏ/dynamic island một khoảng an toàn
        let defaultX = (screen.width - windowWidth) / 2
        let defaultY: CGFloat = 120.0
        
        let savedX = UserDefaults.standard.double(forKey: kPositionX)
        let savedY = UserDefaults.standard.double(forKey: kPositionY)
        
        // Nếu toạ độ lưu hợp lệ (> 0) thì trả về toạ độ đã lưu
        if savedX > 0 && savedY > 0 {
            // Kiểm tra xem vị trí có nằm ngoài giới hạn màn hình hiện tại không (do đổi hướng xoay dọc/ngang)
            let finalX = min(CGFloat(savedX), screen.width - windowWidth)
            let finalY = min(CGFloat(savedY), screen.height - windowHeight)
            return CGPoint(x: max(0, finalX), y: max(0, finalY))
        }
        
        return CGPoint(x: defaultX, y: defaultY)
    }
}
