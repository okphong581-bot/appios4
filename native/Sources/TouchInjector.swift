import Foundation
import UIKit
import CoreFoundation

// MARK: - IOHIDEvent Private API Declarations

typealias IOHIDEventSystemClientRef = OpaquePointer
typealias IOHIDEventRef = OpaquePointer

@_silgen_name("IOHIDEventSystemClientCreate")
func IOHIDEventSystemClientCreate(_ allocator: CFAllocator?) -> IOHIDEventSystemClientRef?

@_silgen_name("IOHIDEventSystemClientScheduleWithRunLoop")
func IOHIDEventSystemClientScheduleWithRunLoop(_ client: IOHIDEventSystemClientRef, _ runLoop: CFRunLoop, _ mode: CFString)

@_silgen_name("IOHIDEventSystemClientDispatchEvent")
func IOHIDEventSystemClientDispatchEvent(_ client: IOHIDEventSystemClientRef, _ event: IOHIDEventRef)

@_silgen_name("IOHIDEventCreateDigitizerEvent")
func IOHIDEventCreateDigitizerEvent(
    _ allocator: CFAllocator?,
    _ timeStamp: UInt64,
    _ transducerType: UInt32,
    _ index: UInt32,
    _ identity: UInt32,
    _ eventMask: UInt32,
    _ buttonMask: UInt32,
    _ x: Double,
    _ y: Double,
    _ z: Double,
    _ tipPressure: Double,
    _ twist: Double,
    _ range: Bool,
    _ touch: Bool,
    _ options: UInt32
) -> IOHIDEventRef?

@_silgen_name("IOHIDEventCreateDigitizerFingerEvent")
func IOHIDEventCreateDigitizerFingerEvent(
    _ allocator: CFAllocator?,
    _ timeStamp: UInt64,
    _ index: UInt32,
    _ identity: UInt32,
    _ eventMask: UInt32,
    _ x: Double,
    _ y: Double,
    _ z: Double,
    _ tipPressure: Double,
    _ twist: Double,
    _ range: Bool,
    _ touch: Bool,
    _ options: UInt32
) -> IOHIDEventRef?

@_silgen_name("IOHIDEventAppendEvent")
func IOHIDEventAppendEvent(_ parent: IOHIDEventRef, _ child: IOHIDEventRef)

@_silgen_name("IOHIDEventSetIntegerValue")
func IOHIDEventSetIntegerValue(_ event: IOHIDEventRef, _ field: Int32, _ value: Int32)

@_silgen_name("IOHIDEventSetSenderID")
func IOHIDEventSetSenderID(_ event: IOHIDEventRef, _ senderID: UInt64)

// MARK: - TouchInjector

class TouchInjector {
    static let shared = TouchInjector()

    private var hidClient: IOHIDEventSystemClientRef?

    private init() {
        setupClient()
    }

    private func setupClient() {
        guard let client = IOHIDEventSystemClientCreate(kCFAllocatorDefault) else {
            print("[TouchInjector] ❌ Không thể tạo IOHIDEventSystemClient")
            return
        }
        IOHIDEventSystemClientScheduleWithRunLoop(client, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        hidClient = client
        print("[TouchInjector] ✅ IOHIDEventSystemClient đã khởi tạo")
    }

    /// Gửi sự kiện chạm đơn tại tọa độ x, y (tính theo điểm màn hình, 0.0 - 1.0 normalized)
    func sendTap(at point: CGPoint) {
        let screen = UIScreen.main.bounds
        let normX = Double(point.x / screen.width)
        let normY = Double(point.y / screen.height)

        sendTouchDown(x: normX, y: normY)
        // Giữ 50ms rồi nhả
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.05) {
            self.sendTouchUp(x: normX, y: normY)
        }
    }

    private func currentMachTime() -> UInt64 {
        return mach_absolute_time()
    }

    private func sendTouchDown(x: Double, y: Double) {
        guard let client = hidClient else { return }

        let ts = currentMachTime()

        // kIOHIDDigitizerTransducerTypeHand = 2
        // kIOHIDDigitizerEventTouch = 0x00000004
        // kIOHIDDigitizerEventRange = 0x00000001
        // kIOHIDDigitizerEventIdentity = 0x00000002
        let touchEventMask: UInt32 = 0x00000004 | 0x00000001 // touch + range
        let handEventMask: UInt32 = 0x00000004 | 0x00000001

        guard let fingerEvent = IOHIDEventCreateDigitizerFingerEvent(
            kCFAllocatorDefault,
            ts,
            1,           // index (finger index)
            1,           // identity
            touchEventMask,
            x, y, 0.0,   // x, y, z
            1.0,         // tipPressure
            0.0,         // twist
            true,        // range
            true,        // touch
            0            // options
        ) else { return }

        guard let handEvent = IOHIDEventCreateDigitizerEvent(
            kCFAllocatorDefault,
            ts,
            2,           // transducerType: kIOHIDDigitizerTransducerTypeHand
            0xFFFF0001,  // index
            1,           // identity
            handEventMask,
            0,           // buttonMask
            x, y, 0.0,
            0.0,
            0.0,
            true,        // range
            true,        // touch
            0            // options
        ) else { return }

        // Sender ID để giả lập BackBoardServices
        IOHIDEventSetSenderID(handEvent, 0x0)
        IOHIDEventAppendEvent(handEvent, fingerEvent)
        IOHIDEventSystemClientDispatchEvent(client, handEvent)
    }

    private func sendTouchUp(x: Double, y: Double) {
        guard let client = hidClient else { return }

        let ts = currentMachTime()
        let liftEventMask: UInt32 = 0x00000004 | 0x00000001

        guard let fingerEvent = IOHIDEventCreateDigitizerFingerEvent(
            kCFAllocatorDefault,
            ts,
            1,
            1,
            liftEventMask,
            x, y, 0.0,
            0.0,         // tipPressure = 0 (lifted)
            0.0,
            false,       // range = false (lifted)
            false,       // touch = false
            0
        ) else { return }

        guard let handEvent = IOHIDEventCreateDigitizerEvent(
            kCFAllocatorDefault,
            ts,
            2,
            0xFFFF0001,
            1,
            liftEventMask,
            0,
            x, y, 0.0,
            0.0, 0.0,
            false,
            false,
            0
        ) else { return }

        IOHIDEventSetSenderID(handEvent, 0x0)
        IOHIDEventAppendEvent(handEvent, fingerEvent)
        IOHIDEventSystemClientDispatchEvent(client, handEvent)
    }
}
