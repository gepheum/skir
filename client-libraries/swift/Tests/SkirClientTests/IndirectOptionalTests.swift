import SkirClient
import XCTest

final class IndirectOptionalTests: XCTestCase {

  // MARK: - none

  func testNoneValueIsNil() {
    let v: SkirClient.IndirectOptional<Int> = .none
    XCTAssertNil(v.value)
  }

  func testNilLiteralIsNone() {
    let v: SkirClient.IndirectOptional<Int> = nil
    if case .none = v {} else { XCTFail("expected .none") }
  }

  // MARK: - some

  func testSomeValueIsNotNil() {
    let v: SkirClient.IndirectOptional<Int> = .some(42)
    XCTAssertEqual(v.value, 42)
  }

  func testSomeWrapsCorrectValue() {
    let v = SkirClient.IndirectOptional.some("hello")
    XCTAssertEqual(v.value, "hello")
  }

  // MARK: - Equatable

  func testNoneEqualsNone() {
    let a: SkirClient.IndirectOptional<Int> = .none
    let b: SkirClient.IndirectOptional<Int> = .none
    XCTAssertEqual(a, b)
  }

  func testSomeEqualssSomeWithSameValue() {
    XCTAssertEqual(SkirClient.IndirectOptional.some(7), .some(7))
  }

  func testSomeDoesNotEqualSomeWithDifferentValue() {
    XCTAssertNotEqual(SkirClient.IndirectOptional.some(1), .some(2))
  }

  func testSomeDoesNotEqualNone() {
    XCTAssertNotEqual(SkirClient.IndirectOptional.some(0), .none)
  }

  func testNoneDoesNotEqualSome() {
    let none: SkirClient.IndirectOptional<Int> = .none
    XCTAssertNotEqual(none, .some(0))
  }

  // MARK: - CustomStringConvertible

  func testNoneDescription() {
    let v: SkirClient.IndirectOptional<String> = .none
    XCTAssertEqual(v.description, "nil")
  }

  func testSomeDescription() {
    let v = SkirClient.IndirectOptional.some("world")
    XCTAssertEqual(v.description, "Optional(world)")
  }

  func testSomeDescriptionWithInt() {
    let v = SkirClient.IndirectOptional.some(99)
    XCTAssertEqual(v.description, "Optional(99)")
  }
}
