import Foundation
import UIKit

// MARK: - TouchInjector
// Dùng dlopen/dlsym để gọi IOHIDEvent private API tại runtime.
// Không cần link IOKit tĩnh — tránh lỗi biên dịch trên iOS SDK.
// Yêu cầu entitlement: com.apple.private.hid.client.event-dispatch

class TouchInjector {
    static let shared = TouchInjector()

    // MARK: - Function pointer types
    typealias CreateClientFn    = @convention(c) (CFAllocator?) -> CFTypeRef?
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

    // MARK: - Loaded functions
    private var fnCreateClient:    CreateClientFn?
    private var fnSchedule:        ScheduleClientFn?
    private var fnDispatch:        DispatchEventFn?
    private var fnAppend:          AppendEventFn?
    private var fnSetSender:       SetSenderFn?
    private var fnCreateDigitizer: CreateDigitizerFn?
    private var fnCreateFinger:    CreateFingerFn?

    private var hidClient: CFTypeRef?

    private init() {
        loadSymbols()
        setupClient()
    }

    // MARK: - Dynamic loading
    private func loadSymbols() {
        // Tải private framework
        let handle = dlopen("/System/Library/PrivateFrameworks/IOKit.framework/IOKit", RTLD_LAZY)
            ?? dlopen("/usr/lib/libIOKit.dylib", RTLD_LAZY)
            ?? dlopen(nil, RTLD_LAZY)  // fallback: tìm trong process hiện tại

        func sym<T>(_ name: String) -> T? {
            guard let ptr = dlsym(handle, name) else { return nil }
            return unsafeBitCast(ptr, to: T.self)
        }

        fnCreateClient    = sym("IOHIDEventSystemClientCreate")
        fnSchedule        = sym("IOHIDEventSystemClientScheduleWithRunLoop")
        fnDispatch        = sym("IOHIDEventSystemClientDispatchEvent")
        fnAppend          = sym("IOHIDEventAppendEvent")
        fnSetSender       = sym("IOHIDEventSetSenderID")
        fnCreateDigitizer = sym("IOHIDEventCreateDigitizerEvent")
        fnCreateFinger    = sym("IOHIDEventCreateDigitizerFingerEvent")

        let loaded = fnCreateClient != nil
        print("[TouchInjector] Symbols loaded: \(loaded)")
    }

    private func setupClient() {
        guard let createFn = fnCreateClient,
              let scheduleFn = fnSchedule else {
            print("[TouchInjector] ❌ Không load được symbol")
            return
        }
        guard let client = createFn(kCFAllocatorDefault) else {
            print("[TouchInjector] ❌ Không tạo được client")
            return
        }
        scheduleFn(client, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue as CFString)
        hidClient = client
        print("[TouchInjector] ✅ Client ready")
    }

    // MARK: - Public API

    func sendTap(at point: CGPoint) {
        let screen = UIScreen.main.bounds
        let nx = Double(point.x / screen.width)
        let ny = Double(point.y / screen.height)
        touchDown(x: nx, y: ny)
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.06) {
            self.touchUp(x: nx, y: ny)
        }
    }

    // MARK: - Private helpers

    private func touchDown(x: Double, y: Double) {
        guard let client = hidClient,
              let createFinger = fnCreateFinger,
              let createHand   = fnCreateDigitizer,
              let appendFn     = fnAppend,
              let setSenderFn  = fnSetSender,
              let dispatchFn   = fnDispatch else { return }

        let ts  = mach_absolute_time()
        let mask: UInt32 = 0x00000004 | 0x00000001 // touch + range

        guard let finger = createFinger(
            kCFAllocatorDefault, ts,
            1, 1, mask,
            x, y, 0.0, 1.0, 0.0,
            true, true, 0
        ) else { return }

        guard let hand = createHand(
            kCFAllocatorDefault, ts,
            2, 0xFFFF0001, 1, mask, 0,
            x, y, 0.0, 0.0, 0.0,
            true, true, 0
        ) else { return }

        setSenderFn(hand, 0)
        appendFn(hand, finger)
        dispatchFn(client, hand)
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

        setSenderFn(hand, 0)
        appendFn(hand, finger)
        dispatchFn(client, hand)
    }
}
