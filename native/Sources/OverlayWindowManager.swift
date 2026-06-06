import UIKit
import AVFoundation

struct OverlayError {
    let code: String
    let message: String
}

class OverlayWindowManager {
    static let shared = OverlayWindowManager()

    private static var overlayWindow: UIWindow?
    private var audioPlayer: AVAudioPlayer?
    private var audioSession: AVAudioSession?

    private let overlayW: CGFloat = 160
    private let overlayH: CGFloat = 54

    private let kX = "ha_x", kY = "ha_y"

    var isOverlayVisible: Bool {
        guard let w = Self.overlayWindow else { return false }
        return !w.isHidden && w.alpha > 0.01
    }

    private init() {
        setupDarwinNotifications()
    }

    private func setupDarwinNotifications() {
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterAddObserver(
            center, Unmanaged.passRetained(self).toOpaque(),
            { _, observer, _, _, _ in
                guard let obs = observer else { return }
                let mgr = Unmanaged<OverlayWindowManager>.fromOpaque(obs).takeUnretainedValue()
                mgr.handleSpringBoardEvent()
            },
            "com.apple.springboard.hasBlankedScreen" as CFString,
            nil, .deliverImmediately
        )
    }

    @objc private func handleSpringBoardEvent() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.isOverlayVisible else { return }
            Self.overlayWindow?.isHidden = false
        }
    }

    func showOverlay(completion: @escaping (Bool, OverlayError?) -> Void) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            if let existing = Self.overlayWindow {
                existing.isHidden = false
                UIView.animate(withDuration: 0.3) { existing.alpha = 1.0 }
                self.startKeepAlive()
                completion(true, nil)
                return
            }

            self.startKeepAlive()

            let pos = self.savedPosition()
            let window = UIWindow(frame: CGRect(
                x: pos.x, y: pos.y,
                width: self.overlayW, height: self.overlayH
            ))
            window.backgroundColor = .clear

            window.windowScene = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first

            window.windowLevel = UIWindow.Level(rawValue: 1_000_000_000)
            window.rootViewController = OverlayViewController()
            window.isUserInteractionEnabled = true
            window.alpha = 0.0
            window.isHidden = false

            Self.overlayWindow = window

            UIView.animate(withDuration: 0.35, delay: 0,
                           options: [.curveEaseOut, .allowUserInteraction]) {
                window.alpha = 1.0
            } completion: { _ in
                completion(true, nil)
                print("[HaOverlay] Overlay visible at \(pos)")
            }
        }
    }

    func hideOverlay(completion: @escaping (Bool, OverlayError?) -> Void) {
        DispatchQueue.main.async { [weak self] in
            guard let window = Self.overlayWindow else {
                completion(true, nil)
                return
            }

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
                print("[HaOverlay] Overlay hidden")
            }
        }
    }

    private func startKeepAlive() {
        guard audioPlayer == nil else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers, .duckOthers])
            try session.setActive(true)

            let player = try AVAudioPlayer(data: makeSilentWAV())
            player.numberOfLoops = -1
            player.volume = 0.0
            player.prepareToPlay()
            player.play()

            audioPlayer = player
        } catch {
            print("[HaOverlay] Keepalive audio error: \(error)")
        }
    }

    private func stopKeepAlive() {
        audioPlayer?.stop()
        audioPlayer = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

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

    private func makeSilentWAV() -> Data {
        let sr: Int32 = 8000
        let ns = Int(sr) * 2
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
