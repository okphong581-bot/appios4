import Foundation
import UIKit

// MARK: - TouchInjector
// Sử dụng IOHIDEvent private API để tiêm sự kiện chạm hệ thống.
// Yêu cầu entitlement: com.apple.private.hid.client.event-dispatch
class TouchInjector {
    static let shared = TouchInjector()

    private var hidClient: IOHIDEventSystemClientRef?

    private init() {
        setupClient()
    }

    private func setupClient() {
        guard let client = IOHIDEventSystemClientCreate(kCFAllocatorDefault) else {
            print("[TouchInjector] ❌ Không tạo được IOHIDEventSystemClient")
            return
        }
        IOHIDEventSystemClientScheduleWithRunLoop(client, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue as CFString)
        hidClient = client
        print("[TouchInjector] ✅ Sẵn sàng")
    }

    /// Gửi tap tại điểm `point` (tọa độ UIKit points)
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
        guard let client = hidClient else { return }
        let ts = mach_absolute_time()

        // eventMask: touch(0x4) | range(0x1)
        let mask: IOHIDDigitizerEventMask = 0x00000004 | 0x00000001

        guard let finger = IOHIDEventCreateDigitizerFingerEvent(
            kCFAllocatorDefault, ts,
            1, 1, mask,
            x, y, 0.0, 1.0, 0.0,
            true, true, 0
        ) else { return }

        // transducerType: kIOHIDDigitizerTransducerTypeHand = 2
        guard let hand = IOHIDEventCreateDigitizerEvent(
            kCFAllocatorDefault, ts,
            2, 0xFFFF0001, 1, mask, 0,
            x, y, 0.0, 0.0, 0.0,
            true, true, 0
        ) else { return }

        IOHIDEventSetSenderID(hand, 0)
        IOHIDEventAppendEvent(hand, finger)
        IOHIDEventSystemClientDispatchEvent(client, hand)
    }

    private func touchUp(x: Double, y: Double) {
        guard let client = hidClient else { return }
        let ts = mach_absolute_time()
        let mask: IOHIDDigitizerEventMask = 0x00000004 | 0x00000001

        guard let finger = IOHIDEventCreateDigitizerFingerEvent(
            kCFAllocatorDefault, ts,
            1, 1, mask,
            x, y, 0.0, 0.0, 0.0,
            false, false, 0
        ) else { return }

        guard let hand = IOHIDEventCreateDigitizerEvent(
            kCFAllocatorDefault, ts,
            2, 0xFFFF0001, 1, mask, 0,
            x, y, 0.0, 0.0, 0.0,
            false, false, 0
        ) else { return }

        IOHIDEventSetSenderID(hand, 0)
        IOHIDEventAppendEvent(hand, finger)
        IOHIDEventSystemClientDispatchEvent(client, hand)
    }
}
