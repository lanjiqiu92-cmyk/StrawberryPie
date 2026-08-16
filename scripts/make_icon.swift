import AppKit

let projectURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let iconsetURL = projectURL.appendingPathComponent("ChocolatePie.iconset", isDirectory: true)
try? FileManager.default.removeItem(at: iconsetURL)
try FileManager.default.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

let entries: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

func drawIcon(size: Int) throws -> Data {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else { throw NSError(domain: "ChocolatePieIcon", code: 1) }

    bitmap.size = NSSize(width: size, height: size)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)

    let canvas = NSRect(x: 0, y: 0, width: size, height: size)
    NSColor.clear.setFill()
    canvas.fill()

    let margin = CGFloat(size) * 0.055
    let tile = canvas.insetBy(dx: margin, dy: margin)
    let tilePath = NSBezierPath(roundedRect: tile, xRadius: CGFloat(size) * 0.22, yRadius: CGFloat(size) * 0.22)
    NSColor(calibratedRed: 0.965, green: 0.937, blue: 0.884, alpha: 1).setFill()
    tilePath.fill()

    let unit = CGFloat(size)
    let ink = NSColor(calibratedRed: 0.17, green: 0.125, blue: 0.115, alpha: 1)
    let paper = NSColor(calibratedRed: 0.99, green: 0.965, blue: 0.90, alpha: 1)
    let pink = NSColor(calibratedRed: 0.84, green: 0.60, blue: 0.66, alpha: 1)
    let chocolate = NSColor(calibratedRed: 0.31, green: 0.21, blue: 0.19, alpha: 1)

    let chocolatePanel = NSBezierPath(roundedRect: canvas.insetBy(dx: unit * 0.12, dy: unit * 0.12), xRadius: unit * 0.16, yRadius: unit * 0.16)
    chocolate.setFill()
    chocolatePanel.fill()
    chocolatePanel.lineWidth = max(1.5, unit * 0.026)
    ink.setStroke()
    chocolatePanel.stroke()

    let head = NSBezierPath()
    head.move(to: NSPoint(x: unit * 0.20, y: unit * 0.50))
    head.line(to: NSPoint(x: unit * 0.23, y: unit * 0.78))
    head.line(to: NSPoint(x: unit * 0.42, y: unit * 0.67))
    head.curve(to: NSPoint(x: unit * 0.67, y: unit * 0.67), controlPoint1: NSPoint(x: unit * 0.49, y: unit * 0.73), controlPoint2: NSPoint(x: unit * 0.59, y: unit * 0.73))
    head.line(to: NSPoint(x: unit * 0.80, y: unit * 0.80))
    head.line(to: NSPoint(x: unit * 0.82, y: unit * 0.50))
    head.curve(to: NSPoint(x: unit * 0.51, y: unit * 0.25), controlPoint1: NSPoint(x: unit * 0.79, y: unit * 0.28), controlPoint2: NSPoint(x: unit * 0.66, y: unit * 0.23))
    head.curve(to: NSPoint(x: unit * 0.20, y: unit * 0.50), controlPoint1: NSPoint(x: unit * 0.35, y: unit * 0.23), controlPoint2: NSPoint(x: unit * 0.22, y: unit * 0.30))
    head.close()
    paper.setFill()
    head.fill()
    head.lineWidth = max(1.5, unit * 0.027)
    ink.setStroke()
    head.stroke()

    pink.setFill()
    let leftEar = NSBezierPath()
    leftEar.move(to: NSPoint(x: unit * 0.27, y: unit * 0.71))
    leftEar.line(to: NSPoint(x: unit * 0.27, y: unit * 0.59))
    leftEar.line(to: NSPoint(x: unit * 0.38, y: unit * 0.65))
    leftEar.close()
    leftEar.fill()
    let rightEar = NSBezierPath()
    rightEar.move(to: NSPoint(x: unit * 0.75, y: unit * 0.72))
    rightEar.line(to: NSPoint(x: unit * 0.73, y: unit * 0.59))
    rightEar.line(to: NSPoint(x: unit * 0.65, y: unit * 0.66))
    rightEar.close()
    rightEar.fill()

    ink.setFill()
    NSBezierPath(ovalIn: NSRect(x: unit * 0.36, y: unit * 0.47, width: unit * 0.045, height: unit * 0.075)).fill()
    NSBezierPath(ovalIn: NSRect(x: unit * 0.62, y: unit * 0.47, width: unit * 0.045, height: unit * 0.075)).fill()

    pink.setFill()
    NSBezierPath(ovalIn: NSRect(x: unit * 0.29, y: unit * 0.38, width: unit * 0.095, height: unit * 0.055)).fill()
    NSBezierPath(ovalIn: NSRect(x: unit * 0.65, y: unit * 0.38, width: unit * 0.095, height: unit * 0.055)).fill()

    let nose = NSBezierPath()
    nose.move(to: NSPoint(x: unit * 0.49, y: unit * 0.43))
    nose.line(to: NSPoint(x: unit * 0.55, y: unit * 0.43))
    nose.line(to: NSPoint(x: unit * 0.52, y: unit * 0.39))
    nose.close()
    chocolate.setFill()
    nose.fill()

    let smile = NSBezierPath()
    smile.move(to: NSPoint(x: unit * 0.52, y: unit * 0.39))
    smile.curve(to: NSPoint(x: unit * 0.43, y: unit * 0.35), controlPoint1: NSPoint(x: unit * 0.51, y: unit * 0.34), controlPoint2: NSPoint(x: unit * 0.47, y: unit * 0.34))
    smile.move(to: NSPoint(x: unit * 0.52, y: unit * 0.39))
    smile.curve(to: NSPoint(x: unit * 0.61, y: unit * 0.35), controlPoint1: NSPoint(x: unit * 0.53, y: unit * 0.34), controlPoint2: NSPoint(x: unit * 0.58, y: unit * 0.34))
    smile.lineWidth = max(1, unit * 0.018)
    smile.lineCapStyle = .round
    ink.setStroke()
    smile.stroke()

    let sparkleColor = NSColor(calibratedRed: 0.91, green: 0.77, blue: 0.39, alpha: 1)
    sparkleColor.setFill()
    for (x, y, r) in [(0.17, 0.83, 0.027), (0.84, 0.25, 0.021), (0.84, 0.86, 0.016)] {
        NSBezierPath(ovalIn: NSRect(x: unit * CGFloat(x - r), y: unit * CGFloat(y - r), width: unit * CGFloat(r * 2), height: unit * CGFloat(r * 2))).fill()
    }

    NSGraphicsContext.restoreGraphicsState()
    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "ChocolatePieIcon", code: 2)
    }
    return data
}

for (name, size) in entries {
    let data = try drawIcon(size: size)
    try data.write(to: iconsetURL.appendingPathComponent(name), options: .atomic)
    if size == 1024 {
        try data.write(to: projectURL.appendingPathComponent("ChocolatePie.png"), options: .atomic)
    }
}

print(iconsetURL.path)
