import KeyboardShortcuts

extension KeyboardShortcuts.Name {
  static let popup = Self("popup", initial: Shortcut(.h, modifiers: [.control, .option, .command]))
  static let pin = Self("pin", initial: Shortcut(.p, modifiers: [.option]))
  static let delete = Self("delete", initial: Shortcut(.delete, modifiers: [.option]))
  static let togglePreview = Self("togglePreview", initial: Shortcut(.space, modifiers: [.control]))
}
