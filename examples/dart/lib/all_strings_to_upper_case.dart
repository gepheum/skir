/// Reflection allows you to inspect and traverse Skir types and values at
/// runtime.
///
/// When *not* to use reflection: when working with a specific type known at
// compile-time, you can directly access the properties and constructor of the
// object, so you dont need reflection.
/// When to use reflection: when the Skir type is passed as a parameter (like
/// the generic T here), you need reflection - the ability to programmatically
/// inspect a type's structure (fields, their types, etc.) and manipulate values
/// without compile-time knowledge of that structure.
///
/// This pattern is useful for building generic utilities like:
/// - Custom validators that work across all your types
/// - Custom formatters/normalizers (like this uppercase example)
/// - Serialization utilities
/// - Any operation that needs to work uniformly across different Skir types

import 'package:skir_client/skir_client.dart' as skir;

/// Using reflection, converts all the strings contained in [input] to upper
/// case. Accepts any Skir type.
///
/// Example input:
///   ```dart
///   User(
///     userId: 123,
///     name: "Tarzan",
///     quote: "AAAAaAaAaAyAAAAaAaAaAyAAAAaAaAaA",
///     pets: [
///       User_Pet(
///         name: "Cheeta",
///         heightInMeters: 1.67,
///         picture: "🐒",
///       ),
///     ],
///   )
///   ```
///
/// Example output:
///   ```dart
///   User(
///     userId: 123,
///     name: "TARZAN",
///     quote: "AAAAAAAAAAYAAAAAAAAAAYAAAAAAAAAA",
///     pets: [
///       User_Pet(
///         name: "CHEETA",
///         heightInMeters: 1.67,
///         picture: "🐒",
///       ),
///     ],
///   )
///   ```
///
T allStringsToUpperCase<T>(
    T input, skir.ReflectiveTypeDescriptor<T> descriptor) {
  final visitor = _ToUpperCaseVisitor<T>(input);
  descriptor.accept(visitor);
  return visitor.result;
}

class _ToUpperCaseTransformer implements skir.ReflectiveTransformer {
  const _ToUpperCaseTransformer();

  @override
  T transform<T>(T input, skir.ReflectiveTypeDescriptor<T> descriptor) {
    return allStringsToUpperCase(input, descriptor);
  }
}

class _ToUpperCaseVisitor<T> extends skir.NoopReflectiveTypeVisitor<T> {
  final T input;
  T result;

  _ToUpperCaseVisitor(this.input) : result = input;
  @override
  void visitOptional<NotNull>(
      skir.ReflectiveOptionalDescriptor<NotNull> descriptor,
      skir.TypeEquivalence<T, NotNull?> equivalence) {
    result = equivalence.toT(
      descriptor.map(
        equivalence.fromT(input),
        const _ToUpperCaseTransformer(),
      ),
    );
  }

  @override
  void visitArray<E, Collection extends Iterable<E>>(
      skir.ReflectiveArrayDescriptor<E, Collection> descriptor,
      skir.TypeEquivalence<T, Collection> equivalence) {
    result = equivalence.toT(
      descriptor.map(
        equivalence.fromT(input),
        const _ToUpperCaseTransformer(),
      ),
    );
  }

  @override
  void visitStruct<Mutable>(
      skir.ReflectiveStructDescriptor<T, Mutable> descriptor) {
    result = descriptor.mapFields(input, const _ToUpperCaseTransformer());
  }

  @override
  void visitEnum(skir.ReflectiveEnumDescriptor<T> descriptor) {
    result = descriptor.mapValue(
      input,
      const _ToUpperCaseTransformer(),
    );
  }

  @override
  void visitString(skir.TypeEquivalence<T, String> equivalence) {
    result = equivalence.toT(
      equivalence.fromT(input).toUpperCase(),
    );
  }
}
