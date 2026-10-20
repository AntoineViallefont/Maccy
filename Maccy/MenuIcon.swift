import AppKit
import Defaults

enum MenuIcon: String, CaseIterable, Identifiable, Defaults.Serializable {
  case maccy
  case clipboard
  case scissors
  case paperclip

  var id: Self { self }

  var image: NSImage {
    switch self {
    case .maccy:
      return Self.securePasteLock
    case .clipboard:
      return NSImage(named: .clipboard)!
    case .scissors:
      return NSImage(named: .scissors)!
    case .paperclip:
      return NSImage(named: .paperclip)!
    }
  }

  // Vector silhouette of the approved blue padlock; tint is controlled by AppDelegate.
  private static var securePasteLock: NSImage {
    let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
      NSColor.black.setFill()
      NSColor.black.setStroke()
      let shackle = NSBezierPath()
      shackle.move(to: NSPoint(x: 5.5, y: 10))
      shackle.line(to: NSPoint(x: 5.5, y: 12.5))
      shackle.curve(to: NSPoint(x: 12.5, y: 12.5),
                    controlPoint1: NSPoint(x: 5.5, y: 17),
                    controlPoint2: NSPoint(x: 12.5, y: 17))
      shackle.line(to: NSPoint(x: 12.5, y: 10))
      shackle.lineWidth = 1.8
      shackle.lineCapStyle = .round
      shackle.stroke()
      let body = NSBezierPath(roundedRect: NSRect(x: 3.5, y: 2, width: 11, height: 9),
                              xRadius: 2, yRadius: 2)
      body.windingRule = .evenOdd
      body.appendOval(in: NSRect(x: 8, y: 5, width: 2, height: 2))
      body.fill()
      return true
    }
    image.isTemplate = true
    image.accessibilityDescription = "SecurePaste — cadenas"
    return image
  }
}
