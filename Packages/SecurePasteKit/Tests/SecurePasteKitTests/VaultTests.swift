import XCTest
@testable import SecurePasteKit

@MainActor
final class VaultTests: XCTestCase {
  func testGreenConfirmationLastsExactlyOneAndAHalfSeconds() {
    var pulse = SuccessPulse()
    XCTAssertFalse(pulse.isVisible(at: 10))
    pulse.confirm(at: 10)
    XCTAssertTrue(pulse.isVisible(at: 11.499))
    XCTAssertFalse(pulse.isVisible(at: 11.5))
  }

  func testNewActionCancelsGreenConfirmation() {
    var pulse = SuccessPulse()
    pulse.confirm(at: 10)
    pulse.cancel()
    XCTAssertFalse(pulse.isVisible(at: 10.1))
  }

  func testExpiresExactlyAtSixtySeconds() throws {
    var clock = 100.0
    let vault = EphemeralVault(now: { clock })
    try vault.replace(with: "factice", clipboardRevision: 4)
    clock = 159.999
    XCTAssertEqual(vault.remaining(clipboardRevision: 4), 1)
    clock = 160
    XCTAssertThrowsError(try vault.withSecret(clipboardRevision: 4) { $0 })
    clock = 100
    XCTAssertEqual(vault.remaining(clipboardRevision: 4), 0)
  }

  func testClipboardChangeInvalidatesEvenWhenItReturnsToPreviousRevision() throws {
    let vault = EphemeralVault()
    try vault.replace(with: "factice", clipboardRevision: 2)
    XCTAssertEqual(vault.remaining(clipboardRevision: 3), 0)
    XCTAssertThrowsError(try vault.withSecret(clipboardRevision: 2) { $0 })
  }

  func testReplacementAndUnicode() throws {
    let vault = EphemeralVault()
    try vault.replace(with: "ancien", clipboardRevision: 2)
    let expected = "éèà 🔒\nSeconde ligne"
    try vault.replace(with: expected, clipboardRevision: 2)
    XCTAssertEqual(try vault.withSecret(clipboardRevision: 2) { $0 }, expected)
  }

  func testFailedReplacementDestroysPreviousSecret() throws {
    let vault = EphemeralVault()
    try vault.replace(with: "ancien", clipboardRevision: 1)
    XCTAssertThrowsError(try vault.replace(with: "", clipboardRevision: 1))
    XCTAssertEqual(vault.remaining(clipboardRevision: 1), 0)
  }

  func testSizeLimitDestroysPreviousSecret() throws {
    let vault = EphemeralVault()
    try vault.replace(with: "ancien", clipboardRevision: 1)
    XCTAssertThrowsError(try vault.replace(
      with: String(repeating: "a", count: EphemeralVault.maximumBytes + 1), clipboardRevision: 1))
    XCTAssertEqual(vault.remaining(clipboardRevision: 1), 0)
  }

  func testManualDestruction() throws {
    let vault = EphemeralVault()
    try vault.replace(with: "factice", clipboardRevision: 1)
    vault.destroy()
    XCTAssertThrowsError(try vault.withSecret(clipboardRevision: 1) { $0 })
  }

  func testReplacementResetsDeadline() throws {
    var clock = 0.0
    let vault = EphemeralVault(now: { clock })
    try vault.replace(with: "A", clipboardRevision: 1)
    clock = 59
    try vault.replace(with: "B", clipboardRevision: 1)
    clock = 60
    XCTAssertEqual(vault.remaining(clipboardRevision: 1), 59)
  }

  func testRoutesPreserveOrdinaryKeysAndModifiers() {
    func route(_ listed: Bool, _ shift: Bool, _ other: Bool = false,
               _ copy: Bool = true) -> SecureRoute {
      .resolve(command: true, shift: shift, otherModifiers: other,
               isCopy: copy, isPaste: !copy, listed: listed)
    }
    XCTAssertEqual(route(false, false), .ordinary)
    XCTAssertEqual(route(false, false, false, false), .ordinary)
    XCTAssertEqual(route(true, false), .copy)
    XCTAssertEqual(route(true, false, false, false), .paste)
    XCTAssertEqual(route(false, true), .copy)
    XCTAssertEqual(route(false, true, false, false), .paste)
    XCTAssertEqual(route(true, true, true), .ordinary)
    XCTAssertEqual(SecureRoute.resolve(command: false, shift: true, otherModifiers: false,
                                      isCopy: true, isPaste: false, listed: true), .ordinary)
  }
}
