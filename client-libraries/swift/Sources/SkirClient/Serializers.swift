import CoreFoundation
import Foundation

public enum Serializers {
  public static let bool = Serializer<Bool>(adapter: BoolAdapter())

  public static let int32 = Serializer<Int32>(adapter: Int32Adapter())

  public static let int64 = Serializer<Int64>(adapter: Int64Adapter())

  public static let hash64 = Serializer<UInt64>(adapter: Hash64Adapter())

  public static let float32 = Serializer<Float>(adapter: Float32Adapter())

  public static let float64 = Serializer<Double>(adapter: Float64Adapter())

  public static let timestamp = Serializer<Foundation.Date>(adapter: TimestampAdapter())

  public static let string = Serializer<String>(adapter: StringAdapter())

  public static let bytes = Serializer<Foundation.Data>(adapter: BytesAdapter())

  public static func array<Element>(
    _ item: Serializer<Element>,
  ) -> Serializer<[Element]> {
    Serializer<[Element]>(
      adapter: ArrayAdapter(item: item.adapter)
    )
  }

  public static func optional<Wrapped>(
    _ other: Serializer<Wrapped>
  ) -> Serializer<Wrapped?> {
    Serializer<Wrapped?>(adapter: OptionalAdapter(other: other.adapter))
  }

  public static func keyedArray<Spec: KeyedArraySpec>(
    _ item: Serializer<Spec.Item>
  ) -> Serializer<KeyedArray<Spec>> {
    Serializer<KeyedArray<Spec>>(
      adapter: KeyedArrayAdapter<Spec>(item: item.adapter)
    )
  }

  public static func recursiveSerializer<Wrapped>(
    _ other: Serializer<Wrapped>
  ) -> Serializer<IndirectOptional<Wrapped>> {
    Serializer<IndirectOptional<Wrapped>>(
      adapter: RecursiveAdapter(other: other.adapter)
    )
  }

  public static func indirectOptionalSerializer<Wrapped>(
    _ other: Serializer<Wrapped>
  ) -> Serializer<IndirectOptional<Wrapped>> {
    Serializer<IndirectOptional<Wrapped>>(
      adapter: OptionBoxAdapter(other: other.adapter)
    )
  }
}

public enum Internal {
  public static func recursiveSerializer<Wrapped>(
    _ other: Serializer<Wrapped>
  ) -> Serializer<IndirectOptional<Wrapped>> {
    Serializers.recursiveSerializer(other)
  }

  public static func indirectOptionalSerializer<Wrapped>(
    _ other: Serializer<Wrapped>
  ) -> Serializer<IndirectOptional<Wrapped>> {
    Serializers.indirectOptionalSerializer(other)
  }
}

private let maxSafeInt64Json: Int64 = 9_007_199_254_740_991
private let maxSafeHash64Json: UInt64 = 9_007_199_254_740_991
private let minTimestampMillis: Int64 = -8_640_000_000_000_000
private let maxTimestampMillis: Int64 = 8_640_000_000_000_000

private let iso8601Formatter: ISO8601DateFormatter = {
  let formatter = ISO8601DateFormatter()
  formatter.timeZone = TimeZone(secondsFromGMT: 0)
  formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
  return formatter
}()

private func isJsonBool(_ value: Any) -> Bool {
  guard let number = value as? NSNumber else {
    return value is Bool
  }
  return CFGetTypeID(number) == CFBooleanGetTypeID()
}

private func jsonNumber(_ value: Any) -> NSNumber? {
  guard let number = value as? NSNumber, !isJsonBool(value) else {
    return nil
  }
  return number
}

private func asJsonDouble(_ value: Any) -> Double? {
  jsonNumber(value)?.doubleValue
}

private func asJsonUInt64(_ value: Any) -> UInt64? {
  guard let number = jsonNumber(value) else {
    return nil
  }
  if number.doubleValue < 0 {
    return nil
  }
  return number.uint64Value
}

private func schemaError(_ message: String) -> SkirError {
  SkirError(message)
}

private func clampTruncatingInt64(_ value: Double) -> Int64 {
  if value.isNaN {
    return 0
  }
  let truncated = value.rounded(.towardZero)
  if truncated >= Double(Int64.max) {
    return Int64.max
  }
  if truncated <= Double(Int64.min) {
    return Int64.min
  }
  return Int64(truncated)
}

private func clampRoundedInt64(_ value: Double) -> Int64 {
  if value.isNaN {
    return 0
  }
  let rounded = value.rounded()
  if rounded >= Double(Int64.max) {
    return Int64.max
  }
  if rounded <= Double(Int64.min) {
    return Int64.min
  }
  return Int64(rounded)
}

private func clampTruncatingInt32(_ value: Double) -> Int32 {
  if value.isNaN {
    return 0
  }
  let truncated = value.rounded(.towardZero)
  if truncated >= Double(Int32.max) {
    return Int32.max
  }
  if truncated <= Double(Int32.min) {
    return Int32.min
  }
  return Int32(truncated)
}

private func clampRoundedUInt64(_ value: Double) -> UInt64 {
  if value.isNaN || value <= 0 {
    return 0
  }
  let rounded = value.rounded()
  if rounded >= Double(UInt64.max) {
    return UInt64.max
  }
  return UInt64(rounded)
}

private func takeBytes(
  _ count: Int,
  from input: inout [UInt8],
  errorMessage: String = "unexpected end of input"
) throws -> [UInt8] {
  guard input.count >= count else {
    throw schemaError(errorMessage)
  }
  let bytes = Array(input.prefix(count))
  input.removeFirst(count)
  return bytes
}

internal func readU8(_ input: inout [UInt8]) throws -> UInt8 {
  guard let byte = input.first else {
    throw schemaError("unexpected end of input")
  }
  input.removeFirst()
  return byte
}

private func readU16(_ input: inout [UInt8]) throws -> UInt16 {
  let bytes = try takeBytes(2, from: &input)
  return UInt16(bytes[0]) | (UInt16(bytes[1]) << 8)
}

private func readU32(_ input: inout [UInt8]) throws -> UInt32 {
  let bytes = try takeBytes(4, from: &input)
  return UInt32(bytes[0])
    | (UInt32(bytes[1]) << 8)
    | (UInt32(bytes[2]) << 16)
    | (UInt32(bytes[3]) << 24)
}

private func readI32(_ input: inout [UInt8]) throws -> Int32 {
  Int32(bitPattern: try readU32(&input))
}

private func readU64(_ input: inout [UInt8]) throws -> UInt64 {
  let bytes = try takeBytes(8, from: &input)
  return UInt64(bytes[0])
    | (UInt64(bytes[1]) << 8)
    | (UInt64(bytes[2]) << 16)
    | (UInt64(bytes[3]) << 24)
    | (UInt64(bytes[4]) << 32)
    | (UInt64(bytes[5]) << 40)
    | (UInt64(bytes[6]) << 48)
    | (UInt64(bytes[7]) << 56)
}

private func readI64(_ input: inout [UInt8]) throws -> Int64 {
  Int64(bitPattern: try readU64(&input))
}

private func readFloat32(_ input: inout [UInt8]) throws -> Float {
  Float(bitPattern: try readU32(&input))
}

private func readFloat64(_ input: inout [UInt8]) throws -> Double {
  Double(bitPattern: try readU64(&input))
}

internal func decodeNumberBody(_ wire: UInt8, input: inout [UInt8]) throws -> Int64 {
  switch wire {
  case 0...231:
    return Int64(wire)
  case 232:
    return Int64(try readU16(&input))
  case 233:
    return Int64(try readU32(&input))
  case 234:
    return Int64(bitPattern: try readU64(&input))
  case 235:
    return Int64(try readU8(&input)) - 256
  case 236:
    return Int64(try readU16(&input)) - 65_536
  case 237:
    return Int64(try readI32(&input))
  case 238, 239:
    return try readI64(&input)
  case 240:
    return clampTruncatingInt64(Double(try readFloat32(&input)))
  case 241:
    return clampTruncatingInt64(try readFloat64(&input))
  default:
    return 0
  }
}

internal func decodeNumber(_ input: inout [UInt8]) throws -> Int64 {
  try decodeNumberBody(readU8(&input), input: &input)
}

private func appendLittleEndian<T: FixedWidthInteger>(_ value: T, to out: inout [UInt8]) {
  let byteCount = MemoryLayout<T>.size
  let unsignedValue = UInt64(truncatingIfNeeded: value)
  for shift in 0..<byteCount {
    out.append(UInt8((unsignedValue >> (shift * 8)) & 0xff))
  }
}

private func appendLittleEndian(_ value: Float, to out: inout [UInt8]) {
  appendLittleEndian(value.bitPattern, to: &out)
}

private func appendLittleEndian(_ value: Double, to out: inout [UInt8]) {
  appendLittleEndian(value.bitPattern, to: &out)
}

internal func encodeInt32(_ value: Int32, out: inout [UInt8]) {
  switch value {
  case Int32.min ... -65_537:
    out.append(237)
    appendLittleEndian(value, to: &out)
  case -65_536 ... -257:
    out.append(236)
    appendLittleEndian(UInt16(truncatingIfNeeded: value), to: &out)
  case -256 ... -1:
    out.append(235)
    out.append(UInt8(truncatingIfNeeded: value))
  case 0...231:
    out.append(UInt8(value))
  case 232...65_535:
    out.append(232)
    appendLittleEndian(UInt16(value), to: &out)
  default:
    out.append(233)
    appendLittleEndian(UInt32(bitPattern: value), to: &out)
  }
}

internal func encodeUInt32(_ value: UInt32, out: inout [UInt8]) {
  switch value {
  case 0...231:
    out.append(UInt8(value))
  case 232...65_535:
    out.append(232)
    appendLittleEndian(UInt16(value), to: &out)
  default:
    out.append(233)
    appendLittleEndian(value, to: &out)
  }
}

private func systemTimeToMillis(_ date: Foundation.Date) -> Int64 {
  let millis = Int64((date.timeIntervalSince1970 * 1000).rounded())
  return min(max(millis, minTimestampMillis), maxTimestampMillis)
}

private func millisToSystemTime(_ millis: Int64) -> Foundation.Date {
  let clamped = min(max(millis, minTimestampMillis), maxTimestampMillis)
  return Foundation.Date(timeIntervalSince1970: Double(clamped) / 1000)
}

private func millisToIso8601(_ millis: Int64) -> String {
  iso8601Formatter.string(from: millisToSystemTime(millis))
}

internal func writeJsonEscapedString(_ string: String, out: inout String) {
  out.append("\"")
  for scalar in string.unicodeScalars {
    switch scalar.value {
    case 0x22:
      out.append("\\\"")
    case 0x5C:
      out.append("\\\\")
    case 0x0A:
      out.append("\\n")
    case 0x0D:
      out.append("\\r")
    case 0x09:
      out.append("\\t")
    case 0x08:
      out.append("\\b")
    case 0x0C:
      out.append("\\f")
    case 0x00...0x1F, 0x7F:
      out.append(String(format: "\\u%04x", scalar.value))
    default:
      out.append(String(scalar))
    }
  }
  out.append("\"")
}

private func encodeBase64(_ data: Foundation.Data) -> String {
  data.base64EncodedString()
}

private func decodeBase64(_ string: String) throws -> Foundation.Data {
  let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
  let remainder = trimmed.count % 4
  let padded = remainder == 0 ? trimmed : trimmed + String(repeating: "=", count: 4 - remainder)
  guard let data = Foundation.Data(base64Encoded: padded) else {
    throw schemaError("invalid base64 data")
  }
  return data
}

private func encodeHex(_ data: Foundation.Data) -> String {
  data.map { String(format: "%02x", $0) }.joined()
}

private func decodeHex(_ string: String) throws -> Foundation.Data {
  guard string.count.isMultiple(of: 2) else {
    throw schemaError("odd hex string length: \(string.count)")
  }

  var bytes: [UInt8] = []
  bytes.reserveCapacity(string.count / 2)
  var index = string.startIndex
  while index < string.endIndex {
    let nextIndex = string.index(index, offsetBy: 2)
    guard let value = UInt8(string[index..<nextIndex], radix: 16) else {
      throw schemaError("invalid hex data")
    }
    bytes.append(value)
    index = nextIndex
  }
  return Foundation.Data(bytes)
}

internal func skipValue(_ input: inout [UInt8]) throws {
  let wire = try readU8(&input)
  switch wire {
  case 0...231, 242, 244, 246, 255:
    return
  case 232, 236:
    _ = try takeBytes(2, from: &input, errorMessage: "unexpected end of input in skipValue")
  case 233, 237, 240:
    _ = try takeBytes(4, from: &input, errorMessage: "unexpected end of input in skipValue")
  case 234, 238, 239, 241:
    _ = try takeBytes(8, from: &input, errorMessage: "unexpected end of input in skipValue")
  case 235:
    _ = try takeBytes(1, from: &input, errorMessage: "unexpected end of input in skipValue")
  case 243, 245:
    let count = try decodeNumber(&input)
    guard count >= 0 else {
      throw schemaError("unexpected negative length in skipValue")
    }
    _ = try takeBytes(
      Int(count), from: &input, errorMessage: "unexpected end of input in skipValue")
  case 247...249:
    for _ in 0..<Int(wire - 246) {
      try skipValue(&input)
    }
  case 250:
    let count = try decodeNumber(&input)
    guard count >= 0 else {
      throw schemaError("unexpected negative array length in skipValue")
    }
    for _ in 0..<Int(count) {
      try skipValue(&input)
    }
  case 251...254:
    try skipValue(&input)
  default:
    return
  }
}

private func floatSpecialString(_ value: Double) -> String {
  if value.isNaN {
    return "NaN"
  }
  if value > 0 {
    return "Infinity"
  }
  return "-Infinity"
}

struct BoolAdapter: TypeAdapter {
  typealias T = Bool

  func isDefault(_ input: Bool) -> Bool {
    !input
  }

  func toJson(_ input: Bool, eolIndent: String?, out: inout String) {
    out.append(eolIndent == nil ? (input ? "1" : "0") : (input ? "true" : "false"))
  }

  func fromJson(_ json: Any, keepUnrecognizedValues _: Bool) throws -> Bool {
    if let value = json as? Bool {
      return value
    }
    if let number = jsonNumber(json) {
      return number.doubleValue != 0
    }
    if let string = json as? String {
      return string != "0"
    }
    return false
  }

  func encode(_ input: Bool, out: inout [UInt8]) {
    out.append(input ? 1 : 0)
  }

  func decode(_ input: inout [UInt8], keepUnrecognizedValues _: Bool) throws -> Bool {
    try readU8(&input) != 0
  }

  func typeDescriptor() -> Reflection.TypeDescriptor {
    .primitive(.bool)
  }
}

struct Int32Adapter: TypeAdapter {
  typealias T = Int32

  func isDefault(_ input: Int32) -> Bool { input == 0 }

  func toJson(_ input: Int32, eolIndent _: String?, out: inout String) {
    out.append(String(input))
  }

  func fromJson(_ json: Any, keepUnrecognizedValues _: Bool) throws -> Int32 {
    if let number = jsonNumber(json) {
      return clampTruncatingInt32(number.doubleValue)
    }
    if let string = json as? String {
      return clampTruncatingInt32(Double(string) ?? 0)
    }
    return 0
  }

  func encode(_ input: Int32, out: inout [UInt8]) {
    encodeInt32(input, out: &out)
  }

  func decode(_ input: inout [UInt8], keepUnrecognizedValues _: Bool) throws -> Int32 {
    Int32(truncatingIfNeeded: try decodeNumber(&input))
  }

  func typeDescriptor() -> Reflection.TypeDescriptor {
    .primitive(.int32)
  }
}

struct Int64Adapter: TypeAdapter {
  typealias T = Int64

  func isDefault(_ input: Int64) -> Bool { input == 0 }

  func toJson(_ input: Int64, eolIndent _: String?, out: inout String) {
    if (-maxSafeInt64Json...maxSafeInt64Json).contains(input) {
      out.append(String(input))
    } else {
      writeJsonEscapedString(String(input), out: &out)
    }
  }

  func fromJson(_ json: Any, keepUnrecognizedValues _: Bool) throws -> Int64 {
    if let number = jsonNumber(json) {
      return clampRoundedInt64(number.doubleValue)
    }
    if let string = json as? String {
      return Int64(string) ?? 0
    }
    return 0
  }

  func encode(_ input: Int64, out: inout [UInt8]) {
    if input >= Int64(Int32.min), input <= Int64(Int32.max) {
      encodeInt32(Int32(input), out: &out)
    } else {
      out.append(238)
      appendLittleEndian(UInt64(bitPattern: input), to: &out)
    }
  }

  func decode(_ input: inout [UInt8], keepUnrecognizedValues _: Bool) throws -> Int64 {
    try decodeNumber(&input)
  }

  func typeDescriptor() -> Reflection.TypeDescriptor {
    .primitive(.int64)
  }
}

struct Hash64Adapter: TypeAdapter {
  typealias T = UInt64

  func isDefault(_ input: UInt64) -> Bool { input == 0 }

  func toJson(_ input: UInt64, eolIndent _: String?, out: inout String) {
    if input <= maxSafeHash64Json {
      out.append(String(input))
    } else {
      writeJsonEscapedString(String(input), out: &out)
    }
  }

  func fromJson(_ json: Any, keepUnrecognizedValues _: Bool) throws -> UInt64 {
    if let value = asJsonUInt64(json) {
      return value
    }
    if let number = asJsonDouble(json) {
      return clampRoundedUInt64(number)
    }
    if let string = json as? String {
      return UInt64(string) ?? 0
    }
    return 0
  }

  func encode(_ input: UInt64, out: inout [UInt8]) {
    switch input {
    case 0...231:
      out.append(UInt8(input))
    case 232...65_535:
      out.append(232)
      appendLittleEndian(UInt16(input), to: &out)
    case 65_536...4_294_967_295:
      out.append(233)
      appendLittleEndian(UInt32(input), to: &out)
    default:
      out.append(234)
      appendLittleEndian(input, to: &out)
    }
  }

  func decode(_ input: inout [UInt8], keepUnrecognizedValues _: Bool) throws -> UInt64 {
    UInt64(bitPattern: try decodeNumber(&input))
  }

  func typeDescriptor() -> Reflection.TypeDescriptor {
    .primitive(.hash64)
  }
}

struct Float32Adapter: TypeAdapter {
  typealias T = Float

  func isDefault(_ input: Float) -> Bool { input == 0 }

  func toJson(_ input: Float, eolIndent _: String?, out: inout String) {
    if Double(input).isFinite {
      out.append(String(input))
    } else {
      writeJsonEscapedString(floatSpecialString(Double(input)), out: &out)
    }
  }

  func fromJson(_ json: Any, keepUnrecognizedValues _: Bool) throws -> Float {
    if let number = asJsonDouble(json) {
      return Float(number)
    }
    if let string = json as? String {
      return Float(string) ?? 0
    }
    return 0
  }

  func encode(_ input: Float, out: inout [UInt8]) {
    if input == 0 {
      out.append(0)
    } else {
      out.append(240)
      appendLittleEndian(input, to: &out)
    }
  }

  func decode(_ input: inout [UInt8], keepUnrecognizedValues _: Bool) throws -> Float {
    let wire = try readU8(&input)
    if wire == 240 {
      return try readFloat32(&input)
    }
    return Float(try decodeNumberBody(wire, input: &input))
  }

  func typeDescriptor() -> Reflection.TypeDescriptor {
    .primitive(.float32)
  }
}

struct Float64Adapter: TypeAdapter {
  typealias T = Double

  func isDefault(_ input: Double) -> Bool { input == 0 }

  func toJson(_ input: Double, eolIndent _: String?, out: inout String) {
    if input.isFinite {
      out.append(String(input))
    } else {
      writeJsonEscapedString(floatSpecialString(input), out: &out)
    }
  }

  func fromJson(_ json: Any, keepUnrecognizedValues _: Bool) throws -> Double {
    if let number = asJsonDouble(json) {
      return number
    }
    if let string = json as? String {
      return Double(string) ?? 0
    }
    return 0
  }

  func encode(_ input: Double, out: inout [UInt8]) {
    if input == 0 {
      out.append(0)
    } else {
      out.append(241)
      appendLittleEndian(input, to: &out)
    }
  }

  func decode(_ input: inout [UInt8], keepUnrecognizedValues _: Bool) throws -> Double {
    let wire = try readU8(&input)
    if wire == 241 {
      return try readFloat64(&input)
    }
    return Double(try decodeNumberBody(wire, input: &input))
  }

  func typeDescriptor() -> Reflection.TypeDescriptor {
    .primitive(.float64)
  }
}

struct TimestampAdapter: TypeAdapter {
  typealias T = Foundation.Date

  func isDefault(_ input: Foundation.Date) -> Bool {
    systemTimeToMillis(input) == 0
  }

  func toJson(_ input: Foundation.Date, eolIndent: String?, out: inout String) {
    let millis = systemTimeToMillis(input)
    if let eolIndent {
      let childIndent = eolIndent + "  "
      out.append("{")
      out.append(childIndent)
      out.append("\"unix_millis\": ")
      out.append(String(millis))
      out.append(",")
      out.append(childIndent)
      out.append("\"formatted\": ")
      writeJsonEscapedString(millisToIso8601(millis), out: &out)
      out.append(eolIndent)
      out.append("}")
    } else {
      out.append(String(millis))
    }
  }

  func fromJson(_ json: Any, keepUnrecognizedValues _: Bool) throws -> Foundation.Date {
    if let number = asJsonDouble(json) {
      return millisToSystemTime(clampRoundedInt64(number))
    }
    if let string = json as? String {
      return millisToSystemTime(clampRoundedInt64(Double(string) ?? 0))
    }
    if let object = json as? [String: Any], let unixMillis = object["unix_millis"] {
      return try fromJson(unixMillis, keepUnrecognizedValues: false)
    }
    return millisToSystemTime(0)
  }

  func encode(_ input: Foundation.Date, out: inout [UInt8]) {
    let millis = systemTimeToMillis(input)
    if millis == 0 {
      out.append(0)
    } else {
      out.append(239)
      appendLittleEndian(UInt64(bitPattern: millis), to: &out)
    }
  }

  func decode(_ input: inout [UInt8], keepUnrecognizedValues _: Bool) throws -> Foundation.Date {
    millisToSystemTime(try decodeNumber(&input))
  }

  func typeDescriptor() -> Reflection.TypeDescriptor {
    .primitive(.timestamp)
  }
}

struct StringAdapter: TypeAdapter {
  typealias T = String

  func isDefault(_ input: String) -> Bool { input.isEmpty }

  func toJson(_ input: String, eolIndent _: String?, out: inout String) {
    writeJsonEscapedString(input, out: &out)
  }

  func fromJson(_ json: Any, keepUnrecognizedValues _: Bool) throws -> String {
    if let string = json as? String {
      return string
    }
    return ""
  }

  func encode(_ input: String, out: inout [UInt8]) {
    if input.isEmpty {
      out.append(242)
    } else {
      let bytes = Array(input.utf8)
      out.append(243)
      encodeUInt32(UInt32(bytes.count), out: &out)
      out.append(contentsOf: bytes)
    }
  }

  func decode(_ input: inout [UInt8], keepUnrecognizedValues _: Bool) throws -> String {
    let wire = try readU8(&input)
    if wire == 0 || wire == 242 {
      return ""
    }
    let count = try decodeNumber(&input)
    guard count >= 0 else {
      throw schemaError("unexpected negative string length")
    }
    return String(decoding: try takeBytes(Int(count), from: &input), as: UTF8.self)
  }

  func typeDescriptor() -> Reflection.TypeDescriptor {
    .primitive(.string)
  }
}

struct BytesAdapter: TypeAdapter {
  typealias T = Foundation.Data

  func isDefault(_ input: Foundation.Data) -> Bool { input.isEmpty }

  func toJson(_ input: Foundation.Data, eolIndent: String?, out: inout String) {
    let payload = eolIndent == nil ? encodeBase64(input) : "hex:" + encodeHex(input)
    writeJsonEscapedString(payload, out: &out)
  }

  func fromJson(_ json: Any, keepUnrecognizedValues _: Bool) throws -> Foundation.Data {
    if let string = json as? String {
      if string.hasPrefix("hex:") {
        return try decodeHex(String(string.dropFirst(4)))
      }
      return try decodeBase64(string)
    }
    return Foundation.Data()
  }

  func encode(_ input: Foundation.Data, out: inout [UInt8]) {
    if input.isEmpty {
      out.append(244)
    } else {
      out.append(245)
      encodeUInt32(UInt32(input.count), out: &out)
      out.append(contentsOf: input)
    }
  }

  func decode(_ input: inout [UInt8], keepUnrecognizedValues _: Bool) throws -> Foundation.Data {
    let wire = try readU8(&input)
    if wire == 0 || wire == 244 {
      return Foundation.Data()
    }
    let count = try decodeNumber(&input)
    guard count >= 0 else {
      throw schemaError("unexpected negative bytes length")
    }
    return Foundation.Data(try takeBytes(Int(count), from: &input))
  }

  func typeDescriptor() -> Reflection.TypeDescriptor {
    .primitive(.bytes)
  }
}

struct ArrayAdapter<Element>: TypeAdapter {
  typealias T = [Element]

  let item: any TypeAdapter<Element>

  func isDefault(_ input: [Element]) -> Bool { input.isEmpty }

  func toJson(_ input: [Element], eolIndent: String?, out: inout String) {
    out.append("[")
    if let eolIndent {
      let childIndent = eolIndent + "  "
      for (index, value) in input.enumerated() {
        out.append(childIndent)
        item.toJson(value, eolIndent: childIndent, out: &out)
        if index + 1 < input.count {
          out.append(",")
        }
      }
      if !input.isEmpty {
        out.append(eolIndent)
      }
    } else {
      for (index, value) in input.enumerated() {
        if index > 0 {
          out.append(",")
        }
        item.toJson(value, eolIndent: nil, out: &out)
      }
    }
    out.append("]")
  }

  func fromJson(_ json: Any, keepUnrecognizedValues: Bool) throws -> [Element] {
    guard let values = json as? [Any] else {
      return []
    }
    return try values.map {
      try item.fromJson($0, keepUnrecognizedValues: keepUnrecognizedValues)
    }
  }

  func encode(_ input: [Element], out: inout [UInt8]) {
    if input.count <= 3 {
      out.append(246 + UInt8(input.count))
    } else {
      out.append(250)
      encodeUInt32(UInt32(input.count), out: &out)
    }
    for value in input {
      item.encode(value, out: &out)
    }
  }

  func decode(_ input: inout [UInt8], keepUnrecognizedValues: Bool) throws -> [Element] {
    let wire = try readU8(&input)
    if wire == 0 || wire == 246 {
      return []
    }

    let count: Int
    if wire == 250 {
      let decoded = try decodeNumber(&input)
      guard decoded >= 0 else {
        throw schemaError("unexpected negative array length")
      }
      count = Int(decoded)
    } else {
      count = Int(wire - 246)
    }

    var values: [Element] = []
    values.reserveCapacity(count)
    for _ in 0..<count {
      values.append(try item.decode(&input, keepUnrecognizedValues: keepUnrecognizedValues))
    }
    return values
  }

  func typeDescriptor() -> Reflection.TypeDescriptor {
    .array(Reflection.ArrayDescriptor(itemType: item.typeDescriptor(), keyExtractor: ""))
  }
}

struct KeyedArrayAdapter<Spec: KeyedArraySpec>: TypeAdapter {
  typealias T = KeyedArray<Spec>

  let item: any TypeAdapter<Spec.Item>

  func isDefault(_ input: KeyedArray<Spec>) -> Bool { input.isEmpty }

  func toJson(_ input: KeyedArray<Spec>, eolIndent: String?, out: inout String) {
    out.append("[")
    if let eolIndent {
      let childIndent = eolIndent + "  "
      for (index, value) in input.enumerated() {
        out.append(childIndent)
        item.toJson(value, eolIndent: childIndent, out: &out)
        if index + 1 < input.count {
          out.append(",")
        }
      }
      if !input.isEmpty {
        out.append(eolIndent)
      }
    } else {
      for (index, value) in input.enumerated() {
        if index > 0 {
          out.append(",")
        }
        item.toJson(value, eolIndent: nil, out: &out)
      }
    }
    out.append("]")
  }

  func fromJson(_ json: Any, keepUnrecognizedValues: Bool) throws -> KeyedArray<Spec> {
    guard let values = json as? [Any] else {
      return KeyedArray<Spec>()
    }
    let items = try values.map {
      try item.fromJson($0, keepUnrecognizedValues: keepUnrecognizedValues)
    }
    return KeyedArray<Spec>(items)
  }

  func encode(_ input: KeyedArray<Spec>, out: inout [UInt8]) {
    if input.count <= 3 {
      out.append(246 + UInt8(input.count))
    } else {
      out.append(250)
      encodeUInt32(UInt32(input.count), out: &out)
    }
    for value in input {
      item.encode(value, out: &out)
    }
  }

  func decode(_ input: inout [UInt8], keepUnrecognizedValues: Bool) throws -> KeyedArray<Spec> {
    let wire = try readU8(&input)
    if wire == 0 || wire == 246 {
      return KeyedArray<Spec>()
    }

    let count: Int
    if wire == 250 {
      let decoded = try decodeNumber(&input)
      guard decoded >= 0 else {
        throw schemaError("unexpected negative array length")
      }
      count = Int(decoded)
    } else {
      count = Int(wire - 246)
    }

    var items: [Spec.Item] = []
    items.reserveCapacity(count)
    for _ in 0..<count {
      items.append(try item.decode(&input, keepUnrecognizedValues: keepUnrecognizedValues))
    }
    return KeyedArray<Spec>(items)
  }

  func typeDescriptor() -> Reflection.TypeDescriptor {
    .array(
      Reflection.ArrayDescriptor(itemType: item.typeDescriptor(), keyExtractor: Spec.keyExtractor())
    )
  }
}

struct OptionalAdapter<Wrapped>: TypeAdapter {
  typealias T = Wrapped?

  let other: any TypeAdapter<Wrapped>

  func isDefault(_ input: Wrapped?) -> Bool { input == nil }

  func toJson(_ input: Wrapped?, eolIndent: String?, out: inout String) {
    guard let input else {
      out.append("null")
      return
    }
    other.toJson(input, eolIndent: eolIndent, out: &out)
  }

  func fromJson(_ json: Any, keepUnrecognizedValues: Bool) throws -> Wrapped? {
    if json is NSNull {
      return nil
    }
    return try other.fromJson(json, keepUnrecognizedValues: keepUnrecognizedValues)
  }

  func encode(_ input: Wrapped?, out: inout [UInt8]) {
    guard let input else {
      out.append(255)
      return
    }
    other.encode(input, out: &out)
  }

  func decode(_ input: inout [UInt8], keepUnrecognizedValues: Bool) throws -> Wrapped? {
    if input.first == 255 {
      input.removeFirst()
      return nil
    }
    return try other.decode(&input, keepUnrecognizedValues: keepUnrecognizedValues)
  }

  func typeDescriptor() -> Reflection.TypeDescriptor {
    .optional(other.typeDescriptor())
  }
}

struct RecursiveAdapter<Wrapped>: TypeAdapter {
  typealias T = IndirectOptional<Wrapped>

  let other: any TypeAdapter<Wrapped>

  func isDefault(_ input: IndirectOptional<Wrapped>) -> Bool {
    guard let inner = input.value else {
      return true
    }
    return other.isDefault(inner)
  }

  func toJson(_ input: IndirectOptional<Wrapped>, eolIndent: String?, out: inout String) {
    guard let inner = input.value else {
      out.append("[]")
      return
    }
    other.toJson(inner, eolIndent: eolIndent, out: &out)
  }

  func fromJson(_ json: Any, keepUnrecognizedValues: Bool) throws -> IndirectOptional<Wrapped> {
    if let values = json as? [Any], values.isEmpty {
      return .none
    }
    if let number = jsonNumber(json), number.doubleValue == 0 {
      return .none
    }
    return .some(try other.fromJson(json, keepUnrecognizedValues: keepUnrecognizedValues))
  }

  func encode(_ input: IndirectOptional<Wrapped>, out: inout [UInt8]) {
    guard let inner = input.value else {
      out.append(246)
      return
    }
    other.encode(inner, out: &out)
  }

  func decode(_ input: inout [UInt8], keepUnrecognizedValues: Bool) throws -> IndirectOptional<
    Wrapped
  > {
    if let first = input.first, first == 246 || first == 0 {
      input.removeFirst()
      return .none
    }
    return .some(try other.decode(&input, keepUnrecognizedValues: keepUnrecognizedValues))
  }

  func typeDescriptor() -> Reflection.TypeDescriptor {
    other.typeDescriptor()
  }
}

struct OptionBoxAdapter<Wrapped>: TypeAdapter {
  typealias T = IndirectOptional<Wrapped>

  let other: any TypeAdapter<Wrapped>

  func isDefault(_ input: IndirectOptional<Wrapped>) -> Bool {
    if case .none = input { return true }
    return false
  }

  func toJson(_ input: IndirectOptional<Wrapped>, eolIndent: String?, out: inout String) {
    guard let inner = input.value else {
      out.append("null")
      return
    }
    other.toJson(inner, eolIndent: eolIndent, out: &out)
  }

  func fromJson(_ json: Any, keepUnrecognizedValues: Bool) throws -> IndirectOptional<Wrapped> {
    if json is NSNull {
      return .none
    }
    return .some(try other.fromJson(json, keepUnrecognizedValues: keepUnrecognizedValues))
  }

  func encode(_ input: IndirectOptional<Wrapped>, out: inout [UInt8]) {
    guard let inner = input.value else {
      out.append(255)
      return
    }
    other.encode(inner, out: &out)
  }

  func decode(_ input: inout [UInt8], keepUnrecognizedValues: Bool) throws -> IndirectOptional<
    Wrapped
  > {
    if input.first == 255 {
      input.removeFirst()
      return .none
    }
    return .some(try other.decode(&input, keepUnrecognizedValues: keepUnrecognizedValues))
  }

  func typeDescriptor() -> Reflection.TypeDescriptor {
    .optional(other.typeDescriptor())
  }
}
