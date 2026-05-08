import Foundation
import ObjectiveC

let frameworkPath = "/System/Library/PrivateFrameworks/CoreBrightness.framework/CoreBrightness"
guard dlopen(frameworkPath, RTLD_NOW) != nil else { exit(1) }

guard let cbClass = NSClassFromString("CBBlueLightClient") as? NSObject.Type else { exit(1) }
let client = cbClass.init()
let clientClass: AnyClass = type(of: client)

typealias SetModeFn = @convention(c) (AnyObject, Selector, Int32) -> Bool
typealias SetEnabledFn = @convention(c) (AnyObject, Selector, Bool) -> Bool
typealias SetStrengthFn = @convention(c) (AnyObject, Selector, Float, Bool) -> Bool
typealias GetStrengthFn = @convention(c) (AnyObject, Selector, UnsafeMutablePointer<Float>) -> Bool
typealias GetStatusFn = @convention(c) (AnyObject, Selector, UnsafeMutableRawPointer) -> Bool
typealias SetScheduleFn = @convention(c) (AnyObject, Selector, UnsafeRawPointer) -> Bool

struct Time: Equatable {
    var hour: Int32 = 0
    var minute: Int32 = 0
}

struct Schedule: Equatable {
    var fromTime = Time()
    var toTime = Time()
}

struct Status {
    var active: Int8 = 0
    var enabled: Int8 = 0
    var sunSchedulePermitted: Int8 = 0
    var mode: Int32 = 0
    var schedule = Schedule()
    var disableFlags: UInt64 = 0
    var available: Int8 = 0
}

func getMethod(_ name: String) -> IMP {
    return method_getImplementation(class_getInstanceMethod(clientClass, Selector((name)))!)
}

let applyMode = unsafeBitCast(getMethod("setMode:"), to: SetModeFn.self)
let applyEnabled = unsafeBitCast(getMethod("setEnabled:"), to: SetEnabledFn.self)
let applyStrength = unsafeBitCast(getMethod("setStrength:commit:"), to: SetStrengthFn.self)
let fetchStrengthFn = unsafeBitCast(getMethod("getStrength:"), to: GetStrengthFn.self)
let fetchStatusFn = unsafeBitCast(getMethod("getBlueLightStatus:"), to: GetStatusFn.self)
let applyScheduleFn = unsafeBitCast(getMethod("setSchedule:"), to: SetScheduleFn.self)

func fetchStatus() -> Status {
    var status = Status()
    _ = withUnsafeMutablePointer(to: &status) {
        fetchStatusFn(client, Selector(("getBlueLightStatus:")), UnsafeMutableRawPointer($0))
    }
    return status
}

func fetchStrength() -> Float {
    var value: Float = 0
    _ = withUnsafeMutablePointer(to: &value) {
        fetchStrengthFn(client, Selector(("getStrength:")), $0)
    }
    return value
}

enum Period { case am, pm }

func makeTime(hour: Int32, minute: Int32, period: Period) -> Time {
    var h = hour
    if period == .am && h == 12 { h = 0 }
    if period == .pm && h < 12 { h += 12 }
    return Time(hour: h, minute: minute)
}

func formatTimeAMPM(_ t: Time) -> String {
    let period = t.hour >= 12 ? "PM" : "AM"
    var h = t.hour % 12
    if h == 0 { h = 12 }
    return String(format: "%d:%02d %@", h, t.minute, period)
}

let currentStatus = fetchStatus()
let currentStrength = fetchStrength()

// ====== CONFIGURATION ======
// ===========================
let desiredStrength: Float = 1.0  // 0.0 (less warm) to 1.0 (most warm)
let desiredMode: Int32 = 1  // 0: Off, 1: Sunset to Sunrise, 2: Custom Schedule
let desiredEnabled: Int8 = 0  // 0: "Turn on until sunrise" OFF, 1: "Turn on until sunrise" ON

// Only applicable if desiredMode == 2
let customScheduleFrom = makeTime(hour: 10, minute: 0, period: .pm)
let customScheduleTo = makeTime(hour: 7, minute: 0, period: .am)
// ===========================
// ===========================

var changed = false

if currentStatus.mode != desiredMode {
    _ = applyMode(client, Selector(("setMode:")), desiredMode)
    changed = true
}

if currentStatus.enabled != desiredEnabled {
    _ = applyEnabled(client, Selector(("setEnabled:")), desiredEnabled == 1)
    changed = true
}

if abs(currentStrength - desiredStrength) > 0.01 {
    _ = applyStrength(client, Selector(("setStrength:commit:")), desiredStrength, true)
    changed = true
}

if desiredMode == 2 {
    var desiredSchedule = Schedule(fromTime: customScheduleFrom, toTime: customScheduleTo)
    if currentStatus.schedule != desiredSchedule {
        _ = withUnsafePointer(to: &desiredSchedule) {
            applyScheduleFn(client, Selector(("setSchedule:")), UnsafeRawPointer($0))
        }
        changed = true
    }
}

let modeDesc: String
switch desiredMode {
case 1: modeDesc = "Sunset to Sunrise"
case 2:
    let fromStr = formatTimeAMPM(customScheduleFrom)
    let toStr = formatTimeAMPM(customScheduleTo)
    modeDesc = "Custom Schedule (\(fromStr) to \(toStr))"
default: modeDesc = "Off"
}
let strengthDesc = "\(Int(desiredStrength * 100))% warmth"
let enabledDesc = desiredEnabled == 1 ? ", Manual Override ON" : ""
let desc = "\(modeDesc), \(strengthDesc)\(enabledDesc)"

if changed {
    print("CONFIGURED|\(desc)")
} else {
    print("ALREADY_CONFIGURED|\(desc)")
}
