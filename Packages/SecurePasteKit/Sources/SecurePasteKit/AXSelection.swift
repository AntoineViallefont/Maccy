import AppKit
import ApplicationServices

@MainActor
struct AXSelection {
  enum Failure: Error { case unsupported, focusChanged, noSelection, permission }
  let pid: pid_t
  let element: AXUIElement
  let range: CFRange?

  init(pid: pid_t) throws {
    guard AXIsProcessTrusted() else { throw Failure.permission }
    guard NSWorkspace.shared.frontmostApplication?.processIdentifier == pid else {
      throw Failure.focusChanged
    }
    let app = AXUIElementCreateApplication(pid)
    AXUIElementSetMessagingTimeout(app, 0.2)
    var raw: CFTypeRef?
    guard AXUIElementCopyAttributeValue(app, kAXFocusedUIElementAttribute as CFString, &raw) == .success,
          let raw, CFGetTypeID(raw) == AXUIElementGetTypeID() else { throw Failure.unsupported }
    element = unsafeDowncast(raw, to: AXUIElement.self)
    AXUIElementSetMessagingTimeout(element, 0.2)
    self.pid = pid
    var selection: CFTypeRef?
    _ = AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &selection)
    var decoded = CFRange()
    if let selection, CFGetTypeID(selection) == AXValueGetTypeID(),
       AXValueGetValue(unsafeDowncast(selection, to: AXValue.self), .cfRange, &decoded) {
      range = decoded
    } else {
      range = nil
    }
    var subrole: CFTypeRef?
    _ = AXUIElementCopyAttributeValue(element, kAXSubroleAttribute as CFString, &subrole)
    guard subrole as? String != "AXSecureTextField" else { throw Failure.unsupported }
  }

  func checkFocus() throws {
    let current = try AXSelection(pid: pid)
    guard CFEqual(element, current.element) else { throw Failure.focusChanged }
    if let range {
      guard let other = current.range, range.location == other.location, range.length == other.length
      else { throw Failure.focusChanged }
    }
  }

  func read() throws -> String {
    var raw: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute as CFString, &raw) == .success,
          let text = raw as? String, !text.isEmpty else { throw Failure.noSelection }
    try checkFocus()
    return text
  }

  func insert(_ text: String, authorize: () -> Bool) throws {
    guard range != nil else { throw Failure.unsupported }
    var writable = DarwinBoolean(false)
    guard AXUIElementIsAttributeSettable(element, kAXSelectedTextAttribute as CFString, &writable) == .success,
          writable.boolValue else { throw Failure.unsupported }
    try checkFocus()
    guard authorize() else { throw Failure.permission }
    guard AXUIElementSetAttributeValue(element, kAXSelectedTextAttribute as CFString, text as CFString) == .success
    else { throw Failure.unsupported }
  }
}
