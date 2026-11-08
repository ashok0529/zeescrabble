import AppKit

// Original vector-drawn artwork, rendered as an opaque App Store icon.
let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1024, pixelsHigh: 1024,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
let ink = NSColor(calibratedRed: 0.08, green: 0.17, blue: 0.24, alpha: 1)
NSGradient(starting: ink, ending: NSColor(calibratedRed: 0.16, green: 0.32, blue: 0.40, alpha: 1))!
    .draw(in: NSRect(x: 0, y: 0, width: 1024, height: 1024), angle: 60)

let face = NSBezierPath(roundedRect: NSRect(x: 172, y: 190, width: 680, height: 680), xRadius: 80, yRadius: 80)
NSGraphicsContext.saveGraphicsState()
let shadow = NSShadow()
shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
shadow.shadowBlurRadius = 42
shadow.shadowOffset = NSSize(width: 0, height: -24)
shadow.set()
NSColor(calibratedRed: 0.66, green: 0.49, blue: 0.28, alpha: 1).setFill()
NSBezierPath(roundedRect: NSRect(x: 172, y: 154, width: 680, height: 700), xRadius: 80, yRadius: 80).fill()
NSGraphicsContext.restoreGraphicsState()
NSGradient(starting: NSColor(calibratedRed: 0.94, green: 0.80, blue: 0.55, alpha: 1),
           ending: NSColor(calibratedRed: 1, green: 0.96, blue: 0.83, alpha: 1))!.draw(in: face, angle: 90)
NSColor.white.withAlphaComponent(0.55).setStroke()
face.lineWidth = 4
face.stroke()
let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 470, weight: .heavy), .foregroundColor: ink]
let letter = "Z" as NSString
let size = letter.size(withAttributes: attributes)
letter.draw(at: NSPoint(x: (1024 - size.width) / 2, y: 530 - size.height / 2), withAttributes: attributes)
("10" as NSString).draw(at: NSPoint(x: 714, y: 228), withAttributes: [.font: NSFont.systemFont(ofSize: 64, weight: .semibold), .foregroundColor: ink])
NSGraphicsContext.restoreGraphicsState()
bitmap.hasAlpha = false
try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "ZeeWords/Assets.xcassets/AppIcon.appiconset/AppIcon.png"))
