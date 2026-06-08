import Foundation
import Darwin

class MemoryReader {
    static let shared = MemoryReader()
    
    private var taskPort: mach_port_t = 0
    private var gamePid: pid_t = 0
    private(set) var unityBaseAddress: UInt64 = 0
    
    var isAttached: Bool {
        return taskPort != 0
    }
    
    private init() {}
    
    /// Tìm PID của game Free Fire (Hỗ trợ cả bản thường và bản Max)
    func findGameProcess() -> pid_t? {
        let targets = ["freefire", "freefiremax"]
        
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0]
        var size = 0
        guard sysctl(&mib, 4, nil, &size, nil, 0) == 0 else { return nil }
        
        let count = size / MemoryLayout<kinfo_proc>.size
        var procs = [kinfo_proc](repeating: kinfo_proc(), count: count)
        guard sysctl(&mib, 4, &procs, &size, nil, 0) == 0 else { return nil }
        
        for proc in procs {
            var comm = proc.kp_proc.p_comm
            let procName = withUnsafePointer(to: &comm) { ptr in
                ptr.withMemoryRebound(to: CChar.self, capacity: 16) { cStr in
                    String(cString: cStr)
                }
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
            print("[MemoryReader] Lỗi task_for_pid: \(kr)")
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
            vm_deallocate(mach_task_self_, vm_address_t(vmData), vm_size_t(bytesRead))
            return data
        }
        return nil
    }
    
    /// Đọc một giá trị kiểu Generic (Int, Float, UInt64...)
    func read<T>(address: UInt64, type: T.Type) -> T? {
        guard let data = readBytes(address: address, size: MemoryLayout<T>.size),
              data.count >= MemoryLayout<T>.size else { return nil }
        let pointer = UnsafeMutablePointer<T>.allocate(capacity: 1)
        defer { pointer.deallocate() }
        let buffer = UnsafeMutableBufferPointer(start: pointer, count: 1)
        _ = data.copyBytes(to: buffer)
        return pointer.pointee
    }
    
    /// Đọc chuỗi ký tự UTF-8 (Tên người chơi...)
    func readString(address: UInt64, maxLength: Int = 32) -> String? {
        guard let data = readBytes(address: address, size: maxLength), !data.isEmpty else { return nil }
        if let nullIndex = data.firstIndex(of: 0) {
            return String(decoding: data.subdata(in: 0..<nullIndex), as: UTF8.self)
        }
        return String(decoding: data, as: UTF8.self)
    }
    
    /// Lấy địa chỉ Base của game (Mach-O Header)
    private func getBaseAddress(pid: pid_t) -> UInt64 {
        let TASK_DYLD_INFO_FLAVOR: task_flavor_t = 17
        struct MyTaskDyldInfo {
            var all_image_info_addr: mach_vm_address_t
            var all_image_info_size: mach_vm_size_t
            var all_image_info_format: integer_t
        }
        
        var dyldInfo = MyTaskDyldInfo(all_image_info_addr: 0, all_image_info_size: 0, all_image_info_format: 0)
        var count = mach_msg_type_number_t(MemoryLayout<MyTaskDyldInfo>.size / MemoryLayout<natural_t>.size)
        
        let kr = withUnsafeMutablePointer(to: &dyldInfo) { (infoPtr) -> kern_return_t in
            let intPtr = UnsafeMutableRawPointer(infoPtr).assumingMemoryBound(to: integer_t.self)
            return task_info(taskPort, TASK_DYLD_INFO_FLAVOR, intPtr, &count)
        }
        
        guard kr == KERN_SUCCESS else {
            return 0x100000000
        }
        
        let allImageInfoAddr = dyldInfo.all_image_info_addr
        guard allImageInfoAddr != 0 else { return 0x100000000 }
        
        guard let infoCount = read(address: allImageInfoAddr + 4, type: UInt32.self),
              let infoArray = read(address: allImageInfoAddr + 8, type: UInt64.self) else {
            return 0x100000000
        }
        
        var exeLoadAddr: UInt64 = 0
        
        for i in 0..<min(infoCount, 500) {
            let infoAddr = infoArray + UInt64(i * 24)
            guard let loadAddr = read(address: infoAddr, type: UInt64.self),
                  let filePathPtr = read(address: infoAddr + 8, type: UInt64.self) else {
                continue
            }
            
            if let path = readString(address: filePathPtr, maxLength: 256) {
                let lowerPath = path.lowercased()
                if lowerPath.contains("unityframework") {
                    return loadAddr
                }
                if lowerPath.contains("freefire") && exeLoadAddr == 0 {
                    exeLoadAddr = loadAddr
                }
            }
        }
        
        return exeLoadAddr != 0 ? exeLoadAddr : 0x100000000
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
    
    /// Trình mô phỏng / Phân tích lệnh ARM64 để tự động phân giải các hàm static getter (ADRP + ADD/LDR)
    func traceStaticGetter(at address: UInt64) -> UInt64 {
        guard isAttached, let data = readBytes(address: address, size: 48), data.count >= 48 else { return 0 }
        
        var registers = Array(repeating: UInt64(0), count: 32)
        
        for i in 0..<12 {
            let ins = data.withUnsafeBytes { $0.load(fromByteOffset: i * 4, as: UInt32.self) }
            let pc = address + UInt64(i * 4)
            
            // ADRP
            if (ins & 0x9F000000) == 0x90000000 {
                let rd = Int(ins & 0x1F)
                let immlo = UInt64((ins >> 29) & 0x3)
                let immhi = UInt64((ins >> 5) & 0x7FFFF)
                var imm = (immhi << 2) | immlo
                if (imm & 0x100000) != 0 {
                    imm |= 0xFFFFFFFFFFE00000
                }
                registers[rd] = (pc & ~0xFFF) &+ (imm << 12)
            }
            // ADD (immediate)
            else if (ins & 0xFFC00000) == 0x91000000 {
                let rd = Int(ins & 0x1F)
                let rn = Int((ins >> 5) & 0x1F)
                let offset = UInt64((ins >> 10) & 0xFFF)
                registers[rd] = registers[rn] &+ offset
            }
            // LDR (immediate, unsigned offset 64-bit)
            else if (ins & 0xFFC00000) == 0xF9400000 {
                let rt = Int(ins & 0x1F)
                let rn = Int((ins >> 5) & 0x1F)
                let offset = UInt64((ins >> 10) & 0xFFF) * 8
                let addr = registers[rn] &+ offset
                if let val = read(address: addr, type: UInt64.self) {
                    registers[rt] = val
                } else {
                    registers[rt] = 0
                }
            }
            // RET
            else if ins == 0xD65F03C0 {
                return registers[0]
            }
        }
        
        return registers[0]
    }
}

