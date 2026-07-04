#ifndef BridgingHeader_h
#define BridgingHeader_h

#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import <mach/mach_time.h>

// ─── IOHIDEvent Private Types ───────────────────────────────────────────────

typedef CFTypeRef IOHIDEventSystemClientRef;
typedef CFTypeRef IOHIDEventRef;
typedef double    IOHIDFloat;
typedef uint32_t  IOHIDDigitizerTransducerType;
typedef uint32_t  IOHIDDigitizerEventMask;
typedef uint32_t  IOHIDEventOptionBits;
typedef uint32_t  IOHIDEventField;

// ─── IOHIDEventSystem Client ────────────────────────────────────────────────

extern IOHIDEventSystemClientRef IOHIDEventSystemClientCreate(CFAllocatorRef allocator);

extern void IOHIDEventSystemClientScheduleWithRunLoop(
    IOHIDEventSystemClientRef client,
    CFRunLoopRef              runLoop,
    CFStringRef               mode
);

extern void IOHIDEventSystemClientDispatchEvent(
    IOHIDEventSystemClientRef client,
    IOHIDEventRef             event
);

// ─── IOHIDEvent Digitizer ───────────────────────────────────────────────────

extern IOHIDEventRef IOHIDEventCreateDigitizerEvent(
    CFAllocatorRef              allocator,
    uint64_t                    timeStamp,
    IOHIDDigitizerTransducerType transducerType,
    uint32_t                    index,
    uint32_t                    identity,
    IOHIDDigitizerEventMask     eventMask,
    uint32_t                    buttonMask,
    IOHIDFloat                  x,
    IOHIDFloat                  y,
    IOHIDFloat                  z,
    IOHIDFloat                  tipPressure,
    IOHIDFloat                  twist,
    Boolean                     range,
    Boolean                     touch,
    IOHIDEventOptionBits        options
);

extern IOHIDEventRef IOHIDEventCreateDigitizerFingerEvent(
    CFAllocatorRef          allocator,
    uint64_t                timeStamp,
    uint32_t                index,
    uint32_t                identity,
    IOHIDDigitizerEventMask eventMask,
    IOHIDFloat              x,
    IOHIDFloat              y,
    IOHIDFloat              z,
    IOHIDFloat              tipPressure,
    IOHIDFloat              twist,
    Boolean                 range,
    Boolean                 touch,
    IOHIDEventOptionBits    options
);

extern void IOHIDEventAppendEvent(IOHIDEventRef  parent, IOHIDEventRef child);
extern void IOHIDEventSetIntegerValue(IOHIDEventRef event, IOHIDEventField field, int value);
extern void IOHIDEventSetSenderID(IOHIDEventRef event, uint64_t senderID);

#endif /* BridgingHeader_h */
