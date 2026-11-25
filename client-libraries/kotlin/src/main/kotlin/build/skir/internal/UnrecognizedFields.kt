package build.skir.internal

import kotlinx.serialization.json.JsonElement
import okio.ByteString

class UnrecognizedFields<T> private constructor(
    internal val totalSlotCount: Int,
    internal val jsonElements: List<JsonElement>?,
    internal val bytes: ByteString?,
) {
    internal constructor(
        totalSlotCount: Int,
        jsonElements: List<JsonElement>,
    ) : this(totalSlotCount, jsonElements, null)

    internal constructor(
        totalSlotCount: Int,
        bytes: ByteString,
    ) : this(totalSlotCount, null, bytes)
}
