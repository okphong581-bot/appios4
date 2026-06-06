import Foundation
import UIKit
import Darwin

var globalHUDDelegate: HUDAppDelegate?

// Lấy tham số command line
let args = CommandLine.arguments

// Đường dẫn lưu PID của daemon
let pidPath = "/var/mobile/Library/Caches/ch.xxtou.hudapp.pid"

if args.count > 1 && args[1] == "-hud" {
    // ----------------------------------------------------
    // CHẾ ĐỘ DAEMON (OVERLAY TOÀN CỤC)
    // ----------------------------------------------------
    let pid = getpid()
    let pidString = "\(pid)"
    try? pidString.write(toFile: pidPath, atomically: true, encoding: .utf8)
    
    // Khởi tạo các service nền tảng
    // Bắt buộc phải có để backend UI hoạt động
    _ = RunLoop.current
    _ = UIScreen.main
    GSInitialize()
    BKSDisplayServicesStart()
    UIApplicationInitialize()
    
    // Ở iOS hiện đại, để biến app thành plugin daemon:
    UIApplicationInstantiateSingleton(HUDApp.self)
    // Phải giữ strong reference để delegate không bị giải phóng (vì UIApplication.delegate là weak)
    let appDelegate = HUDAppDelegate()
    UIApplication.shared.delegate = appDelegate
    
    // Lưu lại trong biến global để giữ strong reference
    globalHUDDelegate = appDelegate
    
    // Run as plugin
    UIApplication.shared.runAsPlugin()
    
    RunLoop.main.run()
    exit(0)
    
} else if args.count > 1 && args[1] == "-exit" {
    // ----------------------------------------------------
    // CHẾ ĐỘ KILL DAEMON
    // ----------------------------------------------------
    if let pidString = try? String(contentsOfFile: pidPath, encoding: .utf8),
       let pid = Int32(pidString) {
        kill(pid, SIGKILL)
        unlink(pidPath)
    }
    exit(0)
    
} else if args.count > 1 && args[1] == "-check" {
    // ----------------------------------------------------
    // CHẾ ĐỘ CHECK DAEMON
    // ----------------------------------------------------
    if let pidString = try? String(contentsOfFile: pidPath, encoding: .utf8),
       let pid = Int32(pidString) {
        let killed = kill(pid, 0)
        exit(killed == 0 ? 1 : 0)
    }
    exit(0)
    
} else {
    // ----------------------------------------------------
    // CHẾ ĐỘ APP BÌNH THƯỜNG (UI CÓ NÚT START/STOP)
    // ----------------------------------------------------
    UIApplicationMain(CommandLine.argc, CommandLine.unsafeArgv, nil, NSStringFromClass(AppDelegate.self))
}
