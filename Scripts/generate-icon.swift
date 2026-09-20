import AppKit

// Rebuild the checked-in icon with: swift Scripts/generate-icon.swift
let output = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let iconset = output.appendingPathComponent(".build/AppIcon.iconset", isDirectory: true)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
try FileManager.default.createDirectory(at: output.appendingPathComponent("RightClick/Resources"), withIntermediateDirectories: true)

func drawIcon(size: Int) -> Data {
    let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
        isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    let context = NSGraphicsContext(bitmapImageRep: bitmap)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.cgContext.scaleBy(x: CGFloat(size) / 1024, y: CGFloat(size) / 1024)

    let tile = NSBezierPath(roundedRect: NSRect(x: 72, y: 72, width: 880, height: 880), xRadius: 200, yRadius: 200)
    NSGradient(starting: NSColor(red: 0.20, green: 0.55, blue: 1, alpha: 1), ending: NSColor(red: 0.25, green: 0.27, blue: 0.86, alpha: 1))!
        .draw(in: tile, angle: -75)

    let page = NSBezierPath()
    page.move(to: NSPoint(x: 324, y: 236))
    page.line(to: NSPoint(x: 638, y: 236))
    page.curve(to: NSPoint(x: 688, y: 286), controlPoint1: NSPoint(x: 671, y: 236), controlPoint2: NSPoint(x: 688, y: 253))
    page.line(to: NSPoint(x: 688, y: 638))
    page.line(to: NSPoint(x: 558, y: 788))
    page.line(to: NSPoint(x: 324, y: 788))
    page.curve(to: NSPoint(x: 274, y: 738), controlPoint1: NSPoint(x: 291, y: 788), controlPoint2: NSPoint(x: 274, y: 771))
    page.line(to: NSPoint(x: 274, y: 286))
    page.curve(to: NSPoint(x: 324, y: 236), controlPoint1: NSPoint(x: 274, y: 253), controlPoint2: NSPoint(x: 291, y: 236))
    page.close()
    NSColor.white.setFill()
    page.fill()

    let fold = NSBezierPath()
    fold.move(to: NSPoint(x: 558, y: 788))
    fold.line(to: NSPoint(x: 558, y: 672))
    fold.curve(to: NSPoint(x: 592, y: 638), controlPoint1: NSPoint(x: 558, y: 651), controlPoint2: NSPoint(x: 571, y: 638))
    fold.line(to: NSPoint(x: 688, y: 638))
    fold.close()
    NSColor(red: 0.80, green: 0.87, blue: 1, alpha: 1).setFill()
    fold.fill()

    NSColor(red: 0.73, green: 0.82, blue: 0.97, alpha: 1).setFill()
    for (y, width) in [(544, 238), (452, 190), (360, 140)] {
        NSBezierPath(roundedRect: NSRect(x: 348, y: y, width: width, height: 26), xRadius: 13, yRadius: 13).fill()
    }

    NSColor.white.setFill()
    NSBezierPath(ovalIn: NSRect(x: 526, y: 180, width: 276, height: 276)).fill()
    NSColor(red: 0.18, green: 0.45, blue: 0.94, alpha: 1).setFill()
    NSBezierPath(ovalIn: NSRect(x: 544, y: 198, width: 240, height: 240)).fill()
    NSColor.white.setFill()
    NSBezierPath(roundedRect: NSRect(x: 644, y: 246, width: 40, height: 144), xRadius: 20, yRadius: 20).fill()
    NSBezierPath(roundedRect: NSRect(x: 592, y: 298, width: 144, height: 40), xRadius: 20, yRadius: 20).fill()

    NSGraphicsContext.restoreGraphicsState()
    return bitmap.representation(using: .png, properties: [:])!
}

for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let suffix = scale == 2 ? "@2x" : ""
        let url = iconset.appendingPathComponent("icon_\(points)x\(points)\(suffix).png")
        try drawIcon(size: points * scale).write(to: url)
    }
}

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconset.path, "-o", output.appendingPathComponent("RightClick/Resources/AppIcon.icns").path]
try process.run()
process.waitUntilExit()
exit(process.terminationStatus)
