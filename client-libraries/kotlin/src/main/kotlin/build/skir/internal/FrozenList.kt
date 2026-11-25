package build.skir.internal

import build.skir.KeyedList
import java.util.Collections

fun <M, E> toFrozenList(
    elements: Iterable<M>,
    toFrozen: (M) -> E,
): List<E> {
    return if (elements is FrozenList) {
        @Suppress("UNCHECKED_CAST")
        elements as List<E>
    } else {
        val result = FrozenList(elements.map(toFrozen))
        if (result.isEmpty()) emptyFrozenList() else result
    }
}

fun <E> toFrozenList(elements: Iterable<E>): List<E> {
    return toFrozenList(elements) { it }
}

@Suppress("UNCHECKED_CAST")
fun <M, E, K> toKeyedList(
    elements: Iterable<M>,
    getKeySpec: String,
    getKey: (E) -> K,
    toFrozen: (M) -> E,
): KeyedList<E, K> {
    return if (elements is KeyedListImpl<*, *> &&
        elements.getKeySpec.isNotEmpty() &&
        elements.getKeySpec == getKeySpec
    ) {
        elements as KeyedList<E, K>
    } else {
        val result = KeyedListImpl(elements.map(toFrozen), getKeySpec, getKey)
        if (result.isEmpty()) emptyKeyedList() else result
    }
}

fun <E, K> toKeyedList(
    elements: Iterable<E>,
    getKeySpec: String,
    getKey: (E) -> K,
): KeyedList<E, K> {
    return toKeyedList(elements, getKeySpec, getKey) { it }
}

@Suppress("UNCHECKED_CAST")
fun <E> emptyFrozenList(): List<E> = FrozenEmptyList as List<E>

@Suppress("UNCHECKED_CAST")
fun <E, K> emptyKeyedList(): KeyedList<E, K> = FrozenEmptyList as KeyedList<E, K>

private open class FrozenList<E>(
    val list: List<E>,
) : List<E> by list {
    override fun iterator(): Iterator<E> = Collections.unmodifiableList(list).iterator()

    override fun listIterator(): ListIterator<E> = Collections.unmodifiableList(list).listIterator()

    override fun listIterator(index: Int): ListIterator<E> = Collections.unmodifiableList(list).listIterator(index)

    override fun subList(
        fromIndex: Int,
        toIndex: Int,
    ): List<E> {
        return FrozenList(list.subList(fromIndex, toIndex))
    }

    override fun equals(other: Any?): Boolean {
        return list == other
    }

    override fun hashCode(): Int {
        return list.hashCode()
    }

    override fun toString(): String {
        return list.toString()
    }
}

private open class KeyedListImpl<E, K>(
    list: List<E>,
    val getKeySpec: String,
    val getKey: (E) -> K,
) : FrozenList<E>(list), KeyedList<E, K> {
    override val mapView: Map<K, E> by lazy {
        list.associateBy(getKey)
    }

    override fun findByKey(key: K): E? {
        return mapView[key]
    }
}

private object FrozenEmptyList : FrozenList<Any>(emptyList()), KeyedList<Any, Any> {
    override val mapView: Map<Any, Any>
        get() = emptyMap()

    override fun findByKey(key: Any): Any? {
        return null
    }
}
