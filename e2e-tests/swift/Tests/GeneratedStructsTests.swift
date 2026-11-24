import XCTest

@testable import e2e_test

final class GeneratedStructsTests: XCTestCase {
  func testDefaultValueHasExpectedZeros() {
    let point = Structs_skir.Point.defaultValue
    XCTAssertEqual(point.x, 0)
    XCTAssertEqual(point.y, 0)
  }

  func testPartialFactorySetsProvidedFieldsOnly() {
    let point = Structs_skir.Point.partial(x: 12)
    XCTAssertEqual(point.x, 12)
    XCTAssertEqual(point.y, 0)
  }

  func testCopyKeepsAndSetsFields() {
    let original = FullName_skir.FullName.partial(firstName: "Ada", lastName: "Lovelace")
    let updated = original.copy(lastName: .set("Byron"))

    XCTAssertEqual(updated.firstName, "Ada")
    XCTAssertEqual(updated.lastName, "Byron")
  }

  func testDescriptionUsesReadableJson() {
    let point = Structs_skir.Point.partial(x: 1, y: 2)
    let description = point.description

    XCTAssertTrue(description.contains("\n"))
    XCTAssertTrue(description.contains("\"x\""))
    XCTAssertTrue(description.contains("\"y\""))
  }

  // MARK: - Serialization

  func testJsonRoundTrip() {
    let point = Structs_skir.Point.partial(x: 42, y: -7)
    let serializer = Structs_skir.Point.serializer
    let json = serializer.toJson(point)
    let decoded = try! serializer.fromJson(json)
    XCTAssertEqual(decoded.x, 42)
    XCTAssertEqual(decoded.y, -7)
  }

  func testBinaryRoundTrip() {
    let point = Structs_skir.Point.partial(x: 100, y: 200)
    let serializer = Structs_skir.Point.serializer
    let bytes = serializer.toBytes(point)
    XCTAssertEqual(bytes[0..<4], [115, 107, 105, 114])  // "skir" magic prefix
    let decoded = try! serializer.fromBytes(bytes)
    XCTAssertEqual(decoded.x, 100)
    XCTAssertEqual(decoded.y, 200)
  }

  func testCompactJsonOmitsFieldNames() {
    let point = Structs_skir.Point.partial(x: 1, y: 2)
    let json = Structs_skir.Point.serializer.toJson(point)
    XCTAssertFalse(json.contains("\"x\""))
    XCTAssertFalse(json.contains("\"y\""))
    XCTAssertFalse(json.contains("\n"))
  }

  func testDefaultValueRoundTrip() {
    let serializer = Structs_skir.Point.serializer
    let bytes = serializer.toBytes(Structs_skir.Point.defaultValue)
    let decoded = try! serializer.fromBytes(bytes)
    XCTAssertEqual(decoded.x, 0)
    XCTAssertEqual(decoded.y, 0)
  }

  // MARK: - Equatable

  func testEqualSameScalarFields() {
    let a = Structs_skir.Point.partial(x: 1, y: 2)
    let b = Structs_skir.Point.partial(x: 1, y: 2)
    XCTAssertEqual(a, b)
  }

  func testNotEqualDifferentScalarField() {
    let a = Structs_skir.Point.partial(x: 1, y: 2)
    let b = Structs_skir.Point.partial(x: 1, y: 99)
    XCTAssertNotEqual(a, b)
  }

  func testEqualNestedStruct() {
    let a = Structs_skir.Triangle.partial(
      color: Structs_skir.Color.partial(r: 1, g: 2, b: 3),
      points: [Structs_skir.Point.partial(x: 0, y: 0)]
    )
    let b = Structs_skir.Triangle.partial(
      color: Structs_skir.Color.partial(r: 1, g: 2, b: 3),
      points: [Structs_skir.Point.partial(x: 0, y: 0)]
    )
    XCTAssertEqual(a, b)
  }

  func testNotEqualNestedStruct() {
    let a = Structs_skir.Triangle.partial(
      color: Structs_skir.Color.partial(r: 1, g: 2, b: 3),
      points: []
    )
    let b = Structs_skir.Triangle.partial(
      color: Structs_skir.Color.partial(r: 9, g: 2, b: 3),
      points: []
    )
    XCTAssertNotEqual(a, b)
  }

  func testDefaultValueEqualsItself() {
    XCTAssertEqual(Structs_skir.Point.defaultValue, Structs_skir.Point.defaultValue)
  }

  func testStructWithKeyedArrayEqualsDifferentInstance() {
    let a = Structs_skir.Items.defaultValue
    let b = Structs_skir.Items.defaultValue
    XCTAssertEqual(a, b)
  }

  func testRecursiveStructBothNilAreEqual() {
    // Both _a_rec are nil → use nil/nil fast path, considered equal
    let a = Structs_skir.RecA.defaultValue
    let b = Structs_skir.RecA.defaultValue
    XCTAssertEqual(a, b)
  }

  func testRecursiveStructOneNonNilNotEqualToDefault() {
    let deepA = Structs_skir.RecA.partial(bool: true)
    let a = Structs_skir.RecA.partial(_a_rec: .some(deepA))
    let b = Structs_skir.RecA.defaultValue  // _a_rec == nil → a == RecA.defaultValue
    // a.a.bool == true  ≠  b.a.bool == false
    XCTAssertNotEqual(a, b)
  }

  func testRecursiveStructSameNestedValueAreEqual() {
    let inner = Structs_skir.RecA.partial(bool: true)
    let a = Structs_skir.RecA.partial(_a_rec: .some(inner))
    let b = Structs_skir.RecA.partial(_a_rec: .some(inner))
    XCTAssertEqual(a, b)
  }
}
