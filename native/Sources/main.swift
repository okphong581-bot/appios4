import Foundation
import UIKit
import Darwin

var globalGetDeviceOrientation: (@convention(c) () -> Int)?

// Khởi tạo BKSHIDServicesGetNonFlatDeviceOrientation để hỗ trợ xác định hướng xoay màn hình chính xác
if let bksHandle = dlopen("/System/Library/PrivateFrameworks/BackBoardServices.framework/BackBoardServices", RTLD_NOW) {
    if let symOrient = dlsym(bksHandle, "BKSHIDServicesGetNonFlatDeviceOrientation") {
        globalGetDeviceOrientation = unsafeBitCast(symOrient, to: (@convention(c) () -> Int).self)
    }
}

UIApplicationMain(CommandLine.argc, CommandLine.unsafeArgv, nil, NSStringFromClass(AppDelegate.self))
