/// An optional whose `some` case is heap-allocated, breaking recursive value-type cycles.
public enum IndirectOptional<T> {
  case none
  indirect case some(T)

  /// The wrapped value, or `nil` if `.none`.
  public var value: T? {
    if case .some(let v) = self { return v }
    return nil
  }
}

extension IndirectOptional: ExpressibleByNilLiteral {
  public init(nilLiteral: ()) { self = .none }
}

extension IndirectOptional: CustomStringConvertible where T: CustomStringConvertible {
  public var description: String {
    switch self {
    case .none: return "nil"
    case .some(let v): return "Optional(\(v.description))"
    }
  }
}

extension IndirectOptional: Equatable where T: Equatable {
  public static func == (lhs: Self, rhs: Self) -> Bool {
    switch (lhs, rhs) {
    case (.none, .none): return true
    case (.some(let a), .some(let b)): return a == b
    default: return false
    }
  }
}
