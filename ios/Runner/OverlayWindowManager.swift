import UIKit
import AVFoundation

// MARK: - OverlayError
struct OverlayError {
    let code: String
    let message: String
}

// MARK: - OverlayWindowManager
///
/// Kỹ thuật học từ FFHuyShare (ch.xxtou.hudapp):
/// 1. `platform-application` + `accessibility-window-hosting` → window cấp SpringBoard
/// 2. `RunningBoard assertions` → process không bị iOS kill khi background
/// 3. UIWindow KHÔNG gọi makeKeyAndVisible() → không chiếm input của app khác
/// 4. Static strong reference → window không bao giờ bị ARC thu hồi
/// 5. Background audio (AVAudioSession.playback) → keepalive dự phòng
/// 6. darwin notify → lắng nghe SpringBoard events (như FFHuyShare dùng gsEvents)
///
class OverlayWindowManager {

    static let shared = OverlayWindowManager()

    // ─────────────────────────────────────────────────────────
    // CRITICAL: Static strong reference — window tồn tại suốt
    // vòng đời process, không bao giờ bị deallocate bởi ARC
    // ─────────────────────────────────────────────────────────
    private static var overlayWindow: UIWindow?

    private var audioPlayer: AVAudioPlayer?
    private var audioSession: AVAudioSession?
    private var notifyToken: Int32 = 0

    // Kích thước widget overlay
    private let overlayW: CGFloat = 160
    private let overlayH: CGFloat = 54

    // UserDefaults keys
    private let kX = "ha_x", kY = "ha_y"

    var isOverlayVisible: Bool {
        guard let w = Self.overlayWindow else { return false }
        return !w.isHidden && w.alpha > 0.01
    }

    private init() {
        // Lắng nghe darwin notification khi screen bật (giống FFHuyShare gsEvents)
        setupDarwinNotifications()
    }

    // MARK: - Darwin Notifications (học từ FFHuyShare ch.xxtou.hudapp.gsEvents)

    private func setupDarwinNotifications() {
        // Lắng nghe khi SpringBoard thay đổi trạng thái
        let center = CFNotificationCenterGetDarwinNotifyCenter()

        // Khi app chuyển foreground/background
        CFNotificationCenterAddObserver(
            center, Unmanaged.passRetained(self).toOpaque(),
            { _, observer, name, _, _ in
                guard let obs = observer else { return }
                let mgr = Unmanaged<OverlayWindowManager>.fromOpaque(obs).takeUnretainedValue()
                mgr.handleSpringBoardEvent()
            },
            "com.apple.springboard.hasBlankedScreen" as CFString,
            nil, .deliverImmediately
        )
    }

    @objc private func handleSpringBoardEvent() {
        // Khi screen lock/unlock — đảm bảo overlay vẫn hiện
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.isOverlayVisible else { return }
            Self.overlayWindow?.isHidden = false
        }
    }

    // MARK: - Show Overlay

    func showOverlay(completion: @escaping (Bool, OverlayError?) -> Void) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // Nếu window đã tồn tại, chỉ cần show lại
            if let existing = Self.overlayWindow {
                existing.isHidden = false
                UIView.animate(withDuration: 0.3) { existing.alpha = 1.0 }
                self.startKeepAlive()
                completion(true, nil)
                return
            }

            // Bật keepalive TRƯỚC (quan trọng — đảm bảo process không bị suspend)
            self.startKeepAlive()

            // Lấy vị trí đã lưu
            let pos = self.savedPosition()

            // ─────────────────────────────────────────────────────────
            // CORE: Tạo UIWindow theo kiểu FFHuyShare
            // - Không dùng UIWindow(windowScene:) để tránh bị tied vào scene lifecycle
            // - Dùng UIWindow(frame:) — iOS sẽ auto-assign scene nhưng window
            //   vẫn tồn tại độc lập nhờ platform-application entitlement
            // ─────────────────────────────────────────────────────────
            let window = UIWindow(frame: CGRect(
                x: pos.x, y: pos.y,
                width: self.overlayW, height: self.overlayH
            ))
            window.backgroundColor = .clear

            // Gán windowScene (bắt buộc iOS 13+ để render)
            window.windowScene = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .sorted { a, b in
                    // Ưu tiên foreground active scene
                    a.activationState == .foregroundActive &&
                    b.activationState != .foregroundActive
                }
                .first

            // ─────────────────────────────────────────────────────────
            // Window level = 1_000_000_000 (cao hơn alert, status bar, everything)
            // Với platform-application entitlement, iOS cho phép level này
            // ─────────────────────────────────────────────────────────
            window.windowLevel = UIWindow.Level(rawValue: 1_000_000_000)

            window.rootViewController = OverlayViewController()
            window.isUserInteractionEnabled = true

            // ─────────────────────────────────────────────────────────
            // KHÔNG gọi makeKeyAndVisible() — đây là điểm khác biệt chính
            // makeKeyAndVisible() chiếm key window và làm hỏng Flutter input
            // Thay vào đó chỉ set isHidden = false
            // ─────────────────────────────────────────────────────────
            window.alpha = 0.0
            window.isHidden = false

            // Lưu strong reference vào static property
            Self.overlayWindow = window

            // Animate fade in
            UIView.animate(withDuration: 0.35, delay: 0,
                           options: [.curveEaseOut, .allowUserInteraction]) {
                window.alpha = 1.0
            } completion: { _ in
                completion(true, nil)
                print("[HaOverlay] ✅ Overlay visible tại \(pos)")
            }
        }
    }

    // MARK: - Hide Overlay

    func hideOverlay(completion: @escaping (Bool, OverlayError?) -> Void) {
        DispatchQueue.main.async { [weak self] in
            guard let window = Self.overlayWindow else {
                completion(true, nil)
                return
            }

            // Lưu vị trí trước khi ẩn
            self?.persistPosition(window.frame.origin)

            UIView.animate(withDuration: 0.25, delay: 0,
                           options: [.curveEaseIn]) {
                window.alpha = 0.0
            } completion: { [weak self] _ in
                window.isHidden = true
                window.rootViewController = nil
                Self.overlayWindow = nil
                self?.stopKeepAlive()
                completion(true, nil)
                print("[HaOverlay] ✅ Overlay đã tắt")
            }
        }
    }

    // MARK: - Toggle

    func toggleOverlay(completion: @escaping (Bool, OverlayError?) -> Void) {
        if isOverlayVisible {
            hideOverlay { _, err in completion(false, err) }
        } else {
            showOverlay { _, err in completion(true, err) }
        }
    }

    // MARK: - Keep Alive (Background Audio + Session)
    // Học từ FFHuyShare: kết hợp nhiều cơ chế để giữ process sống

    private func startKeepAlive() {
        guard audioPlayer == nil else { return }

        do {
            let session = AVAudioSession.sharedInstance()
            // .playback + mixWithOthers: phát nhạc nền, không làm gián đoạn app khác
            // Đây là cơ chế giúp iOS không suspend process khi background
            try session.setCategory(
                .playback,
                mode: .default,
                options: [.mixWithOthers, .duckOthers]
            )
            try session.setActive(true)

            let player = try AVAudioPlayer(data: makeSilentWAV())
            player.numberOfLoops = -1  // vô hạn
            player.volume = 0.0
            player.prepareToPlay()
            player.play()

            audioPlayer = player
            print("[HaOverlay] 🎵 Keepalive audio started")
        } catch {
            print("[HaOverlay] ⚠️ Keepalive audio error: \(error)")
        }
    }

    private func stopKeepAlive() {
        audioPlayer?.stop()
        audioPlayer = nil
        try? AVAudioSession.sharedInstance().setActive(false,
             options: .notifyOthersOnDeactivation)
        print("[HaOverlay] 🔇 Keepalive stopped")
    }

    // MARK: - Position

    func savePosition(_ point: CGPoint) { persistPosition(point) }

    func persistPosition(_ point: CGPoint) {
        UserDefaults.standard.set(Double(point.x), forKey: kX)
        UserDefaults.standard.set(Double(point.y), forKey: kY)
        UserDefaults.standard.synchronize()
    }

    func savePositionIfNeeded() {
        if let w = Self.overlayWindow { persistPosition(w.frame.origin) }
    }

    func syncOverlayState() {
        if isOverlayVisible { startKeepAlive() }
    }

    private func savedPosition() -> CGPoint {
        let s = UIScreen.main.bounds
        let dx = UserDefaults.standard.double(forKey: kX)
        let dy = UserDefaults.standard.double(forKey: kY)
        guard dx > 1, dy > 1 else {
            return CGPoint(x: (s.width - overlayW) / 2, y: 130)
        }
        return CGPoint(
            x: min(max(0, CGFloat(dx)), s.width  - overlayW),
            y: min(max(60, CGFloat(dy)), s.height - overlayH)
        )
    }

    // MARK: - Silent WAV Generator (1 sec, 8kHz mono PCM)

    private func makeSilentWAV() -> Data {
        let sr: Int32 = 8000
        let ns = Int(sr) * 2  // 2 bytes/sample
        func le<T>(_ v: T) -> Data { var x = v; return withUnsafeBytes(of: &x) { Data($0) } }
        var d = Data()
        d += "RIFF".data(using: .utf8)!; d += le(Int32(36 + ns).littleEndian)
        d += "WAVE".data(using: .utf8)!; d += "fmt ".data(using: .utf8)!
        d += le(Int32(16).littleEndian);  d += le(Int16(1).littleEndian)
        d += le(Int16(1).littleEndian);   d += le(sr.littleEndian)
        d += le(Int32(sr * 2).littleEndian); d += le(Int16(2).littleEndian)
        d += le(Int16(16).littleEndian)
        d += "data".data(using: .utf8)!; d += le(Int32(ns).littleEndian)
        d += Data(repeating: 0, count: ns)
        return d
    }
}
