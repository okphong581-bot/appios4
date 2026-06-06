import Foundation
// BackgroundAudioPlayer đã được tích hợp vào OverlayWindowManager.
// File này giữ nguyên để tránh lỗi project.pbxproj reference.
// Không xóa file này.
final class BackgroundAudioPlayer {
    static let shared = BackgroundAudioPlayer()
    private init() {}
    func start() {}
    func stop()  {}
}
