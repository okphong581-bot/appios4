import Foundation
import Darwin

class MemoryReader {
    static let shared = MemoryReader()
    
    private var taskPort: mach_port_t = 0
    private var gamePid: pid_t = 0
    private var unityBaseAddress: UInt64 = 0
    
    var isAttached: Bool {
        return taskPort != 0
    }
    
    private init() {}
    
    /// Tìm PID của game Free Fire (Hỗ trợ cả bản thường và bản Max)
    func findGameProcess() -> pid_t? {
        let targets = ["freefire", "freefiremax"]
        
        var mib = [CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0]
        var size = 0
        guard sysctl(&mib, 4, nil, &size, nil, 0) == 0 else { return nil }
        
        let count = size / MemoryLayout<kinfo_proc>.size
        var procs = [kinfo_proc](repeating: kinfo_proc(), count: count)
        guard sysctl(&mib, 4, &procs, &size, nil, 0) == 0 else { return nil }
        
        for proc in procs {
            let procName = withUnsafeBytes(of: proc.kp_proc.p_comm) { (rawBuffer) -> String in
                guard let baseAddress = rawBuffer.baseAddress else { return "" }
                let ptr = baseAddress.assumingMemoryBound(to: CChar.self)
                return String(cString: ptr)
            }
            
            for target in targets {
                if procName.lowercased().contains(target) {
                    return proc.kp_proc.p_pid
                }
            }
        }
        return nil
    }
    
    /// Kết nối tới tiến trình game qua task_for_pid
    func attach() -> Bool {
        if isAttached { return true }
        
        guard let pid = findGameProcess() else {
            print("[MemoryReader] Không tìm thấy tiến trình Free Fire.")
            return false
        }
        
        var port: mach_port_t = 0
        let kr = task_for_pid(mach_task_self_, pid, &port)
        if kr == KERN_SUCCESS {
            self.taskPort = port
            self.gamePid = pid
            self.unityBaseAddress = getBaseAddress(pid: pid)
            print("[MemoryReader] Đã kết nối thành công tới PID: \(pid), Base Address: 0x\(String(unityBaseAddress, radix: 16))")
            return true
        } else {
            print("[MemoryReader] Lỗi task_for_pid: \(kr). Đảm bảo thiết bị đã jailbreak hoặc cài qua TrollStore có entitlements task-ports.")
            return false
        }
    }
    
    /// Ngắt kết nối
    func detach() {
        if taskPort != 0 {
            mach_port_deallocate(mach_task_self_, taskPort)
            taskPort = 0
            gamePid = 0
            unityBaseAddress = 0
            print("[MemoryReader] Đã ngắt kết nối.")
        }
    }
    
    /// Đọc vùng nhớ thô (Raw Bytes) an toàn
    func readBytes(address: UInt64, size: Int) -> Data? {
        guard isAttached else { return nil }
        
        var data = Data(count: size)
        var bytesRead: mach_msg_type_number_t = mach_msg_type_number_t(size)
        var vmData: vm_offset_t = 0
        
        let kr = vm_read(taskPort, vm_address_t(address), vm_size_t(size), &vmData, &bytesRead)
        if kr == KERN_SUCCESS {
            let ptr = UnsafeRawPointer(bitPattern: vmData)!
            data = Data(bytes: ptr, count: Int(bytesRead))
            vm_deallocate(mach_task_self_, vmData, vm_size_t(bytesRead))
            return data
        }
        return nil
    }
    
    /// Đọc một giá trị kiểu Generic (Int, Float, UInt64...)
    func read<T>(address: UInt64, type: T.Type) -> T? {
        guard let data = readBytes(address: address, size: MemoryLayout<T>.size) else { return nil }
        return data.withUnsafeBytes { $0.load(as: T.self) }
    }
    
    /// Đọc chuỗi ký tự UTF-8 (Tên người chơi...)
    func readString(address: UInt64, maxLength: Int = 32) -> String? {
        guard let data = readBytes(address: address, size: maxLength) else { return nil }
        return data.withUnsafeBytes { (rawBuffer) -> String? in
            guard let baseAddress = rawBuffer.baseAddress else { return nil }
            let ptr = baseAddress.assumingMemoryBound(to: CChar.self)
            return String(cString: ptr)
        }
    }
    
    /// Lấy địa chỉ Base của game (Mach-O Header)
    private func getBaseAddress(pid: pid_t) -> UInt64 {
        // Mặc định địa chỉ nạp tối thiểu của ứng dụng 64-bit trên iOS thường là 0x100000000
        // Trong môi trường TrollStore thoát sandbox, chúng ta có thể trả về giá trị mặc định này
        // hoặc đọc vùng nhớ để định dạng header.
        return 0x100000000
    }
    
    /// Đọc con trỏ lồng nhau (Pointer Chain Offset)
    func readChain(base: UInt64, offsets: [UInt64]) -> UInt64? {
        var addr = base
        for offset in offsets {
            if let nextAddr = read(address: addr + offset, type: UInt64.self) {
                addr = nextAddr
                if addr == 0 { return nil }
            } else {
                return nil
            }
        }
        return addr
    }
}
