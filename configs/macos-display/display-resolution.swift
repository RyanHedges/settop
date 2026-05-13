import CoreGraphics
import Foundation

// ====== CONFIGURATION ======
// Change this single line to switch the built-in display resolution preset.
// Only the built-in display is affected; external monitors are never touched.
//
//   .moreSpace    — highest logical resolution; most screen real estate, smallest text
//                   Matches "More Space" in System Settings > Displays
//   .recommended  — renders at the native panel resolution with no scaling; the system
//                   default on a fresh install. Matches "Default (Recommended)".
//   .largerText   — lowest logical resolution; largest text, least real estate
//                   Matches "Larger Text" in System Settings > Displays
let target: DisplayResolutionPreset = .moreSpace
// let target: DisplayResolutionPreset = .recommended
// let target: DisplayResolutionPreset = .largerText
// ===========================

enum DisplayResolutionPreset: String {
    case moreSpace
    case recommended
    case largerText
}

// --- Helpers ---

// Discovery / selection info goes to stderr so stdout stays a clean STATE|DESC
// line for setup.sh to parse. The user still sees the log as the script runs.
func info(_ s: String) {
    FileHandle.standardError.write(Data("\(s)\n".utf8))
}

func fail(_ s: String) -> Never {
    print("ERROR|\(s)")
    exit(1)
}

// Bridge the CFArray returned by CGDisplayCopyAllDisplayModes into a Swift array.
// CGDisplayMode is a CoreFoundation opaque type; Unmanaged is required because
// it does not bridge through `as?` in a Swift script context.
func loadModes(_ display: CGDirectDisplayID, options: CFDictionary?) -> [CGDisplayMode] {
    guard let raw = CGDisplayCopyAllDisplayModes(display, options) else { return [] }
    return (0..<CFArrayGetCount(raw)).compactMap { i in
        guard let ptr = CFArrayGetValueAtIndex(raw, i) else { return nil }
        return Unmanaged<CGDisplayMode>.fromOpaque(ptr).takeUnretainedValue()
    }
}

func formatHz(_ rate: Double) -> String {
    return rate > 0 ? "\(Int(rate.rounded()))Hz" : "?Hz"
}

// --- Find the built-in display ---
// External monitors are excluded by design: "More Space" is a Retina concept
// tied to the built-in panel, and an external monitor's highest HiDPI mode may
// be its native 1:1 pixel mode — not a sensible default to force on every run.
var displayCount: UInt32 = 0
CGGetOnlineDisplayList(0, nil, &displayCount)
var displayIDs = [CGDirectDisplayID](repeating: 0, count: Int(displayCount))
CGGetOnlineDisplayList(displayCount, &displayIDs, &displayCount)

guard let builtIn = displayIDs.first(where: { CGDisplayIsBuiltin($0) != 0 }) else {
    fail("No built-in display found")
}

// --- Determine the native panel resolution and aspect ratio ---
// Without kCGDisplayShowDuplicateLowResolutionModes, CGDisplayCopyAllDisplayModes
// returns only the non-scaled (1:1) modes — pixelWidth == width for every one.
// The mode with the greatest pixel area is the panel's physical resolution.
// Multiple modes share the same pixelWidth at different aspect ratios (e.g. a
// 16" MBP reports both 3456×2160 (16:10) and 3456×2234 (native 1.547:1));
// picking by area selects the native-aspect mode unambiguously.
let nativeModes = loadModes(builtIn, options: nil)
guard
    let nativeMode = nativeModes.max(by: {
        ($0.pixelWidth * $0.pixelHeight) < ($1.pixelWidth * $1.pixelHeight)
    })
else {
    fail("Could not determine native panel resolution")
}
let nativePixelWidth = nativeMode.pixelWidth
let nativePixelHeight = nativeMode.pixelHeight
let nativeRatio = Double(nativePixelWidth) / Double(nativePixelHeight)

info(
    "Native panel: \(nativePixelWidth)x\(nativePixelHeight) (ratio \(String(format: "%.3f", nativeRatio)))"
)

// --- Enumerate HiDPI modes matching the native aspect ratio ---
// kCGDisplayShowDuplicateLowResolutionModes adds the HiDPI (Retina-scaled)
// modes. HiDPI ⇔ pixelWidth > width (framebuffer wider than logical width).
//
// Why filter by native aspect ratio: CoreGraphics also reports 16:10
// letterboxed legacy modes that System Settings hides. Filtering to modes
// whose logical (width/height) matches the panel's native ratio leaves
// exactly the positions Apple shows on the Displays slider — 5 on every
// M-series MacBook tested (14", 16"), and the same approach works on any
// future Mac since the ratio is read from the panel itself, not hardcoded.
let aspectTolerance = 0.01
let allModes = loadModes(
    builtIn, options: [kCGDisplayShowDuplicateLowResolutionModes: true] as CFDictionary)
let hiDPIMatchingRatio = allModes.filter {
    $0.pixelWidth > $0.width && $0.isUsableForDesktopGUI()
        && abs((Double($0.width) / Double($0.height)) - nativeRatio) < aspectTolerance
}

guard !hiDPIMatchingRatio.isEmpty else {
    fail("No HiDPI modes match native aspect ratio (\(String(format: "%.3f", nativeRatio)))")
}

// --- Collapse refresh-rate duplicates, keeping the highest Hz per resolution ---
// Each logical resolution appears once per supported refresh rate. Keep the
// highest-Hz variant so ProMotion (120Hz) is preserved on M-series MBPs.
let grouped = Dictionary(grouping: hiDPIMatchingRatio, by: { "\($0.width)x\($0.height)" })
let positions = grouped.values.compactMap { group in
    group.max(by: { $0.refreshRate < $1.refreshRate })
}.sorted {
    $0.width != $1.width ? $0.width < $1.width : $0.height < $1.height
}

// --- Report discovery ---
info(
    "Found \(positions.count) slider position\(positions.count == 1 ? "" : "s") at native aspect ratio:"
)
for (idx, m) in positions.enumerated() {
    var markers: [String] = []
    if idx == 0 { markers.append("Larger Text") }
    if m.pixelWidth == nativePixelWidth { markers.append("Default (Recommended)") }
    if idx == positions.count - 1 { markers.append("More Space") }
    let suffix = markers.isEmpty ? "" : "  ← \(markers.joined(separator: " / "))"
    info("  \(m.width)x\(m.height) @ \(formatHz(m.refreshRate))\(suffix)")
}

// --- Select the target mode ---
let targetMode: CGDisplayMode?
switch target {
case .moreSpace:
    // Highest (width, height) in the slider = most screen real estate.
    targetMode = positions.last

case .largerText:
    // Lowest (width, height) in the slider = largest text.
    targetMode = positions.first

case .recommended:
    // "Default (Recommended)" renders at the panel's native pixel count: the
    // HiDPI framebuffer (2× the logical width) equals the physical panel
    // width exactly, so no scaling occurs at the display engine.
    // Fallback: the middle slider position if no exact pixelWidth match
    // (defensive — shouldn't happen on any tested Mac).
    targetMode =
        positions.first(where: { $0.pixelWidth == nativePixelWidth })
        ?? positions[positions.count / 2]
}

guard let mode = targetMode else {
    fail("No mode found for preset .\(target.rawValue)")
}

info(
    "Selected: \(mode.width)x\(mode.height) @ \(formatHz(mode.refreshRate)) (preset: .\(target.rawValue))"
)

// --- Idempotency check ---
// Compare logical (width × height); refresh rate is intentionally ignored so
// re-runs don't reapply just because the mode object differs.
if let current = CGDisplayCopyDisplayMode(builtIn),
    current.width == mode.width && current.height == mode.height
{
    print("ALREADY_CONFIGURED|\(mode.width)x\(mode.height)")
    exit(0)
}

// --- Apply the new display mode ---
// CGCompleteDisplayConfiguration(.permanently) survives reboots, matching
// what System Settings writes when you move the Displays slider.
var config: CGDisplayConfigRef?
CGBeginDisplayConfiguration(&config)
CGConfigureDisplayWithDisplayMode(config, builtIn, mode, nil)
let result = CGCompleteDisplayConfiguration(config, .permanently)

if result == .success {
    print("CONFIGURED|\(mode.width)x\(mode.height)")
} else {
    fail("CGCompleteDisplayConfiguration failed with code \(result.rawValue)")
}
