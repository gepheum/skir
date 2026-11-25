package build.skir.internal

import okio.Buffer

/**
 * Rejects JSON whose container nesting exceeds [maxNestingDepth], without recursive parsing.
 * Scalars have depth 0; arrays and objects add one level, even when empty.
 * This is a depth check, not a full JSON validator.
 */
internal fun expectDepthWithinLimit(
    jsonCode: String,
    maxNestingDepth: Int,
) {
    require(maxNestingDepth >= 0) { "maxNestingDepth must be non-negative" }
    var depth = 0
    var inString = false
    var escaped = false
    for (character in jsonCode) {
        if (inString) {
            when {
                escaped -> escaped = false
                character == '\\' -> escaped = true
                character == '"' -> inString = false
            }
        } else {
            when (character) {
                '"' -> inString = true
                '[', '{' -> {
                    depth++
                    require(depth <= maxNestingDepth) { "Maximum JSON nesting depth $maxNestingDepth exceeded" }
                }
                ']', '}' -> {
                    depth--
                    require(depth >= 0) { "Unmatched JSON closing delimiter" }
                }
            }
        }
    }
    require(!inString && depth == 0) { "Unterminated JSON string or container" }
}

/**
 * Checks Skir binary data positioned after the "skir" prefix.
 * Leaves [buffer] unchanged. Binary arrays and value-bearing enum wrappers add
 * one nesting level; scalar values have depth 0.
 */
internal fun expectDepthWithinLimit(
    buffer: Buffer,
    maxNestingDepth: Int,
) {
    require(maxNestingDepth >= 0) { "maxNestingDepth must be non-negative" }
    val input = buffer.copy()
    val remaining = ArrayDeque<Long>()
    remaining.addLast(1L)
    while (remaining.isNotEmpty()) {
        if (remaining.last() == 0L) {
            remaining.removeLast()
            continue
        }
        remaining[remaining.lastIndex] -= 1L
        val wire = input.readByte().toInt() and 0xFF
        val children =
            when (wire) {
                232, 236 -> {
                    input.skip(2)
                    0L
                }
                233, 237, 240 -> {
                    input.skip(4)
                    0L
                }
                234, 238, 239, 241 -> {
                    input.skip(8)
                    0L
                }
                235 -> {
                    input.skip(1)
                    0L
                }
                243, 245 -> {
                    val length = decodeNumber(input).toLong()
                    require(length >= 0) { "Negative binary byte length" }
                    input.skip(length)
                    0L
                }
                247, in 251..254 -> 1L
                248 -> 2L
                249 -> 3L
                250 ->
                    decodeNumber(input).toLong().also {
                        require(it >= 0) { "Negative binary element count" }
                    }
                else -> 0L
            }
        if (wire in 246..254) {
            require(remaining.size <= maxNestingDepth) { "Maximum binary nesting depth $maxNestingDepth exceeded" }
        }
        if (children > 0) remaining.addLast(children)
    }
    require(input.exhausted()) { "Extra bytes after binary value" }
}
