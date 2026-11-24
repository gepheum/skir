import Foundation
import SkirClient
import XCTest

@testable import e2e_test

// Shorthand alias for the generated golden-tests module namespace.
private typealias G = External_Gepheum_SkirGoldenTests_Goldens_skir

// MARK: - Type-erased typed value

/// A type-erased wrapper around any Skir-serializable value.
/// Closure-based so that every operation is available without knowing the concrete type T.
private struct AnyTypedValue {
  let toBytes: () -> [UInt8]
  let toDenseJson: () -> String
  let toReadableJson: () -> String
  let typeDescriptorJson: () -> String
  let fromJsonFn: (_ json: String) -> AnyTypedValue
  let fromBytesFn: (_ bytes: [UInt8]) -> AnyTypedValue

  func fromJson(_ json: String) -> AnyTypedValue { fromJsonFn(json) }
  func fromBytes(_ bytes: [UInt8]) -> AnyTypedValue { fromBytesFn(bytes) }
}

private func makeATV<T>(_ value: T, _ s: SkirClient.Serializer<T>) -> AnyTypedValue {
  AnyTypedValue(
    toBytes: { s.toBytes(value) },
    toDenseJson: { s.toJson(value) },
    toReadableJson: { s.toJson(value, readable: true) },
    typeDescriptorJson: { s.typeDescriptor.asJson() },
    fromJsonFn: { json in makeATV(try! s.fromJson(json), s) },
    fromBytesFn: { bytes in makeATV(try! s.fromBytes(bytes), s) }
  )
}

// MARK: - Expression evaluators

private func evaluateTypedValue(_ tv: G.TypedValue) -> AnyTypedValue {
  switch tv {
  case .bool(let v):
    return makeATV(v, Serializers.bool)
  case .int32(let v):
    return makeATV(v, Serializers.int32)
  case .int64(let v):
    return makeATV(v, Serializers.int64)
  case .hash64(let v):
    return makeATV(v, Serializers.hash64)
  case .float32(let v):
    return makeATV(v, Serializers.float32)
  case .float64(let v):
    return makeATV(v, Serializers.float64)
  case .timestamp(let v):
    return makeATV(v, Serializers.timestamp)
  case .string(let v):
    return makeATV(v, Serializers.string)
  case .bytes(let v):
    return makeATV(v, Serializers.bytes)
  case .boolOptional(let v):
    return makeATV(v, Serializers.optional(Serializers.bool))
  case .ints(let v):
    return makeATV(v, Serializers.array(Serializers.int32))
  case .point(let v):
    return makeATV(v, G.Point.serializer)
  case .color(let v):
    return makeATV(v, G.Color.serializer)
  case .myEnum(let v):
    return makeATV(v, G.MyEnum.serializer)
  case .enumA(let v):
    return makeATV(v, G.EnumA.serializer)
  case .enumB(let v):
    return makeATV(v, G.EnumB.serializer)
  case .keyedArrays(let v):
    return makeATV(v, G.KeyedArrays.serializer)
  case .recStruct(let v):
    return makeATV(v, G.RecStruct.serializer)
  case .recEnum(let v):
    return makeATV(v, G.RecEnum.serializer)
  case .roundTripDenseJson(let inner):
    let a = evaluateTypedValue(inner)
    return a.fromJson(a.toDenseJson())
  case .roundTripReadableJson(let inner):
    let a = evaluateTypedValue(inner)
    return a.fromJson(a.toReadableJson())
  case .roundTripBytes(let inner):
    let a = evaluateTypedValue(inner)
    return a.fromBytes(a.toBytes())
  case .pointFromJsonKeepUnrecognized(let expr):
    return makeATV(
      try! G.Point.serializer.fromJson(evaluateString(expr), keepUnrecognized: true),
      G.Point.serializer)
  case .pointFromJsonDropUnrecognized(let expr):
    return makeATV(
      try! G.Point.serializer.fromJson(evaluateString(expr), keepUnrecognized: false),
      G.Point.serializer)
  case .pointFromBytesKeepUnrecognized(let expr):
    return makeATV(
      try! G.Point.serializer.fromBytes(evaluateBytes(expr), keepUnrecognized: true),
      G.Point.serializer)
  case .pointFromBytesDropUnrecognized(let expr):
    return makeATV(
      try! G.Point.serializer.fromBytes(evaluateBytes(expr), keepUnrecognized: false),
      G.Point.serializer)
  case .colorFromJsonKeepUnrecognized(let expr):
    return makeATV(
      try! G.Color.serializer.fromJson(evaluateString(expr), keepUnrecognized: true),
      G.Color.serializer)
  case .colorFromJsonDropUnrecognized(let expr):
    return makeATV(
      try! G.Color.serializer.fromJson(evaluateString(expr), keepUnrecognized: false),
      G.Color.serializer)
  case .colorFromBytesKeepUnrecognized(let expr):
    return makeATV(
      try! G.Color.serializer.fromBytes(evaluateBytes(expr), keepUnrecognized: true),
      G.Color.serializer)
  case .colorFromBytesDropUnrecognized(let expr):
    return makeATV(
      try! G.Color.serializer.fromBytes(evaluateBytes(expr), keepUnrecognized: false),
      G.Color.serializer)
  case .myEnumFromJsonKeepUnrecognized(let expr):
    return makeATV(
      try! G.MyEnum.serializer.fromJson(evaluateString(expr), keepUnrecognized: true),
      G.MyEnum.serializer)
  case .myEnumFromJsonDropUnrecognized(let expr):
    return makeATV(
      try! G.MyEnum.serializer.fromJson(evaluateString(expr), keepUnrecognized: false),
      G.MyEnum.serializer)
  case .myEnumFromBytesKeepUnrecognized(let expr):
    return makeATV(
      try! G.MyEnum.serializer.fromBytes(evaluateBytes(expr), keepUnrecognized: true),
      G.MyEnum.serializer)
  case .myEnumFromBytesDropUnrecognized(let expr):
    return makeATV(
      try! G.MyEnum.serializer.fromBytes(evaluateBytes(expr), keepUnrecognized: false),
      G.MyEnum.serializer)
  case .enumAFromJsonKeepUnrecognized(let expr):
    return makeATV(
      try! G.EnumA.serializer.fromJson(evaluateString(expr), keepUnrecognized: true),
      G.EnumA.serializer)
  case .enumAFromJsonDropUnrecognized(let expr):
    return makeATV(
      try! G.EnumA.serializer.fromJson(evaluateString(expr), keepUnrecognized: false),
      G.EnumA.serializer)
  case .enumAFromBytesKeepUnrecognized(let expr):
    return makeATV(
      try! G.EnumA.serializer.fromBytes(evaluateBytes(expr), keepUnrecognized: true),
      G.EnumA.serializer)
  case .enumAFromBytesDropUnrecognized(let expr):
    return makeATV(
      try! G.EnumA.serializer.fromBytes(evaluateBytes(expr), keepUnrecognized: false),
      G.EnumA.serializer)
  case .enumBFromJsonKeepUnrecognized(let expr):
    return makeATV(
      try! G.EnumB.serializer.fromJson(evaluateString(expr), keepUnrecognized: true),
      G.EnumB.serializer)
  case .enumBFromJsonDropUnrecognized(let expr):
    return makeATV(
      try! G.EnumB.serializer.fromJson(evaluateString(expr), keepUnrecognized: false),
      G.EnumB.serializer)
  case .enumBFromBytesKeepUnrecognized(let expr):
    return makeATV(
      try! G.EnumB.serializer.fromBytes(evaluateBytes(expr), keepUnrecognized: true),
      G.EnumB.serializer)
  case .enumBFromBytesDropUnrecognized(let expr):
    return makeATV(
      try! G.EnumB.serializer.fromBytes(evaluateBytes(expr), keepUnrecognized: false),
      G.EnumB.serializer)
  case .unknown:
    fatalError("Unknown TypedValue variant encountered in golden test")
  }
}

private func evaluateString(_ expr: G.StringExpression) -> String {
  switch expr {
  case .literal(let s):
    return s
  case .toDenseJson(let tv):
    return evaluateTypedValue(tv).toDenseJson()
  case .toReadableJson(let tv):
    return evaluateTypedValue(tv).toReadableJson()
  case .unknown:
    fatalError("Unknown StringExpression variant encountered in golden test")
  }
}

private func evaluateBytes(_ expr: G.BytesExpression) -> [UInt8] {
  switch expr {
  case .literal(let data):
    return Array(data)
  case .toBytes(let tv):
    return evaluateTypedValue(tv).toBytes()
  case .unknown:
    fatalError("Unknown BytesExpression variant encountered in golden test")
  }
}

private func toHex(_ bytes: [UInt8]) -> String {
  bytes.map { String(format: "%02x", $0) }.joined()
}

// MARK: - Test class

final class GeneratedGoldensTests: XCTestCase {

  func testGoldens() {
    let tests = G.unitTests
    XCTAssertFalse(tests.isEmpty, "unitTests should not be empty")
    for (i, unitTest) in tests.enumerated() {
      let testNum = unitTest.testNumber
      if i > 0 {
        XCTAssertEqual(
          testNum, tests[i - 1].testNumber + 1,
          "Test numbers are not consecutive at index \(i)"
        )
      }
      verifyAssertion(unitTest.assertion, testNum: testNum)
    }
  }

  // MARK: - Assertion dispatch

  private func verifyAssertion(_ assertion: G.Assertion, testNum: Int32) {
    switch assertion {
    case .bytesEqual(let v):
      let actual = toHex(evaluateBytes(v.actual))
      let expected = toHex(evaluateBytes(v.expected))
      XCTAssertEqual(actual, expected, "test \(testNum): bytesEqual failed")
    case .bytesIn(let v):
      let actual = toHex(evaluateBytes(v.actual))
      XCTAssertTrue(
        v.expected.contains { toHex(Array($0)) == actual },
        "test \(testNum): bytesIn failed, actual=\(actual)"
      )
    case .stringEqual(let v):
      XCTAssertEqual(
        evaluateString(v.actual), evaluateString(v.expected),
        "test \(testNum): stringEqual failed"
      )
    case .stringIn(let v):
      let actual = evaluateString(v.actual)
      XCTAssertTrue(
        v.expected.contains(actual),
        "test \(testNum): stringIn failed, actual=\(actual)"
      )
    case .reserializeValue(let v):
      verifyReserializeValue(v, testNum: testNum)
    case .reserializeLargeString(let v):
      verifyReserializeLargeString(v, testNum: testNum)
    case .reserializeLargeArray(let v):
      verifyReserializeLargeArray(v, testNum: testNum)
    case .enumAFromJsonIsConstant(let v):
      verifyEnumAFromJsonIsConstant(v, testNum: testNum)
    case .enumAFromBytesIsConstant(let v):
      verifyEnumAFromBytesIsConstant(v, testNum: testNum)
    case .enumBFromJsonIsWrapperB(let v):
      verifyEnumBFromJsonIsWrapperB(v, testNum: testNum)
    case .enumBFromBytesIsWrapperB(let v):
      verifyEnumBFromBytesIsWrapperB(v, testNum: testNum)
    case .unknown:
      XCTFail("test \(testNum): unknown assertion type")
    }
  }

  private func verifyEnumAFromJsonIsConstant(
    _ input: G.Assertion.EnumAFromJsonIsConstant, testNum: Int32
  ) {
    let enumA = try! G.EnumA.serializer.fromJson(
      evaluateString(input.actual), keepUnrecognized: input.keepUnrecognized)
    switch enumA {
    case .a:
      break
    default:
      XCTFail("test \(testNum): expected EnumA.A constant")
    }
  }

  private func verifyEnumAFromBytesIsConstant(
    _ input: G.Assertion.EnumAFromBytesIsConstant, testNum: Int32
  ) {
    let enumA = try! G.EnumA.serializer.fromBytes(
      evaluateBytes(input.actual), keepUnrecognized: input.keepUnrecognized)
    switch enumA {
    case .a:
      break
    default:
      XCTFail("test \(testNum): expected EnumA.A constant")
    }
  }

  private func verifyEnumBFromJsonIsWrapperB(
    _ input: G.Assertion.EnumBFromJsonIsWrapperB, testNum: Int32
  ) {
    let enumB = try! G.EnumB.serializer.fromJson(
      evaluateString(input.actual), keepUnrecognized: input.keepUnrecognized)
    switch enumB {
    case .b(let value):
      XCTAssertEqual(value, input.expected, "test \(testNum): EnumB.b value mismatch")
    default:
      XCTFail("test \(testNum): expected EnumB.b wrapper")
    }
  }

  private func verifyEnumBFromBytesIsWrapperB(
    _ input: G.Assertion.EnumBFromBytesIsWrapperB, testNum: Int32
  ) {
    let enumB = try! G.EnumB.serializer.fromBytes(
      evaluateBytes(input.actual), keepUnrecognized: input.keepUnrecognized)
    switch enumB {
    case .b(let value):
      XCTAssertEqual(value, input.expected, "test \(testNum): EnumB.b value mismatch")
    default:
      XCTFail("test \(testNum): expected EnumB.b wrapper")
    }
  }

  // MARK: - reserializeValue

  private func verifyReserializeValue(
    _ input: G.Assertion.ReserializeValue, testNum: Int32
  ) {
    let atv = evaluateTypedValue(input.value)
    // Verify the original value and three round-trip variations.
    for v in [
      atv, atv.fromJson(atv.toDenseJson()),
      atv.fromJson(atv.toReadableJson()),
      atv.fromBytes(atv.toBytes()),
    ] {
      verifyReserializeSingle(v, input: input, testNum: testNum)
    }
  }

  private func verifyReserializeSingle(
    _ atv: AnyTypedValue,
    input: G.Assertion.ReserializeValue,
    testNum: Int32
  ) {
    if !input.expectedDenseJson.isEmpty {
      let denseJson = atv.toDenseJson()
      XCTAssertTrue(
        input.expectedDenseJson.contains(denseJson),
        "test \(testNum): denseJson '\(denseJson)' not in \(input.expectedDenseJson)"
      )
      // Each alternative JSON must round-trip back to the same canonical dense JSON.
      for altExpr in input.alternativeJsons {
        let altJson = evaluateString(altExpr)
        XCTAssertEqual(
          atv.fromJson(altJson).toDenseJson(), denseJson,
          "test \(testNum): alt JSON '\(altJson)' round-tripped to wrong denseJson"
        )
      }
    }
    if !input.expectedReadableJson.isEmpty {
      let readableJson = atv.toReadableJson()
      XCTAssertTrue(
        input.expectedReadableJson.contains(readableJson),
        "test \(testNum): readableJson not in expectedReadableJson"
      )
    }
    if !input.expectedBytes.isEmpty {
      let bytesHex = toHex(atv.toBytes())
      XCTAssertTrue(
        input.expectedBytes.contains { toHex(Array($0)) == bytesHex },
        "test \(testNum): bytes '\(bytesHex)' not found in expectedBytes"
      )
      // Each alternative bytes encoding must round-trip back to the canonical dense JSON.
      if !input.expectedDenseJson.isEmpty {
        let denseJson = atv.toDenseJson()
        for altExpr in input.alternativeBytes {
          let altBytes = evaluateBytes(altExpr)
          XCTAssertEqual(
            atv.fromBytes(altBytes).toDenseJson(), denseJson,
            "test \(testNum): alt bytes round-tripped to wrong denseJson"
          )
        }
      }
    }
    if let expectedTd = input.expectedTypeDescriptor {
      let actualTd = atv.typeDescriptorJson()
      XCTAssertEqual(actualTd, expectedTd, "test \(testNum): type descriptor mismatch")
      let reparsedTd = try! Reflection.TypeDescriptor.parseFromJson(actualTd).asJson()
      XCTAssertEqual(
        reparsedTd, actualTd,
        "test \(testNum): TypeDescriptor.parseFromJson round-trip failed"
      )
    }
  }

  // MARK: - reserializeLargeString / reserializeLargeArray

  private func verifyReserializeLargeString(
    _ input: G.Assertion.ReserializeLargeString, testNum: Int32
  ) {
    let str = String(repeating: "a", count: Int(input.numChars))
    let serializer = SkirClient.Serializers.string
    let bytes = serializer.toBytes(str)
    let decoded = try! serializer.fromBytes(bytes)
    XCTAssertEqual(decoded, str, "test \(testNum): large string round-trip failed")
    let reBytes = serializer.toBytes(decoded)
    let expectedPrefix = Array(input.expectedBytePrefix)
    XCTAssertTrue(
      reBytes.count >= expectedPrefix.count
        && Array(reBytes.prefix(expectedPrefix.count)) == expectedPrefix,
      "test \(testNum): large string byte prefix mismatch"
    )
  }

  private func verifyReserializeLargeArray(
    _ input: G.Assertion.ReserializeLargeArray, testNum: Int32
  ) {
    let arr = [Int32](repeating: 1, count: Int(input.numItems))
    let serializer = SkirClient.Serializers.array(Serializers.int32)
    let bytes = serializer.toBytes(arr)
    let decoded = try! serializer.fromBytes(bytes)
    XCTAssertEqual(decoded, arr, "test \(testNum): large array round-trip failed")
    let reBytes = serializer.toBytes(decoded)
    let expectedPrefix = Array(input.expectedBytePrefix)
    XCTAssertTrue(
      reBytes.count >= expectedPrefix.count
        && Array(reBytes.prefix(expectedPrefix.count)) == expectedPrefix,
      "test \(testNum): large array byte prefix mismatch"
    )
  }
}
