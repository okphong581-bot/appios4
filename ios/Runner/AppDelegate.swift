import UIKit
import Flutter

@UIApplicationMain
class AppDelegate: FlutterAppDelegate {

    static let channelName = "ha.floating/overlay"

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)

        // Đăng ký channel ngay nếu có FlutterViewController
        setupChannel()

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    func setupChannel() {
        // Thử lấy FlutterViewController từ window
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self = self,
                  let ctrl = self.window?.rootViewController as? FlutterViewController else {
                return
            }
            self.registerChannel(on: ctrl.binaryMessenger)
        }
    }

    func registerChannel(on messenger: FlutterBinaryMessenger) {
        let ch = FlutterMethodChannel(name: AppDelegate.channelName,
                                      binaryMessenger: messenger)
        ch.setMethodCallHandler { [weak self] call, result in
            self?.handle(call, result: result)
        }
        print("[HaOverlay] ✅ MethodChannel registered via AppDelegate")
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "showOverlay":
            OverlayWindowManager.shared.showOverlay { ok, err in
                ok ? result("success") : result(FlutterError(
                    code: err?.code ?? "ERR",
                    message: err?.message, details: nil))
            }
        case "hideOverlay":
            OverlayWindowManager.shared.hideOverlay { ok, err in
                ok ? result("success") : result(FlutterError(
                    code: err?.code ?? "ERR",
                    message: err?.message, details: nil))
            }
        case "getOverlayState":
            result(OverlayWindowManager.shared.isOverlayVisible)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    override func applicationDidEnterBackground(_ application: UIApplication) {
        super.applicationDidEnterBackground(application)
        OverlayWindowManager.shared.savePositionIfNeeded()
    }

    override func applicationWillEnterForeground(_ application: UIApplication) {
        super.applicationWillEnterForeground(application)
        OverlayWindowManager.shared.syncOverlayState()
    }
}
