from typing import Final, Literal, TypeVar, overload

from skir._impl import primitives
from skir._impl.arrays import get_array_adapter
from skir._impl.optionals import get_optional_adapter
from skir._impl.serializer import Serializer, make_serializer
from skir._impl.timestamp import Timestamp

Item = TypeVar("Item")
Other = TypeVar("Other")


def array_serializer(item_serializer: Serializer[Item]) -> Serializer[tuple[Item, ...]]:
    return make_serializer(get_array_adapter(item_serializer._adapter, ()))


def optional_serializer(
    other_serializer: Serializer[Other],
) -> Serializer[Other | None]:
    return make_serializer(get_optional_adapter(other_serializer._adapter))


@overload
def primitive_serializer(primitive: Literal["bool"]) -> Serializer[bool]: ...
@overload
def primitive_serializer(primitive: Literal["int32"]) -> Serializer[int]: ...
@overload
def primitive_serializer(primitive: Literal["int64"]) -> Serializer[int]: ...
@overload
def primitive_serializer(primitive: Literal["hash64"]) -> Serializer[int]: ...
@overload
def primitive_serializer(primitive: Literal["float32"]) -> Serializer[float]: ...
@overload
def primitive_serializer(primitive: Literal["float64"]) -> Serializer[float]: ...
@overload
def primitive_serializer(primitive: Literal["timestamp"]) -> Serializer[Timestamp]: ...
@overload
def primitive_serializer(primitive: Literal["string"]) -> Serializer[str]: ...
@overload
def primitive_serializer(primitive: Literal["bytes"]) -> Serializer[bytes]: ...


def primitive_serializer(
    primitive: (
        Literal["bool"]
        | Literal["int32"]
        | Literal["int64"]
        | Literal["hash64"]
        | Literal["float32"]
        | Literal["float64"]
        | Literal["timestamp"]
        | Literal["string"]
        | Literal["bytes"]
    ),
) -> (
    Serializer[bool]
    | Serializer[int]
    | Serializer[float]
    | Serializer[Timestamp]
    | Serializer[str]
    | Serializer[bytes]
):
    return _primitive_to_serializer[primitive]


_primitive_to_serializer: Final = {
    "bool": make_serializer(primitives.BOOL_ADAPTER),
    "int32": make_serializer(primitives.INT32_ADAPTER),
    "int64": make_serializer(primitives.INT64_ADAPTER),
    "hash64": make_serializer(primitives.HASH64_ADAPTER),
    "float32": make_serializer(primitives.FLOAT32_ADAPTER),
    "float64": make_serializer(primitives.FLOAT64_ADAPTER),
    "timestamp": make_serializer(primitives.TIMESTAMP_ADAPTER),
    "string": make_serializer(primitives.STRING_ADAPTER),
    "bytes": make_serializer(primitives.BYTES_ADAPTER),
}
