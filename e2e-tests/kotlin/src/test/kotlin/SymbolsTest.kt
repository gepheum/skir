import com.google.common.truth.Truth.assertThat
import org.junit.jupiter.api.Test
import symbols_check.rebuild

/**
 * The symbols_check companion generator rebuilds every enum variant with the
 * provider's constructor from the value its value accessor reads, so a
 * rebuilt value equals the original only if both symbols agree with the
 * generated code.
 */
class SymbolsTest {
    @Test
    fun `symbol provider rebuilds constant and wrapper variants`() {
        val values =
            listOf(
                skirout.enums.JsonValue.NULL,
                skirout.enums.JsonValue.BooleanWrapper(true),
                skirout.enums.JsonValue.StringWrapper("skir"),
                skirout.enums.JsonValue.ArrayWrapper(listOf(skirout.enums.JsonValue.NumberWrapper(1.0))),
            )
        for (value in values) {
            assertThat(value.rebuild()).isEqualTo(value)
        }
    }

    @Test
    fun `symbol provider rebuilds variants with conflicting names`() {
        val values =
            listOf(
                skirout.enums.EnumWithNameConflict.SERIALIZER,
                skirout.enums.EnumWithNameConflict.IfWrapper(true),
                skirout.enums.EnumWithNameConflict.FooWrapper(1),
                skirout.enums.EnumWithNameConflict.FooWrapperWrapper(2),
            )
        for (value in values) {
            assertThat(value.rebuild()).isEqualTo(value)
        }
    }
}
