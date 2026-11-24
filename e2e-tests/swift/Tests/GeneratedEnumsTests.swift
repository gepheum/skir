import XCTest

@testable import e2e_test

final class GeneratedEnumsTests: XCTestCase {
  func testUnknownValueKindIsUnknown() {
    XCTAssertEqual(Enums_skir.Weekday.unknownValue.kind, .unknown)
  }

  func testWeekdayDescriptionUsesReadableJson() {
    let description = Enums_skir.Weekday.monday.description
    XCTAssertTrue(description.contains("MONDAY") || description.contains("monday"))
  }

  func testWrapperEnumDescriptionContainsKindAndValue() {
    let value = Enums_skir.JsonValue.boolean(true)
    let description = value.description

    XCTAssertTrue(description.contains("\"kind\""))
    XCTAssertTrue(description.contains("\"value\""))
  }

  // MARK: - Serialization

  func testWeekdayJsonRoundTrip() {
    let day = Enums_skir.Weekday.friday
    let serializer = Enums_skir.Weekday.serializer
    let json = serializer.toJson(day)
    let decoded = try! serializer.fromJson(json)
    XCTAssertEqual(decoded.kind, .friday)
  }

  func testWeekdayBinaryRoundTrip() {
    let day = Enums_skir.Weekday.wednesday
    let serializer = Enums_skir.Weekday.serializer
    let bytes = serializer.toBytes(day)
    XCTAssertEqual(bytes[0..<4], [115, 107, 105, 114])  // "skir" magic prefix
    let decoded = try! serializer.fromBytes(bytes)
    XCTAssertEqual(decoded.kind, .wednesday)
  }

  func testUnknownWeekdayRoundTrip() {
    // Deserializing an unrecognized ordinal should produce an unknown value
    let decoded = try! Enums_skir.Weekday.serializer.fromJson("999")
    XCTAssertEqual(decoded.kind, .unknown)
  }

  func testWrapperEnumJsonRoundTrip() {
    let value = Enums_skir.JsonValue.number(2.71828)
    let serializer = Enums_skir.JsonValue.serializer
    let json = serializer.toJson(value)
    let decoded = try! serializer.fromJson(json)
    guard case .number(let n) = decoded else {
      XCTFail("Expected .number, got \(decoded)")
      return
    }
    XCTAssertEqual(n, 2.71828, accuracy: 1e-10)
  }

  func testWrapperEnumBinaryRoundTrip() {
    let value = Enums_skir.JsonValue.string("hello")
    let serializer = Enums_skir.JsonValue.serializer
    let bytes = serializer.toBytes(value)
    let decoded = try! serializer.fromBytes(bytes)
    guard case .string(let s) = decoded else {
      XCTFail("Expected .string, got \(decoded)")
      return
    }
    XCTAssertEqual(s, "hello")
  }

  // MARK: - Equatable

  func testSameConstantVariantAreEqual() {
    XCTAssertEqual(Enums_skir.Weekday.monday, Enums_skir.Weekday.monday)
  }

  func testDifferentConstantVariantsAreNotEqual() {
    XCTAssertNotEqual(Enums_skir.Weekday.monday, Enums_skir.Weekday.friday)
  }

  func testSameWrapperVariantWithSameValueAreEqual() {
    XCTAssertEqual(Enums_skir.JsonValue.boolean(true), Enums_skir.JsonValue.boolean(true))
  }

  func testSameWrapperVariantWithDifferentValuesAreNotEqual() {
    XCTAssertNotEqual(Enums_skir.JsonValue.boolean(true), Enums_skir.JsonValue.boolean(false))
  }

  func testDifferentVariantsAreNotEqual() {
    XCTAssertNotEqual(Enums_skir.JsonValue.boolean(true), Enums_skir.JsonValue.number(1.0))
  }

  func testBothUnknownValueAreEqual() {
    XCTAssertEqual(Enums_skir.Weekday.unknownValue, Enums_skir.Weekday.unknownValue)
  }

  func testUnknownValueNotEqualToKnownVariant() {
    XCTAssertNotEqual(Enums_skir.Weekday.unknownValue, Enums_skir.Weekday.monday)
  }

  func testUnknownWithSameDataAreEqual() {
    // Two values decoded from the same JSON produce equal unknown variants
    let a = try! Enums_skir.Weekday.serializer.fromJson("999")
    let b = try! Enums_skir.Weekday.serializer.fromJson("999")
    XCTAssertEqual(a, b)
  }

  func testUnknownVariantsAreAlwaysEqual() {
    // Unrecognized data is not compared — any two .unknown values are equal
    let a = try! Enums_skir.Weekday.serializer.fromJson("999")
    let b = try! Enums_skir.Weekday.serializer.fromJson("888")
    XCTAssertEqual(a, b)
  }

  func testWrapperVariantWithNestedStructAreEqual() {
    let s1 = Enums_skir.EnumWithStructField.s(
      Enums_skir.EnumWithStructField.S.partial(x: 1.0, y: 2.0)
    )
    let s2 = Enums_skir.EnumWithStructField.s(
      Enums_skir.EnumWithStructField.S.partial(x: 1.0, y: 2.0)
    )
    XCTAssertEqual(s1, s2)
  }

  func testWrapperVariantWithDifferentNestedStructAreNotEqual() {
    let s1 = Enums_skir.EnumWithStructField.s(
      Enums_skir.EnumWithStructField.S.partial(x: 1.0, y: 2.0)
    )
    let s2 = Enums_skir.EnumWithStructField.s(
      Enums_skir.EnumWithStructField.S.partial(x: 9.0, y: 2.0)
    )
    XCTAssertNotEqual(s1, s2)
  }

  // MARK: - Switch

  func testSwitchOnWeekday() {
    func isWeekend(_ day: Enums_skir.Weekday) -> Bool {
      switch day {
      case .saturday, .sunday:
        return true
      case .monday, .tuesday, .wednesday, .thursday, .friday:
        return false
      case .unknown:
        return false
      }
    }

    XCTAssertTrue(isWeekend(.saturday))
    XCTAssertTrue(isWeekend(.sunday))
    XCTAssertFalse(isWeekend(.monday))
    XCTAssertFalse(isWeekend(.friday))
    XCTAssertFalse(isWeekend(.unknownValue))
  }

  func testSwitchOnWrapperEnum() {
    func describe(_ v: Enums_skir.JsonValue) -> String {
      switch v {
      case .null:
        return "null"
      case .boolean(let b):
        return "bool(\(b))"
      case .number(let n):
        return "number(\(n))"
      case .string(let s):
        return "string(\(s))"
      case .array(let arr):
        return "array(\(arr.count) items)"
      case .object(let obj):
        return "object(\(obj.count) pairs)"
      case .unknown:
        return "unknown"
      }
    }

    XCTAssertEqual(describe(.null), "null")
    XCTAssertEqual(describe(.boolean(true)), "bool(true)")
    XCTAssertEqual(describe(.number(3.14)), "number(3.14)")
    XCTAssertEqual(describe(.string("hi")), "string(hi)")
    XCTAssertEqual(describe(.array([.null, .boolean(false)])), "array(2 items)")
    XCTAssertEqual(describe(.unknownValue), "unknown")
  }
}
