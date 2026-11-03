// Draws the app icon and writes Resources/AppIcon.icns and docs/icon.png.
// Run from the repository root: swift scripts/make-icon.swift
import AppKit

func color(_ hex: UInt32) -> NSColor {
    NSColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: 1
    )
}

func rounded(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat, _ fill: NSColor) {
    fill.setFill()
    NSBezierPath(roundedRect: NSRect(x: x, y: y, width: w, height: h), xRadius: r, yRadius: r).fill()
}

// Artwork lives on a 200-unit square with y growing downward, placed on Apple's 824/1024 icon grid.
func drawIcon(size: Int) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8,
        samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
        bytesPerRow: 0, bitsPerPixel: 0
    )!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let unit = CGFloat(size) * (824.0 / 1024.0) / 200
    let margin = CGFloat(size) * (100.0 / 1024.0)

    let transform = NSAffineTransform()
    transform.translateX(by: margin, yBy: CGFloat(size) - margin)
    transform.scaleX(by: unit, yBy: -unit)
    transform.concat()

    NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: 200, height: 200), xRadius: 45, yRadius: 45).addClip()
    color(0x0F2F4A).setFill()
    NSRect(x: 0, y: 0, width: 200, height: 200).fill()

    rounded(80, 62, 40, 78, 0, color(0xCFC8B8))
    rounded(60, 42, 80, 24, 12, color(0xF2EDE3))
    rounded(52, 136, 96, 20, 7, color(0xF2EDE3))

    color(0xF28C38).setStroke()
    let upper = NSBezierPath()
    upper.move(to: NSPoint(x: 74, y: 104))
    upper.line(to: NSPoint(x: 126, y: 88))
    let lower = NSBezierPath()
    lower.move(to: NSPoint(x: 74, y: 124))
    lower.line(to: NSPoint(x: 126, y: 108))
    lower.curve(to: NSPoint(x: 205, y: 116), controlPoint1: NSPoint(x: 150, y: 102), controlPoint2: NSPoint(x: 170, y: 122))
    for rope in [upper, lower] {
        rope.lineWidth = 12
        rope.lineCapStyle = .round
        rope.stroke()
    }

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let fm = FileManager.default
let iconset = fm.temporaryDirectory.appendingPathComponent("AppIcon-\(UUID().uuidString).iconset")
try fm.createDirectory(at: iconset, withIntermediateDirectories: true)
for points in [16, 32, 128, 256, 512] {
    try drawIcon(size: points).write(to: iconset.appendingPathComponent("icon_\(points)x\(points).png"))
    try drawIcon(size: points * 2).write(to: iconset.appendingPathComponent("icon_\(points)x\(points)@2x.png"))
}

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", "Resources/AppIcon.icns"]
try iconutil.run()
iconutil.waitUntilExit()
try fm.removeItem(at: iconset)

try fm.createDirectory(atPath: "docs", withIntermediateDirectories: true)
try drawIcon(size: 512).write(to: URL(fileURLWithPath: "docs/icon.png"))
