import Foundation
import UIKit
import Darwin

let POSIX_SPAWN_PERSONA_FLAGS_OVERRIDE: UInt32 = 1

@_silgen_name("posix_spawnattr_set_persona_np")
func posix_spawnattr_set_persona_np(_ attr: UnsafeMutablePointer<posix_spawnattr_t?>?, _ persona_id: uid_t, _ flags: UInt32) -> Int32

@_silgen_name("posix_spawnattr_set_persona_uid_np")
func posix_spawnattr_set_persona_uid_np(_ attr: UnsafeMutablePointer<posix_spawnattr_t?>?, _ uid: uid_t) -> Int32

@_silgen_name("posix_spawnattr_set_persona_gid_np")
func posix_spawnattr_set_persona_gid_np(_ attr: UnsafeMutablePointer<posix_spawnattr_t?>?, _ gid: uid_t) -> Int32

@_silgen_name("_NSGetExecutablePath")
func _NSGetExecutablePath(_ buf: UnsafeMutablePointer<CChar>?, _ bufsize: UnsafeMutablePointer<UInt32>?) -> Int32

// UIApplication Private APIs
@_silgen_name("UIApplicationInstantiateSingleton")
func UIApplicationInstantiateSingleton(_ appClass: AnyClass)

@_silgen_name("UIApplicationInitialize")
func UIApplicationInitialize()

extension UIApplication {
    func runAsPlugin() {
        let selector = NSSelectorFromString("__completeAndRunAsPlugin")
        if responds(to: selector) {
            perform(selector)
        }
    }
}
