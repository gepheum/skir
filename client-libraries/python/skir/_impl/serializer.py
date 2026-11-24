import json as jsonlib
from collections.abc import Callable
from dataclasses import FrozenInstanceError
from functools import cached_property
from typing import Any, Generic, TypeVar, cast, final
from weakref import WeakValueDictionary

from skir import reflection
from skir._impl.function_maker import Expr, LineSpan, make_function
from skir._impl.never import Never
from skir._impl.type_adapter import ByteStream, TypeAdapter

T = TypeVar("T")


@final
class Serializer(Generic[T]):
    __slots__ = (
        "__weakref__",
        "_adapter",
        "_to_dense_json_fn",
        "_to_readable_json_fn",
        "_from_json_fn",
        "_encode_fn",
        "_decode_fn",
        "__dict__",
    )

    _adapter: TypeAdapter[T]
    _to_dense_json_fn: Callable[[T], Any]
    _to_readable_json_fn: Callable[[T], Any]
    _from_json_fn: Callable[[Any, bool], T]
    _encode_fn: Callable[[T, bytearray], None]
    _decode_fn: Callable[[ByteStream], T]

    def __init__(self, adapter: Never):
        # Use Never (^) as a trick to make the constructor internal.
        as_adapter = cast(TypeAdapter[T], adapter)
        object.__setattr__(self, "_adapter", as_adapter)
        object.__setattr__(
            self, "_to_dense_json_fn", _make_to_json_fn(as_adapter, readable=False)
        )
        object.__setattr__(
            self,
            "_to_readable_json_fn",
            _make_to_json_fn(as_adapter, readable=True),
        )
        object.__setattr__(self, "_from_json_fn", _make_from_json_fn(as_adapter))
        object.__setattr__(self, "_encode_fn", as_adapter.encode_fn())
        object.__setattr__(self, "_decode_fn", as_adapter.decode_fn())

    def to_json(self, input: T, *, readable=False) -> Any:
        if readable:
            return self._to_readable_json_fn(input)
        else:
            return self._to_dense_json_fn(input)

    def to_json_code(self, input: T, readable=False) -> str:
        if readable:
            return jsonlib.dumps(self._to_readable_json_fn(input), indent=2)
        else:
            return jsonlib.dumps(self._to_dense_json_fn(input), separators=(",", ":"))

    def from_json(self, json: Any, keep_unrecognized_values: bool = False) -> T:
        return self._from_json_fn(json, keep_unrecognized_values)

    def from_json_code(
        self, json_code: str, keep_unrecognized_values: bool = False
    ) -> T:
        return self._from_json_fn(jsonlib.loads(json_code), keep_unrecognized_values)

    def to_bytes(self, input: T) -> bytes:
        buffer = bytearray(b"skir")
        self._encode_fn(input, buffer)
        return bytes(buffer)

    def from_bytes(self, bytes: bytes, keep_unrecognized_values: bool = False) -> T:
        if bytes.startswith(b"skir"):
            stream = ByteStream(
                bytes, position=4, keep_unrecognized_values=keep_unrecognized_values
            )
            return self._decode_fn(stream)
        return self.from_json_code(bytes.decode("utf-8"))

    @cached_property
    def type_descriptor(self) -> reflection.TypeDescriptor:
        records: dict[str, reflection.Record] = {}
        self._adapter.register_records(records)
        return reflection.TypeDescriptor(
            type=self._adapter.get_type(),
            records=tuple(records.values()),
        )

    def __setattr__(self, name: str, value: Any):
        raise FrozenInstanceError(self.__class__.__qualname__)

    def __delattr__(self, name: str):
        raise FrozenInstanceError(self.__class__.__qualname__)


# A cache to make sure we only create one Serializer for each TypeAdapter.
_type_adapter_to_serializer: WeakValueDictionary[TypeAdapter, Serializer] = (
    WeakValueDictionary()
)


def make_serializer(adapter: TypeAdapter[T]) -> Serializer[T]:
    return _type_adapter_to_serializer.setdefault(
        adapter, Serializer(cast(Never, adapter))
    )


def _make_to_json_fn(adapter: TypeAdapter[T], readable: bool) -> Callable[[T], Any]:
    return make_function(
        name="to_json",
        params=["input"],
        body=[
            LineSpan.join(
                "return ",
                adapter.to_json_expr(
                    adapter.to_frozen_expr(Expr.join("input")),
                    readable=readable,
                ),
            ),
        ],
    )


def _make_from_json_fn(adapter: TypeAdapter[T]) -> Callable[[Any, bool], T]:
    return make_function(
        name="from_json",
        params=["json", "keep_unrecognized_values"],
        body=[
            LineSpan.join(
                "return ", adapter.from_json_expr("json", "keep_unrecognized_values")
            ),
        ],
    )
