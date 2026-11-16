// Draws the 1024x1024 app icon. Usage: swift scripts/make-icon.swift <out.png>
import AppKit

let size: CGFloat = 1024
let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { _ in
    // macOS icon grid: an 824-point rounded square on a 1024 canvas
    let body = NSRect(x: 100, y: 100, width: 824, height: 824)
    let shape = NSBezierPath(roundedRect: body, xRadius: 185, yRadius: 185)

    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
    shadow.shadowBlurRadius = 24
    shadow.shadowOffset = NSSize(width: 0, height: -10)
    shadow.set()
    NSColor.black.setFill()
    shape.fill()
    NSGraphicsContext.restoreGraphicsState()

    // Ivory case, like the PC-98's
    NSGradient(colors: [
        NSColor(red: 0.95, green: 0.93, blue: 0.86, alpha: 1),
        NSColor(red: 0.84, green: 0.81, blue: 0.72, alpha: 1),
    ])!.draw(in: shape, angle: -90)

    // CRT screen
    let screenRect = NSRect(x: 190, y: 330, width: 644, height: 470)
    let screen = NSBezierPath(roundedRect: screenRect, xRadius: 60, yRadius: 60)
    NSGradient(colors: [
        NSColor(red: 0.10, green: 0.12, blue: 0.16, alpha: 1),
        NSColor(red: 0.02, green: 0.03, blue: 0.05, alpha: 1),
    ])!.draw(in: screen, angle: -90)

    // "98" in chunky pixels on the screen
    let glyphs: [[String]] = [
        ["01110", "10001", "10001", "01111", "00001", "00010", "01100"],
        ["01110", "10001", "10001", "01110", "10001", "10001", "01110"],
    ]
    let pixel: CGFloat = 46
    let glyphWidth = pixel * 5, gap = pixel
    let totalWidth = glyphWidth * 2 + gap
    let originX = screenRect.midX - totalWidth / 2
    let originY = screenRect.midY + pixel * 3.5
    NSColor(red: 0.55, green: 1.0, blue: 0.62, alpha: 1).setFill()
    for (g, rows) in glyphs.enumerated() {
        for (r, row) in rows.enumerated() {
            for (c, bit) in row.enumerated() where bit == "1" {
                NSRect(x: originX + CGFloat(g) * (glyphWidth + gap) + CGFloat(c) * pixel,
                       y: originY - CGFloat(r + 1) * pixel,
                       width: pixel - 4, height: pixel - 4).fill()
            }
        }
    }

    // Two floppy drive slots below the screen
    NSColor(red: 0.30, green: 0.28, blue: 0.24, alpha: 1).setFill()
    for x in [CGFloat(230), 542] {
        NSBezierPath(roundedRect: NSRect(x: x, y: 200, width: 252, height: 34), xRadius: 17, yRadius: 17).fill()
    }
    return true
}

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size), bitsPerSample: 8,
                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
image.draw(in: NSRect(x: 0, y: 0, width: size, height: size))
NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
