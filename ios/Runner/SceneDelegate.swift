import UIKit
import Flutter

/// SceneDelegate — Quản lý vòng đời UIWindowScene (iOS 13+).
/// Đăng ký MethodChannel và lưu vị trí overlay khi app vào nền.
class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?
    private var methodChannel: FlutterMethodChannel?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }
        _ = windowScene  // Ghi chú scene nhưng không dùng để tạo overlay (tránh bị ẩn khi background)

        // Đăng ký MethodChannel từ FlutterViewController của scene này
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.tryRegisterChannel()
        }
    }

    private func tryRegisterChannel() {
        // Thử lấy FlutterViewController từ nhiều nguồn khác nhau
        let flutterVC: FlutterViewController?

        if let fvc = window?.rootViewController as? FlutterViewController {
            flutterVC = fvc
        } else if let appDelegate = UIApplication.shared.delegate as? AppDelegate,
                  let fvc = appDelegate.window?.rootViewController as? FlutterViewController {
            flutterVC = fvc
        } else {
            flutterVC = nil
        }

        guard let fvc = flutterVC else {
            print("[HaOverlay] SceneDelegate: Chưa tìm thấy FlutterViewController.")
            return
        }

        let channel = FlutterMethodChannel(
            name: AppDelegate.channelName,
            binaryMessenger: fvc.binaryMessenger
        )
        self.methodChannel = channel

        channel.setMethodCallHandler { call, result in
            guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else {
                result(FlutterError(code: "NO_DELEGATE", message: "AppDelegate not found", details: nil))
                return
            }
            appDelegate.handleCall(call, result: result)
        }

        print("[HaOverlay] SceneDelegate: MethodChannel đã đăng ký thành công.")
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        OverlayWindowManager.shared.syncOverlayState()
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // App sắp vào nền — lưu vị trí overlay
        OverlayWindowManager.shared.savePositionIfNeeded()
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        OverlayWindowManager.shared.savePositionIfNeeded()
    }
}
