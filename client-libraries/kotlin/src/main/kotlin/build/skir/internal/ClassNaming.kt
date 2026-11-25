package build.skir.internal

import kotlin.reflect.KClass

internal fun getClassNameWithoutPackage(clazz: KClass<*>): String? {
    val qualifiedName = clazz.qualifiedName ?: return null
    val packageName = clazz.java.packageName
    return if (packageName.isNotEmpty()) {
        qualifiedName.removePrefix("$packageName.")
    } else {
        qualifiedName
    }
}
