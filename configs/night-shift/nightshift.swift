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

// Each case represents a complete, self-consistent Night Shift configuration.
// Invalid combinations (e.g. a manual override on top of a sunset schedule)
// are impossible to express — pick one preset and all derived settings follow.
//
//   .sunsetToSunrise    — OS auto-enables at sunset, disables at sunrise (recommended)
//   .customSchedule     — OS auto-enables/disables on a fixed daily time window
//   .manualUntilSunrise — no recurring schedule; manually on until tonight's sunrise
//   .off                — Night Shift disabled entirely
enum NightShiftPreset {
    case sunsetToSunrise(strength: Float)
    case customSchedule(from: Time, to: Time, strength: Float)
    case manualUntilSunrise(strength: Float)
    case off
}

// ====== CONFIGURATION ======
// ===========================
let preset: NightShiftPreset = .sunsetToSunrise(strength: 1.0)
// let preset: NightShiftPreset = .customSchedule(
//     from: makeTime(hour: 10, minute: 0, period: .pm),
//     to:   makeTime(hour: 7,  minute: 0, period: .am),
//     strength: 1.0
// )
// let preset: NightShiftPreset = .manualUntilSunrise(strength: 1.0)
// let preset: NightShiftPreset = .off
// ===========================
// ===========================

let currentStatus = fetchStatus()
let currentStrength = fetchStrength()

var changed = false

// Apply mode
let desiredMode: Int32
switch preset {
case .sunsetToSunrise:      desiredMode = 1
case .customSchedule:       desiredMode = 2
case .manualUntilSunrise:   desiredMode = 0
case .off:                  desiredMode = 0
}

if currentStatus.mode != desiredMode {
    _ = applyMode(client, Selector(("setMode:")), desiredMode)
    changed = true
}

// Apply strength (not applicable for .off — Night Shift is disabled so warmth
// has no visible effect and there is no meaningful value to preserve)
let desiredStrength: Float?
switch preset {
case .sunsetToSunrise(let s):           desiredStrength = s
case .customSchedule(_, _, let s):      desiredStrength = s
case .manualUntilSunrise(let s):        desiredStrength = s
case .off:                              desiredStrength = nil
}

if let strength = desiredStrength, abs(currentStrength - strength) > 0.01 {
    _ = applyStrength(client, Selector(("setStrength:commit:")), strength, true)
    changed = true
}

// Apply custom schedule times (mode 2 only)
if case .customSchedule(let from, let to, _) = preset {
    var desiredSchedule = Schedule(fromTime: from, toTime: to)
    if currentStatus.schedule != desiredSchedule {
        _ = withUnsafePointer(to: &desiredSchedule) {
            applyScheduleFn(client, Selector(("setSchedule:")), UnsafeRawPointer($0))
        }
        changed = true
    }
}

// Apply enabled state.
//
// For scheduled presets (.sunsetToSunrise, .customSchedule), the OS manages
// the enabled state automatically — it sets it ON at sunset/schedule-start and
// OFF at sunrise/schedule-end. The `active` field in Status reflects whether
// the current time falls within the active window (independent of any prior
// override). Re-reading status after the mode is applied ensures we see the
// correct active state even on a first-time run (setMode(1) at night
// immediately activates the schedule).
//
// Deriving the desired enabled value from `active` rather than hardcoding 0
// prevents the script from calling setEnabled(false) while the schedule has
// Night Shift on, which would disable it mid-window and set a persistent
// override flag (BlueLightReductionAlgoOverride) that blocks the schedule from
// re-enabling it until the next sunset/sunrise transition.
let statusForEnabled = (desiredMode == 1 || desiredMode == 2) ? fetchStatus() : currentStatus

let desiredEnabled: Int8
switch preset {
case .sunsetToSunrise, .customSchedule:
    // Follow the OS-computed active window; don't override the schedule state.
    desiredEnabled = statusForEnabled.active
case .manualUntilSunrise:
    desiredEnabled = 1
case .off:
    desiredEnabled = 0
}

if statusForEnabled.enabled != desiredEnabled {
    _ = applyEnabled(client, Selector(("setEnabled:")), desiredEnabled == 1)
    changed = true
}

// Build description
let modeDesc: String
switch preset {
case .sunsetToSunrise:
    modeDesc = "Sunset to Sunrise"
case .customSchedule(let from, let to, _):
    modeDesc = "Custom Schedule (\(formatTimeAMPM(from)) to \(formatTimeAMPM(to)))"
case .manualUntilSunrise:
    modeDesc = "Manual"
case .off:
    modeDesc = "Off"
}

let strengthDesc: String
if let strength = desiredStrength {
    strengthDesc = "\(Int(strength * 100))% warmth"
} else {
    strengthDesc = "warmth unchanged"
}

let enabledDesc: String
switch preset {
case .sunsetToSunrise, .customSchedule:
    enabledDesc = desiredEnabled == 1 ? ", currently active" : ""
case .manualUntilSunrise:
    enabledDesc = ", Manual Override ON"
case .off:
    enabledDesc = ""
}

let desc = "\(modeDesc), \(strengthDesc)\(enabledDesc)"

if changed {
    print("CONFIGURED|\(desc)")
} else {
    print("ALREADY_CONFIGURED|\(desc)")
}
