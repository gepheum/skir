part of '../skir_client.dart';

/// 🪞 A function object that takes in a skir value of any type and returns a
/// new value of the same type.
///
/// Usage: write your own implementations of this interface, and pass it to
/// methods such as [ReflectiveStructDescriptor.mapFields] to recursively
/// transform a skir value.
///
/// See a complete example at
/// https://github.com/gepheum/skir-dart-example/blob/main/lib/all_strings_to_upper_case.dart
abstract class ReflectiveTransformer {
  /// Returns values unchanged.
  static const ReflectiveTransformer identity = _IdentityTransformer();

  /// Expects a skir value of any type, returns a value of the same type.
  T transform<T>(T input, ReflectiveTypeDescriptor<T> descriptor);

  const ReflectiveTransformer();
}

class _IdentityTransformer extends ReflectiveTransformer {
  const _IdentityTransformer();

  @override
  T transform<T>(T input, ReflectiveTypeDescriptor<T> descriptor) {
    return input;
  }
}
