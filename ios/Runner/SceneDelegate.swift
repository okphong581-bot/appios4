import UIKit
import Flutter

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?
    private var channel: FlutterMethodChannel?

    func scene(_ scene: UIScene,
               willConnectTo session: UISceneSession,
               options: UIScene.ConnectionOptions) {
        // Đợi Flutter engine khởi động xong rồi mới đăng ký channel
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.tryRegisterChannel()
        }
    }

    private func tryRegisterChannel() {
        // Lấy FlutterViewController từ scene window hoặc AppDelegate window
        let fvc: FlutterViewController? =
            (window?.rootViewController as? FlutterViewController) ??
            (UIApplication.shared.delegate as? AppDelegate)?
                .window?.rootViewController as? FlutterViewController

        guard let fvc = fvc else {
            print("[HaOverlay] SceneDelegate: FlutterVC chưa sẵn sàng, thử lại...")
            // Thử lại sau thêm 0.3s nếu Flutter chưa xong
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.tryRegisterChannel()
            }
            return
        }

        let ch = FlutterMethodChannel(name: AppDelegate.channelName,
                                      binaryMessenger: fvc.binaryMessenger)
        channel = ch
        ch.setMethodCallHandler { call, result in
            (UIApplication.shared.delegate as? AppDelegate)?
                .handle(call, result: result)
                ?? result(FlutterError(code: "NO_DELEGATE",
                                       message: "AppDelegate not found", details: nil))
        }
        print("[HaOverlay] ✅ MethodChannel registered via SceneDelegate")
    }

    func sceneWillResignActive(_ scene: UIScene) {
        OverlayWindowManager.shared.savePositionIfNeeded()
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        OverlayWindowManager.shared.savePositionIfNeeded()
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        OverlayWindowManager.shared.syncOverlayState()
    }
}
