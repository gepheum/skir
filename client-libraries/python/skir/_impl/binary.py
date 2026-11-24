import struct
from typing import Callable, Final, Literal

from skir._impl.function_maker import BodyBuilder, Expr, ExprLike, make_function
from skir._impl.type_adapter import ByteStream


def encode_int32(input_val: int, buffer: bytearray) -> None:
    """Encode a 32-bit integer using variable-length encoding."""
    if input_val < 0:
        if input_val >= -256:
            buffer.append(235)
            buffer.append((input_val + 256) & 0xFF)
        elif input_val >= -65536:
            buffer.append(236)
            buffer.extend(struct.pack("<H", input_val + 65536))
        else:
            buffer.append(237)
            buffer.extend(
                struct.pack(
                    "<i", -2147483648 if input_val <= -2147483648 else input_val
                )
            )
    elif input_val < 232:
        buffer.append(input_val)
    elif input_val < 65536:
        buffer.append(232)
        buffer.extend(struct.pack("<H", input_val))
    else:
        buffer.append(233)
        buffer.extend(
            struct.pack("<I", input_val if input_val <= 2147483647 else 2147483647)
        )


def encode_int64(value: int, buffer: bytearray) -> None:
    if -2147483648 <= value <= 2147483647:
        encode_int32(value, buffer)
    else:
        buffer.append(238)
        buffer.extend(
            struct.pack(
                "<q",
                (
                    -9223372036854775808
                    if value <= -9223372036854775808
                    else value if value <= 9223372036854775807 else 9223372036854775807
                ),
            )
        )


def encode_hash64(value: int, buffer: bytearray) -> None:
    if value < 232:
        buffer.append(0 if value <= 0 else value)
    elif value < 65536:
        buffer.append(232)
        buffer.extend(struct.pack("<H", value))
    elif value < 4294967296:
        buffer.append(233)
        buffer.extend(struct.pack("<I", value))
    else:
        buffer.append(234)
        buffer.extend(
            struct.pack(
                "<Q", value if value <= 18446744073709551615 else 18446744073709551615
            )
        )


def encode_float32(value: float, buffer: bytearray) -> None:
    if value == 0.0:
        buffer.append(0)
    else:
        buffer.append(240)
        buffer.extend(struct.pack("<f", value))


def encode_float64(value: float, buffer: bytearray) -> None:
    if value == 0.0:
        buffer.append(0)
    else:
        buffer.append(241)
        buffer.extend(struct.pack("<d", value))


def encode_length_prefix(length: int, buffer: bytearray) -> None:
    """Encode a length prefix using variable-length encoding."""
    if length < 232:
        if length >= 0:
            buffer.append(length)
        else:
            raise ValueError(f"Length overflow: {length & 0xFFFFFFFF}")
    elif length < 65536:
        buffer.append(232)
        buffer.extend(struct.pack("<H", length))
    elif length < 4294967296:
        buffer.append(233)
        buffer.extend(struct.pack("<I", length))
    else:
        raise ValueError(f"Length overflow: {length & 0xFFFFFFFF}")


def make_decode_number_fn(
    target_type: Literal[
        "bool",
        "int32",
        "int64",
        "hash64",
        "float",
    ],
) -> Callable:
    target_min_int: int
    target_max_int: int
    if target_type == "int32":
        target_min_int = -(2**31)
        target_max_int = 2**31 - 1
    elif target_type == "int64":
        target_min_int = -(2**63)
        target_max_int = 2**63 - 1
    elif target_type == "hash64":
        target_min_int = 0
        target_max_int = 2**64 - 1
    else:  # float
        _: Literal["bool", "float"] = target_type
        target_min_int = 0
        target_max_int = 0

    def clamp(number: int) -> int:
        if number < target_min_int:
            return target_min_int
        elif number <= target_max_int:
            return number
        else:
            return target_max_int

    def make_return_expr(
        raw: ExprLike, min_int: int, max_int: int, is_float: bool
    ) -> ExprLike:
        if target_type == "bool":
            return Expr.join("True if ", raw, " else False")
        elif target_type == "float":
            if is_float:
                return raw
            else:
                return Expr.join(raw, " + 0.0")
        elif is_float:
            return Expr.join("int(", raw, ")")
        elif target_min_int <= min_int and max_int <= target_max_int:
            return raw
        else:
            return Expr.join(Expr.local("clamp", clamp), "(", raw, ")")

    def make_unpack_expr(fmt: str, num_bytes: int, offset: int = 0) -> Expr:
        return Expr.join(
            Expr.local("unpack", struct.unpack),
            f"('{fmt}', stream.read({num_bytes}))[0]",
            "" if offset == 0 else f" + {offset}",
        )

    body_builder = BodyBuilder()
    body_builder.append_ln("wire = stream.buffer[stream.position]")
    body_builder.append_ln("stream.position += 1")
    body_builder.append_ln("if wire < 232:")
    body_builder.append_ln(" return ", make_return_expr("wire", 0, 231, False))
    body_builder.append_ln("elif wire <= 236:")  # 232-236
    body_builder.append_ln(" if wire <= 234:")  # 232-234
    body_builder.append_ln("  if wire == 232:")
    # 16-bit unsigned integer
    body_builder.append_ln(
        "   return ",
        make_return_expr(make_unpack_expr("<H", 2), 0, 65535, False),
    )
    body_builder.append_ln("  elif wire == 233:")
    # 32-bit unsigned integer
    body_builder.append_ln(
        "   return ",
        make_return_expr(make_unpack_expr("<I", 4), 0, 4294967295, False),
    )
    body_builder.append_ln("  elif wire == 234:")
    # 64-bit unsigned integer
    body_builder.append_ln(
        "   return ",
        make_return_expr(make_unpack_expr("<Q", 8), 0, 18446744073709551615, False),
    )
    body_builder.append_ln(" elif wire == 235:")
    # 8-bit signed integer (offset by 256)
    body_builder.append_ln(
        "  return ",
        make_return_expr(make_unpack_expr("<B", 1, -256), -256, -1, False),
    )
    body_builder.append_ln(" else:")  # 236
    # 16-bit signed integer (offset by 65536)
    body_builder.append_ln(
        "  return ",
        make_return_expr(make_unpack_expr("<H", 2, -65536), -65536, -1, False),
    )
    body_builder.append_ln("elif wire <= 239:")  # 237-239
    body_builder.append_ln(" if wire == 237:")
    # 32-bit signed integer
    body_builder.append_ln(
        "  return ",
        make_return_expr(make_unpack_expr("<i", 4), -2147483648, 2147483647, False),
    )
    body_builder.append_ln(" else:")  # 238-239
    # 64-bit signed integer
    body_builder.append_ln(
        "  return ",
        make_return_expr(
            make_unpack_expr("<q", 8), -9223372036854775808, 9223372036854775807, False
        ),
    )
    body_builder.append_ln("elif wire == 240:")
    # 32-bit float
    body_builder.append_ln(
        " return ",
        make_return_expr(make_unpack_expr("<f", 4), 0, 0, True),
    )
    body_builder.append_ln("elif wire == 241:")
    # 64-bit float
    body_builder.append_ln(
        " return ",
        make_return_expr(make_unpack_expr("<d", 8), 0, 0, True),
    )
    body_builder.append_ln("else:")
    body_builder.append_ln(" raise ValueError(f'Unsupported wire type: {wire}')")

    return make_function(
        f"decode_{target_type}",
        ["stream"],
        body_builder.build(),
    )


decode_bool: Final[Callable[[ByteStream], bool]] = make_decode_number_fn("bool")
decode_int32: Final[Callable[[ByteStream], int]] = make_decode_number_fn("int32")
decode_int64: Final[Callable[[ByteStream], int]] = make_decode_number_fn("int64")
decode_hash64: Final[Callable[[ByteStream], int]] = make_decode_number_fn("hash64")
decode_float: Final[Callable[[ByteStream], float]] = make_decode_number_fn("float")


def decode_unused(stream: ByteStream) -> None:
    wire_offset = stream.read_wire() - 232
    if wire_offset < 0:
        return
    elif wire_offset <= 9:
        if wire_offset in (0, 4):  # uint16, uint16 - 65536
            stream.position += 2
        elif wire_offset in (1, 5, 8):  # uint32, int32, float32
            stream.position += 4
        elif wire_offset == 3:  # uint8 - 256
            stream.position += 1
        else:  # 2, 6, 7, 9
            stream.position += 8
    elif wire_offset in (11, 13):  # string, bytes
        length = decode_int64(stream)
        stream.position += length
    elif wire_offset in (15, 19, 20, 21, 22):  # array length==1, enum value kind==1-4
        decode_unused(stream)
    elif wire_offset == 16:  # array length==2
        decode_unused(stream)
        decode_unused(stream)
    elif wire_offset == 17:  # array length==3
        decode_unused(stream)
        decode_unused(stream)
        decode_unused(stream)
    elif wire_offset == 18:  # array length==N
        length = decode_int64(stream)
        for _ in range(length):
            decode_unused(stream)
