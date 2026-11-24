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

/**
 * Using reflection, converts all the strings contained in [input] to upper case. Accepts
 * any Skir type.
 *
 * Example input:
 * ```
 * {
 *   "user_id": 123,
 *   "name": "Tarzan",
 *   "quote": "AAAAaAaAaAyAAAAaAaAaAyAAAAaAaAaA",
 *   "pets": [
 *     {
 *       "name": "Cheeta",
 *       "height_in_meters": 1.67,
 *       "picture": "🐒"
 *     }
 *   ],
 *   "subscription_status": {
 *     "kind": "trial",
 *     "value": {
 *       "start_time": {
 *         "unix_millis": 1743592409000,
 *         "formatted": "2025-04-02T11:13:29Z"
 *       }
 *     }
 *   }
 * }
 * ```
 *
 * Example output:
 * ```
 * {
 *   "user_id": 123,
 *   "name": "TARZAN",
 *   "quote": "AAAAAAAAAAYAAAAAAAAAAYAAAAAAAAAA",
 *   "pets": [
 *     {
 *       "name": "CHEETA",
 *       "height_in_meters": 1.67,
 *       "picture": "🐒"
 *     }
 *   ],
 *   "subscription_status": {
 *     "kind": "trial",
 *     "value": {
 *       "start_time": {
 *         "unix_millis": 1743592409000,
 *         "formatted": "2025-04-02T11:13:29Z"
 *       }
 *     }
 *   }
 * }
 * ```
 */
fun <T> allStringsToUpperCase(
    input: T,
    descriptor: TypeDescriptor.Reflective<T>,
): T {
    val visitor = ToUpperCaseVisitor(input)
    descriptor.accept(visitor)
    return visitor.result
}

private object ToUpperCaseTransformer : ReflectiveTransformer {
    override fun <T> transform(
        input: T,
        descriptor: TypeDescriptor.Reflective<T>,
    ): T {
        return allStringsToUpperCase(input, descriptor)
    }
}

private class ToUpperCaseVisitor<T>(val input: T) : ReflectiveTypeVisitor.Noop<T>() {
    var result: T = input

    override fun <NotNull : Any> visitOptional(
        descriptor: OptionalDescriptor.Reflective<NotNull>,
        equivalence: TypeEquivalence<T, NotNull?>,
    ) {
        result =
            equivalence.toT(
                descriptor.map(equivalence.fromT(input), ToUpperCaseTransformer),
            )
    }

    override fun <Other : Any> visitJavaOptional(
        descriptor: OptionalDescriptor.JavaReflective<Other>,
        equivalence: TypeEquivalence<T, java.util.Optional<Other>>,
    ) {
        result =
            equivalence.toT(
                descriptor.map(equivalence.fromT(input), ToUpperCaseTransformer),
            )
    }

    override fun <E, L : List<E>> visitArray(
        descriptor: ArrayDescriptor.Reflective<E, L>,
        equivalence: TypeEquivalence<T, L>,
    ) {
        result =
            equivalence.toT(
                descriptor.map(equivalence.fromT(input), ToUpperCaseTransformer),
            )
    }

    override fun <Mutable> visitStruct(descriptor: StructDescriptor.Reflective<T, Mutable>) {
        val transformed = descriptor.mapFields(input, ToUpperCaseTransformer)
        result = transformed
    }

    override fun visitEnum(descriptor: EnumDescriptor.Reflective<T>) {
        result = descriptor.mapValue(input, ToUpperCaseTransformer)
    }

    override fun visitString(equivalence: TypeEquivalence<T, String>) {
        result = equivalence.toT(equivalence.fromT(input).uppercase())
    }
}
