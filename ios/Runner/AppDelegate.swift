import UIKit
import Flutter

/// AppDelegate — Điểm vào chính của ứng dụng iOS.
///
/// Trách nhiệm:
/// 1. Đăng ký các plugins tự động qua `GeneratedPluginRegistrant`.
/// 2. Đăng ký MethodChannel `ha.floating/overlay` để bridge với Flutter/Dart.
/// 3. Xử lý các lệnh từ giao diện Flutter (showOverlay, hideOverlay, toggleOverlay, getOverlayState).
@UIApplicationMain
class AppDelegate: FlutterAppDelegate {

    private static let channelName = "ha.floating/overlay"

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // 1. Đăng ký các plugin của Flutter
        GeneratedPluginRegistrant.register(with: self)

        // 2. Thiết lập cầu nối MethodChannel với Dart
        setupOverlayChannel()

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    private func setupOverlayChannel() {
        guard let controller = window?.rootViewController as? FlutterViewController else {
            // Trong trường hợp dùng SceneDelegate, channel sẽ do SceneDelegate đăng ký
            print("[HaFloating] AppDelegate: Không tìm thấy FlutterViewController, "
                  + "sẽ setup channel từ SceneDelegate.")
            return
        }

        let messenger = controller.binaryMessenger
        let channel = FlutterMethodChannel(
            name: AppDelegate.channelName,
            binaryMessenger: messenger
        )

        channel.setMethodCallHandler { [weak self] call, result in
            self?.handleMethodCall(call, result: result)
        }

        print("[HaFloating] MethodChannel '\(AppDelegate.channelName)' đã được đăng ký thành công.")
    }

    /// Xử lý các phương thức MethodChannel gọi từ Flutter
    func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        print("[HaFloating] Nhận MethodChannel: \(call.method)")

        switch call.method {
        case "showOverlay":
            OverlayWindowManager.shared.showOverlay { success, error in
                if success {
                    result("success")
                } else {
                    result(FlutterError(
                        code: error?.code ?? "SHOW_FAILED",
                        message: error?.message ?? "Không thể hiển thị overlay",
                        details: nil
                    ))
                }
            }
            
        case "hideOverlay":
            OverlayWindowManager.shared.hideOverlay { success, error in
                if success {
                    result("success")
                } else {
                    result(FlutterError(
                        code: error?.code ?? "HIDE_FAILED",
                        message: error?.message ?? "Không thể ẩn overlay",
                        details: nil
                    ))
                }
            }
            
        case "toggleOverlay":
            OverlayWindowManager.shared.toggleOverlay { isVisible, error in
                if let error = error {
                    result(FlutterError(
                        code: error.code,
                        message: error.message,
                        details: nil
                    ))
                } else {
                    result(isVisible)
                }
            }
            
        case "getOverlayState":
            let isVisible = OverlayWindowManager.shared.isOverlayVisible
            result(isVisible)
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
