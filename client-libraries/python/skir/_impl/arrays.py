from collections.abc import Callable
from dataclasses import FrozenInstanceError
from functools import cached_property
from typing import Generic, Optional
from weakref import WeakValueDictionary

from skir import _spec, reflection
from skir._impl.binary import decode_int64, encode_length_prefix
from skir._impl.function_maker import Any, Expr, ExprLike, Line, make_function
from skir._impl.keyed_items import Item, Key, KeyedItems
from skir._impl.type_adapter import ByteStream, T, TypeAdapter


def get_array_adapter(
    item_adapter: TypeAdapter[T],
    key_attributes: tuple[str, ...],
) -> TypeAdapter[tuple[T, ...]]:
    if key_attributes:
        default_expr = item_adapter.default_expr()
        listuple_class = _new_keyed_items_class(key_attributes, default_expr)
    else:
        listuple_class = _new_listuple_class()
    array_adapter = _ArrayAdapter(item_adapter, listuple_class, key_attributes)
    return _item_to_array_adapter.setdefault(
        (item_adapter, key_attributes), array_adapter
    )


class _ArrayAdapter(Generic[T], TypeAdapter[tuple[T, ...]]):
    __slots__ = (
        "item_adapter",
        "listuple_class",
        "key_attributes",
        "empty_listuple",
    )

    item_adapter: TypeAdapter[T]
    listuple_class: type
    empty_listuple: tuple[()]

    def __init__(
        self,
        item_adapter: TypeAdapter[T],
        listuple_class: type,
        key_attributes: tuple[str, ...],
    ):
        self.item_adapter = item_adapter
        self.listuple_class = listuple_class
        self.key_attributes = key_attributes
        self.empty_listuple = listuple_class()

    def default_expr(self) -> ExprLike:
        return Expr.local("_d?", self.empty_listuple)

    def to_frozen_expr(self, arg_expr: ExprLike) -> Expr:
        listuple_class_local = Expr.local("_lstpl?", self.listuple_class)
        empty_listuple_local = Expr.local("_emp?", self.empty_listuple)
        return Expr.join(
            "(",
            arg_expr,
            " if ",
            arg_expr,
            ".__class__ is ",
            listuple_class_local,
            " else (",
            listuple_class_local,
            "([",
            self.item_adapter.to_frozen_expr("_e"),
            " for _e in ",
            arg_expr,
            "]) or ",
            empty_listuple_local,
            "))",
        )

    def is_not_default_expr(self, arg_expr: ExprLike, attr_expr: ExprLike) -> ExprLike:
        # Can't use arg_expr, an empty iterable is not guaranteed to evaluate to False.
        return attr_expr

    def to_json_expr(self, in_expr: ExprLike, readable: bool) -> ExprLike:
        item_to_json = self.item_adapter.to_json_expr("_e", readable)
        if Expr.join(item_to_json) == Expr.join("_e"):
            return in_expr
        return Expr.join(
            "[",
            item_to_json,
            " for _e in ",
            in_expr,
            "]",
        )

    def from_json_expr(
        self, json_expr: ExprLike, keep_unrecognized_expr: ExprLike
    ) -> Expr:
        listuple_class_local = Expr.local("_lstpl?", self.listuple_class)
        empty_listuple_local = Expr.local("_emp?", self.empty_listuple)
        return Expr.join(
            listuple_class_local,
            "([",
            self.item_adapter.from_json_expr("_e", keep_unrecognized_expr),
            " for _e in (",
            json_expr,
            " or ())] or ",
            empty_listuple_local,
            ")",
        )

    @cached_property
    def encode_fn_impl(self) -> Callable[[tuple[T, ...], bytearray], None]:
        encode_item = self.item_adapter.encode_fn()

        def encode(
            value: tuple[T, ...],
            buffer: bytearray,
        ) -> None:
            if not value:
                buffer.append(246)
                return
            length = len(value)
            if length <= 3:
                buffer.append(246 + length)
            else:
                buffer.append(250)
                encode_length_prefix(length, buffer)
            for i in range(length):
                encode_item(value[i], buffer)

        return encode

    def encode_fn(self) -> Callable[[tuple[T, ...], bytearray], None]:
        return self.encode_fn_impl

    @cached_property
    def decode_fn_impl(self) -> Callable[[ByteStream], tuple[T, ...]]:
        decode_item = self.item_adapter.decode_fn()

        def decode(
            stream: ByteStream,
        ) -> tuple[T, ...]:
            wire = stream.read_wire()
            if wire in (0, 246):
                return self.empty_listuple
            length: int
            if wire == 250:
                length = decode_int64(stream)
            else:
                length = wire - 246
            return self.listuple_class(decode_item(stream) for _ in range(length))

        return decode

    def decode_fn(self) -> Callable[[ByteStream], tuple[T, ...]]:
        return self.decode_fn_impl

    def finalize(
        self,
        resolve_type_fn: Callable[[_spec.Type], "TypeAdapter"],
    ) -> None:
        self.item_adapter.finalize(resolve_type_fn)

    def get_type(self) -> reflection.Type:
        key_extractor = ".".join(a.rstrip("_") for a in self.key_attributes)
        return reflection.ArrayType(
            kind="array",
            value=reflection.ArrayType.Array(
                item=self.item_adapter.get_type(),
                key_extractor=key_extractor,
            ),
        )

    def register_records(
        self,
        registry: dict[str, reflection.Record],
    ) -> None:
        self.item_adapter.register_records(registry)

    def frozen_class_of_struct(self) -> type | None:
        return None


_ItemAndKeyAttributes = tuple[TypeAdapter, tuple[str, ...]]
_ItemToArrayAdapter = WeakValueDictionary[_ItemAndKeyAttributes, _ArrayAdapter]

_item_to_array_adapter: _ItemToArrayAdapter = WeakValueDictionary()


def _new_listuple_class() -> type:
    class Listuple(Generic[Item], tuple[Item, ...]):
        __slots__ = ()

    return Listuple


def _new_keyed_items_class(key_attributes: tuple[str, ...], default_expr: ExprLike):
    key_items = make_function(
        name="key_items",
        params=["items"],
        body=[
            "ret = {}",
            "for item in items:",
            f"  ret[item.{'.'.join(key_attributes)}] = item",
            "return ret",
        ],
    )

    default = make_function(
        name="get_default",
        params="",
        body=[Line.join("return ", default_expr)],
    )()

    class KeyedItemsImpl(KeyedItems[Item, Key]):
        # nonempty __slots__ not supported for subtype of 'tuple'

        _key_to_item: dict[Key, Item]

        def find(self, key: Key) -> Optional[Item]:
            try:
                key_to_item = self._key_to_item
            except AttributeError:
                key_to_item = key_items(self)
                object.__setattr__(self, "_key_to_item", key_to_item)
            return key_to_item.get(key)

        def find_or_default(self, key: Key) -> Any:
            return self.find(key) or default

        def __setattr__(self, name: str, value: Any):
            raise FrozenInstanceError(self.__class__.__qualname__)

        def __delattr__(self, name: str):
            raise FrozenInstanceError(self.__class__.__qualname__)

    return KeyedItemsImpl
