from collections.abc import Callable
from dataclasses import dataclass
from functools import cached_property
from typing import Generic
from weakref import WeakValueDictionary

from skir import _spec, reflection
from skir._impl.function_maker import Expr, ExprLike
from skir._impl.type_adapter import ByteStream, T, TypeAdapter


def get_optional_adapter(other_adapter: TypeAdapter[T]) -> TypeAdapter[T | None]:
    return _other_adapter_to_optional_adapter.setdefault(
        other_adapter, _OptionalAdapter(other_adapter)
    )


@dataclass(frozen=True)
class _OptionalAdapter(Generic[T], TypeAdapter[T | None]):
    __slots__ = ("other_adapter",)

    other_adapter: TypeAdapter

    def default_expr(self) -> ExprLike:
        return "None"

    def to_frozen_expr(self, arg_expr: ExprLike) -> Expr:
        return Expr.join(
            "(None if ",
            arg_expr,
            " is None else ",
            self.other_adapter.to_frozen_expr(arg_expr),
            ")",
        )

    def is_not_default_expr(self, arg_expr: ExprLike, attr_expr: ExprLike) -> Expr:
        return Expr.join(arg_expr, " is not None")

    def to_json_expr(self, in_expr: ExprLike, readable: bool) -> ExprLike:
        other_to_json = self.other_adapter.to_json_expr(in_expr, readable)
        if other_to_json == in_expr:
            return in_expr
        return Expr.join(
            "(None if ",
            in_expr,
            " is None else ",
            other_to_json,
            ")",
        )

    def from_json_expr(
        self, json_expr: ExprLike, keep_unrecognized_expr: ExprLike
    ) -> ExprLike:
        other_from_json = self.other_adapter.from_json_expr(
            json_expr, keep_unrecognized_expr
        )
        if other_from_json == json_expr:
            return json_expr
        return Expr.join(
            "(None if ",
            json_expr,
            " is None else ",
            other_from_json,
            ")",
        )

    @cached_property
    def encode_fn_impl(self) -> Callable[[T | None, bytearray], None]:
        encode_value = self.other_adapter.encode_fn()

        def encode(
            value: T | None,
            buffer: bytearray,
        ) -> None:
            if value is None:
                buffer.append(255)
            else:
                encode_value(value, buffer)

        return encode

    def encode_fn(self) -> Callable[[T | None, bytearray], None]:
        return self.encode_fn_impl

    @cached_property
    def decode_fn_impl(self) -> Callable[[ByteStream], T | None]:
        decode_value = self.other_adapter.decode_fn()

        def decode(
            stream: ByteStream,
        ) -> T | None:
            if stream.buffer[stream.position] == 255:
                stream.position += 1
                return None
            else:
                return decode_value(stream)

        return decode

    def decode_fn(self) -> Callable[[ByteStream], T | None]:
        return self.decode_fn_impl

    def finalize(
        self,
        resolve_type_fn: Callable[[_spec.Type], "TypeAdapter"],
    ) -> None:
        self.other_adapter.finalize(resolve_type_fn)

    def get_type(self) -> reflection.Type:
        return reflection.OptionalType(
            kind="optional",
            value=self.other_adapter.get_type(),
        )

    def register_records(
        self,
        registry: dict[str, reflection.Record],
    ) -> None:
        self.other_adapter.register_records(registry)

    def frozen_class_of_struct(self) -> type | None:
        return None


_other_adapter_to_optional_adapter: WeakValueDictionary[TypeAdapter, TypeAdapter] = (
    WeakValueDictionary()
)
