package build.skir.reflection

import okio.ByteString
import java.time.Instant

/**
 * Visitor for performing type-specific reflective operations on Skir types.
 *
 * Implement this interface to execute different logic based on whether a type
 * is a struct, enum, optional, array, or primitive. While you could achieve
 * the same using when expressions on [TypeDescriptor.Reflective], this visitor
 * provides type safety that's difficult to achieve manually.
 *
 * For example, when visiting an [ArrayDescriptor.Reflective], the [visitArray]
 * method receives type parameter `E` representing the element type, allowing
 * the compiler to enforce type correctness throughout your implementation.
 *
 * Usage: write your own implementations of this interface, which can possibly
 * extend [ReflectiveTypeVisitor.Noop], and pass it to methods such as
 * [TypeDescriptor.Reflective.accept].
 *
 * See a complete example at
 * https://github.com/gepheum/skir-java-example/blob/main/src/main/java/examples/AllStringsToUpperCase.java
 */
interface ReflectiveTypeVisitor<T> {
    /** Visits a struct type. */
    fun <Mutable> visitStruct(descriptor: StructDescriptor.Reflective<T, Mutable>)

    /** Visits an enum type. */
    fun visitEnum(descriptor: EnumDescriptor.Reflective<T>)

    /**
     * Visits an optional type (nullable type).
     *
     * [equivalence] allows safe conversion between [T] and [NotNull?].
     */
    fun <NotNull : Any> visitOptional(
        descriptor: OptionalDescriptor.Reflective<NotNull>,
        equivalence: TypeEquivalence<T, NotNull?>,
    )

    /**
     * Visits an optional type (nullable type) for Java interop.
     *
     * [equivalence] allows safe conversion between [T] and [java.util.Optional<Other>].
     */
    fun <Other : Any> visitJavaOptional(
        descriptor: OptionalDescriptor.JavaReflective<Other>,
        equivalence: TypeEquivalence<T, java.util.Optional<Other>>,
    )

    /**
     * Visits an array type.
     *
     * [equivalence] allows safe conversion between [T] and [L].
     */
    fun <E, L : List<E>> visitArray(
        descriptor: ArrayDescriptor.Reflective<E, L>,
        equivalence: TypeEquivalence<T, L>,
    )

    /** Visits a boolean primitive type. */
    fun visitBool(equivalence: TypeEquivalence<T, Boolean>)

    /** Visits a 32-bit signed integer primitive type. */
    fun visitInt32(equivalence: TypeEquivalence<T, Int>)

    /** Visits a 64-bit signed integer primitive type. */
    fun visitInt64(equivalence: TypeEquivalence<T, Long>)

    /** Visits a 64-bit unsigned integer primitive type. */
    fun visitHash64(equivalence: TypeEquivalence<T, ULong>)

    /** Visits a 64-bit unsigned integer primitive type (Java compatible). */
    fun visitJavaHash64(equivalence: TypeEquivalence<T, Long>)

    /** Visits a 32-bit floating point primitive type. */
    fun visitFloat32(equivalence: TypeEquivalence<T, Float>)

    /** Visits a 64-bit floating point primitive type. */
    fun visitFloat64(equivalence: TypeEquivalence<T, Double>)

    /** Visits a timestamp primitive type. */
    fun visitTimestamp(equivalence: TypeEquivalence<T, Instant>)

    /** Visits a string primitive type. */
    fun visitString(equivalence: TypeEquivalence<T, String>)

    /** Visits a bytes primitive type. */
    fun visitBytes(equivalence: TypeEquivalence<T, ByteString>)

    /**
     * 🪞 A no-op implementation of [ReflectiveTypeVisitor] that does nothing for
     * each visit method.
     *
     * This class is useful as a base class when you only need to override a few
     * specific visit methods while leaving the others as no-ops.
     *
     * See a complete example at
     * https://github.com/gepheum/skir-java-example/blob/main/src/main/java/examples/AllStringsToUpperCase.java
     */
    open class Noop<T> : ReflectiveTypeVisitor<T> {
        override fun <Mutable> visitStruct(descriptor: StructDescriptor.Reflective<T, Mutable>) {
        }

        override fun visitEnum(descriptor: EnumDescriptor.Reflective<T>) {
        }

        override fun <NotNull : Any> visitOptional(
            descriptor: OptionalDescriptor.Reflective<NotNull>,
            equivalence: TypeEquivalence<T, NotNull?>,
        ) {
        }

        override fun <Other : Any> visitJavaOptional(
            descriptor: OptionalDescriptor.JavaReflective<Other>,
            equivalence: TypeEquivalence<T, java.util.Optional<Other>>,
        ) {
        }

        override fun <E, L : List<E>> visitArray(
            descriptor: ArrayDescriptor.Reflective<E, L>,
            equivalence: TypeEquivalence<T, L>,
        ) {
        }

        override fun visitBool(equivalence: TypeEquivalence<T, Boolean>) {
        }

        override fun visitInt32(equivalence: TypeEquivalence<T, Int>) {
        }

        override fun visitInt64(equivalence: TypeEquivalence<T, Long>) {
        }

        override fun visitHash64(equivalence: TypeEquivalence<T, ULong>) {
        }

        override fun visitJavaHash64(equivalence: TypeEquivalence<T, Long>) {
        }

        override fun visitFloat32(equivalence: TypeEquivalence<T, Float>) {
        }

        override fun visitFloat64(equivalence: TypeEquivalence<T, Double>) {
        }

        override fun visitTimestamp(equivalence: TypeEquivalence<T, Instant>) {
        }

        override fun visitString(equivalence: TypeEquivalence<T, String>) {
        }

        override fun visitBytes(equivalence: TypeEquivalence<T, ByteString>) {
        }
    }

    companion object {
        internal fun <T> acceptImpl(
            descriptor: TypeDescriptor.Reflective<T>,
            visitor: ReflectiveTypeVisitor<T>,
        ) {
            when (descriptor) {
                is StructDescriptor.Reflective<*, *> -> {
                    @Suppress("UNCHECKED_CAST")
                    visitor.visitStruct(
                        descriptor as StructDescriptor.Reflective<T, Any>,
                    )
                }
                is EnumDescriptor.Reflective<*> -> {
                    visitor.visitEnum(
                        descriptor as EnumDescriptor.Reflective<T>,
                    )
                }
                is OptionalDescriptor.Reflective<*> -> {
                    @Suppress("UNCHECKED_CAST")
                    visitOptionalImpl(
                        descriptor as OptionalDescriptor.Reflective<Any>,
                        visitor,
                    )
                }
                is OptionalDescriptor.JavaReflective<*> -> {
                    @Suppress("UNCHECKED_CAST")
                    visitJavaOptionalImpl(
                        descriptor as OptionalDescriptor.JavaReflective<Any>,
                        visitor,
                    )
                }
                is ArrayDescriptor.Reflective<*, *> -> {
                    @Suppress("UNCHECKED_CAST")
                    visitArrayImpl(
                        descriptor as ArrayDescriptor.Reflective<Any?, List<Any?>>,
                        visitor,
                    )
                }
                PrimitiveDescriptor.Reflective.Bool -> {
                    visitor.visitBool(TypeEquivalence.get())
                }
                PrimitiveDescriptor.Reflective.Int32 -> {
                    visitor.visitInt32(TypeEquivalence.get())
                }
                PrimitiveDescriptor.Reflective.Int64 -> {
                    visitor.visitInt64(TypeEquivalence.get())
                }
                PrimitiveDescriptor.Reflective.Hash64 -> {
                    visitor.visitHash64(TypeEquivalence.get())
                }
                PrimitiveDescriptor.Reflective.JavaHash64 -> {
                    visitor.visitJavaHash64(TypeEquivalence.get())
                }
                PrimitiveDescriptor.Reflective.Float32 -> {
                    visitor.visitFloat32(TypeEquivalence.get())
                }
                PrimitiveDescriptor.Reflective.Float64 -> {
                    visitor.visitFloat64(TypeEquivalence.get())
                }
                PrimitiveDescriptor.Reflective.Timestamp -> {
                    visitor.visitTimestamp(TypeEquivalence.get())
                }
                PrimitiveDescriptor.Reflective.String -> {
                    visitor.visitString(TypeEquivalence.get())
                }
                PrimitiveDescriptor.Reflective.Bytes -> {
                    visitor.visitBytes(TypeEquivalence.get())
                }
            }
        }

        private fun <NotNull : Any, T> visitOptionalImpl(
            descriptor: OptionalDescriptor.Reflective<NotNull>,
            visitor: ReflectiveTypeVisitor<T>,
        ) {
            visitor.visitOptional(
                descriptor,
                TypeEquivalence.get(),
            )
        }

        private fun <Other : Any, T> visitJavaOptionalImpl(
            descriptor: OptionalDescriptor.JavaReflective<Other>,
            visitor: ReflectiveTypeVisitor<T>,
        ) {
            visitor.visitJavaOptional(
                descriptor,
                TypeEquivalence.get(),
            )
        }

        private fun <E, L : List<E>, T> visitArrayImpl(
            descriptor: ArrayDescriptor.Reflective<E, L>,
            visitor: ReflectiveTypeVisitor<T>,
        ) {
            visitor.visitArray(
                descriptor,
                TypeEquivalence.get(),
            )
        }
    }
}
