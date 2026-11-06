import AppKit
let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1024, pixelsHigh: 1024, bitsPerSample: 8, samplesPerPixel: 3, hasAlpha: false, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
NSColor(calibratedRed: 0.08, green: 0.14, blue: 0.20, alpha: 1).setFill()
NSBezierPath(rect: NSRect(x: 0, y: 0, width: 1024, height: 1024)).fill()
NSColor(calibratedRed: 0.98, green: 0.88, blue: 0.66, alpha: 1).setFill()
NSBezierPath(roundedRect: NSRect(x: 180, y: 180, width: 664, height: 664), xRadius: 70, yRadius: 70).fill()
let ink = NSColor(calibratedRed: 0.08, green: 0.14, blue: 0.20, alpha: 1)
("Z" as NSString).draw(at: NSPoint(x: 335, y: 240), withAttributes: [.font: NSFont.systemFont(ofSize: 480, weight: .bold), .foregroundColor: ink])
("10" as NSString).draw(at: NSPoint(x: 690, y: 210), withAttributes: [.font: NSFont.systemFont(ofSize: 72, weight: .medium), .foregroundColor: ink])
NSGraphicsContext.restoreGraphicsState()
try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "ZeeScrabble/Assets.xcassets/AppIcon.appiconset/AppIcon.png"))
