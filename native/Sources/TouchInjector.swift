import Foundation
import UIKit
import CoreFoundation

// MARK: - TouchInjector
// Dùng dlopen/dlsym để gọi IOHIDEvent private API tại runtime.
// Không cần link IOKit tĩnh — tránh lỗi biên dịch trên iOS SDK.
// Yêu cầu entitlement: com.apple.private.hid.client.event-dispatch

class TouchInjector {
    static let shared = TouchInjector()

    var logs: [String] = []

    func log(_ msg: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        let timeStr = formatter.string(from: Date())
        let line = "[\(timeStr)] \(msg)"
        logs.append(line)
        if logs.count > 15 {
            logs.removeFirst()
        }
        print(line)
    }

    // MARK: - Function pointer types
    typealias CreateClientFn    = @convention(c) (CFAllocator?) -> CFTypeRef?
    typealias CreateClientWithTypeFn = @convention(c) (CFAllocator?, UInt32, CFDictionary?) -> CFTypeRef?
    typealias ScheduleClientFn  = @convention(c) (CFTypeRef, CFRunLoop, CFString) -> Void
    typealias DispatchEventFn   = @convention(c) (CFTypeRef, CFTypeRef) -> Void
    typealias AppendEventFn     = @convention(c) (CFTypeRef, CFTypeRef) -> Void
    typealias SetSenderFn       = @convention(c) (CFTypeRef, UInt64) -> Void

    typealias CreateDigitizerFn = @convention(c) (
        CFAllocator?, UInt64,
        UInt32, UInt32, UInt32, UInt32, UInt32,
        Double, Double, Double, Double, Double,
        Bool, Bool, UInt32
    ) -> CFTypeRef?

    typealias CreateFingerFn = @convention(c) (
        CFAllocator?, UInt64,
        UInt32, UInt32, UInt32,
        Double, Double, Double, Double, Double,
        Bool, Bool, UInt32
    ) -> CFTypeRef?

    typealias SetDigitizerInfoFn = @convention(c) (
        CFTypeRef, UInt32, UInt8, UInt8, CFString?, Double, Float
    ) -> Void

    // MARK: - Loaded functions
    private var fnCreateClient:    CreateClientFn?
    private var fnCreateClientWithType: CreateClientWithTypeFn?
    private var fnSchedule:        ScheduleClientFn?
    private var fnDispatch:        DispatchEventFn?
    private var fnAppend:          AppendEventFn?
    private var fnSetSender:       SetSenderFn?
    private var fnCreateDigitizer: CreateDigitizerFn?
    private var fnCreateFinger:    CreateFingerFn?
    private var fnSetDigitizerInfo: SetDigitizerInfoFn?

    private var hidClient: CFTypeRef?

    private init() {
        log("Khởi tạo TouchInjector...")
        loadSymbols()
        setupClient()
    }

    // MARK: - Dynamic loading
    private func loadSymbols() {
        let paths = [
            "/System/Library/Frameworks/IOKit.framework/IOKit",
            "/System/Library/PrivateFrameworks/IOKit.framework/IOKit",
            "/usr/lib/libIOKit.dylib"
        ]
        
        var handle: UnsafeMutableRawPointer? = nil
        for path in paths {
            handle = dlopen(path, RTLD_LAZY)
            if handle != nil {
                log("Đã load IOKit từ: \(path)")
                break
            }
        }
        
        if handle == nil {
            handle = dlopen(nil, RTLD_LAZY)
            log("Fallback load nil handle")
        }

        func sym<T>(_ name: String) -> T? {
            guard let ptr = dlsym(handle, name) else {
                log("❌ Không tìm thấy symbol: \(name)")
                return nil
            }
            return unsafeBitCast(ptr, to: T.self)
        }

        fnCreateClient          = sym("IOHIDEventSystemClientCreate")
        fnCreateClientWithType  = sym("IOHIDEventSystemClientCreateWithType")
        fnSchedule              = sym("IOHIDEventSystemClientScheduleWithRunLoop")
        fnDispatch              = sym("IOHIDEventSystemClientDispatchEvent")
        fnAppend                = sym("IOHIDEventAppendEvent")
        fnSetSender             = sym("IOHIDEventSetSenderID")
        fnCreateDigitizer       = sym("IOHIDEventCreateDigitizerEvent")
        fnCreateFinger          = sym("IOHIDEventCreateDigitizerFingerEvent")

        // Load BKSHIDEventSetDigitizerInfo from BackBoardServices
        let bksHandle = dlopen("/System/Library/PrivateFrameworks/BackBoardServices.framework/BackBoardServices", RTLD_LAZY)
        if bksHandle != nil {
            if let ptr = dlsym(bksHandle, "BKSHIDEventSetDigitizerInfo") {
                fnSetDigitizerInfo = unsafeBitCast(ptr, to: SetDigitizerInfoFn.self)
                log("Đã load BKSHIDEventSetDigitizerInfo")
            } else {
                log("❌ Không tìm thấy BKSHIDEventSetDigitizerInfo")
            }
        } else {
            log("❌ Không load được BackBoardServices framework")
        }

        let loaded = fnCreateClient != nil || fnCreateClientWithType != nil
        log("Khởi tạo symbols xong. Loaded client function: \(loaded)")
    }

    private func setupClient() {
        if let createWithTypeFn = fnCreateClientWithType {
            // kIOHIDEventSystemClientTypeSystem = 1
            hidClient = createWithTypeFn(kCFAllocatorDefault, 1, nil)
            log("Tạo client loại 1 (System): \(hidClient != nil)")
        }
        
        if hidClient == nil, let createFn = fnCreateClient {
            hidClient = createFn(kCFAllocatorDefault)
            log("Tạo client fallback: \(hidClient != nil)")
        }
        
        if let client = hidClient, let scheduleFn = fnSchedule {
            scheduleFn(client, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue as CFString)
            log("Đã schedule client lên runloop")
        } else {
            log("❌ Không setup được client")
        }
    }

    // MARK: - Public API

    func sendTap(at point: CGPoint) {
        let rx = Double(point.x)
        let ry = Double(point.y)
        log("Tap tại: (\(rx), \(ry))")
        touchDown(x: rx, y: ry)
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.08) {
            self.touchUp(x: rx, y: ry)
        }
    }

    // MARK: - Private helpers

    private func touchDown(x: Double, y: Double) {
        guard let client = hidClient else {
            log("❌ client nil")
            return
        }
        guard let createFinger = fnCreateFinger else {
            log("❌ createFinger nil")
            return
        }
        guard let createHand = fnCreateDigitizer else {
            log("❌ createHand nil")
            return
        }
        guard let appendFn = fnAppend else {
            log("❌ appendFn nil")
            return
        }
        guard let setSenderFn = fnSetSender else {
            log("❌ setSenderFn nil")
            return
        }
        guard let dispatchFn = fnDispatch else {
            log("❌ dispatchFn nil")
            return
        }

        let ts  = mach_absolute_time()
        let mask: UInt32 = 0x00000004 | 0x00000001 // touch + range

        guard let finger = createFinger(
            kCFAllocatorDefault, ts,
            1, 1, mask,
            x, y, 0.0, 1.0, 0.0,
            true, true, 0
        ) else {
            log("❌ Lỗi tạo finger event")
            return
        }

        guard let hand = createHand(
            kCFAllocatorDefault, ts,
            2, 0xFFFF0001, 1, mask, 0,
            x, y, 0.0, 1.0, 0.0,
            true, true, 0
        ) else {
            log("❌ Lỗi tạo hand event")
            return
        }

        setSenderFn(hand, 0x0000000100000001)
        
        if let setDigitizerInfoFn = fnSetDigitizerInfo {
            setDigitizerInfoFn(hand, 0, 0, 0, nil, 0.0, 0.0)
        }
        
        appendFn(hand, finger)
        dispatchFn(client, hand)
        log("Đã gửi TouchDown")
    }

    private func touchUp(x: Double, y: Double) {
        guard let client = hidClient,
              let createFinger = fnCreateFinger,
              let createHand   = fnCreateDigitizer,
              let appendFn     = fnAppend,
              let setSenderFn  = fnSetSender,
              let dispatchFn   = fnDispatch else { return }

        let ts  = mach_absolute_time()
        let mask: UInt32 = 0x00000004 | 0x00000001

        guard let finger = createFinger(
            kCFAllocatorDefault, ts,
            1, 1, mask,
            x, y, 0.0, 0.0, 0.0,
            false, false, 0
        ) else { return }

        guard let hand = createHand(
            kCFAllocatorDefault, ts,
            2, 0xFFFF0001, 1, mask, 0,
            x, y, 0.0, 0.0, 0.0,
            false, false, 0
        ) else { return }

        setSenderFn(hand, 0x0000000100000001)
        
        if let setDigitizerInfoFn = fnSetDigitizerInfo {
            setDigitizerInfoFn(hand, 0, 0, 0, nil, 0.0, 0.0)
        }
        
        appendFn(hand, finger)
        dispatchFn(client, hand)
        log("Đã gửi TouchUp")
    }
}
