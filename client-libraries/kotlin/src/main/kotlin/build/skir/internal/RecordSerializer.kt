package build.skir.internal

import build.skir.reflection.FieldOrVariant
import build.skir.reflection.RecordDescriptor
import build.skir.reflection.RecordDescriptorBase
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive

sealed class RecordSerializer<T, Field : FieldOrVariant> : SerializerImpl<T>(), RecordDescriptorBase {
    internal abstract val parsedRecordId: RecordId
    abstract override val doc: String

    abstract override val typeDescriptor: RecordDescriptor.Reflective<T, Field>

    final override val name: String
        get() = parsedRecordId.name

    final override val qualifiedName: String
        get() = parsedRecordId.qualifiedName

    final override val modulePath: String
        get() = parsedRecordId.modulePath

    final override val typeSignature: JsonElement
        get() =
            JsonObject(
                mapOf(
                    "kind" to JsonPrimitive("record"),
                    "value" to JsonPrimitive(parsedRecordId.recordId),
                ),
            )
}
