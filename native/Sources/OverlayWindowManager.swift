import Foundation
import UIKit

struct OverlayError {
    let code: String
    let message: String
}

class OverlayWindowManager {
    static let shared = OverlayWindowManager()
    
    // Đường dẫn PID file
    private let pidPath = "/var/mobile/Library/Caches/ch.xxtou.hudapp.pid"
    
    var isOverlayVisible: Bool {
        if let pidString = try? String(contentsOfFile: pidPath, encoding: .utf8),
           let pid = Int32(pidString) {
            let killed = kill(pid, 0)
            return killed == 0
        }
        return false
    }

    private init() {
    }

    // Khởi chạy tiến trình Daemon (-hud)
    func showOverlay(completion: @escaping (Bool, OverlayError?) -> Void) {
        if isOverlayVisible {
            completion(true, nil)
            return
        }
        
        // Cấp quyền persona để chạy daemon cấp hệ thống
        var attr = posix_spawnattr_t(nil)
        posix_spawnattr_init(&attr)
        posix_spawnattr_set_persona_np(&attr, 99, POSIX_SPAWN_PERSONA_FLAGS_OVERRIDE)
        posix_spawnattr_set_persona_uid_np(&attr, 0)
        posix_spawnattr_set_persona_gid_np(&attr, 0)
        
        // Lấy đường dẫn file thực thi hiện tại
        var executablePath = [CChar](repeating: 0, count: 1024)
        var executablePathSize: UInt32 = 1024
        _NSGetExecutablePath(&executablePath, &executablePathSize)
        
        let args = [String(cString: executablePath), "-hud"]
        var cArgs = args.map { strdup($0) }
        cArgs.append(nil)
        
        // Cần truyền environment variables
        var envs = [UnsafeMutablePointer<CChar>?]()
        let envDict = ProcessInfo.processInfo.environment
        for (key, value) in envDict {
            envs.append(strdup("\(key)=\(value)"))
        }
        envs.append(nil)
        
        var task_pid: pid_t = 0
        let rc = posix_spawn(&task_pid, executablePath, nil, &attr, &cArgs, &envs)
        
        posix_spawnattr_destroy(&attr)
        
        for arg in cArgs { free(arg) }
        for env in envs { free(env) }
        
        if rc == 0 {
            print("[HUDManager] Đã khởi chạy daemon thành công, PID: \(task_pid)")
            completion(true, nil)
        } else {
            print("[HUDManager] Lỗi khởi chạy daemon: \(rc)")
            completion(false, OverlayError(code: "\(rc)", message: "posix_spawn error"))
        }
    }

    // Tắt tiến trình Daemon (-exit)
    func hideOverlay(completion: @escaping (Bool, OverlayError?) -> Void) {
        if !isOverlayVisible {
            completion(true, nil)
            return
        }
        
        var attr = posix_spawnattr_t(nil)
        posix_spawnattr_init(&attr)
        posix_spawnattr_set_persona_np(&attr, 99, POSIX_SPAWN_PERSONA_FLAGS_OVERRIDE)
        posix_spawnattr_set_persona_uid_np(&attr, 0)
        posix_spawnattr_set_persona_gid_np(&attr, 0)
        
        var executablePath = [CChar](repeating: 0, count: 1024)
        var executablePathSize: UInt32 = 1024
        _NSGetExecutablePath(&executablePath, &executablePathSize)
        
        let args = [String(cString: executablePath), "-exit"]
        var cArgs = args.map { strdup($0) }
        cArgs.append(nil)
        
        // Environment variables
        var envs = [UnsafeMutablePointer<CChar>?]()
        for (key, value) in ProcessInfo.processInfo.environment {
            envs.append(strdup("\(key)=\(value)"))
        }
        envs.append(nil)
        
        var task_pid: pid_t = 0
        let rc = posix_spawn(&task_pid, executablePath, nil, &attr, &cArgs, &envs)
        
        posix_spawnattr_destroy(&attr)
        for arg in cArgs { free(arg) }
        for env in envs { free(env) }
        
        if rc == 0 {
            // Chờ một chút để lệnh kill thực thi xong
            Thread.sleep(forTimeInterval: 0.1)
            completion(true, nil)
        } else {
            completion(false, OverlayError(code: "\(rc)", message: "posix_spawn error"))
        }
    }

    func syncOverlayState() {
        // Không cần làm gì
    }
    
    func savePositionIfNeeded() {
        // Không cần làm gì
    }
}
