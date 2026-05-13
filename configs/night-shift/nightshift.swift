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

// Returns true if it is currently daylight (Night Shift should be OFF),
// false if it is nighttime (Night Shift should be ON), or nil if the OS
// cannot determine the answer (e.g. location services are disabled).
//
// isDaylight is read from corebrightnessdiag — the same OS-computed value
// the Night Shift daemon uses internally for its own sunset/sunrise schedule.
// It is the only reliable signal for "are we in the nighttime window right now."
//
// status.active (AutoBlueReductionEnabled in CoreBrightness) is NOT a
// time-of-day indicator — it is 1 whenever an automatic schedule mode is
// configured (mode 1 or 2), day or night alike, and must not be used here.
func getDaylightStatus() -> Bool? {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/libexec/corebrightnessdiag")
    process.arguments = ["nightshift-internal"]
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = Pipe()
    do {
        try process.run()
        process.waitUntilExit()
        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        // "(null)" appears when location services are disabled and the OS has
        // no sunrise/sunset data — treat this as indeterminate, not as daytime.
        if output.contains("isDaylight = (null)") { return nil }
        if output.contains("isDaylight = 1;")     { return true  }
        if output.contains("isDaylight = 0;")     { return false }
        return nil
    } catch {
        return nil
    }
}

// Returns true if the current local time falls within a custom schedule window.
// Handles overnight windows correctly (e.g. 10:00 PM to 7:00 AM, where
// fromMinutes > toMinutes spans midnight).
func isInCustomWindow(from: Time, to: Time) -> Bool {
    let now = Calendar.current.dateComponents([.hour, .minute], from: Date())
    let currentMinutes = (now.hour ?? 0) * 60 + (now.minute ?? 0)
    let fromMinutes    = Int(from.hour) * 60 + Int(from.minute)
    let toMinutes      = Int(to.hour)   * 60 + Int(to.minute)
    if fromMinutes > toMinutes {
        // Overnight: active from fromMinutes until midnight, and again from midnight until toMinutes
        return currentMinutes >= fromMinutes || currentMinutes < toMinutes
    }
    return currentMinutes >= fromMinutes && currentMinutes < toMinutes
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
var daylightWarning = false

// Derive the desired mode
let desiredMode: Int32
switch preset {
case .sunsetToSunrise:      desiredMode = 1
case .customSchedule:       desiredMode = 2
case .manualUntilSunrise:   desiredMode = 0
case .off:                  desiredMode = 0
}

// Derive the desired enabled state from the current time.
// For scheduled presets this is time-aware; for explicit presets it is constant.
let desiredEnabled: Int8
switch preset {
case .sunsetToSunrise:
    switch getDaylightStatus() {
    case .some(true):   desiredEnabled = 0                  // daytime  — keep off
    case .some(false):  desiredEnabled = 1                  // nighttime — keep on
    case .none:
        desiredEnabled = currentStatus.enabled              // unknown   — leave unchanged
        daylightWarning = true
    }
case .customSchedule(let from, let to, _):
    desiredEnabled = isInCustomWindow(from: from, to: to) ? 1 : 0
case .manualUntilSunrise:
    desiredEnabled = 1
case .off:
    desiredEnabled = 0
}

// Apply mode and enabled state.
//
// For scheduled presets (.sunsetToSunrise, .customSchedule), setEnabled is
// never called. Any call to setEnabled writes a persistent
// BlueLightReductionAlgoOverride into the CoreBrightness daemon that blocks
// the OS schedule from self-correcting at the next natural sunset/sunrise event.
//
// Instead, when the enabled state is wrong (a stuck override from a prior bad
// call), we repair it by toggling through mode=0 before reasserting the desired
// mode. This resets AlgoOverride to 0, returning full OS control of the schedule.
// Empirically verified: setMode(0) → setMode(n) always produces AlgoOverride=0.
//
// For explicit presets (.manualUntilSunrise, .off), setEnabled is appropriate
// because these modes intentionally set a persistent state by design.
switch preset {
case .sunsetToSunrise, .customSchedule:
    let modeWrong    = currentStatus.mode != desiredMode
    let enabledWrong = !daylightWarning && currentStatus.enabled != desiredEnabled
    if modeWrong || enabledWrong {
        if !modeWrong {
            // Mode is already correct but a stuck override is forcing the wrong
            // enabled state — toggle through 0 to reset AlgoOverride.
            _ = applyMode(client, Selector(("setMode:")), 0)
        }
        _ = applyMode(client, Selector(("setMode:")), desiredMode)
        changed = true
    }

case .manualUntilSunrise:
    if currentStatus.mode != desiredMode {
        _ = applyMode(client, Selector(("setMode:")), desiredMode)
        changed = true
    }
    if currentStatus.enabled != desiredEnabled {
        _ = applyEnabled(client, Selector(("setEnabled:")), true)
        changed = true
    }

case .off:
    if currentStatus.mode != desiredMode {
        _ = applyMode(client, Selector(("setMode:")), desiredMode)
        changed = true
    }
    if currentStatus.enabled != desiredEnabled {
        _ = applyEnabled(client, Selector(("setEnabled:")), false)
        changed = true
    }
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

if daylightWarning {
    let action = changed ? "partially configured" : "no changes needed, but"
    print("WARNING|\(desc) — \(action): cannot determine daylight status (location services may be disabled); Night Shift enabled state left unchanged")
} else if changed {
    print("CONFIGURED|\(desc)")
} else {
    print("ALREADY_CONFIGURED|\(desc)")
}
