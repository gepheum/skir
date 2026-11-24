import Foundation
import SkirClient
import XCTest

final class SerializersTests: XCTestCase {

  // MARK: - Bool

  func testBoolJsonRoundTrip() throws {
    let s = Serializers.bool
    XCTAssertEqual(try s.fromJson(s.toJson(true)), true)
    XCTAssertEqual(try s.fromJson(s.toJson(false)), false)
  }

  func testBoolBinaryRoundTrip() throws {
    let s = Serializers.bool
    XCTAssertEqual(try s.fromBytes(s.toBytes(true)), true)
    XCTAssertEqual(try s.fromBytes(s.toBytes(false)), false)
  }

  // MARK: - Int32

  func testInt32JsonRoundTrip() throws {
    let s = Serializers.int32
    XCTAssertEqual(try s.fromJson(s.toJson(42)), 42)
    XCTAssertEqual(try s.fromJson(s.toJson(-1)), -1)
  }

  func testInt32BinaryRoundTrip() throws {
    let s = Serializers.int32
    XCTAssertEqual(try s.fromBytes(s.toBytes(42)), 42)
    XCTAssertEqual(try s.fromBytes(s.toBytes(-1)), -1)
  }

  // MARK: - Int64

  func testInt64JsonRoundTrip() throws {
    let s = Serializers.int64
    XCTAssertEqual(try s.fromJson(s.toJson(123)), 123)
    // Values within the JS safe integer range are serialized as numbers.
    XCTAssertEqual(try s.fromJson(s.toJson(9_007_199_254_740_991)), 9_007_199_254_740_991)
  }

  func testInt64BinaryRoundTrip() throws {
    let s = Serializers.int64
    XCTAssertEqual(try s.fromBytes(s.toBytes(Int64.max)), Int64.max)
    XCTAssertEqual(try s.fromBytes(s.toBytes(Int64.min)), Int64.min)
  }

  // MARK: - Hash64 (UInt64)

  func testHash64JsonRoundTrip() throws {
    let s = Serializers.hash64
    XCTAssertEqual(try s.fromJson(s.toJson(42)), 42)
  }

  func testHash64BinaryRoundTrip() throws {
    let s = Serializers.hash64
    XCTAssertEqual(try s.fromBytes(s.toBytes(UInt64.max)), UInt64.max)
  }

  // MARK: - Float32

  func testFloat32JsonRoundTrip() throws {
    let s = Serializers.float32
    XCTAssertEqual(try s.fromJson(s.toJson(1.5)), 1.5, accuracy: 1e-6)
  }

  func testFloat32BinaryRoundTrip() throws {
    let s = Serializers.float32
    XCTAssertEqual(try s.fromBytes(s.toBytes(3.14)), 3.14, accuracy: 1e-5)
  }

  // MARK: - Float64

  func testFloat64JsonRoundTrip() throws {
    let s = Serializers.float64
    XCTAssertEqual(try s.fromJson(s.toJson(1.5)), 1.5, accuracy: 1e-15)
  }

  func testFloat64BinaryRoundTrip() throws {
    let s = Serializers.float64
    XCTAssertEqual(try s.fromBytes(s.toBytes(Double.pi)), Double.pi, accuracy: 1e-15)
  }

  // MARK: - Timestamp

  func testTimestampJsonRoundTrip() throws {
    let s = Serializers.timestamp
    let date = Date(timeIntervalSince1970: 1_000_000)
    let result = try s.fromJson(s.toJson(date))
    XCTAssertEqual(result.timeIntervalSince1970, date.timeIntervalSince1970, accuracy: 0.001)
  }

  func testTimestampBinaryRoundTrip() throws {
    let s = Serializers.timestamp
    let date = Date(timeIntervalSince1970: 1_703_984_028)
    let result = try s.fromBytes(s.toBytes(date))
    XCTAssertEqual(result.timeIntervalSince1970, date.timeIntervalSince1970, accuracy: 0.001)
  }

  // MARK: - String

  func testStringJsonRoundTrip() throws {
    let s = Serializers.string
    XCTAssertEqual(try s.fromJson(s.toJson("hello")), "hello")
    XCTAssertEqual(try s.fromJson(s.toJson("")), "")
  }

  func testStringBinaryRoundTrip() throws {
    let s = Serializers.string
    XCTAssertEqual(try s.fromBytes(s.toBytes("hello")), "hello")
  }

  func testStringBinaryDecodeReplacesMalformedUtf8() throws {
    let s = Serializers.string
    let bytes: [UInt8] = [0x73, 0x6B, 0x69, 0x72, 0xF3, 0x02, 0xFF, 0x7A]
    XCTAssertEqual(try s.fromBytes(bytes), "�z")
  }

  // MARK: - Bytes (Data)

  func testBytesJsonRoundTrip() throws {
    let s = Serializers.bytes
    let data = Data([0x01, 0x02, 0x03])
    XCTAssertEqual(try s.fromJson(s.toJson(data)), data)
  }

  func testBytesBinaryRoundTrip() throws {
    let s = Serializers.bytes
    let data = Data([0xDE, 0xAD, 0xBE, 0xEF])
    XCTAssertEqual(try s.fromBytes(s.toBytes(data)), data)
  }

  // MARK: - Array

  func testArrayJsonRoundTrip() throws {
    let s = Serializers.array(Serializers.int32)
    let value: [Int32] = [1, 2, 3]
    XCTAssertEqual(try s.fromJson(s.toJson(value)), value)
  }

  func testArrayBinaryRoundTrip() throws {
    let s = Serializers.array(Serializers.int32)
    let value: [Int32] = [10, 20, 30]
    XCTAssertEqual(try s.fromBytes(s.toBytes(value)), value)
  }

  func testEmptyArrayRoundTrip() throws {
    let s = Serializers.array(Serializers.string)
    XCTAssertEqual(try s.fromJson(s.toJson([])), [])
  }

  // MARK: - Optional

  func testOptionalSomeJsonRoundTrip() throws {
    let s = Serializers.optional(Serializers.int32)
    XCTAssertEqual(try s.fromJson(s.toJson(99)), 99)
  }

  func testOptionalNoneJsonRoundTrip() throws {
    let s = Serializers.optional(Serializers.int32)
    XCTAssertNil(try s.fromJson(s.toJson(nil)))
  }

  func testOptionalBinaryRoundTrip() throws {
    let s = Serializers.optional(Serializers.string)
    XCTAssertEqual(try s.fromBytes(s.toBytes("test")), "test")
    XCTAssertNil(try s.fromBytes(s.toBytes(nil)))
  }
}

// MARK: - Enum name case-compatibility tests

private enum TestColor: Swift.Equatable {
  case unknown(unrecognized: SkirClient.UnrecognizedVariant<TestColor>)
  case red
  case green
  case blue

  static let unknownValue = unknown(unrecognized: nil)

  static func == (lhs: TestColor, rhs: TestColor) -> Bool {
    switch (lhs, rhs) {
    case (.unknown, .unknown): return true
    case (.red, .red): return true
    case (.green, .green): return true
    case (.blue, .blue): return true
    default: return false
    }
  }

  static let _typeAdapter = SkirClient.Internal.EnumAdapter<TestColor>(
    modulePath: "test.skir",
    qualifiedName: "TestColor",
    doc: "",
    defaultValue: unknownValue,
    getKindOrdinal: { input in
      switch input {
      case .unknown: return 0
      case .red: return 1
      case .green: return 2
      case .blue: return 3
      }
    },
    wrapUnrecognized: { unrecognized in .unknown(unrecognized: .some(unrecognized)) },
    getUnrecognized: { input in
      switch input {
      case .unknown(let u): return u
      default: return nil
      }
    }
  )

  static let serializer: SkirClient.Serializer<TestColor> = {
    _typeAdapter.addConstantVariant(name: "red", number: 1, kindOrdinal: 1, doc: "", instance: .red)
    _typeAdapter.addConstantVariant(
      name: "green", number: 2, kindOrdinal: 2, doc: "", instance: .green)
    _typeAdapter.addConstantVariant(
      name: "blue", number: 3, kindOrdinal: 3, doc: "", instance: .blue)
    _typeAdapter.finalize()
    return SkirClient.Serializer(adapter: _typeAdapter)
  }()
}

final class EnumNameCaseCompatibilityTests: XCTestCase {

  // MARK: - Condition 1: serialise using the registered (lower_case) name

  func testSerialisesLowercaseConstantToLowerCaseReadableJson() throws {
    let s = TestColor.serializer
    // toJson returns raw JSON code; for a string enum variant that is "\"red\""
    XCTAssertEqual(s.toJson(.red, readable: true), "\"red\"")
    XCTAssertEqual(s.toJson(.green, readable: true), "\"green\"")
  }

  // MARK: - Condition 2: parse both UPPER_CASE and lower_case names

  func testParsesUpperCaseConstantName() throws {
    let s = TestColor.serializer
    XCTAssertEqual(try s.fromJson("\"RED\""), TestColor.red)
  }

  func testParsesLowerCaseConstantName() throws {
    let s = TestColor.serializer
    XCTAssertEqual(try s.fromJson("\"green\""), TestColor.green)
  }

  func testUpperCaseAndLowerCaseConstantNamesYieldSameResult() throws {
    let s = TestColor.serializer
    XCTAssertEqual(try s.fromJson("\"RED\""), try s.fromJson("\"red\""))
    XCTAssertEqual(try s.fromJson("\"RED\""), TestColor.red)
  }

  func testUnknownUpperAndLowerYieldSameResult() throws {
    let s = TestColor.serializer
    XCTAssertEqual(try s.fromJson("\"UNKNOWN\""), try s.fromJson("\"unknown\""))
    XCTAssertEqual(try s.fromJson("\"unknown\""), TestColor.unknownValue)
  }
}
