package build.skir

import build.skir.reflection.ArrayDescriptor
import build.skir.reflection.EnumDescriptor
import build.skir.reflection.OptionalDescriptor
import build.skir.reflection.PrimitiveDescriptor
import build.skir.reflection.ReflectiveTransformer
import build.skir.reflection.ReflectiveTypeVisitor
import build.skir.reflection.StructDescriptor
import build.skir.reflection.TypeDescriptor
import build.skir.reflection.TypeEquivalence
import com.google.common.truth.Truth.assertThat
import org.junit.jupiter.api.Test
import java.util.Optional

class ReflectionTest {
    @Test
    fun `test allStringsToUpperCase with string`() {
        val input = "hello world"
        val result = allStringsToUpperCase(input, PrimitiveDescriptor.Reflective.String)
        assertThat(result).isEqualTo("HELLO WORLD")
    }

    @Test
    fun `test allStringsToUpperCase with array of strings`() {
        // Create a simple reflective array descriptor for List<String>
        val descriptor = build.skir.Serializers.list(build.skir.Serializers.string).typeDescriptor

        val input = listOf("hello", "world", "foo")
        val result = allStringsToUpperCase(input, descriptor)
        assertThat(result).isEqualTo(listOf("HELLO", "WORLD", "FOO"))
    }

    @Test
    fun `test allStringsToUpperCase with java optional string`() {
        val descriptor =
            object : OptionalDescriptor.JavaReflective<String> {
                override val otherType: TypeDescriptor.Reflective<String>
                    get() = PrimitiveDescriptor.Reflective.String
            }

        val input = Optional.of("hello")
        val result = allStringsToUpperCase(input, descriptor)
        assertThat(result.isPresent).isTrue()
        assertThat(result.get()).isEqualTo("HELLO")

        val emptyInput = Optional.empty<String>()
        val emptyResult = allStringsToUpperCase(emptyInput, descriptor)
        assertThat(emptyResult.isPresent).isFalse()
    }

    @Test
    fun `test allStringsToUpperCase with nullable string`() {
        val descriptor =
            object : OptionalDescriptor.Reflective<String> {
                override val otherType: TypeDescriptor.Reflective<String>
                    get() = PrimitiveDescriptor.Reflective.String
            }

        var input: String? = "hello"
        var result = allStringsToUpperCase(input, descriptor)
        assertThat(result).isEqualTo("HELLO")

        input = null
        result = allStringsToUpperCase(input, descriptor)
        assertThat(result).isEqualTo(null)

        val nullInput: String? = null
        val nullResult = allStringsToUpperCase(nullInput, descriptor)
        assertThat(nullResult).isNull()
    }
}

/**
 * Using reflection, converts all the strings contained in [input] to upper case.
 * Accepts any Skir type.
 *
 * This pattern is useful for building generic utilities like:
 * - Custom validators that work across all your types
 * - Custom formatters/normalizers (like this uppercase example)
 * - Serialization utilities
 * - Any operation that needs to work uniformly across different Skir types
 */
fun <T> allStringsToUpperCase(
    input: T,
    descriptor: TypeDescriptor.Reflective<T>,
): T {
    val visitor = ToUpperCaseVisitor(input)
    descriptor.accept(visitor)
    return visitor.result
}

private class ToUpperCaseTransformer : ReflectiveTransformer {
    override fun <T> transform(
        input: T,
        descriptor: TypeDescriptor.Reflective<T>,
    ): T {
        return allStringsToUpperCase(input, descriptor)
    }

    companion object {
        val INSTANCE = ToUpperCaseTransformer()
    }
}

private class ToUpperCaseVisitor<T>(
    val input: T,
) : ReflectiveTypeVisitor.Noop<T>() {
    var result: T = input

    override fun <NotNull : Any> visitOptional(
        descriptor: OptionalDescriptor.Reflective<NotNull>,
        equivalence: TypeEquivalence<T, NotNull?>,
    ) {
        result =
            equivalence.toT(
                descriptor.map(
                    equivalence.fromT(input),
                    ToUpperCaseTransformer.INSTANCE,
                ),
            )
    }

    override fun <NotNull : Any> visitJavaOptional(
        descriptor: OptionalDescriptor.JavaReflective<NotNull>,
        equivalence: TypeEquivalence<T, Optional<NotNull>>,
    ) {
        result =
            equivalence.toT(
                descriptor.map(
                    equivalence.fromT(input),
                    ToUpperCaseTransformer.INSTANCE,
                ),
            )
    }

    override fun <E, L : List<E>> visitArray(
        descriptor: ArrayDescriptor.Reflective<E, L>,
        equivalence: TypeEquivalence<T, L>,
    ) {
        result =
            equivalence.toT(
                descriptor.map(
                    equivalence.fromT(input),
                    ToUpperCaseTransformer.INSTANCE,
                ),
            )
    }

    override fun <Mutable> visitStruct(descriptor: StructDescriptor.Reflective<T, Mutable>) {
        result = descriptor.mapFields(input, ToUpperCaseTransformer.INSTANCE)
    }

    override fun visitEnum(descriptor: EnumDescriptor.Reflective<T>) {
        result =
            descriptor.mapValue(
                input,
                ToUpperCaseTransformer.INSTANCE,
            )
    }

    override fun visitString(equivalence: TypeEquivalence<T, String>) {
        result =
            equivalence.toT(
                equivalence.fromT(input).uppercase(),
            )
    }
}
