import XCTest
@testable import Maccy

@MainActor
final class IntentBoundsTests: XCTestCase {
  func testInvalidPositionsDoNotCrashOrAccessHistory() async {
    for number in [Int.min, -1, 0, Int.max] {
      let get = Get()
      get.selected = false
      get.number = number
      do { _ = try await get.perform(); XCTFail("Get accepted an invalid position") } catch {}
      let select = Select()
      select.number = number
      do { _ = try await select.perform(); XCTFail("Select accepted an invalid position") } catch {}
      let delete = Delete()
      delete.number = number
      do { _ = try await delete.perform(); XCTFail("Delete accepted an invalid position") } catch {}
    }
  }
}
