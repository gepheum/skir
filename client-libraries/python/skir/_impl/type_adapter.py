from collections.abc import Callable
from dataclasses import dataclass
from typing import Generic, Protocol, TypeVar

from skir import _spec, reflection
from skir._impl.function_maker import ExprLike

T = TypeVar("T")


@dataclass(frozen=False)
class ByteStream:
    __slots__ = ("buffer", "position", "keep_unrecognized_values")

    buffer: bytes
    position: int
    keep_unrecognized_values: bool

    def read_wire(self) -> int:
        wire = self.buffer[self.position]
        self.position += 1
        return wire

    def read(self, length: int) -> bytes:
        data = self.buffer[self.position : self.position + length]
        self.position += length
        return data


class TypeAdapter(Protocol, Generic[T]):
    def default_expr(self) -> ExprLike:
        """
        The default value for T.
        """
        ...

    def to_frozen_expr(self, arg_expr: ExprLike) -> ExprLike:
        """
        Transforms the argument passed to the constructor of a frozen class into a
        frozen value which will be assigned to the attribute of the frozen object.

        The type of the returned expression must be T even if the argument does not have
        the expected type. Ideally, the expression should raise an error in the latter
        case.
        """
        ...

    def is_not_default_expr(self, arg_expr: ExprLike, attr_expr: ExprLike) -> ExprLike:
        """
        Returns an expression which evaluates to true if the given value is *not* the
        default value for T.
        This expression is inserted in the constructor of a frozen class, after the
        attribute has been assigned from the result of freezing arg_expr.
        If possible, an implemtation should try to use arg_expr instead of attr_expr as
        it offers a marginal performance advantage ('x' vs 'self.x').
        """
        ...

    def to_json_expr(self, in_expr: ExprLike, readable: bool) -> ExprLike:
        """
        Returns an expression which can be passed to 'json.dumps()' in order to
        serialize the given T into JSON format.
        The JSON flavor (dense versus readable) is given by the 'readable' arg.
        """
        ...

    def from_json_expr(
        self, json_expr: ExprLike, keep_unrecognized_expr: ExprLike
    ) -> ExprLike:
        """
        Transforms 'json_expr' into a T.
        The 'json_expr' arg is obtained by calling 'json.loads()'.
        """
        ...

    def encode_fn(
        self,
    ) -> Callable[[T, bytearray], None]: ...

    def decode_fn(
        self,
    ) -> Callable[[ByteStream], T]: ...

    def finalize(
        self,
        resolve_type_fn: Callable[[_spec.Type], "TypeAdapter"],
    ) -> None: ...

    def get_type(self) -> reflection.Type: ...

    def register_records(
        self,
        registry: dict[str, reflection.Record],
    ) -> None: ...

    def frozen_class_of_struct(self) -> type | None: ...
