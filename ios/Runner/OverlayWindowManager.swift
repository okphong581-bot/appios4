import UIKit
import AVFoundation

// MARK: - OverlayError
struct OverlayError {
    let code: String
    let message: String
}

// MARK: - OverlayWindowManager
/// Quản lý cửa sổ nổi toàn cục — hiển thị bên trên TẤT CẢ ứng dụng khác.
///
/// Kỹ thuật cốt lõi để overlay nổi ra ngoài app:
/// 1. `UIWindow(frame:)` — KHÔNG gắn vào windowScene cụ thể để tránh bị ẩn khi app background
/// 2. `windowLevel = 1_000_000` — mức cao nhất, vẽ đè lên tất cả
/// 3. Background audio (AVAudioSession) — giữ app process sống khi user thoát ra ngoài
/// 4. Strong reference tĩnh — window tồn tại suốt vòng đời process, không bị ARC thu hồi
/// 5. `com.apple.private.security.no-sandbox` entitlement (do TrollStore cấp) cho phép điều này
class OverlayWindowManager {

    static let shared = OverlayWindowManager()

    // MARK: - Private State
    // Strong reference — giữ window sống suốt vòng đời process (critical!)
    private var overlayWindow: UIWindow?
    private var audioPlayer: AVAudioPlayer?
    private var isAudioRunning = false

    // Kích thước cửa sổ nổi
    private let windowW: CGFloat = 150
    private let windowH: CGFloat = 52

    // Persistence keys
    private let kPosX = "ha_ox"
    private let kPosY = "ha_oy"

    // MARK: - Public State
    var isOverlayVisible: Bool {
        guard let w = overlayWindow else { return false }
        return !w.isHidden && w.alpha > 0
    }

    private init() {}

    // MARK: - Show / Hide

    /// Bật overlay và giữ app alive trong nền
    func showOverlay(completion: @escaping (Bool, OverlayError?) -> Void) {
        // Luôn chạy trên main thread (UIKit yêu cầu)
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // Nếu window đã tồn tại, chỉ cần make visible
            if let existing = self.overlayWindow {
                existing.isHidden = false
                UIView.animate(withDuration: 0.3) { existing.alpha = 1.0 }
                self.startBackgroundAudio()
                completion(true, nil)
                return
            }

            // Bật audio TRƯỚC khi tạo window để giữ process alive
            self.startBackgroundAudio()

            // Lấy vị trí từ bộ nhớ (hoặc vị trí mặc định)
            let pos = self.savedPosition()
            let frame = CGRect(x: pos.x, y: pos.y, width: self.windowW, height: self.windowH)

            // ─────────────────────────────────────────────────────────
            // CORE TECHNIQUE: Tạo UIWindow với frame, KHÔNG dùng
            // UIWindow(windowScene:) để window tồn tại độc lập với scene
            // ─────────────────────────────────────────────────────────
            let window = UIWindow(frame: frame)
            window.backgroundColor = .clear

            // Window level cực cao — vẽ đè lên tất cả, kể cả alert, status bar
            // UIWindow.Level.alert = 2000, ta dùng 1_000_000 để vượt qua mọi thứ
            window.windowLevel = UIWindow.Level(rawValue: 1_000_000)

            // Gắn rootViewController
            window.rootViewController = OverlayViewController()

            // Cần thiết để window nhận touch input
            window.isUserInteractionEnabled = true

            // Fade-in effect
            window.alpha = 0.0
            window.isHidden = false

            // Trên iOS 13+, gán windowScene để window hiển thị đúng
            // Tuy nhiên dùng scene mà KHÔNG phải scene chính của app
            if let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive })
                    ?? UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first {
                window.windowScene = scene
            }

            // Hiển thị window (quan trọng: gọi sau khi set windowScene)
            window.makeKeyAndVisible()

            // Sau makeKeyAndVisible, hạ key xuống để không chiếm input của app chính
            // overlayWindow chỉ xử lý touch trong vùng của nó
            self.overlayWindow = window

            UIView.animate(withDuration: 0.35, delay: 0, options: [.curveEaseOut]) {
                window.alpha = 1.0
            } completion: { _ in
                completion(true, nil)
            }

            print("[HaOverlay] ✅ Overlay window đã hiển thị tại \(frame)")
        }
    }

    /// Tắt overlay và dừng audio nền
    func hideOverlay(completion: @escaping (Bool, OverlayError?) -> Void) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            guard let window = self.overlayWindow else {
                completion(true, nil)
                return
            }

            // Lưu vị trí trước khi ẩn
            self.persistPosition(window.frame.origin)

            UIView.animate(withDuration: 0.25, delay: 0, options: [.curveEaseIn]) {
                window.alpha = 0.0
            } completion: { [weak self] _ in
                window.isHidden = true
                window.rootViewController = nil
                self?.overlayWindow = nil
                self?.stopBackgroundAudio()
                completion(true, nil)
                print("[HaOverlay] ✅ Overlay đã tắt hoàn toàn")
            }
        }
    }

    /// Toggle trạng thái overlay
    func toggleOverlay(completion: @escaping (Bool, OverlayError?) -> Void) {
        if isOverlayVisible {
            hideOverlay { success, err in completion(false, err) }
        } else {
            showOverlay { success, err in completion(true, err) }
        }
    }

    // MARK: - Position Persistence

    func persistPosition(_ point: CGPoint) {
        UserDefaults.standard.set(Double(point.x), forKey: kPosX)
        UserDefaults.standard.set(Double(point.y), forKey: kPosY)
        UserDefaults.standard.synchronize()
    }

    // Alias để OverlayViewController gọi được
    func savePosition(_ point: CGPoint) {
        persistPosition(point)
    }

    private func savedPosition() -> CGPoint {
        let screen = UIScreen.main.bounds
        let defX = (screen.width - windowW) / 2
        let defY: CGFloat = 130

        let sx = UserDefaults.standard.double(forKey: kPosX)
        let sy = UserDefaults.standard.double(forKey: kPosY)

        guard sx > 1 && sy > 1 else {
            return CGPoint(x: defX, y: defY)
        }

        let clampedX = min(max(0, CGFloat(sx)), screen.width - windowW)
        let clampedY = min(max(60, CGFloat(sy)), screen.height - windowH)
        return CGPoint(x: clampedX, y: clampedY)
    }

    func savePositionIfNeeded() {
        if let w = overlayWindow, !w.isHidden {
            persistPosition(w.frame.origin)
        }
    }

    func syncOverlayState() {
        if isOverlayVisible {
            startBackgroundAudio()
        }
    }

    // MARK: - Background Audio (giữ process sống khi app xuống nền)

    private func startBackgroundAudio() {
        guard !isAudioRunning else { return }

        do {
            let session = AVAudioSession.sharedInstance()
            // .playback + mixWithOthers: phát trong nền, không cướp audio app khác
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)

            let wavData = makeSilentWAV()
            let player = try AVAudioPlayer(data: wavData)
            player.numberOfLoops = -1  // lặp vô hạn
            player.volume = 0.0        // hoàn toàn im lặng
            player.prepareToPlay()
            player.play()

            audioPlayer = player
            isAudioRunning = true
            print("[HaOverlay] 🎵 Background audio đang chạy (giữ process alive)")
        } catch {
            print("[HaOverlay] ⚠️ Audio error: \(error)")
        }
    }

    private func stopBackgroundAudio() {
        audioPlayer?.stop()
        audioPlayer = nil
        isAudioRunning = false

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        print("[HaOverlay] 🔇 Background audio đã dừng")
    }

    /// Tạo 1 giây WAV im lặng (8kHz mono) trong memory
    private func makeSilentWAV() -> Data {
        let sampleRate: Int32 = 8000
        let numSamples = Int(sampleRate)
        let dataSize = numSamples * 2  // 16-bit = 2 bytes/sample

        func le<T>(_ val: T) -> Data {
            var v = val
            return withUnsafeBytes(of: &v) { Data($0) }
        }

        var d = Data()
        d += "RIFF".data(using: .utf8)!
        d += le(Int32(36 + dataSize).littleEndian)
        d += "WAVE".data(using: .utf8)!
        d += "fmt ".data(using: .utf8)!
        d += le(Int32(16).littleEndian)
        d += le(Int16(1).littleEndian)   // PCM
        d += le(Int16(1).littleEndian)   // mono
        d += le(sampleRate.littleEndian)
        d += le(Int32(sampleRate * 2).littleEndian) // byteRate
        d += le(Int16(2).littleEndian)   // blockAlign
        d += le(Int16(16).littleEndian)  // bitsPerSample
        d += "data".data(using: .utf8)!
        d += le(Int32(dataSize).littleEndian)
        d += Data(repeating: 0, count: dataSize)
        return d
    }
}
