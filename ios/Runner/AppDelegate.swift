import UIKit
import Flutter

/// AppDelegate — Điểm khởi động chính của ứng dụng.
/// Đăng ký MethodChannel `ha.floating/overlay` để bridge Flutter ↔ iOS native.
@UIApplicationMain
class AppDelegate: FlutterAppDelegate {

    static let channelName = "ha.floating/overlay"

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)

        // Setup MethodChannel nếu rootViewController đã sẵn sàng
        // (trong trường hợp không dùng Scene-based lifecycle)
        if let controller = window?.rootViewController as? FlutterViewController {
            registerChannel(messenger: controller.binaryMessenger)
        }

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    func registerChannel(messenger: FlutterBinaryMessenger) {
        let channel = FlutterMethodChannel(
            name: AppDelegate.channelName,
            binaryMessenger: messenger
        )
        channel.setMethodCallHandler { [weak self] call, result in
            self?.handleCall(call, result: result)
        }
        print("[HaOverlay] MethodChannel '\(AppDelegate.channelName)' đã đăng ký.")
    }

    func handleCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "showOverlay":
            OverlayWindowManager.shared.showOverlay { success, error in
                if success {
                    result("success")
                } else {
                    result(FlutterError(code: error?.code ?? "ERR", message: error?.message, details: nil))
                }
            }

        case "hideOverlay":
            OverlayWindowManager.shared.hideOverlay { success, error in
                if success {
                    result("success")
                } else {
                    result(FlutterError(code: error?.code ?? "ERR", message: error?.message, details: nil))
                }
            }

        case "getOverlayState":
            result(OverlayWindowManager.shared.isOverlayVisible)

        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
