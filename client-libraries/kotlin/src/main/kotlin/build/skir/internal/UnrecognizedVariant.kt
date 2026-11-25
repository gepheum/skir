package build.skir.internal

import kotlinx.serialization.json.JsonElement
import okio.ByteString

class UnrecognizedVariant<Enum> private constructor(
    internal val jsonElement: JsonElement?,
    internal val bytes: ByteString?,
) {
    internal constructor(
        jsonElement: JsonElement,
    ) : this(jsonElement, null)

    internal constructor(
        bytes: ByteString,
    ) : this(null, bytes)
}
