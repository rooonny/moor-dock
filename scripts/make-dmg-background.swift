// Draws the disk image window background and writes Resources/dmg-background.tiff.
// Run from the repository root: swift scripts/make-dmg-background.swift
import AppKit

func drawBackground(scale: Int) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: 640 * scale, pixelsHigh: 400 * scale, bitsPerSample: 8,
        samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
        bytesPerRow: 0, bitsPerPixel: 0
    )!
    rep.size = NSSize(width: 640, height: 400)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    NSColor(srgbRed: 0.949, green: 0.929, blue: 0.890, alpha: 1).setFill()
    NSRect(x: 0, y: 0, width: 640, height: 400).fill()

    let orange = NSColor(srgbRed: 0.949, green: 0.549, blue: 0.220, alpha: 1)
    orange.setStroke()
    let arrow = NSBezierPath()
    arrow.move(to: NSPoint(x: 260, y: 210))
    arrow.line(to: NSPoint(x: 380, y: 210))
    arrow.move(to: NSPoint(x: 360, y: 228))
    arrow.line(to: NSPoint(x: 380, y: 210))
    arrow.line(to: NSPoint(x: 360, y: 192))
    arrow.lineWidth = 7
    arrow.lineCapStyle = .round
    arrow.lineJoinStyle = .round
    arrow.stroke()

    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    let title = NSAttributedString(string: "Drag Moor to Applications", attributes: [
        .font: NSFont.systemFont(ofSize: 20, weight: .semibold),
        .foregroundColor: NSColor(srgbRed: 0.059, green: 0.184, blue: 0.290, alpha: 1),
        .paragraphStyle: paragraph,
    ])
    title.draw(in: NSRect(x: 0, y: 325, width: 640, height: 32))

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let fm = FileManager.default
let folder = fm.temporaryDirectory.appendingPathComponent("dmg-background-\(UUID().uuidString)")
try fm.createDirectory(at: folder, withIntermediateDirectories: true)
let normal = folder.appendingPathComponent("background.png")
let retina = folder.appendingPathComponent("background@2x.png")
try drawBackground(scale: 1).write(to: normal)
try drawBackground(scale: 2).write(to: retina)

let tiffutil = Process()
tiffutil.executableURL = URL(fileURLWithPath: "/usr/bin/tiffutil")
tiffutil.arguments = ["-cathidpicheck", normal.path, retina.path, "-out", "Resources/dmg-background.tiff"]
try tiffutil.run()
tiffutil.waitUntilExit()
try fm.removeItem(at: folder)
