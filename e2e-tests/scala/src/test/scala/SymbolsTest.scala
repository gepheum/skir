import com.google.common.truth.Truth.assertThat
import org.junit.jupiter.api.Test
import symbols_check.rebuild
import scala.jdk.CollectionConverters.*

class SymbolsTest {
  @Test
  def testSymbolProviderRebuildsConstantAndWrapperVariants(): Unit = {
    val values = Seq(
      skirout.enums.JsonValue.NULL,
      skirout.enums.JsonValue.BooleanWrapper(true),
      skirout.enums.JsonValue.StringWrapper("skir"),
      skirout.enums.JsonValue.ArrayWrapper(
        Seq(skirout.enums.JsonValue.NumberWrapper(1.0)).asJava,
      ),
    )
    for (value <- values) {
      assertThat(value.rebuild()).isEqualTo(value)
    }
  }

  @Test
  def testSymbolProviderRebuildsVariantsWithConflictingNames(): Unit = {
    val values = Seq(
      skirout.enums.EnumWithNameConflict.SERIALIZER,
      skirout.enums.EnumWithNameConflict.IfWrapper(true),
      skirout.enums.EnumWithNameConflict.FooWrapper(1),
      skirout.enums.EnumWithNameConflict.FooWrapperWrapper(2),
    )
    for (value <- values) {
      assertThat(value.rebuild()).isEqualTo(value)
    }
  }
}
