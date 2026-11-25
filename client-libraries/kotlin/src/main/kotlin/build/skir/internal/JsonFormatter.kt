package build.skir.internal

import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive

fun formatDenseJson(element: JsonElement): String {
    val stringBuilder = StringBuilder()
    formatDenseJson(element, stringBuilder)
    return stringBuilder.toString()
}

private fun formatDenseJson(
    element: JsonElement,
    out: StringBuilder,
) {
    when (element) {
        is JsonObject -> {
            val iterator = element.iterator()
            if (iterator.hasNext()) {
                val first = iterator.next()
                // In practice there can't be special characters in our keys so we don't
                // need to escape.
                out.append("{\"").append(first.key).append("\":")
                formatDenseJson(first.value, out)
                while (iterator.hasNext()) {
                    val next = iterator.next()
                    out.append(",\"").append(next.key).append("\":")
                    formatDenseJson(next.value, out)
                }
                out.append('}')
            } else {
                out.append("{}")
            }
        }
        is JsonArray -> {
            val iterator = element.iterator()
            if (iterator.hasNext()) {
                out.append('[')
                formatDenseJson(iterator.next(), out)
                while (iterator.hasNext()) {
                    out.append(',')
                    formatDenseJson(iterator.next(), out)
                }
                out.append(']')
            } else {
                out.append("[]")
            }
        }
        is JsonPrimitive -> {
            out.append(element)
        }
    }
}

fun formatReadableJson(element: JsonElement): String {
    val stringBuilder = StringBuilder()
    formatReadableJson(element, "", stringBuilder)
    return stringBuilder.toString()
}

private fun formatReadableJson(
    element: JsonElement,
    indent: String,
    out: StringBuilder,
) {
    when (element) {
        is JsonObject -> {
            val iterator = element.iterator()
            if (iterator.hasNext()) {
                val newIndent = indent + INDENT_UNIT
                out.append("{\n").append(newIndent)
                val first = iterator.next()
                out.append('\"').append(first.key).append("\": ")
                formatReadableJson(first.value, newIndent, out)
                while (iterator.hasNext()) {
                    out.append(",\n").append(newIndent)
                    val entry = iterator.next()
                    out.append('\"').append(entry.key).append("\": ")
                    formatReadableJson(entry.value, newIndent, out)
                }
                out.append('\n').append(indent).append('}')
            } else {
                out.append("{}")
            }
        }
        is JsonArray -> {
            val iterator = element.iterator()
            if (iterator.hasNext()) {
                val newIndent = indent + INDENT_UNIT
                out.append("[\n").append(newIndent)
                formatReadableJson(iterator.next(), newIndent, out)
                while (iterator.hasNext()) {
                    out.append(",\n").append(newIndent)
                    formatReadableJson(iterator.next(), newIndent, out)
                }
                out.append('\n').append(indent).append(']')
            } else {
                out.append("[]")
            }
        }
        is JsonPrimitive -> {
            out.append(element)
        }
    }
}
