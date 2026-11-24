import XCTest

@testable import e2e_test

final class GeneratedUnambiguousAliasesTests: XCTestCase {
  func testWorks() {
    let _ = Skir.AddUser
    let _ = Skir.AIDecisionTree.fleeAction("foo")
    let _ = Skir.pi
  }
}
