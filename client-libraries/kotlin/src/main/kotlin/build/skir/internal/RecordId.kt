package build.skir.internal

internal data class RecordId(
    val recordId: String,
    val modulePath: String,
    val name: String,
    val qualifiedName: String,
    private val nameParts: List<String>,
) {
    companion object {
        fun parse(recordId: String): RecordId {
            val colonIndex = recordId.lastIndexOf(":")
            val modulePath = recordId.substring(0, colonIndex)
            val qualifiedName = recordId.substring(colonIndex + 1)
            val nameParts = qualifiedName.split(".")
            return RecordId(
                recordId = recordId,
                modulePath = modulePath,
                name = nameParts.last(),
                qualifiedName = qualifiedName,
                nameParts = nameParts,
            )
        }
    }

    val parentId: String? by lazy {
        if (nameParts.size <= 1) {
            null
        } else {
            val parentNameParts = nameParts.subList(0, nameParts.size - 1)
            parentNameParts.joinToString(".")
        }
    }
}
