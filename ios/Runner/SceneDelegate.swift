import UIKit
import Flutter

/// SceneDelegate — Quản lý vòng đời UIWindowScene (iOS 13+).
///
/// Trách nhiệm:
/// 1. Liên kết WindowScene đang hoạt động với `OverlayWindowManager`.
/// 2. Hỗ trợ đăng ký MethodChannel dự phòng nếu FlutterViewController được nạp qua Scene Session.
/// 3. Lưu toạ độ overlay khi app đi vào nền (Background).
/// 4. Đồng bộ/Tái khởi động audio chạy ngầm khi app quay lại hoạt động (Foreground).
class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    private static let channelName = "ha.floating/overlay"
    var window: UIWindow?
    private var methodChannel: FlutterMethodChannel?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }

        // Gắn kết Window Scene hiện tại vào quản lý overlay
        OverlayWindowManager.shared.setScene(windowScene)

        // Cấu hình MethodChannel nếu rootViewController là FlutterViewController
        if let flutterVC = window?.rootViewController as? FlutterViewController {
            setupMethodChannel(messenger: flutterVC.binaryMessenger)
        } else {
            // Dự phòng: Lấy từ AppDelegate
            if let appDelegate = UIApplication.shared.delegate as? AppDelegate,
               let rootVC = appDelegate.window?.rootViewController as? FlutterViewController {
                setupMethodChannel(messenger: rootVC.binaryMessenger)
            }
        }
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        print("[HaFloating] Scene did disconnect.")
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        print("[HaFloating] Scene did become active.")
    }

    func sceneWillResignActive(_ scene: UIScene) {
        print("[HaFloating] Scene will resign active.")
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Đồng bộ trạng thái và giữ cho Audio chạy ngầm tiếp tục khi app bật lại
        OverlayWindowManager.shared.syncOverlayState()
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Tự động lưu toạ độ hiện tại khi thoát ứng dụng hoặc tắt màn hình
        OverlayWindowManager.shared.savePositionIfNeeded()
    }

    // ──────────────────────────────────────────────────────────────
    // Private Helpers
    // ──────────────────────────────────────────────────────────────

    private func setupMethodChannel(messenger: FlutterBinaryMessenger) {
        let channel = FlutterMethodChannel(
            name: SceneDelegate.channelName,
            binaryMessenger: messenger
        )

        self.methodChannel = channel

        channel.setMethodCallHandler { [weak self] call, result in
            guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else {
                result(FlutterError(
                    code: "NO_APP_DELEGATE",
                    message: "Không tìm thấy AppDelegate",
                    details: nil
                ))
                return
            }
            appDelegate.handleMethodCall(call, result: result)
        }

        print("[HaFloating] SceneDelegate: Đã liên kết MethodChannel thành công.")
    }
}
