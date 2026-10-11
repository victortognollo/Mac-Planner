// Renders the 1024 px app icon: a blue rounded square with a white week strip.
import AppKit

let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon-1024.png"
let px = 1024

guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                                 samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                 colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { exit(1) }
rep.size = NSSize(width: px, height: px)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

// macOS icon grid: 824 pt body centered in 1024.
let body = NSRect(x: 100, y: 100, width: 824, height: 824)
NSColor(srgbRed: 0.0, green: 0.4, blue: 0.8, alpha: 1).setFill()
NSBezierPath(roundedRect: body, xRadius: 185, yRadius: 185).fill()

// Seven day columns; today is the tall filled one.
let cols = 7
let gap: CGFloat = 18
let inner = body.insetBy(dx: 120, dy: 250)
let w = (inner.width - gap * CGFloat(cols - 1)) / CGFloat(cols)
for i in 0..<cols {
    let x = inner.minX + CGFloat(i) * (w + gap)
    let isToday = i == 4
    let h: CGFloat = isToday ? inner.height : inner.height * 0.72
    let r = NSRect(x: x, y: inner.minY, width: w, height: h)
    NSColor.white.withAlphaComponent(isToday ? 1 : 0.42).setFill()
    NSBezierPath(roundedRect: r, xRadius: w / 2, yRadius: w / 2).fill()
}

NSGraphicsContext.restoreGraphicsState()
guard let png = rep.representation(using: .png, properties: [:]) else { exit(1) }
try png.write(to: URL(fileURLWithPath: out))
