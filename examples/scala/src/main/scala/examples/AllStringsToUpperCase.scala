// Reflection allows you to inspect and traverse Skir types and values at
// runtime.
//
// When *not* to use reflection: when working with a specific type known at
// compile-time, you can directly access the properties and constructor of the
// object, so you don't need reflection.
//
// When to use reflection: when the Skir type is passed as a parameter (like the
// generic T here), you need reflection - the ability to programmatically
// inspect a type's structure (fields, their types, etc.) and manipulate values
// without compile-time knowledge of that structure.
//
// This pattern is useful for building generic utilities like:
//   - Custom validators that work across all your types
//   - Custom formatters/normalizers (like this uppercase example)
//   - Serialization utilities
//   - Any operation that needs to work uniformly across different Skir types

package examples

import build.skir.reflection.ArrayDescriptor
import build.skir.reflection.EnumDescriptor
import build.skir.reflection.OptionalDescriptor
import build.skir.reflection.ReflectiveTransformer
import build.skir.reflection.ReflectiveTypeVisitor
import build.skir.reflection.StructDescriptor
import build.skir.reflection.TypeDescriptor
import build.skir.reflection.TypeEquivalence
import java.util.List
import java.util.Optional

object AllStringsToUpperCase:
  /**
   * Using reflection, converts all the strings contained in `input` to upper
   * case. Accepts any Skir type.
   */
  def allStringsToUpperCase[T](
    input: T,
    descriptor: TypeDescriptor.Reflective[T],
  ): T =
    val visitor = new ToUpperCaseVisitor[T](input)
    descriptor.accept(visitor)
    visitor.result

  private object ToUpperCaseTransformer extends ReflectiveTransformer:
    override def transform[T](
      input: T,
      descriptor: TypeDescriptor.Reflective[T],
    ): T =
      allStringsToUpperCase(input, descriptor)

  private class ToUpperCaseVisitor[T](val input: T)
      extends ReflectiveTypeVisitor.Noop[T]:
    var result: T = input

    override def visitOptional[NotNull](
      descriptor: OptionalDescriptor.Reflective[NotNull],
      equivalence: TypeEquivalence[T, NotNull],
    ): Unit =
      result = equivalence.toT(
        descriptor.map(equivalence.fromT(input), ToUpperCaseTransformer),
      )

    override def visitJavaOptional[NotNull](
      descriptor: OptionalDescriptor.JavaReflective[NotNull],
      equivalence: TypeEquivalence[T, Optional[NotNull]],
    ): Unit =
      result = equivalence.toT(
        descriptor.map(equivalence.fromT(input), ToUpperCaseTransformer),
      )

    override def visitArray[E, L <: List[? <: E]](
      descriptor: ArrayDescriptor.Reflective[E, L],
      equivalence: TypeEquivalence[T, L],
    ): Unit =
      result = equivalence.toT(
        descriptor.map(equivalence.fromT(input), ToUpperCaseTransformer),
      )

    override def visitStruct[Mutable](
      descriptor: StructDescriptor.Reflective[T, Mutable],
    ): Unit =
      result = descriptor.mapFields(input, ToUpperCaseTransformer)

    override def visitEnum(
      descriptor: EnumDescriptor.Reflective[T],
    ): Unit =
      result = descriptor.mapValue(input, ToUpperCaseTransformer)

    override def visitString(
      equivalence: TypeEquivalence[T, String],
    ): Unit =
      result = equivalence.toT(equivalence.fromT(input).toUpperCase())
