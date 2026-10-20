import AppKit
import ApplicationServices
import Carbon
import Observation

/// Security boundary at module level, in the same process as Maccy (not an XPC sandbox).
/// Its public interface exposes state and settings only, never secret content.
@MainActor @Observable
public final class SecurePasteService {
  public static let shared = SecurePasteService()

  public private(set) var isOperational = false
  public private(set) var isSecureApplication = false
  public private(set) var remainingSeconds = 0
  public private(set) var showsGreenConfirmation = false
  public private(set) var message = "Protection inactive — autorisation Accessibilité requise."
  public var showsRedIcon: Bool { isOperational && remainingSeconds > 0 }

  @ObservationIgnored private let vault = EphemeralVault()
  @ObservationIgnored private var applications: Set<String> = []
  @ObservationIgnored private var copyCode: CGKeyCode = 8
  @ObservationIgnored private var pasteCode: CGKeyCode = 9
  @ObservationIgnored private var tap: CFMachPort?
  @ObservationIgnored private var source: CFRunLoopSource?
  @ObservationIgnored private var timer: Timer?
  @ObservationIgnored private var suppressedKeys: Set<CGKeyCode> = []
  @ObservationIgnored private var observers: [NSObjectProtocol] = []
  @ObservationIgnored private var revision = 0
  @ObservationIgnored private var generation: UInt64 = 0
  @ObservationIgnored private var suspended = false
  @ObservationIgnored private var started = false
  @ObservationIgnored private var confirmation = SuccessPulse()

  private init() {}

  public func configure(applications: Set<String>, copyKeyCode: UInt16, pasteKeyCode: UInt16) {
    self.applications = applications
    copyCode = copyKeyCode
    pasteCode = pasteKeyCode
    refresh()
  }

  public func start() {
    guard !started else { return }
    started = true
    revision = NSPasteboard.general.changeCount
    installTap()
    let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
      MainActor.assumeIsolated { self?.refresh() }
    }
    self.timer = timer
    RunLoop.main.add(timer, forMode: .common)
    let center = NSWorkspace.shared.notificationCenter
    for name in [NSWorkspace.willSleepNotification, NSWorkspace.screensDidSleepNotification,
                 NSWorkspace.sessionDidResignActiveNotification] {
      observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
        MainActor.assumeIsolated {
          self?.suspended = true
          self?.clear()
        }
      })
    }
    for name in [NSWorkspace.didWakeNotification, NSWorkspace.screensDidWakeNotification,
                 NSWorkspace.sessionDidBecomeActiveNotification] {
      observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
        MainActor.assumeIsolated {
          self?.suspended = false
          self?.clear()
        }
      })
    }
    refresh()
  }

  public func requestAccessibility() {
    // The SDK exports the constant as a mutable C global; its documented value is fixed.
    let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
    _ = AXIsProcessTrustedWithOptions(options)
    installTap()
    refresh()
  }

  public func clear() {
    generation &+= 1
    vault.destroy()
    remainingSeconds = 0
    confirmation.cancel()
    showsGreenConfirmation = false
    message = "Secret détruit."
  }

  public func stop() {
    clear()
    timer?.invalidate()
    timer = nil
    removeTap()
    for observer in observers { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
    observers.removeAll()
    started = false
    isOperational = false
  }

  private func installTap() {
    guard tap == nil, AXIsProcessTrusted(), !suspended else { return }
    let mask = (CGEventMask(1) << CGEventType.keyDown.rawValue) |
      (CGEventMask(1) << CGEventType.keyUp.rawValue)
    tap = CGEvent.tapCreate(
      tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
      eventsOfInterest: mask,
      callback: { _, type, event, context in
        guard let context else { return Unmanaged.passUnretained(event) }
        // Installed exclusively on the main run loop. No AX calls inside the tap callback.
        let forward = MainActor.assumeIsolated {
          let service = Unmanaged<SecurePasteService>.fromOpaque(context).takeUnretainedValue()
          return service.filter(type: type, event: event) != nil
        }
        return forward ? Unmanaged.passUnretained(event) : nil
      }, userInfo: Unmanaged.passUnretained(self).toOpaque()
    )
    if let tap {
      source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
      if let source { CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes) }
      CGEvent.tapEnable(tap: tap, enable: true)
    }
  }

  private func removeTap() {
    if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
    if let tap { CFMachPortInvalidate(tap) }
    source = nil
    tap = nil
    suppressedKeys.removeAll()
  }

  private func refresh() {
    showsGreenConfirmation = confirmation.isVisible(at: continuousSeconds())
    let count = NSPasteboard.general.changeCount
    if count != revision {
      revision = count
      clear()
    }
    let previous = remainingSeconds
    remainingSeconds = vault.remaining(clipboardRevision: count)
    if previous > 0 && remainingSeconds == 0 { message = "Secret expiré ou invalidé." }
    isSecureApplication = NSWorkspace.shared.frontmostApplication?.bundleIdentifier.map(applications.contains) ?? false
    if started && tap == nil { installTap() }
    let trusted = AXIsProcessTrusted()
    let wasOperational = isOperational
    isOperational = trusted && !suspended && !IsSecureEventInputEnabled() &&
      tap.map { CGEvent.tapIsEnabled(tap: $0) } == true
    if !isOperational {
      vault.destroy()
      remainingSeconds = 0
      confirmation.cancel()
      showsGreenConfirmation = false
      message = "Protection indisponible : vérifier Accessibilité et la saisie sécurisée. ⌘C peut rester classique."
    } else if !wasOperational {
      message = "Protection active — aucun secret en mémoire."
    }
  }

  private func filter(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
      clear()
      isOperational = false
      message = "Interception interrompue — secret détruit."
      if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
      return Unmanaged.passUnretained(event)
    }
    let key = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
    if type == .keyUp {
      return suppressedKeys.remove(key) != nil ? nil : Unmanaged.passUnretained(event)
    }
    guard type == .keyDown else { return Unmanaged.passUnretained(event) }
    if suppressedKeys.contains(key) { return nil }
    let flags = event.flags
    let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier
    let listed = NSWorkspace.shared.frontmostApplication?.bundleIdentifier.map(applications.contains) ?? false
    let route = SecureRoute.resolve(
      command: flags.contains(.maskCommand), shift: flags.contains(.maskShift),
      otherModifiers: !flags.intersection([.maskControl, .maskAlternate]).isEmpty,
      isCopy: key == copyCode, isPaste: key == pasteCode, listed: listed
    )
    guard route != .ordinary else {
      if flags.contains(.maskCommand) && key == copyCode { clear() }
      return Unmanaged.passUnretained(event)
    }
    suppressedKeys.insert(key)
    // Suppress even on failure. Never fall back to a classical copy/paste here.
    guard !suspended, AXIsProcessTrusted(), !IsSecureEventInputEnabled(), let pid else {
      clear()
      message = "Action sécurisée bloquée : protection indisponible."
      return nil
    }
    if route == .copy { clear() }
    let token = generation
    let scheduled = ContinuousClock.now
    DispatchQueue.main.async { [weak self] in
      guard let self, token == self.generation else { return }
      guard scheduled.duration(to: .now) < .milliseconds(300) else {
        self.clear()
        self.message = "Action annulée : délai de traitement dépassé."
        return
      }
      self.perform(route: route, pid: pid)
    }
    return nil
  }

  private func perform(route: SecureRoute, pid: pid_t) {
    do {
      refresh()
      guard isOperational else { throw AXSelection.Failure.permission }
      let target = try AXSelection(pid: pid)
      if route == .copy {
        let before = NSPasteboard.general.changeCount
        let text = try target.read()
        guard before == NSPasteboard.general.changeCount else { throw EphemeralVault.Failure.unavailable }
        try vault.replace(with: text, clipboardRevision: before)
        remainingSeconds = vault.remaining(clipboardRevision: before)
        message = "Secret disponible — 60 s maximum."
      } else {
        try vault.withSecret(clipboardRevision: NSPasteboard.general.changeCount) { text in
          // Check expiry/revision again after any AX round trips, immediately before writing.
          try target.checkFocus()
          guard vault.remaining(clipboardRevision: NSPasteboard.general.changeCount) > 0 else {
            throw EphemeralVault.Failure.unavailable
          }
          try target.insert(text) {
            vault.remaining(clipboardRevision: NSPasteboard.general.changeCount) > 0
          }
        }
        clear()
        confirmation.confirm(at: continuousSeconds())
        showsGreenConfirmation = true
        message = "Insertion effectuée — secret détruit."
      }
    } catch {
      clear()
      message = "Action refusée : aucun secret valide, sélection inaccessible ou champ incompatible."
      NSSound.beep()
    }
  }
}
