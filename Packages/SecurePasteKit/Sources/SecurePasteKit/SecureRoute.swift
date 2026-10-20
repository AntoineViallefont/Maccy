import Foundation

enum SecureRoute: Equatable {
  case copy, paste, ordinary

  static func resolve(command: Bool, shift: Bool, otherModifiers: Bool,
                      isCopy: Bool, isPaste: Bool, listed: Bool) -> Self {
    guard command, !otherModifiers, shift || listed else { return .ordinary }
    if isCopy { return .copy }
    if isPaste { return .paste }
    return .ordinary
  }
}
