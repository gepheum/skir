package build.skir.reflection

/**
 * A witness that two types [T] and [U] are guaranteed to be identical at runtime, even
 * if the compiler sees them as different types.
 *
 * Provides safe casting methods to make the compiler happy.
 */
sealed class TypeEquivalence<T, U> {
    /** Converts from type [U] to type [T]. */
    @Suppress("UNCHECKED_CAST")
    fun toT(u: U): T = u as T

    /** Converts from type [T] to type [U]. */
    @Suppress("UNCHECKED_CAST")
    fun fromT(t: T): U = t as U

    private data object Instance : TypeEquivalence<Nothing, Nothing>()

    companion object {
        @Suppress("UNCHECKED_CAST")
        internal fun <T, U> get(): TypeEquivalence<T, U> = Instance as TypeEquivalence<T, U>
    }
}
