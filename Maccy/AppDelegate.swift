import Defaults
import KeyboardShortcuts
import SecurePasteKit
import Sauce
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
  nonisolated static let isTesting = CommandLine.arguments.contains("enable-testing")
  var panel: FloatingPanel<ContentView>!

  @objc
  private lazy var statusItem: NSStatusItem = {
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    statusItem.behavior = .removalAllowed
    statusItem.button?.action = #selector(performStatusItemClick)
    statusItem.button?.image = Defaults[.menuIcon].image
    statusItem.button?.imagePosition = .imageLeft
    statusItem.button?.target = self
    statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
    return statusItem
  }()

  // Base accessibility label for the status item; kept separate from the optional
  // dynamic `title` (recent copy text) so VoiceOver always announces something
  // meaningful even when that preference is off or the app is disabled.
  private func updateStatusItemAccessibilityLabel() {
    var accessibilityLabel = NSLocalizedString("status_item_accessibility_label", comment: "")
    if isStatusItemDisabled {
      accessibilityLabel += " — \(NSLocalizedString("status_item_disabled_accessibility_suffix", comment: ""))"
    }
    if SecurePasteService.shared.showsRedIcon { accessibilityLabel += " — Mode sécurisé" }
    if SecurePasteService.shared.showsGreenConfirmation {
      accessibilityLabel += " — Insertion réussie, secret détruit"
    }
    statusItem.button?.setAccessibilityLabel(accessibilityLabel)
  }

  private var isStatusItemDisabled: Bool {
    Defaults[.ignoreEvents] || Defaults[.enabledPasteboardTypes].isEmpty
  }

  private var statusItemVisibilityObserver: NSKeyValueObservation?

  private var isAutomatedTest: Bool {
    #if DEBUG
    return Self.isTesting || ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    #else
    return false
    #endif
  }

  func applicationWillFinishLaunching(_ notification: Notification) { // swiftlint:disable:this function_body_length
    // Use the fork's icon explicitly, even when Launch Services retains an older cached icon.
    if let url = Bundle.main.url(forResource: "SecurePasteIcon", withExtension: "icns"),
       let icon = NSImage(contentsOf: url) {
      NSApp.applicationIconImage = icon
    }
    #if DEBUG
    if Self.isTesting {
      // Start from a clean slate for the isolated testing preferences.
      UserDefaults.standard.removePersistentDomain(forName: Defaults.Keys.testingSuiteName)
    }
    #endif

    // Bridge FloatingPanel via AppDelegate.
    AppState.shared.appDelegate = self

    Clipboard.shared.onNewCopy { History.shared.add($0) }
    Clipboard.shared.start()

    Task {
      for await _ in Defaults.updates(.clipboardCheckInterval, initial: false) {
        Clipboard.shared.restart()
      }
    }

    statusItemVisibilityObserver = observe(\.statusItem.isVisible, options: .new) { _, change in
      if let newValue = change.newValue, Defaults[.showInStatusBar] != newValue {
        Defaults[.showInStatusBar] = newValue
      }
    }

    Task {
      for await value in Defaults.updates(.showInStatusBar) {
        statusItem.isVisible = value
      }
    }

    Task {
      for await value in Defaults.updates(.menuIcon, initial: false) {
        _ = value
        updateSecureStatusItem()
      }
    }

    synchronizeMenuIconText()
    Task {
      for await value in Defaults.updates(.showRecentCopyInMenuBar) {
        if value {
          statusItem.button?.title = AppState.shared.menuIconText
        } else {
          statusItem.button?.title = ""
        }
      }
    }

    updateStatusItemAccessibilityLabel()

    Task {
      for await _ in Defaults.updates(.ignoreEvents) {
        statusItem.button?.appearsDisabled = isStatusItemDisabled
        updateStatusItemAccessibilityLabel()
      }
    }

    Task {
      for await _ in Defaults.updates(.enabledPasteboardTypes) {
        statusItem.button?.appearsDisabled = isStatusItemDisabled
        updateStatusItemAccessibilityLabel()
      }
    }
  }

  func applicationDidFinishLaunching(_ aNotification: Notification) {
    migrateUserDefaults()
    disableUnusedGlobalHotkeys()

    panel = FloatingPanel(
      contentRect: NSRect(origin: .zero, size: Defaults[.windowSize]),
      identifier: Bundle.main.bundleIdentifier ?? "org.p0deje.Maccy",
      statusBarButton: statusItem.button,
      onClose: { AppState.shared.popup.reset() }
    ) {
      ContentView()
    }
    startSecurePaste()
  }

  func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
    panel.toggle(height: AppState.shared.popup.height)
    return true
  }

  func applicationWillTerminate(_ notification: Notification) {
    SecurePasteService.shared.stop()
    if Defaults[.clearOnQuit] {
      AppState.shared.history.clear()
    }
  }

  private func configureSecurePaste() {
    let copy = KeyboardLayout.current.commandSwitchesToQWERTY ? UInt16(8) : Sauce.shared.keyCode(for: .c)
    let paste = KeyboardLayout.current.commandSwitchesToQWERTY ? UInt16(9) : Sauce.shared.keyCode(for: .v)
    SecurePasteService.shared.configure(
      applications: Set(Defaults[.secureApplications]), copyKeyCode: copy, pasteKeyCode: paste
    )
  }

  private func startSecurePaste() {
    guard !isAutomatedTest else { return }
    validatePopupShortcut()
    configureSecurePaste()
    SecurePasteService.shared.start()
    updateSecureStatusItem()
    observeSecureState()
    Task {
      for await _ in Defaults.updates(.secureApplications, initial: false) {
        configureSecurePaste()
      }
    }
    Task {
      for await _ in NotificationCenter.default.notifications(
        named: NSTextInputContext.keyboardSelectionDidChangeNotification
      ) {
        configureSecurePaste()
      }
    }
  }

  private func observeSecureState() {
    _ = withObservationTracking {
      let security = SecurePasteService.shared
      return (security.showsRedIcon, security.showsGreenConfirmation,
              security.isOperational, security.message, security.remainingSeconds)
    } onChange: { [weak self] in
      DispatchQueue.main.async { [weak self] in
        self?.updateSecureStatusItem()
        self?.observeSecureState()
      }
    }
  }

  private func validatePopupShortcut() {
    guard let shortcut = KeyboardShortcuts.getShortcut(for: .popup),
          shortcut.key == .c || shortcut.key == .v,
          shortcut.modifiers == [.command] || shortcut.modifiers == [.command, .shift] else { return }
    KeyboardShortcuts.setShortcut(.init(.h, modifiers: [.control, .option, .command]), for: .popup)
  }

  private func updateSecureStatusItem() {
    let security = SecurePasteService.shared
    if security.showsRedIcon || security.showsGreenConfirmation,
       let image = Defaults[.menuIcon].image.copy() as? NSImage {
      image.isTemplate = false
      image.lockFocus()
      (security.showsGreenConfirmation ? NSColor.systemGreen : NSColor.systemRed).setFill()
      NSRect(origin: .zero, size: image.size).fill(using: .sourceAtop)
      image.unlockFocus()
      statusItem.button?.image = image
      statusItem.button?.appearsDisabled = false
    } else if !security.isOperational && !isAutomatedTest {
      let image = NSImage(systemSymbolName: "exclamationmark.shield.fill", accessibilityDescription: "Protection indisponible")?
        .withSymbolConfiguration(.init(paletteColors: [.systemOrange]))
      image?.isTemplate = false
      statusItem.button?.image = image
      statusItem.button?.appearsDisabled = false
    } else {
      if let image = Defaults[.menuIcon].image.copy() as? NSImage {
        image.isTemplate = false
        image.lockFocus()
        NSColor.secondaryLabelColor.setFill()
        NSRect(origin: .zero, size: image.size).fill(using: .sourceAtop)
        image.unlockFocus()
        statusItem.button?.image = image
      }
      statusItem.button?.appearsDisabled = isStatusItemDisabled
    }
    statusItem.button?.toolTip = "SecurePaste — " + security.message
    updateStatusItemAccessibilityLabel()
  }

  private func ensureMigration(key: String, _ action: () -> Void) {
    if Defaults[.migrations][key] != true {
      action()
      Defaults[.migrations][key] = true
    }
  }

  @MainActor
  private func migrateUserDefaults() {
    ensureMigration(key: "2024-07-01-version-2") {
      // Start 2.x from scratch.
      Defaults.reset(.migrations)

      // Inverse hide* configuration keys.
      Defaults[.showFooter] = !UserDefaults.standard.bool(forKey: "hideFooter")
      Defaults[.showSearch] = !UserDefaults.standard.bool(forKey: "hideSearch")
      Defaults[.showTitle] = !UserDefaults.standard.bool(forKey: "hideTitle")
      UserDefaults.standard.removeObject(forKey: "hideFooter")
      UserDefaults.standard.removeObject(forKey: "hideSearch")
      UserDefaults.standard.removeObject(forKey: "hideTitle")
    }

    ensureMigration(key: "2025-07-04-add-jpeg-heic") {
      var types = Defaults[.enabledPasteboardTypes]
      if !types.isDisjoint(with: StorageType.images.types) {
        types.formUnion(StorageType.images.types)
      }
      Defaults[.enabledPasteboardTypes] = types
    }

    ensureMigration(key: "2026-08-12-cleanup-orphaned-history-item-contents") {
      _ = try? Storage.shared.cleanupOrphanedContents()
    }

    ensureMigration(key: "2026-08-31-sanitize-history-item-titles") {
      _ = try? Storage.shared.sanitizeTitles()
    }

    ensureMigration(key: "2026-09-15-remove-unpersistable-contents") {
      _ = try? Storage.shared.removeUnpersistableContents()
    }

    // The following defaults are not used in Maccy 2.x
    // and should be removed in 3.x.
    // - LaunchAtLogin__hasMigrated
    // - avoidTakingFocus
    // - saratovSeparator
    // - maxMenuItemLength
    // - maxMenuItems
  }

  @objc
  private func performStatusItemClick() {
    if NSApp.currentEvent?.type == .rightMouseUp {
      let menu = NSMenu()
      let status = NSMenuItem(title: SecurePasteService.shared.message, action: nil, keyEquivalent: "")
      menu.addItem(status)
      menu.addItem(.separator())
      let settings = NSMenuItem(title: "Réglages SecurePaste…", action: #selector(openSecureSettings), keyEquivalent: "")
      settings.target = self
      menu.addItem(settings)
      let clear = NSMenuItem(title: "Détruire le secret", action: #selector(clearSecureSecret), keyEquivalent: "")
      clear.target = self
      clear.isEnabled = SecurePasteService.shared.remainingSeconds > 0
      menu.addItem(clear)
      statusItem.menu = menu
      statusItem.button?.performClick(nil)
      statusItem.menu = nil
      return
    }
    let modifierFlags = (NSApp.currentEvent?.modifierFlags ?? [])
      .union(NSEvent.modifierFlags)
      .intersection(.deviceIndependentFlagsMask)

    if modifierFlags.contains(.option) {
      Defaults[.ignoreEvents].toggle()

      if modifierFlags.contains(.shift) {
        Defaults[.ignoreOnlyNextEvent] = Defaults[.ignoreEvents]
      }

      return
    }

    panel.toggle(height: AppState.shared.popup.height, at: .statusItem)
  }

  private func synchronizeMenuIconText() {
    _ = withObservationTracking {
      AppState.shared.menuIconText
    } onChange: {
      DispatchQueue.main.async {
        if Defaults[.showRecentCopyInMenuBar] {
          self.statusItem.button?.title = AppState.shared.menuIconText
        }
        self.synchronizeMenuIconText()
      }
    }
  }

  @objc private func openSecureSettings() {
    AppState.shared.openPreferences()
  }

  @objc private func clearSecureSecret() {
    SecurePasteService.shared.clear()
  }

  private func disableUnusedGlobalHotkeys() {
    let names: [KeyboardShortcuts.Name] = [.delete, .pin, .togglePreview]
    KeyboardShortcuts.disable(names)

    NotificationCenter.default.addObserver(
      forName: Notification.Name("KeyboardShortcuts_shortcutByNameDidChange"),
      object: nil,
      queue: nil
    ) { notification in
      guard let name = notification.userInfo?["name"] as? KeyboardShortcuts.Name else { return }
      MainActor.assumeIsolated {
        if names.contains(name) { KeyboardShortcuts.disable(name) }
        if name == .popup { self.validatePopupShortcut() }
      }
    }
  }
}
