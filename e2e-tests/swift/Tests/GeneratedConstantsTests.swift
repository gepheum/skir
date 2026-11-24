import XCTest

@testable import e2e_test

final class GeneratedConstantsTests: XCTestCase {
  func testOneBool() {
    XCTAssertTrue(Constants_skir.oneBool)
  }

  func testB() {
    XCTAssertFalse(Constants_skir.b)
  }

  func testFooMethod() {
    XCTAssertTrue(Constants_skir.fooMethod)
  }

  func testOneFloat() {
    XCTAssertEqual(Constants_skir.oneFloat, 3.14, accuracy: 1e-5)
  }

  func testOneDouble() {
    XCTAssertEqual(Constants_skir.oneDouble, 3.141592653589793, accuracy: 1e-15)
  }

  func testPi() {
    XCTAssertEqual(Constants_skir.pi, Double.pi, accuracy: 1e-10)
  }

  func testLargeInt64() {
    XCTAssertEqual(Constants_skir.largeInt64, Int64.max)
  }

  func testLargeHash64() {
    XCTAssertEqual(Constants_skir.largeHash64, UInt64.max)
  }

  func testInfinity() {
    XCTAssertEqual(Constants_skir.infinity, Float.infinity)
  }

  func testNegativeInfinity() {
    XCTAssertEqual(Constants_skir.negativeInfinity, -Float.infinity)
  }

  func testNaN() {
    XCTAssertTrue(Constants_skir.nan.isNaN)
  }

  func testOneTimestamp() {
    // 1703984028000 ms = 1703984028 s from Unix epoch (2023-12-31)
    let expected = Date(timeIntervalSince1970: 1_703_984_028.0)
    XCTAssertEqual(
      Constants_skir.oneTimestamp.timeIntervalSince1970,
      expected.timeIntervalSince1970,
      accuracy: 1.0)
  }

  func testOneSingleQuotedString() {
    // The skir source uses single-quoted 'Foo', which maps to the string "Foo"
    XCTAssertTrue(Constants_skir.oneSingleQuotedString.contains("Foo"))
  }

  func testOneConstantIsArray() {
    // ONE_CONSTANT is defined as a JsonValue array in constants.skir
    guard case .array = Constants_skir.oneConstant else {
      XCTFail("Expected .array, got \(Constants_skir.oneConstant)")
      return
    }
  }
}
