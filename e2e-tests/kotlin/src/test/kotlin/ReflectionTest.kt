package build.skir

import com.google.common.truth.Truth.assertThat
import org.junit.jupiter.api.Test

class ReflectionTest {
    @Test
    fun `test generated struct - toString()`() {
        assertThat(
            skirout.full_name.FullName(
                firstName = "foo",
                lastName = "bar",
            ),
        )
    }
}
