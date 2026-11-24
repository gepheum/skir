import Foundation

public enum Reflection {
  enum ParseError: Error, CustomStringConvertible {
    case message(String)

    var description: String {
      switch self {
      case .message(let message):
        return message
      }
    }
  }

  public enum PrimitiveType: String, CaseIterable, CustomStringConvertible {
    case bool = "bool"
    case int32 = "int32"
    case int64 = "int64"
    case hash64 = "hash64"
    case float32 = "float32"
    case float64 = "float64"
    case timestamp = "timestamp"
    case string = "string"
    case bytes = "bytes"

    public var description: String { rawValue }
  }

  public indirect enum TypeDescriptor: CustomStringConvertible {
    case primitive(PrimitiveType)
    case optional(TypeDescriptor)
    case array(ArrayDescriptor)
    case structRecord(StructDescriptor)
    case enumRecord(EnumDescriptor)

    public func asJson() -> String {
      return typeDescriptorToJson(self)
    }

    public static func parseFromJson(_ jsonCode: String) throws -> TypeDescriptor {
      do {
        guard let data = jsonCode.data(using: .utf8) else {
          throw ParseError.message("TypeDescriptor::parse_from_json: invalid UTF-8 input")
        }
        let rootObject = try JSONSerialization.jsonObject(with: data)
        guard let root = rootObject as? [String: Any] else {
          throw ParseError.message("TypeDescriptor::parse_from_json: root must be a JSON object")
        }
        return try parseTypeDescriptorFromValue(root)
      } catch let error as ParseError {
        throw error
      } catch {
        throw ParseError.message("TypeDescriptor::parse_from_json: \(error)")
      }
    }

    public var description: String {
      return asJson()
    }
  }

  public final class ArrayDescriptor: CustomStringConvertible {
    let itemType: TypeDescriptor
    let keyExtractor: String

    init(itemType: TypeDescriptor, keyExtractor: String) {
      self.itemType = itemType
      self.keyExtractor = keyExtractor
    }

    public var description: String {
      return "ArrayDescriptor(item_type: \(itemType), key_extractor: \(keyExtractor))"
    }
  }

  public final class StructField: CustomStringConvertible {
    let name: String
    let number: Int32
    let fieldType: TypeDescriptor
    let doc: String

    init(name: String, number: Int32, fieldType: TypeDescriptor, doc: String) {
      self.name = name
      self.number = number
      self.fieldType = fieldType
      self.doc = doc
    }

    public var description: String {
      return "StructField(name: \(name), number: \(number), doc: \(doc))"
    }
  }

  final class EnumConstantVariant: CustomStringConvertible {
    let name: String
    let number: Int32
    let doc: String

    init(name: String, number: Int32, doc: String) {
      self.name = name
      self.number = number
      self.doc = doc
    }

    var description: String {
      return "EnumConstantVariant(name: \(name), number: \(number), doc: \(doc))"
    }
  }

  final class EnumWrapperVariant: CustomStringConvertible {
    let name: String
    let number: Int32
    let variantType: TypeDescriptor
    let doc: String

    init(name: String, number: Int32, variantType: TypeDescriptor, doc: String) {
      self.name = name
      self.number = number
      self.variantType = variantType
      self.doc = doc
    }

    var description: String {
      return "EnumWrapperVariant(name: \(name), number: \(number), doc: \(doc))"
    }
  }

  enum EnumVariant: CustomStringConvertible {
    case constant(EnumConstantVariant)
    case wrapper(EnumWrapperVariant)

    var name: String {
      switch self {
      case .constant(let v):
        return v.name
      case .wrapper(let v):
        return v.name
      }
    }

    var number: Int32 {
      switch self {
      case .constant(let v):
        return v.number
      case .wrapper(let v):
        return v.number
      }
    }

    var doc: String {
      switch self {
      case .constant(let v):
        return v.doc
      case .wrapper(let v):
        return v.doc
      }
    }

    var variantType: TypeDescriptor? {
      switch self {
      case .constant:
        return nil
      case .wrapper(let v):
        return v.variantType
      }
    }

    var description: String {
      switch self {
      case .constant(let v):
        return v.description
      case .wrapper(let v):
        return v.description
      }
    }
  }

  public final class StructDescriptor: CustomStringConvertible {
    let name: String
    let qualifiedName: String
    let modulePath: String
    let doc: String

    private var removedNumbersStorage: Set<Int32>?
    private var fieldsStorage: [StructField]?
    private var lookups: (byName: [String: Int], byNumber: [Int32: Int])?

    init(modulePath: String, qualifiedName: String, doc: String) {
      self.name = qualifiedName.split(separator: ".").last.map(String.init) ?? qualifiedName
      self.qualifiedName = qualifiedName
      self.modulePath = modulePath
      self.doc = doc
      self.removedNumbersStorage = nil
      self.fieldsStorage = nil
      self.lookups = nil
    }

    var removedNumbers: Set<Int32> {
      if removedNumbersStorage == nil {
        removedNumbersStorage = []
      }
      return removedNumbersStorage!
    }

    var fields: [StructField] {
      guard let fieldsStorage else {
        fatalError("StructDescriptor fields not yet initialized")
      }
      return fieldsStorage
    }

    func setFields(_ fields: [StructField]) {
      guard fieldsStorage == nil else {
        return
      }
      fieldsStorage = fields
      lookups = nil
    }

    func setRemovedNumbers(_ nums: Set<Int32>) {
      guard removedNumbersStorage == nil else {
        return
      }
      removedNumbersStorage = nums
    }

    func fieldByName(_ name: String) -> StructField? {
      let index = ensureLookups().byName[name]
      guard let index else {
        return nil
      }
      return fields[index]
    }

    func fieldByNumber(_ number: Int32) -> StructField? {
      let index = ensureLookups().byNumber[number]
      guard let index else {
        return nil
      }
      return fields[index]
    }

    fileprivate func recordId() -> String {
      return "\(modulePath):\(qualifiedName)"
    }

    private func ensureLookups() -> (byName: [String: Int], byNumber: [Int32: Int]) {
      if let lookups {
        return lookups
      }
      var byName: [String: Int] = [:]
      var byNumber: [Int32: Int] = [:]
      for (index, field) in fields.enumerated() {
        byName[field.name] = index
        byNumber[field.number] = index
      }
      let built = (byName: byName, byNumber: byNumber)
      lookups = built
      return built
    }

    public var description: String {
      return "StructDescriptor(\(recordId()))"
    }
  }

  public final class EnumDescriptor: CustomStringConvertible {
    let name: String
    let qualifiedName: String
    let modulePath: String
    let doc: String

    private var removedNumbersStorage: Set<Int32>?
    private var variantsStorage: [EnumVariant]?
    private var lookups: (byName: [String: Int], byNumber: [Int32: Int])?

    init(modulePath: String, qualifiedName: String, doc: String) {
      self.name = qualifiedName.split(separator: ".").last.map(String.init) ?? qualifiedName
      self.qualifiedName = qualifiedName
      self.modulePath = modulePath
      self.doc = doc
      self.removedNumbersStorage = nil
      self.variantsStorage = nil
      self.lookups = nil
    }

    var removedNumbers: Set<Int32> {
      if removedNumbersStorage == nil {
        removedNumbersStorage = []
      }
      return removedNumbersStorage!
    }

    var variants: [EnumVariant] {
      guard let variantsStorage else {
        fatalError("EnumDescriptor variants not yet initialized")
      }
      return variantsStorage
    }

    func setVariants(_ variants: [EnumVariant]) {
      guard variantsStorage == nil else {
        return
      }
      variantsStorage = variants
      lookups = nil
    }

    func setRemovedNumbers(_ nums: Set<Int32>) {
      guard removedNumbersStorage == nil else {
        return
      }
      removedNumbersStorage = nums
    }

    func variantByName(_ name: String) -> EnumVariant? {
      let index = ensureLookups().byName[name]
      guard let index else {
        return nil
      }
      return variants[index]
    }

    func variantByNumber(_ number: Int32) -> EnumVariant? {
      let index = ensureLookups().byNumber[number]
      guard let index else {
        return nil
      }
      return variants[index]
    }

    fileprivate func recordId() -> String {
      return "\(modulePath):\(qualifiedName)"
    }

    private func ensureLookups() -> (byName: [String: Int], byNumber: [Int32: Int]) {
      if let lookups {
        return lookups
      }
      var byName: [String: Int] = [:]
      var byNumber: [Int32: Int] = [:]
      for (index, variant) in variants.enumerated() {
        byName[variant.name] = index
        byNumber[variant.number] = index
      }
      let built = (byName: byName, byNumber: byNumber)
      lookups = built
      return built
    }

    public var description: String {
      return "EnumDescriptor(\(recordId()))"
    }
  }

  private enum JsonValue {
    case object([(String, JsonValue)])
    case array([JsonValue])
    case string(String)
    case number(Int)
    case bool(Bool)
    case null

    func prettyString(indentLevel: Int = 0) -> String {
      switch self {
      case .string(let value):
        return quoteJsonString(value)
      case .number(let value):
        return String(value)
      case .bool(let value):
        return value ? "true" : "false"
      case .null:
        return "null"
      case .array(let items):
        if items.isEmpty {
          return "[]"
        }
        let indent = String(repeating: " ", count: indentLevel)
        let childIndent = String(repeating: " ", count: indentLevel + 2)
        let body =
          items
          .map { childIndent + $0.prettyString(indentLevel: indentLevel + 2) }
          .joined(separator: ",\n")
        return "[\n\(body)\n\(indent)]"
      case .object(let pairs):
        if pairs.isEmpty {
          return "{}"
        }
        let indent = String(repeating: " ", count: indentLevel)
        let childIndent = String(repeating: " ", count: indentLevel + 2)
        let body =
          pairs
          .map { key, value in
            "\(childIndent)\(quoteJsonString(key)): \(value.prettyString(indentLevel: indentLevel + 2))"
          }
          .joined(separator: ",\n")
        return "{\n\(body)\n\(indent)}"
      }
    }
  }

  private enum RecordDescriptorInner {
    case structDescriptor(StructDescriptor)
    case enumDescriptor(EnumDescriptor)

    func recordId() -> String {
      switch self {
      case .structDescriptor(let s):
        return s.recordId()
      case .enumDescriptor(let e):
        return e.recordId()
      }
    }

    func asTypeDescriptor() -> TypeDescriptor {
      switch self {
      case .structDescriptor(let s):
        return .structRecord(s)
      case .enumDescriptor(let e):
        return .enumRecord(e)
      }
    }
  }

  private struct RecordBundle {
    let descriptor: RecordDescriptorInner
    let fieldsOrVariants: [[String: Any]]
  }

  private static func quoteJsonString(_ input: String) -> String {
    var result = "\""
    for scalar in input.unicodeScalars {
      switch scalar.value {
      case 0x22: result += "\\\""
      case 0x5C: result += "\\\\"
      case 0x08: result += "\\b"
      case 0x0C: result += "\\f"
      case 0x0A: result += "\\n"
      case 0x0D: result += "\\r"
      case 0x09: result += "\\t"
      case 0x00...0x1F:
        let hex = String(scalar.value, radix: 16, uppercase: false)
        result += "\\u" + String(repeating: "0", count: 4 - hex.count) + hex
      default:
        result.unicodeScalars.append(scalar)
      }
    }
    result += "\""
    return result
  }

  private static func typeDescriptorToJson(_ td: TypeDescriptor) -> String {
    let records = collectRecordValues(td)
    let root = JsonValue.object([
      ("type", typeSignatureToValue(td)),
      ("records", .array(records)),
    ])
    return root.prettyString()
  }

  private static func collectRecordValues(_ td: TypeDescriptor) -> [JsonValue] {
    var order: [String] = []
    var recordIdToValue: [String: JsonValue] = [:]
    addRecordValues(td, order: &order, recordIdToValue: &recordIdToValue)
    return order.compactMap { recordIdToValue[$0] }
  }

  private static func addRecordValues(
    _ td: TypeDescriptor,
    order: inout [String],
    recordIdToValue: inout [String: JsonValue]
  ) {
    switch td {
    case .primitive:
      return
    case .optional(let inner):
      addRecordValues(inner, order: &order, recordIdToValue: &recordIdToValue)
    case .array(let arr):
      addRecordValues(arr.itemType, order: &order, recordIdToValue: &recordIdToValue)
    case .structRecord(let s):
      let rid = s.recordId()
      if recordIdToValue[rid] != nil {
        return
      }
      recordIdToValue[rid] = .null
      let value = structRecordToValue(s)
      recordIdToValue[rid] = value
      order.append(rid)
      for field in s.fields {
        addRecordValues(field.fieldType, order: &order, recordIdToValue: &recordIdToValue)
      }
    case .enumRecord(let e):
      let rid = e.recordId()
      if recordIdToValue[rid] != nil {
        return
      }
      recordIdToValue[rid] = .null
      let value = enumRecordToValue(e)
      recordIdToValue[rid] = value
      order.append(rid)
      for variant in e.variants {
        if case .wrapper(let w) = variant {
          addRecordValues(w.variantType, order: &order, recordIdToValue: &recordIdToValue)
        }
      }
    }
  }

  private static func structRecordToValue(_ s: StructDescriptor) -> JsonValue {
    let fields = s.fields.map { field -> JsonValue in
      var pairs: [(String, JsonValue)] = [
        ("name", .string(field.name)),
        ("number", .number(Int(field.number))),
        ("type", typeSignatureToValue(field.fieldType)),
      ]
      if !field.doc.isEmpty {
        pairs.append(("doc", .string(field.doc)))
      }
      return .object(pairs)
    }

    var pairs: [(String, JsonValue)] = [
      ("kind", .string("struct")),
      ("id", .string(s.recordId())),
    ]
    if !s.doc.isEmpty {
      pairs.append(("doc", .string(s.doc)))
    }
    pairs.append(("fields", .array(fields)))

    let removed = removedNumbersToSortedSlice(s.removedNumbers)
    if !removed.isEmpty {
      pairs.append(("removed_numbers", .array(removed.map { .number(Int($0)) })))
    }
    return .object(pairs)
  }

  private static func enumRecordToValue(_ e: EnumDescriptor) -> JsonValue {
    let sorted = e.variants.sorted { $0.number < $1.number }
    let variants = sorted.map { variant -> JsonValue in
      var pairs: [(String, JsonValue)] = [
        ("name", .string(variant.name)),
        ("number", .number(Int(variant.number))),
      ]
      if case .wrapper(let w) = variant {
        pairs.append(("type", typeSignatureToValue(w.variantType)))
      }
      if !variant.doc.isEmpty {
        pairs.append(("doc", .string(variant.doc)))
      }
      return .object(pairs)
    }

    var pairs: [(String, JsonValue)] = [
      ("kind", .string("enum")),
      ("id", .string(e.recordId())),
    ]
    if !e.doc.isEmpty {
      pairs.append(("doc", .string(e.doc)))
    }
    pairs.append(("variants", .array(variants)))

    let removed = removedNumbersToSortedSlice(e.removedNumbers)
    if !removed.isEmpty {
      pairs.append(("removed_numbers", .array(removed.map { .number(Int($0)) })))
    }
    return .object(pairs)
  }

  private static func typeSignatureToValue(_ td: TypeDescriptor) -> JsonValue {
    switch td {
    case .primitive(let p):
      return .object([
        ("kind", .string("primitive")),
        ("value", .string(p.rawValue)),
      ])
    case .optional(let inner):
      return .object([
        ("kind", .string("optional")),
        ("value", typeSignatureToValue(inner)),
      ])
    case .array(let arr):
      var valuePairs: [(String, JsonValue)] = [
        ("item", typeSignatureToValue(arr.itemType))
      ]
      if !arr.keyExtractor.isEmpty {
        valuePairs.append(("key_extractor", .string(arr.keyExtractor)))
      }
      return .object([
        ("kind", .string("array")),
        ("value", .object(valuePairs)),
      ])
    case .structRecord(let s):
      return .object([
        ("kind", .string("record")),
        ("value", .string(s.recordId())),
      ])
    case .enumRecord(let e):
      return .object([
        ("kind", .string("record")),
        ("value", .string(e.recordId())),
      ])
    }
  }

  private static func removedNumbersToSortedSlice(_ set: Set<Int32>) -> [Int32] {
    return set.sorted()
  }

  private static func parseTypeDescriptorFromValue(_ root: [String: Any]) throws -> TypeDescriptor {
    var recordIdToBundle: [String: RecordBundle] = [:]

    let records = (root["records"] as? [Any]) ?? []
    for recordValue in records {
      guard let recordObject = recordValue as? [String: Any] else {
        continue
      }
      let descriptor = try parseRecordDescriptorPartial(recordObject)
      let rid = descriptor.recordId()
      let fieldsOrVariants =
        (recordObject["fields"] as? [Any] ?? recordObject["variants"] as? [Any] ?? [])
        .compactMap { $0 as? [String: Any] }
      recordIdToBundle[rid] = RecordBundle(
        descriptor: descriptor,
        fieldsOrVariants: fieldsOrVariants
      )
    }

    let ids = Array(recordIdToBundle.keys)
    for id in ids {
      guard let bundle = recordIdToBundle[id] else {
        continue
      }

      switch bundle.descriptor {
      case .structDescriptor(let s):
        var fields: [StructField] = []
        fields.reserveCapacity(bundle.fieldsOrVariants.count)
        for fieldValue in bundle.fieldsOrVariants {
          let name = getJsonStr(fieldValue, key: "name")
          let number = getJsonI32(fieldValue, key: "number")
          guard let typeValue = fieldValue["type"] else {
            throw ParseError.message("struct field \(String(reflecting: name)) is missing 'type'")
          }
          let fieldType = try parseTypeSignature(typeValue, recordIdToBundle: recordIdToBundle)
          let doc = getJsonStr(fieldValue, key: "doc")
          fields.append(StructField(name: name, number: number, fieldType: fieldType, doc: doc))
        }
        s.setFields(fields)
      case .enumDescriptor(let e):
        var variants: [EnumVariant] = []
        variants.reserveCapacity(bundle.fieldsOrVariants.count)
        for variantValue in bundle.fieldsOrVariants {
          let name = getJsonStr(variantValue, key: "name")
          let number = getJsonI32(variantValue, key: "number")
          let doc = getJsonStr(variantValue, key: "doc")
          if let typeValue = variantValue["type"] {
            let variantType = try parseTypeSignature(typeValue, recordIdToBundle: recordIdToBundle)
            variants.append(
              .wrapper(
                EnumWrapperVariant(
                  name: name,
                  number: number,
                  variantType: variantType,
                  doc: doc
                ))
            )
          } else {
            variants.append(.constant(EnumConstantVariant(name: name, number: number, doc: doc)))
          }
        }
        e.setVariants(variants)
      }
    }

    guard let typeValue = root["type"] else {
      throw ParseError.message("type descriptor JSON is missing 'type'")
    }
    return try parseTypeSignature(typeValue, recordIdToBundle: recordIdToBundle)
  }

  private static func parseRecordDescriptorPartial(_ value: [String: Any]) throws
    -> RecordDescriptorInner
  {
    let kind = getJsonStr(value, key: "kind")
    let id = getJsonStr(value, key: "id")
    let doc = getJsonStr(value, key: "doc")
    let (modulePath, qualifiedName) = try splitRecordId(id)

    let removedNumbers: Set<Int32> = Set(
      ((value["removed_numbers"] as? [Any]) ?? []).compactMap { raw in
        switch raw {
        case let int as Int:
          return Int32(int)
        case let int32 as Int32:
          return int32
        case let int64 as Int64:
          return Int32(int64)
        case let double as Double:
          return Int32(double)
        case let number as NSNumber:
          return number.int32Value
        default:
          return nil
        }
      }
    )

    switch kind {
    case "struct":
      let descriptor = StructDescriptor(
        modulePath: modulePath, qualifiedName: qualifiedName, doc: doc)
      descriptor.setRemovedNumbers(removedNumbers)
      return .structDescriptor(descriptor)
    case "enum":
      let descriptor = EnumDescriptor(
        modulePath: modulePath, qualifiedName: qualifiedName, doc: doc)
      descriptor.setRemovedNumbers(removedNumbers)
      return .enumDescriptor(descriptor)
    default:
      throw ParseError.message("unknown record kind \(String(reflecting: kind))")
    }
  }

  private static func parseTypeSignature(
    _ value: Any,
    recordIdToBundle: [String: RecordBundle]
  ) throws -> TypeDescriptor {
    guard let object = value as? [String: Any] else {
      throw ParseError.message("type signature must be an object")
    }

    let kind = getJsonStr(object, key: "kind")
    guard let rawValue = object["value"] else {
      throw ParseError.message("type signature missing 'value' (kind=\(String(reflecting: kind)))")
    }

    switch kind {
    case "primitive":
      let primitiveName = (rawValue as? String) ?? ""
      guard let primitive = PrimitiveType(rawValue: primitiveName) else {
        throw ParseError.message("unknown primitive type \(String(reflecting: primitiveName))")
      }
      return .primitive(primitive)
    case "optional":
      return .optional(try parseTypeSignature(rawValue, recordIdToBundle: recordIdToBundle))
    case "array":
      guard let arrayObject = rawValue as? [String: Any] else {
        throw ParseError.message("array type signature value must be an object")
      }
      guard let itemValue = arrayObject["item"] else {
        throw ParseError.message("array type signature missing 'item'")
      }
      let itemType = try parseTypeSignature(itemValue, recordIdToBundle: recordIdToBundle)
      let keyExtractor = (arrayObject["key_extractor"] as? String) ?? ""
      return .array(ArrayDescriptor(itemType: itemType, keyExtractor: keyExtractor))
    case "record":
      let recordId = (rawValue as? String) ?? ""
      guard let bundle = recordIdToBundle[recordId] else {
        throw ParseError.message("unknown record id \(String(reflecting: recordId))")
      }
      return bundle.descriptor.asTypeDescriptor()
    default:
      throw ParseError.message("unknown type kind \(String(reflecting: kind))")
    }
  }

  private static func getJsonStr(_ value: [String: Any], key: String) -> String {
    return (value[key] as? String) ?? ""
  }

  private static func getJsonI32(_ value: [String: Any], key: String) -> Int32 {
    let raw = value[key]
    switch raw {
    case let int as Int:
      return Int32(int)
    case let int32 as Int32:
      return int32
    case let int64 as Int64:
      return Int32(int64)
    case let double as Double:
      return Int32(double)
    case let number as NSNumber:
      return number.int32Value
    default:
      return 0
    }
  }

  private static func splitRecordId(_ id: String) throws -> (String, String) {
    guard let index = id.firstIndex(of: ":") else {
      throw ParseError.message(
        "malformed record id \(String(reflecting: id)) (expected 'modulePath:qualifiedName')"
      )
    }
    let modulePath = String(id[..<index])
    let qualifiedName = String(id[id.index(after: index)...])
    return (modulePath, qualifiedName)
  }
}
