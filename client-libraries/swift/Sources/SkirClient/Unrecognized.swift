public typealias UnrecognizedFields<T> = IndirectOptional<Internal.UnrecognizedFieldsData<T>>
public typealias UnrecognizedVariant<T> = IndirectOptional<Internal.UnrecognizedVariantData<T>>

extension Internal {
  public final class UnrecognizedFieldsData<T> {
    let format: UnrecognizedFormat
    let arrayLen: UInt32
    let values: [UInt8]

    init(
      format: UnrecognizedFormat = .unknown,
      arrayLen: UInt32 = 0,
      values: [UInt8] = []
    ) {
      self.format = format
      self.arrayLen = arrayLen
      self.values = values
    }

    static func newFromJson(arrayLen: UInt32, jsonBytes: [UInt8]) -> UnrecognizedFields<T> {
      return .some(
        UnrecognizedFieldsData(
          format: .denseJson,
          arrayLen: arrayLen,
          values: jsonBytes
        ))
    }

    static func newFromBytes(arrayLen: UInt32, rawBytes: [UInt8]) -> UnrecognizedFields<T> {
      return .some(
        UnrecognizedFieldsData(
          format: .bytes,
          arrayLen: arrayLen,
          values: rawBytes
        ))
    }
  }

  public final class UnrecognizedVariantData<T> {
    let format: UnrecognizedFormat
    let number: Int32
    let value: [UInt8]

    init(
      format: UnrecognizedFormat = .unknown,
      number: Int32 = 0,
      value: [UInt8] = []
    ) {
      self.format = format
      self.number = number
      self.value = value
    }

    static func newFromBytes(number: Int32, rawBytes: [UInt8]) -> UnrecognizedVariant<T> {
      return .some(
        UnrecognizedVariantData(
          format: .bytes,
          number: number,
          value: rawBytes
        ))
    }

    static func newFromJson(number: Int32, jsonBytes: [UInt8]) -> UnrecognizedVariant<T> {
      return .some(
        UnrecognizedVariantData(
          format: .denseJson,
          number: number,
          value: jsonBytes
        ))
    }
  }
}

enum UnrecognizedFormat {
  case unknown
  case denseJson
  case bytes
}
