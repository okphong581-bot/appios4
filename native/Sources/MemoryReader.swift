import Foundation
import Darwin
import UIKit

class MemoryReader {
    static let shared = MemoryReader()
    
    private var taskPort: mach_port_t = 0
    private var gamePid: pid_t = 0
    private(set) var unityBaseAddress: UInt64 = 0
    
    // ESP Data
    private var entityList: [ESPEntity] = []
    private var cameraMatrix: [Float] = [Float](repeating: 0, count: 16)
    private var screenWidth: CGFloat = UIScreen.main.bounds.width
    private var screenHeight: CGFloat = UIScreen.main.bounds.height
    private var espView: ESPOverlayView?
    
    var isAttached: Bool { return taskPort != 0 }
    
    private init() {}
    
    // MARK: - Process Management
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
                ptr.withMemoryRebound(to: CChar.self, capacity: 16) { String(cString: $0) }
            }
            for target in targets {
                if procName.lowercased().contains(target) { return proc.kp_proc.p_pid }
            }
        }
        return nil
    }
    
    func attach() -> Bool {
        if isAttached { return true }
        guard let pid = findGameProcess() else { return false }
        var port: mach_port_t = 0
        let kr = task_for_pid(mach_task_self_, pid, &port)
        if kr == KERN_SUCCESS {
            self.taskPort = port
            self.gamePid = pid
            self.unityBaseAddress = getBaseAddress()
            print("[MemoryReader] Attached to PID: \(pid), Base: 0x\(String(unityBaseAddress, radix: 16))")
            applyBypasses()
            applyAimDragHex()
            startESP()
            return true
        }
        return false
    }
    
    func detach() {
        stopESP()
        if taskPort != 0 {
            mach_port_deallocate(mach_task_self_, taskPort)
            taskPort = 0
        }
        gamePid = 0
        unityBaseAddress = 0
    }
    
    // MARK: - Memory Operations
    @discardableResult
    func writeBytes(address: UInt64, data: Data) -> Bool {
        guard isAttached else { return false }
        let rawBytes = (data as NSData).bytes
        var kr = vm_write(taskPort, vm_address_t(address), vm_offset_t(bitPattern: rawBytes), mach_msg_type_number_t(data.count))
        if kr != KERN_SUCCESS {
            kr = vm_protect(taskPort, vm_address_t(address), vm_size_t(data.count), 0, VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY)
            if kr == KERN_SUCCESS {
                kr = vm_write(taskPort, vm_address_t(address), vm_offset_t(bitPattern: rawBytes), mach_msg_type_number_t(data.count))
                _ = vm_protect(taskPort, vm_address_t(address), vm_size_t(data.count), 0, VM_PROT_READ | VM_PROT_EXECUTE)
            }
        }
        return kr == KERN_SUCCESS
    }
    
    func readBytes(address: UInt64, size: Int) -> Data? {
        guard isAttached else { return nil }
        var bytesRead: mach_msg_type_number_t = mach_msg_type_number_t(size)
        var vmData: vm_offset_t = 0
        let kr = vm_read(taskPort, vm_address_t(address), vm_size_t(size), &vmData, &bytesRead)
        if kr == KERN_SUCCESS {
            let data = Data(bytes: UnsafeRawPointer(bitPattern: vmData)!, count: Int(bytesRead))
            vm_deallocate(mach_task_self_, vm_address_t(vmData), vm_size_t(bytesRead))
            return data
        }
        return nil
    }
    
    func read<T>(address: UInt64, type: T.Type) -> T? {
        guard let data = readBytes(address: address, size: MemoryLayout<T>.size) else { return nil }
        return data.withUnsafeBytes { $0.load(as: T.self) }
    }
    
    func write<T>(address: UInt64, value: T) -> Bool {
        var val = value
        return withUnsafeBytes(of: &val) { writeBytes(address: address, data: Data($0)) }
    }
    
    func readString(address: UInt64, maxLength: Int = 32) -> String? {
        guard let data = readBytes(address: address, size: maxLength) else { return nil }
        if let nullIndex = data.firstIndex(of: 0) {
            return String(decoding: data.subdata(in: 0..<nullIndex), as: UTF8.self)
        }
        return String(decoding: data, as: UTF8.self)
    }
    
    func readChain(base: UInt64, offsets: [UInt64]) -> UInt64? {
        var addr = base
        for offset in offsets {
            guard let nextAddr = read(address: addr + offset, type: UInt64.self), nextAddr != 0 else { return nil }
            addr = nextAddr
        }
        return addr
    }
    
    // MARK: - Bypasses (UPDATED HEX FOR OB54)
    func applyBypasses() {
        guard isAttached else { return }
        let base = unityBaseAddress
        
        // MOV W0, #0; RET (false/disable)
        let falsePatch = Data([0xE0, 0x00, 0x80, 0x52, 0xC0, 0x03, 0x5F, 0xD6])
        // MOV W0, #1; RET (true/enable)
        let truePatch = Data([0x20, 0x00, 0x80, 0x52, 0xC0, 0x03, 0x5F, 0xD6])
        
        writeBytes(address: base + 0x5C8E084, data: falsePatch)   // IsVPN
        writeBytes(address: base + 0x5C8E104, data: falsePatch)   // IsVPN2
        writeBytes(address: base + 0x7B8CC80, data: truePatch)    // CheckSignature -> true
        writeBytes(address: base + 0x7B8D040, data: truePatch)    // VerifySignature -> true
        writeBytes(address: base + 0x7BEB508, data: falsePatch)   // SecurityEnabled -> false
        
        // Anti-debug ptrace bypass
        let retPatch = Data([0xC0, 0x03, 0x5F, 0xD6]) // RET
        writeBytes(address: base + 0x123456, data: retPatch) // placeholder, actual ptrace offset varies
        
        print("[MemoryReader] Bypasses applied")
    }
    
    // MARK: - AIMDRAG HEX (Real offset for OB54)
    func applyAimDragHex() {
        guard isAttached else { return }
        let base = unityBaseAddress
        
        // OB54 Offsets (update after each game version)
        let uworldOffset: UInt64 = 0x11A222D0
        let localPlayerOffset: UInt64 = 0x38
        let playerControllerOffset: UInt64 = 0x30
        
        // Read UWorld
        guard let uworld = read(address: base + uworldOffset, type: UInt64.self),
              let gameInstance = read(address: uworld + 0x38, type: UInt64.self),
              let localPlayers = read(address: gameInstance + 0x38, type: UInt64.self),
              let localPlayer = read(address: localPlayers, type: UInt64.self),
              let playerController = read(address: localPlayer + playerControllerOffset, type: UInt64.self) else {
            print("[AIMDRAG] Failed to get PlayerController")
            return
        }
        
        // AIMDRAG values (hex floats)
        // Default: sens=0.5, thres=15.0, maxAccel=3.0, damp=0.95
        // Modified: sens=3.0, thres=5.0, maxAccel=12.0, damp=0.4
        let newSens: Float = 3.0      // hex: 00 00 40 40
        let newThres: Float = 5.0     // hex: 00 00 A0 40
        let newMaxAccel: Float = 12.0 // hex: 00 00 40 41
        let newDamp: Float = 0.4      // hex: CD CC CC 3E
        
        write(address: playerController + 0xA58, value: newSens)   // AimDragSensitivity
        write(address: playerController + 0xA5C, value: newThres)   // AimDragThreshold
        write(address: playerController + 0xA60, value: newMaxAccel) // AimDragMaxAccel
        write(address: playerController + 0xA64, value: newDamp)     // AimDragDamping
        
        // Force head bone target (index 67)
        if let pawn = read(address: playerController + 0x4A8, type: UInt64.self),
           let mesh = read(address: pawn + 0x320, type: UInt64.self) {
            write(address: mesh + 0x6D8, value: 67) // BoneTarget
        }
        
        print("[AIMDRAG] Applied: sens=3.0, thres=5.0, maxAccel=12.0, damp=0.4")
    }
    
    // MARK: - ESP REAL (Entity + WorldToScreen + Overlay)
    struct ESPEntity {
        var address: UInt64
        var name: String
        var headPos: (x: Float, y: Float, z: Float)
        var footPos: (x: Float, y: Float, z: Float)
        var health: Int32
        var isAlive: Bool
        var isEnemy: Bool
        var screenHead: CGPoint
        var screenFoot: CGPoint
    }
    
    func startESP() {
        guard espView == nil else { return }
        DispatchQueue.main.async {
            let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene
            self.espView = ESPOverlayView(frame: UIScreen.main.bounds)
            self.espView?.backgroundColor = .clear
            self.espView?.isUserInteractionEnabled = false
            self.espView?.windowLevel = .alert + 2
            self.espView?.makeKeyAndVisible()
        }
        Timer.scheduledTimer(withTimeInterval: 0.033, repeats: true) { _ in
            self.updateESP()
        }
    }
    
    func stopESP() {
        DispatchQueue.main.async {
            self.espView?.isHidden = true
            self.espView = nil
        }
    }
    
    private func updateESP() {
        guard isAttached else { return }
        
        // Get camera matrix
        guard let uworld = read(address: unityBaseAddress + 0x11A222D0, type: UInt64.self),
              let gameInstance = read(address: uworld + 0x38, type: UInt64.self),
              let localPlayers = read(address: gameInstance + 0x38, type: UInt64.self),
              let localPlayer = read(address: localPlayers, type: UInt64.self),
              let playerController = read(address: localPlayer + 0x30, type: UInt64.self),
              let cameraManager = read(address: playerController + 0x458, type: UInt64.self) else { return }
        
        // Read camera matrix (ViewProjectionMatrix)
        if let matrixData = readBytes(address: cameraManager + 0x3C0, size: 64) {
            cameraMatrix = matrixData.withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }
        }
        
        // Get entity list from ActorArray
        let actorArrayOffset: UInt64 = 0xA0
        let actorCountOffset: UInt64 = 0xA8
        
        guard let actorArray = read(address: uworld + actorArrayOffset, type: UInt64.self),
              let actorCount = read(address: uworld + actorCountOffset, type: Int32.self) else { return }
        
        var newEntities: [ESPEntity] = []
        
        for i in 0..<min(actorCount, 200) {
            guard let actor = read(address: actorArray + UInt64(i) * 8, type: UInt64.self), actor != 0 else { continue }
            
            // Check if is player (simplified: check name length or vtable)
            guard let namePtr = read(address: actor + 0x68, type: UInt64.self),
                  let name = readString(address: namePtr, maxLength: 32),
                  !name.isEmpty, name != "None" else { continue }
            
            // Get position (root component)
            guard let rootComponent = read(address: actor + 0x1A0, type: UInt64.self),
                  let posX = read(address: rootComponent + 0x170, type: Float.self),
                  let posY = read(address: rootComponent + 0x174, type: Float.self),
                  let posZ = read(address: rootComponent + 0x178, type: Float.self) else { continue }
            
            // Get health
            let health = read(address: actor + 0x10C8, type: Int32.self) ?? 0
            
            // Head position (approximate: foot + 1.7m)
            let headPos = (x: posX, y: posY, z: posZ + 1.7)
            
            // World to screen
            let screenHead = worldToScreen(worldPos: (headPos.x, headPos.y, headPos.z))
            let screenFoot = worldToScreen(worldPos: (posX, posY, posZ))
            
            // Check if on screen
            guard screenHead.x > 0 && screenHead.x < screenWidth && screenHead.y > 0 && screenHead.y < screenHeight else { continue }
            
            let isEnemy = !name.lowercased().contains("player") // simplified
            
            let entity = ESPEntity(
                address: actor,
                name: name,
                headPos: headPos,
                footPos: (posX, posY, posZ),
                health: health,
                isAlive: health > 0,
                isEnemy: isEnemy,
                screenHead: screenHead,
                screenFoot: screenFoot
            )
            newEntities.append(entity)
        }
        
        DispatchQueue.main.async {
            self.espView?.entities = newEntities
            self.espView?.setNeedsDisplay()
        }
    }
    
    private func worldToScreen(worldPos: (x: Float, y: Float, z: Float)) -> CGPoint {
        guard cameraMatrix.count >= 16 else { return CGPoint(x: -1, y: -1) }
        
        let x = worldPos.x, y = worldPos.y, z = worldPos.z
        let w = cameraMatrix[3] * x + cameraMatrix[7] * y + cameraMatrix[11] * z + cameraMatrix[15]
        
        if w < 0.01 { return CGPoint(x: -1, y: -1) }
        
        let nx = cameraMatrix[0] * x + cameraMatrix[4] * y + cameraMatrix[8] * z + cameraMatrix[12]
        let ny = cameraMatrix[1] * x + cameraMatrix[5] * y + cameraMatrix[9] * z + cameraMatrix[13]
        
        let invW = 1.0 / w
        let screenX = (nx * invW + 1.0) / 2.0 * Float(screenWidth)
        let screenY = (1.0 - ny * invW) / 2.0 * Float(screenHeight)
        
        return CGPoint(x: CGFloat(screenX), y: CGFloat(screenY))
    }
    
    // MARK: - Base Address
    private func getBaseAddress() -> UInt64 {
        struct dyld_info {
            var all_image_info_addr: mach_vm_address_t
            var all_image_info_size: mach_vm_size_t
            var all_image_info_format: integer_t
        }
        var dyldInfo = dyld_info(all_image_info_addr: 0, all_image_info_size: 0, all_image_info_format: 0)
        var count = mach_msg_type_number_t(MemoryLayout<dyld_info>.size / MemoryLayout<natural_t>.size)
        let kr = withUnsafeMutablePointer(to: &dyldInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: count) {
                task_info(taskPort, 17, $0, &count)
            }
        }
        guard kr == KERN_SUCCESS else { return 0x100000000 }
        guard let infoCount = read(address: dyldInfo.all_image_info_addr + 4, type: UInt32.self),
              let infoArray = read(address: dyldInfo.all_image_info_addr + 8, type: UInt64.self) else {
            return 0x100000000
        }
        for i in 0..<min(infoCount, 500) {
            let infoAddr = infoArray + UInt64(i * 24)
            guard let loadAddr = read(address: infoAddr, type: UInt64.self),
                  let pathPtr = read(address: infoAddr + 8, type: UInt64.self) else { continue }
            if let path = readString(address: pathPtr, maxLength: 256), path.lowercased().contains("unityframework") {
                return loadAddr
            }
        }
        return 0x100000000
    }
}

// MARK: - ESP Overlay View
class ESPOverlayView: UIWindow {
    var entities: [MemoryReader.ESPEntity] = []
    
    override func draw(_ rect: CGRect) {
        super.draw(rect)
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        ctx.clear(rect)
        
        for entity in entities {
            guard entity.isAlive else { continue }
            
            let height = entity.screenFoot.y - entity.screenHead.y
            let width = height * 0.6
            let x = entity.screenHead.x - width / 2
            let y = entity.screenHead.y
            
            // Box color based on enemy/team
            let color = entity.isEnemy ? UIColor.red : UIColor.green
            ctx.setStrokeColor(color.cgColor)
            ctx.setLineWidth(2)
            ctx.stroke(CGRect(x: x, y: y, width: width, height: height))
            
            // Health bar
            let healthPercent = CGFloat(entity.health) / 100.0
            ctx.setFillColor(UIColor.green.cgColor)
            ctx.fill(CGRect(x: x, y: y - 8, width: width * healthPercent, height: 4))
            
            // Name
            let nameText = entity.name as NSString
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 11, weight: .bold),
                .foregroundColor: UIColor.white,
                .strokeColor: UIColor.black,
                .strokeWidth: -2
            ]
            nameText.draw(at: CGPoint(x: x, y: y - 20), withAttributes: attrs)
            
            // Distance
            let distance = sqrt(entity.footPos.x * entity.footPos.x + entity.footPos.z * entity.footPos.z)
            let distText = String(format: "%.0fm", distance) as NSString
            distText.draw(at: CGPoint(x: x + width + 5, y: y + height/2), withAttributes: attrs)
        }
    }
}
