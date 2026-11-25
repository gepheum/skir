package build.skir.internal

import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive

internal class JsonObjectBuilder {
    fun put(
        key: String,
        value: JsonElement,
    ): JsonObjectBuilder {
        map[key] = value
        return this
    }

    fun putUnlessEmpty(
        key: String,
        value: JsonElement,
    ): JsonObjectBuilder {
        val isEmpty =
            (value is JsonArray && value.isEmpty()) ||
                (value is JsonPrimitive && value.isString && value.content.isEmpty())
        if (!isEmpty) {
            map[key] = value
        }
        return this
    }

    fun build(): JsonObject {
        return JsonObject(map)
    }

    private val map = mutableMapOf<String, JsonElement>()
}
