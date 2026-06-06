import Foundation

// BackgroundAudioPlayer đã được gộp vào OverlayWindowManager.
// File này được giữ để tương thích với project.pbxproj references.
// Không xóa file này.
@available(*, deprecated, renamed: "OverlayWindowManager")
final class BackgroundAudioPlayer {
    static let shared = BackgroundAudioPlayer()
    private init() {}
    func start() { OverlayWindowManager.shared.syncOverlayState() }
    func stop()  {}
}
