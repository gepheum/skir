package build.skir

/**
 * An immutable list which exposes a [mapView] for fast lookups by key. A key is
 * extracted from each element using the function passed to [toKeyedList]. Each
 * element in the list is assumed to "contain" its own key.
 *
 * @param E The type of elements in the list; contains the key
 * @param K The type of keys used for indexing
 */
interface KeyedList<E, K> : List<E> {
    /**
     * A map that provides fast key-based access to elements in the list.
     *
     * The indexing, which runs in O(N), only happens the first time this map is
     * requested.
     *
     * If multiple elements have the same key, only the last one is added to the map.
     */
    val mapView: Map<K, E>

    /**
     * Returns the last element associated with the specified key.
     * Returns null if the key is not present.
     */
    fun findByKey(key: K): E?

    companion object {
        /**
         * Creates an immutable [KeyedList] from the given elements, using the provided function
         * to extract keys.
         *
         * @param elements The collection of elements to include in the keyed list
         * @param getKey A function that extracts the key from each element
         * @return A new KeyedList containing the elements with key-based indexing
         */
        @JvmStatic
        fun <E, K> toKeyedList(
            elements: Iterable<E>,
            getKey: (E) -> K,
        ): KeyedList<E, K> {
            return build.skir.internal.toKeyedList(elements, "", getKey) { it }
        }
    }
}
