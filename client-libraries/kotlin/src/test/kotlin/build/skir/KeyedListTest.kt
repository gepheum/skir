package build.skir

import build.skir.internal.toKeyedList
import com.google.common.truth.Truth.assertThat
import org.junit.jupiter.api.Test

class KeyedListTest {
    @Test
    fun `test keyed list - works`() {
        val keyedList = KeyedList.toKeyedList(listOf("a", "bb", "ccc"), { it.length })
        assertThat(keyedList.size).isEqualTo(3)
        assertThat(keyedList).isEqualTo(listOf("a", "bb", "ccc"))
        assertThat(keyedList.mapView).isEqualTo(
            mapOf(
                1 to "a",
                2 to "bb",
                3 to "ccc",
            ),
        )
        assertThat(keyedList.findByKey(2)).isEqualTo("bb")
        assertThat(keyedList.findByKey(4)).isEqualTo(null)
    }

    @Test
    fun `test keyed list - duplicate keys`() {
        val keyedList = KeyedList.toKeyedList(listOf("a", "bb", "cc"), { it.length })
        assertThat(keyedList.mapView).isEqualTo(
            mapOf(
                1 to "a",
                2 to "cc",
            ),
        )
    }

    @Test
    fun `test keyed list - empty`() {
        val keyedList = KeyedList.toKeyedList(emptyList<String>(), { it.length })
        assertThat(keyedList).isSameInstanceAs(KeyedList.toKeyedList(emptyList<String>(), { it.length }))
        assertThat(keyedList.mapView).isEqualTo(emptyMap<Int, String>())
        assertThat(keyedList.findByKey(2)).isEqualTo(null)
    }

    @Test
    fun `test keyed list - copy or not`() {
        val keyedList = toKeyedList(listOf("a", "bb", "cc"), "foo", { it.length })
        assertThat(
            KeyedList.toKeyedList(keyedList, { it.length }),
        ).isNotSameInstanceAs(keyedList)
        assertThat(
            toKeyedList(keyedList, "bar", { it.length }),
        ).isNotSameInstanceAs(keyedList)
        assertThat(
            toKeyedList(keyedList, "foo", { it.length }),
        ).isSameInstanceAs(keyedList)
    }
}
