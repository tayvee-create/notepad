// Draws the Notepad app icon at every size and builds Notepad.icns.
// Run: swift Icon/make-icon.swift  (from the project folder)
import AppKit

func draw(_ px: Int) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let s = CGFloat(px) / 1024
    let ctx = NSGraphicsContext.current!.cgContext
    ctx.scaleBy(x: s, y: s)

    // Paper with drop shadow
    let paper = NSRect(x: 196, y: 100, width: 632, height: 790)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 30, color: NSColor.black.withAlphaComponent(0.35).cgColor)
    NSColor(calibratedRed: 1, green: 1, blue: 0.97, alpha: 1).setFill()
    NSBezierPath(roundedRect: paper, xRadius: 22, yRadius: 22).fill()
    ctx.restoreGState()

    // Blue header band (the classic Notepad pad top)
    let band = NSBezierPath(roundedRect: NSRect(x: 196, y: 770, width: 632, height: 120), xRadius: 22, yRadius: 22)
    band.append(NSBezierPath(rect: NSRect(x: 196, y: 770, width: 632, height: 40)))
    NSGradient(starting: NSColor(calibratedRed: 0.36, green: 0.62, blue: 0.93, alpha: 1),
               ending: NSColor(calibratedRed: 0.15, green: 0.40, blue: 0.78, alpha: 1))!.draw(in: band, angle: -90)

    // Ruled lines
    NSColor(calibratedRed: 0.55, green: 0.72, blue: 0.92, alpha: 1).setStroke()
    var y: CGFloat = 700
    while y > 150 {
        let line = NSBezierPath(); line.lineWidth = 6
        line.move(to: NSPoint(x: 236, y: y)); line.line(to: NSPoint(x: 788, y: y)); line.stroke()
        y -= 64
    }
    // Red margin line
    NSColor(calibratedRed: 0.9, green: 0.35, blue: 0.35, alpha: 1).setStroke()
    let margin = NSBezierPath(); margin.lineWidth = 6
    margin.move(to: NSPoint(x: 300, y: 130)); margin.line(to: NSPoint(x: 300, y: 760)); margin.stroke()

    // "Text" on the first lines
    NSColor(calibratedWhite: 0.25, alpha: 1).setFill()
    for (i, w) in [400, 330, 440, 260].enumerated() {
        let ly = 700 - CGFloat(i) * 64 + 10
        NSBezierPath(roundedRect: NSRect(x: 330, y: ly, width: CGFloat(w), height: 22), xRadius: 11, yRadius: 11).fill()
    }

    // Spiral rings
    for i in 0..<7 {
        let x = 250 + CGFloat(i) * 87
        let hole = NSRect(x: x - 14, y: 800, width: 28, height: 28)
        NSColor(calibratedWhite: 0.1, alpha: 0.55).setFill()
        NSBezierPath(ovalIn: hole).fill()
        let ring = NSBezierPath(roundedRect: NSRect(x: x - 11, y: 814, width: 22, height: 120), xRadius: 11, yRadius: 11)
        NSGradient(starting: NSColor(calibratedWhite: 0.95, alpha: 1),
                   ending: NSColor(calibratedWhite: 0.55, alpha: 1))!.draw(in: ring, angle: 0)
        NSColor(calibratedWhite: 0.35, alpha: 1).setStroke()
        ring.lineWidth = 3; ring.stroke()
    }

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

let dir = URL(fileURLWithPath: "Icon/Notepad.iconset")
try? FileManager.default.removeItem(at: dir)
try! FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = scale == 1 ? "icon_\(base)x\(base).png" : "icon_\(base)x\(base)@2x.png"
        try! draw(base * scale).representation(using: .png, properties: [:])!.write(to: dir.appendingPathComponent(name))
    }
}
try! draw(1024).representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "Icon/Notepad-1024.png"))
print("done")
