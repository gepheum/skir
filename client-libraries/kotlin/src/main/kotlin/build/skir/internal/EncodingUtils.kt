package build.skir.internal

import okio.Buffer
import okio.BufferedSource

fun encodeInt32(
    input: Int,
    buffer: Buffer,
) {
    when {
        input < 0 -> {
            when {
                input >= -256 -> {
                    buffer.writeByte(235)
                    buffer.writeByte((input + 256))
                }
                input >= -65536 -> {
                    buffer.writeByte(236)
                    buffer.writeShortLe((input + 65536))
                }
                else -> {
                    buffer.writeByte(237)
                    buffer.writeIntLe(input)
                }
            }
        }
        input < 232 -> {
            buffer.writeByte(input)
        }
        input < 65536 -> {
            buffer.writeByte(232)
            buffer.writeShortLe(input)
        }
        else -> {
            buffer.writeByte(233)
            buffer.writeIntLe(input)
        }
    }
}

fun encodeLengthPrefix(
    length: Int,
    buffer: Buffer,
) {
    when {
        length < 232 -> {
            if (length >= 0) {
                buffer.writeByte(length)
            } else {
                throw IllegalArgumentException("Length overflow: ${length.toUInt()}")
            }
        }
        length < 65536 -> {
            buffer.writeByte(232)
            buffer.writeShortLe(length)
        }
        else -> {
            buffer.writeByte(233)
            buffer.writeIntLe(length)
        }
    }
}

fun decodeNumber(buffer: BufferedSource): Number {
    val wire = buffer.readByte().toInt() and 0xFF
    return decodeNumberPastWire(buffer, wire)
}

fun decodeNumberPastWire(
    buffer: BufferedSource,
    wire: Int,
): Number {
    return when (wire) {
        in 0..231 -> wire
        232 -> buffer.readShortLe().toInt() and 0xFFFF // uint16
        233 -> buffer.readIntLe().toLong() and 0xFFFFFFFF // uint32
        234 -> buffer.readLongLe() // uint64
        235 -> (buffer.readByte().toInt() and 0xFF) - 256L
        236 -> (buffer.readShortLe().toInt() and 0xFFFF) - 65536L
        237 -> buffer.readIntLe()
        238, 239 -> buffer.readLongLe()
        240 -> Float.fromBits(buffer.readIntLe())
        241 -> Double.fromBits(buffer.readLongLe())
        else -> throw IllegalArgumentException("Expected: number; wire: $wire")
    }
}

fun decodeNumberAndCountBytes(buffer: BufferedSource): Pair<Number, Int> {
    return when (val wire = buffer.readByte().toInt() and 0xFF) {
        in 0..231 -> Pair(wire, 1)
        232 -> Pair(buffer.readShortLe().toInt() and 0xFFFF, 3) // uint16
        233 -> Pair(buffer.readIntLe().toLong() and 0xFFFFFFFF, 5) // uint32
        234 -> Pair(buffer.readLongLe(), 9) // uint64
        235 -> Pair((buffer.readByte().toInt() and 0xFF) - 256L, 2)
        236 -> Pair((buffer.readShortLe().toInt() and 0xFFFF) - 65536L, 3)
        237 -> Pair(buffer.readIntLe(), 5)
        238, 239 -> Pair(buffer.readLongLe(), 9)
        240 -> Pair(Float.fromBits(buffer.readIntLe()), 5)
        241 -> Pair(Double.fromBits(buffer.readLongLe()), 9)
        else -> throw IllegalArgumentException("Expected: number; wire: $wire")
    }
}

fun decodeUnused(buffer: BufferedSource): Long {
    val wire = buffer.readByte().toInt() and 0xFF
    if (wire < 232) {
        return 1
    }

    when (wire - 232) {
        0, 4 -> { // uint16, uint16 - 65536
            buffer.skip(2)
            return 3
        }
        1, 5, 8 -> { // uint32, int32, float32
            buffer.skip(4)
            return 5
        }
        2, 6, 7, 9 -> { // uint64, int64, int64 timestamp, float64
            buffer.skip(8)
            return 9
        }
        3 -> { // uint8 - 256
            buffer.skip(1)
            return 2
        }
        11, 13 -> { // string, bytes
            val (length, lengthByteCount) = decodeNumberAndCountBytes(buffer)
            val lengthLong = length.toLong()
            buffer.skip(lengthLong)
            return 1 + lengthByteCount + lengthLong
        }
        15, 19, 20, 21, 22 -> { // array length==1, enum value kind==1-4
            return 1 + decodeUnused(buffer)
        }
        16 -> { // array length==2
            return 1 + decodeUnused(buffer) + decodeUnused(buffer)
        }
        17 -> { // array length==3
            return 1 + decodeUnused(buffer) + decodeUnused(buffer) + decodeUnused(buffer)
        }
        18 -> { // array length==N
            val (length, lengthByteCount) = decodeNumberAndCountBytes(buffer)
            val lengthLong = length.toLong()
            var result = 1L + lengthByteCount
            for (i in 0L until lengthLong) {
                result += decodeUnused(buffer)
            }
            return result
        }
        else -> {
            // 10, 12
            return 1
        }
    }
}
