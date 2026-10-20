import CryptoKit
import Darwin
import Foundation

/// Internal to the security module. No persistence, logging or history dependency.
@MainActor
final class EphemeralVault {
  enum Failure: Error { case empty, tooLarge, unavailable }
  private struct Entry {
    let box: AES.GCM.SealedBox
    let key: SymmetricKey
    let deadline: TimeInterval
    let clipboardRevision: Int
  }

  private var entry: Entry?
  private let now: () -> TimeInterval
  static let lifetime: TimeInterval = 60
  static let maximumBytes = 1_048_576

  init(now: @escaping () -> TimeInterval = continuousSeconds) {
    self.now = now
  }

  func replace(with text: String, clipboardRevision: Int) throws {
    destroy()
    guard !text.isEmpty else { throw Failure.empty }
    guard text.utf8.count <= Self.maximumBytes else { throw Failure.tooLarge }
    var bytes = Data(text.utf8)
    defer { bytes.resetBytes(in: bytes.startIndex..<bytes.endIndex) }
    let key = SymmetricKey(size: .bits256)
    let box = try AES.GCM.seal(bytes, using: key)
    entry = Entry(box: box, key: key, deadline: now() + Self.lifetime,
                  clipboardRevision: clipboardRevision)
  }

  func remaining(clipboardRevision: Int) -> Int {
    guard let entry else { return 0 }
    let interval = entry.deadline - now()
    guard interval > 0, entry.clipboardRevision == clipboardRevision else {
      destroy()
      return 0
    }
    return Int(ceil(interval))
  }

  // The clear text never crosses the module's public API.
  func withSecret<T>(clipboardRevision: Int, _ body: (String) throws -> T) throws -> T {
    guard remaining(clipboardRevision: clipboardRevision) > 0, let entry else {
      throw Failure.unavailable
    }
    var bytes = try AES.GCM.open(entry.box, using: entry.key)
    defer { bytes.resetBytes(in: bytes.startIndex..<bytes.endIndex) }
    guard let text = String(data: bytes, encoding: .utf8) else {
      destroy()
      throw Failure.unavailable
    }
    return try body(text)
  }

  func destroy() {
    // Logical invalidation. Swift/CryptoKit cannot guarantee physical erasure of every copy.
    entry = nil
  }
}

func continuousSeconds() -> TimeInterval {
  var info = mach_timebase_info_data_t()
  mach_timebase_info(&info)
  return Double(mach_continuous_time()) * Double(info.numer) / Double(info.denom) / 1_000_000_000
}
