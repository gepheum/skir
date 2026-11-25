package build.skir.internal

import build.skir.Serializer

fun <T> makeSerializer(impl: SerializerImpl<T>): Serializer<T> {
    return Serializer(impl)
}
