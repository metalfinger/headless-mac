// factory-display: keeps one virtual screen alive on a headless Mac.
// The screen exists for as long as this process runs. Stop it with SIGTERM or Ctrl-C.

import AppKit
import CoreGraphics
import Foundation

setvbuf(stdout, nil, _IOLBF, 0)

// Sizes offered, in points. All are 2x (HiDPI) unless --no-hidpi is given.
let sizes: [(Int, Int, String)] = [
    (2560, 1440, "16:9, default"),
    (1920, 1080, "16:9"),
    (1728, 1117, "MacBook Pro 16"),
    (1710, 1107, "MacBook Air 15"),
    (1512, 982, "MacBook Pro 14"),
    (1470, 956, "MacBook Air 13"),
    (1440, 900, "16:10"),
    (1280, 800, "16:10"),
]

var width = 2560
var height = 1440
var hiDPI = true

// The chosen size is kept in ~/.config/factory-display/config.json.
let configURL = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent(".config/factory-display/config.json")

func loadConfig() {
    guard let data = try? Data(contentsOf: configURL),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Int],
          let w = json["width"], let h = json["height"],
          sizes.contains(where: { $0.0 == w && $0.1 == h }) else { return }
    width = w
    height = h
}

func saveConfig() {
    try? FileManager.default.createDirectory(at: configURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    let data = try? JSONSerialization.data(withJSONObject: ["width": width, "height": height], options: [.prettyPrinted])
    try? data?.write(to: configURL)
}
loadConfig()

func usage() -> Never {
    print("usage: factory-display [--width <points>] [--height <points>] [--no-hidpi]")
    print("default: the size saved from the menu, or 2560 x 1440 points at 2x")
    print("sizes: " + sizes.map { "\($0.0)x\($0.1)" }.joined(separator: " "))
    exit(2)
}

var args = Array(CommandLine.arguments.dropFirst())
while !args.isEmpty {
    let arg = args.removeFirst()
    switch arg {
    case "--width", "--height":
        guard let value = args.first.flatMap({ Int($0) }), value >= 640, value <= 2560 else { usage() }
        args.removeFirst()
        if arg == "--width" { width = value } else { height = value }
    case "--no-hidpi":
        hiDPI = false
    default:
        usage()
    }
}

let scale = hiDPI ? 2 : 1

let descriptor = CGVirtualDisplayDescriptor()
descriptor.queue = DispatchQueue.main
descriptor.name = "Factory Display"
guard sizes.contains(where: { $0.0 == width && $0.1 == height }) else { usage() }
descriptor.maxPixelsWide = UInt32(2560 * scale)
descriptor.maxPixelsHigh = UInt32(1440 * scale)
// About 27 inches, so macOS treats it as a normal desktop monitor.
descriptor.sizeInMillimeters = CGSize(width: 597, height: 336)
// Fixed identity: macOS remembers this as the same monitor across restarts.
descriptor.vendorID = 0xFAC7
descriptor.productID = 0x0001
descriptor.serialNum = 0x0001
descriptor.terminationHandler = { _, _ in
    print("macOS removed the virtual display; exiting so launchd starts a new one")
    exit(1)
}

guard let display = CGVirtualDisplay(descriptor: descriptor) else {
    print("error: macOS refused to create the virtual display")
    exit(1)
}

let settings = CGVirtualDisplaySettings()
settings.hiDPI = hiDPI ? 1 : 0
settings.modes = sizes.map { CGVirtualDisplayMode(width: UInt($0.0), height: UInt($0.1), refreshRate: 60) }
guard display.apply(settings) else {
    print("error: macOS refused the display modes")
    exit(1)
}

let displayID = display.displayID

// macOS may start the screen in its 1x mode. Switch to the mode we asked for.
func selectRequestedMode() {
    let options = [kCGDisplayShowDuplicateLowResolutionModes: kCFBooleanTrue] as CFDictionary
    guard let modes = CGDisplayCopyAllDisplayModes(displayID, options) as? [CGDisplayMode] else { return }
    guard let wanted = modes.first(where: {
        $0.width == width && $0.height == height && $0.pixelWidth == width * scale
    }) else {
        print("warning: mode \(width) x \(height) at \(scale)x is not offered; leaving the current mode")
        return
    }
    let result = CGDisplaySetDisplayMode(displayID, wanted, nil)
    if result != .success { print("warning: could not select the mode (error \(result.rawValue))") }
}
selectRequestedMode()

func currentSummary() -> String {
    guard let mode = CGDisplayCopyDisplayMode(displayID) else { return "\(width) x \(height)" }
    return "\(mode.width) x \(mode.height) points, \(mode.pixelWidth) x \(mode.pixelHeight) pixels"
}
print("virtual display \(displayID) is on: \(currentSummary())")

// Menu bar icon: shows that it is running and switches the size.
final class MenuController: NSObject, NSMenuDelegate {
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

    override init() {
        super.init()
        if let image = NSImage(systemSymbolName: "display", accessibilityDescription: "Factory Display") {
            item.button?.image = image
        } else {
            item.button?.title = "FD"
        }
        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        for line in ["Factory Display is on", currentSummary()] {
            let info = NSMenuItem(title: line, action: nil, keyEquivalent: "")
            info.isEnabled = false
            menu.addItem(info)
        }
        menu.addItem(.separator())
        for (index, size) in sizes.enumerated() {
            let entry = NSMenuItem(title: "\(size.0) x \(size.1)  \(size.2)", action: #selector(pick(_:)), keyEquivalent: "")
            entry.target = self
            entry.tag = index
            entry.state = (size.0 == width && size.1 == height) ? .on : .off
            menu.addItem(entry)
        }
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Turn off until next login", action: #selector(NSApplication.terminate(_:)), keyEquivalent: ""))
    }

    @objc func pick(_ sender: NSMenuItem) {
        let size = sizes[sender.tag]
        width = size.0
        height = size.1
        selectRequestedMode()
        saveConfig()
        print("size changed: \(currentSummary())")
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let menuController = MenuController()

// Leave cleanly on SIGTERM (launchd, kill) and SIGINT (Ctrl-C).
var signalSources: [DispatchSourceSignal] = []
for sig in [SIGTERM, SIGINT] {
    signal(sig, SIG_IGN)
    let source = DispatchSource.makeSignalSource(signal: sig, queue: .main)
    source.setEventHandler {
        print("stopping; the virtual display goes away")
        exit(0)
    }
    source.resume()
    signalSources.append(source)
}

withExtendedLifetime(display) { app.run() }
