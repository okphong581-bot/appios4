import UIKit
import Flutter

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  
  var overlayWindow: UIWindow?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    // Thiết lập cầu nối (MethodChannel) để nhận lệnh từ nút bấm Flutter
    let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
    let hackChannel = FlutterMethodChannel(name: "com.mod.menu/hack", binaryMessenger: controller.binaryMessenger)
    
    hackChannel.setMethodCallHandler({
      (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      if call.method == "showMenu" {
          self.setupFloatingMenu()
          result("Success")
      } else {
          result(FlutterMethodNotImplemented)
      }
    })
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  func setupFloatingMenu() {
      // Chỉ tạo Menu khi có lệnh từ người dùng
      DispatchQueue.main.async {
          if self.overlayWindow != nil { return } // Tránh tạo nhiều lần
          
          let overlay = UIWindow(frame: CGRect(x: 20, y: 150, width: 60, height: 60))
          overlay.windowLevel = UIWindow.Level.statusBar + 1000
          overlay.backgroundColor = .clear
          
          let vc = UIViewController()
          vc.view.backgroundColor = .clear
          overlay.rootViewController = vc
          
          // Nút bấm tròn giả lập
          let btn = UIButton(frame: CGRect(x: 0, y: 0, width: 60, height: 60))
          btn.backgroundColor = .green
          btn.layer.cornerRadius = 30
          btn.layer.borderWidth = 2
          btn.layer.borderColor = UIColor.white.cgColor
          btn.setTitle("", for: .normal)
          btn.setTitleColor(.black, for: .normal)
          btn.titleLabel?.font = UIFont.boldSystemFont(ofSize: 30)
          
          let pan = UIPanGestureRecognizer(target: self, action: #selector(self.panGesture(_:)))
          btn.addGestureRecognizer(pan)
          
          vc.view.addSubview(btn)
          
          // Hiển thị Window đè hệ thống
          overlay.makeKeyAndVisible()
          self.overlayWindow = overlay
      }
  }
  
  @objc func panGesture(_ gesture: UIPanGestureRecognizer) {
      guard let window = self.overlayWindow else { return }
      let translation = gesture.translation(in: nil)
      window.center = CGPoint(x: window.center.x + translation.x, y: window.center.y + translation.y)
      gesture.setTranslation(.zero, in: nil)
  }
}
