// Rebuild the approved native vector design without external libraries.
import AppKit

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let folder = root.appendingPathComponent("Maccy/Assets.xcassets/SecurePasteIcon.appiconset")
try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
let navy = NSColor(srgbRed: 0.025, green: 0.08, blue: 0.17, alpha: 1)
let blue = NSColor(srgbRed: 0.06, green: 0.36, blue: 0.66, alpha: 1)
let specifications = [(16, 1), (16, 2), (32, 1), (32, 2), (128, 1),
                      (128, 2), (256, 1), (256, 2), (512, 1), (512, 2)]
var entries: [[String: String]] = []

for (points, scale) in specifications {
  let pixels = points * scale
  let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                                bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                isPlanar: false, colorSpaceName: .deviceRGB,
                                bytesPerRow: 0, bitsPerPixel: 0)!
  NSGraphicsContext.saveGraphicsState()
  NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
  let transform = NSAffineTransform()
  transform.scale(by: CGFloat(pixels) / 1024)
  transform.concat()
  let background = NSBezierPath(roundedRect: NSRect(x: 56, y: 56, width: 912, height: 912),
                               xRadius: 208, yRadius: 208)
  NSGradient(starting: navy, ending: blue)!.draw(in: background, angle: 70)
  NSColor.white.setStroke()
  NSColor.white.setFill()
  let shackle = NSBezierPath()
  shackle.move(to: NSPoint(x: 366, y: 565))
  shackle.line(to: NSPoint(x: 366, y: 682))
  shackle.curve(to: NSPoint(x: 658, y: 682),
                controlPoint1: NSPoint(x: 366, y: 881),
                controlPoint2: NSPoint(x: 658, y: 881))
  shackle.line(to: NSPoint(x: 658, y: 565))
  shackle.lineWidth = 65
  shackle.lineCapStyle = .round
  shackle.stroke()
  NSBezierPath(roundedRect: NSRect(x: 270, y: 240, width: 484, height: 365),
               xRadius: 83, yRadius: 83).fill()
  navy.setFill()
  NSBezierPath(ovalIn: NSRect(x: 472, y: 407, width: 80, height: 80)).fill()
  NSBezierPath(roundedRect: NSRect(x: 494, y: 343, width: 36, height: 95),
               xRadius: 16, yRadius: 16).fill()
  NSGraphicsContext.restoreGraphicsState()
  let filename = "SecurePaste-\(points)@\(scale)x.png"
  try bitmap.representation(using: .png, properties: [:])!.write(to: folder.appendingPathComponent(filename))
  entries.append(["filename": filename, "idiom": "mac", "scale": "\(scale)x", "size": "\(points)x\(points)"])
}
let contents: [String: Any] = ["images": entries, "info": ["author": "xcode", "version": 1]]
try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
  .write(to: folder.appendingPathComponent("Contents.json"))
print("SecurePaste icon: 10 native sizes generated.")
