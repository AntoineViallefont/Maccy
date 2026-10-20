struct SuccessPulse {
  private var deadline: Double?

  mutating func confirm(at time: Double) { deadline = time + 1.5 }
  mutating func cancel() { deadline = nil }
  func isVisible(at time: Double) -> Bool { deadline.map { time < $0 } ?? false }
}
