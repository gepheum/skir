import copy
import itertools
from collections.abc import Callable, Sequence
from dataclasses import FrozenInstanceError, dataclass
from typing import Any, Final, Generic, Union, cast

from skir import _spec, reflection
from skir._impl.binary import decode_int64, decode_unused, encode_length_prefix
from skir._impl.function_maker import (
    BodyBuilder,
    Expr,
    ExprLike,
    Line,
    LineSpan,
    LineSpanLike,
    Param,
    Params,
    make_function,
)
from skir._impl.keep import KEEP
from skir._impl.repr import repr_impl
from skir._impl.type_adapter import ByteStream, T, TypeAdapter


class StructAdapter(Generic[T], TypeAdapter[T]):
    __slots__ = (
        "spec",
        "record_hash",
        "gen_class",
        "mutable_class",
        "simple_class",
        "private_is_frozen_attr",
        "finalization_state",
        "fields",
    )

    spec: Final[_spec.Struct]
    record_hash: Final[int]
    # The frozen class.
    gen_class: Final[type]
    mutable_class: Final[type]
    simple_class: Final[type]
    private_is_frozen_attr: Final[str]

    # 0: has not started; 1: in progress; 2: done
    finalization_state: int
    fields: tuple["_Field", ...]
    num_slots_incl_removed: int
    slot_to_field: list["_Field | None"]

    def __init__(self, spec: _spec.Struct):
        self.finalization_state = 0
        self.spec = spec
        self.record_hash = hash(spec.id)

        self.private_is_frozen_attr = _name_private_is_frozen_attr(spec.id)

        slots = tuple(f.attribute for f in self.spec.fields) + (
            # Unrecognized fields encountered during deserialization.
            "_unrecognized",
            # Lowest number greater than the number of every field with a non-default
            # value.
            "_array_len",
        )
        frozen_class = self.gen_class = _make_dataclass(slots)
        frozen_class.__name__ = spec.class_name
        frozen_class.__qualname__ = spec.class_qualname
        frozen_class.__setattr__ = cast(Any, _Frozen.__setattr__)
        frozen_class.__delattr__ = cast(Any, _Frozen.__delattr__)
        # We haven't added an __init__ method to the frozen class yet, so frozen_class()
        # returns an object with no attribute set. We'll set the attributes of DEFAULT
        # at the finalization step.
        frozen_class.DEFAULT = frozen_class()

        mutable_class = self.mutable_class = _make_dataclass(slots)
        mutable_class.__name__ = "Mutable"
        mutable_class.__qualname__ = f"{spec.class_qualname}.Mutable"
        frozen_class.Mutable = mutable_class
        frozen_class.OrMutable = Union[frozen_class, mutable_class]

        # The 'simple' class is a class which only has __slots__ defined.
        # To construct instances of the frozen class from internal implementation,
        # instead of calling the constructor of the frozen class, we use the following
        # technique: create an instance of the simple class, assign all the attributes,
        # then assign the frozen class to the __class__ attribute.
        # Reason why it's faster: we don't need to call object.__setattr__().
        self.simple_class = _make_dataclass(slots)

        def forward_encode(value: Any, buffer: bytearray) -> None:
            frozen_class._encode(value, buffer)

        # Will be overridden at finalization time.
        frozen_class._encode = forward_encode

        def forward_decode(stream: ByteStream) -> None:
            return frozen_class._decode(stream)

        frozen_class._decode = forward_decode

    def finalize(
        self,
        resolve_type_fn: Callable[[_spec.Type], TypeAdapter],
    ) -> None:
        if self.finalization_state != 0:
            # Finalization is either in progress or done.
            return
        # Mark finalization as in progress.
        self.finalization_state = 1

        # Resolve the type of every field.
        self.fields = fields = tuple(
            sorted(
                (_Field(f, resolve_type_fn(f.type)) for f in self.spec.fields),
                key=lambda f: f.field.number,
            )
        )

        num_slots_incl_removed: Final = max(
            itertools.chain(
                (f.field.number + 1 for f in fields),
                (n + 1 for n in self.spec.removed_numbers),
                [0],
            )
        )
        self.num_slots_incl_removed = num_slots_incl_removed

        slot_to_field: Final[list[_Field | None]] = [None] * self.num_slots_incl_removed
        self.slot_to_field = slot_to_field

        # Aim to have dependencies finalized *before* the dependent. It's not always
        # possible, because there can be cyclic dependencies.
        # The function returned by the do_x_fn() method of a dependency is marginally
        # faster if the dependency is finalized. If the dependency is not finalized,
        # this function is a "forwarding" function.
        for field in fields:
            field.type.finalize(resolve_type_fn)
            self.slot_to_field[field.field.number] = field

        frozen_class = self.gen_class
        mutable_class = self.mutable_class
        simple_class = self.simple_class

        frozen_class.to_frozen = _identity
        frozen_class.to_mutable = _make_to_mutable_fn(
            mutable_class=mutable_class,
            simple_class=simple_class,
            fields=fields,
        )
        mutable_class.to_frozen = _make_to_frozen_fn(
            frozen_class=frozen_class,
            simple_class=simple_class,
            fields=fields,
        )
        setattr(frozen_class, self.private_is_frozen_attr, True)
        setattr(mutable_class, self.private_is_frozen_attr, False)

        frozen_class.__init__ = cast(
            Any,
            _make_frozen_class_init_fn(
                fields,
                frozen_class=frozen_class,
                simple_class=simple_class,
            ),
        )
        mutable_class.__init__ = _make_mutable_class_init_fn(fields)
        frozen_class.partial = _make_partial_static_factory_method(
            fields,
            frozen_class,
        )
        frozen_class.replace = _make_replace_method(fields, frozen_class)

        frozen_class.__eq__ = _make_eq_fn(fields)
        frozen_class.__hash__ = cast(Any, _make_hash_fn(fields, self.record_hash))
        frozen_class.__repr__ = mutable_class.__repr__ = cast(
            Any, _make_repr_fn(fields)
        )

        frozen_class._tdj = _make_to_dense_json_fn(
            fields=fields,
            num_slots_incl_removed=num_slots_incl_removed,
        )
        frozen_class._trj = _make_to_readable_json_fn(fields=fields)
        frozen_class._encode = _make_encode_fn(
            fields=fields,
            num_slots_incl_removed=num_slots_incl_removed,
        )
        frozen_class._decode = _make_decode_fn(
            frozen_class=frozen_class,
            simple_class=simple_class,
            fields=fields,
            removed_numbers=self.spec.removed_numbers,
            num_slots_incl_removed=num_slots_incl_removed,
        )

        frozen_class._fj = _make_from_json_fn(
            frozen_class=frozen_class,
            simple_class=simple_class,
            fields=fields,
            removed_numbers=self.spec.removed_numbers,
            num_slots_incl_removed=self.num_slots_incl_removed,
        )

        # Initialize DEFAULT.
        _init_default(self.gen_class.DEFAULT, fields)

        # Define mutable getters
        for field in fields:
            if field.field.has_mutable_getter:
                mutable_getter = _make_mutable_getter(field)
                mutable_getter_name = mutable_getter.__name__
                setattr(mutable_class, mutable_getter_name, property(mutable_getter))

        # Mark finalization as done.
        self.finalization_state = 2

    def default_expr(self) -> Expr:
        return Expr.local("_d?", self.gen_class.DEFAULT)

    def to_frozen_expr(self, arg_expr: ExprLike) -> Expr:
        # The goal of referring to private_is_frozen_attr is to raise an error if the
        # struct has the wrong type.
        return Expr.join(
            "(",
            arg_expr,
            " if ",
            arg_expr,
            f".{self.private_is_frozen_attr} else ",
            arg_expr,
            ".to_frozen())",
        )

    def is_not_default_expr(self, arg_expr: ExprLike, attr_expr: ExprLike) -> Expr:
        return Expr.join(
            "(",
            attr_expr,
            "._unrecognized or ",
            attr_expr,
            "._array_len)",
        )

    def to_json_expr(
        self,
        in_expr: ExprLike,
        readable: bool,
    ) -> Expr:
        return Expr.join(in_expr, "._trj" if readable else "._tdj", "()")

    def from_json_expr(
        self, json_expr: ExprLike, keep_unrecognized_expr: ExprLike
    ) -> Expr:
        fn_name = "_fj"
        # The _fj method may not have been added to the class yet.
        from_json_fn = getattr(self.gen_class, fn_name, None)
        if from_json_fn:
            return Expr.join(
                Expr.local("_fj?", from_json_fn),
                "(",
                json_expr,
                ", ",
                keep_unrecognized_expr,
                ")",
            )
        else:
            return Expr.join(
                Expr.local("_cls?", self.gen_class),
                f".{fn_name}(",
                json_expr,
                ", ",
                keep_unrecognized_expr,
                ")",
            )

    def get_type(self) -> reflection.Type:
        return reflection.RecordType(
            kind="record",
            value=self.spec.id,
        )

    def register_records(
        self,
        registry: dict[str, reflection.Record],
    ) -> None:
        record_id = self.spec.id
        if record_id in registry:
            return
        registry[record_id] = reflection.Struct(
            kind="struct",
            id=record_id,
            doc=self.spec.doc,
            fields=tuple(
                reflection.Field(
                    name=field.field.name,
                    number=field.field.number,
                    type=field.type.get_type(),
                    doc=field.field.doc,
                )
                for field in self.fields
            ),
            removed_numbers=self.spec.removed_numbers,
        )
        for field in self.fields:
            field.type.register_records(registry)

    def frozen_class_of_struct(self) -> type:
        return self.gen_class

    def encode_fn(self) -> Callable[[T, bytearray], None]:
        return self.gen_class._encode

    def decode_fn(self) -> Callable[[ByteStream], T]:
        return self.gen_class._decode


class _Frozen:
    def __setattr__(self, name: str, value: Any):
        raise FrozenInstanceError(self.__class__.__qualname__)

    def __delattr__(self, name: str):
        raise FrozenInstanceError(self.__class__.__qualname__)


def _make_dataclass(slots: tuple[str, ...]) -> type:
    class Result:
        __slots__ = slots

    return Result


def _identity(input: Any) -> Any:
    return input


@dataclass(frozen=True)
class _Field:
    field: _spec.Field
    type: TypeAdapter


def _make_frozen_class_init_fn(
    fields: Sequence[_Field],
    frozen_class: type,
    simple_class: type,
) -> Callable[..., None]:
    """
    Returns the implementation of the __init__() method of the frozen class.
    """

    # Set the params.
    params: Params = ["_self"]
    if fields:
        params.append("*")
    params.extend(field.field.attribute for field in fields)

    builder = BodyBuilder()
    # Since __setattr__() was overridden to raise errors in order to make the class
    # immutable, the only way to set attributes in the constructor is to call
    # object.__setattr__().
    obj_setattr = Expr.local("_setattr", object.__setattr__)

    def array_len_expr() -> Expr:
        spans: list[LineSpanLike] = []
        # Fields are sorted by number.
        for field in reversed(fields):
            spans.append(
                LineSpan.join(
                    f"{field.field.number + 1} if ",
                    field.type.is_not_default_expr(
                        arg_expr=field.field.attribute,
                        attr_expr=f"_self.{field.field.attribute}",
                    ),
                    " else ",
                )
            )
        spans.append("0")
        return Expr.join(*spans)

    if len(fields) < 3:
        # If the class has less than 3 fields, it is faster to assign every field with
        # object.__setattr__().
        for field in fields:
            attribute = field.field.attribute
            builder.append_ln(
                obj_setattr,
                '(_self, "',
                attribute,
                '", ',
                field.type.to_frozen_expr(attribute),
                ")",
            )
        # Set the _unrecognized field.
        builder.append_ln(obj_setattr, '(_self, "_unrecognized", None)')
        # Set array length.
        builder.append_ln(
            obj_setattr,
            '(_self, "_array_len", ',
            array_len_expr(),
            ")",
        )
    else:
        # If the class has 4 fields or more, it is faster to first change the __class__
        # attribute of the object so it's no longer immutable, assign all the attributes
        # with regular assignment, and then change back the __class__ attribute.
        builder.append_ln(
            obj_setattr,
            '(_self, "__class__", ',
            Expr.local("Simple", simple_class),
            ")",
        )
        for field in fields:
            attribute = field.field.attribute
            builder.append_ln(
                "_self.",
                attribute,
                " = ",
                field.type.to_frozen_expr(attribute),
            )
        # Set the _unrecognized field.
        builder.append_ln("_self._unrecognized = None")
        # Set array length.
        builder.append_ln("_self._array_len = ", array_len_expr())
        # Change back the __class__.
        builder.append_ln("_self.__class__ = ", Expr.local("Frozen", frozen_class))

    return make_function(
        name="__init__",
        params=params,
        body=builder.build(),
    )


def _make_mutable_class_init_fn(fields: Sequence[_Field]) -> Callable[..., None]:
    """
    Returns the implementation of the __init__() method of the mutable class.
    """

    params: Params = ["_self"]
    builder = BodyBuilder()
    for field in fields:
        attribute = field.field.attribute
        params.append(
            Param(
                name=attribute,
                default=field.type.default_expr(),
            )
        )
        builder.append_ln(
            "_self.",
            attribute,
            " = ",
            attribute,
        )
    builder.append_ln("_self._unrecognized = None")
    return make_function(
        name="__init__",
        params=params,
        body=builder.build(),
    )


def _make_partial_static_factory_method(
    fields: Sequence[_Field],
    frozen_class: type,
) -> Callable[..., None]:
    """
    Returns the implementation of the partial() method of the frozen class.
    """

    params: Params = []
    if fields:
        params.append("*")
    params.extend(
        Param(
            name=field.field.attribute,
            default=field.type.default_expr(),
        )
        for field in fields
    )

    builder = BodyBuilder()
    builder.append_ln(
        "return ",
        Expr.local("Frozen", frozen_class),
        "(",
        ", ".join(
            f"{field.field.attribute}={field.field.attribute}" for field in fields
        ),
        ")",
    )

    return make_function(
        name="partial",
        params=params,
        body=builder.build(),
    )


def _make_replace_method(
    fields: Sequence[_Field],
    frozen_class: type,
) -> Callable[..., None]:
    """
    Returns the implementation of the replace() method of the frozen class.
    """

    keep_local = Expr.local("KEEP", KEEP)
    params: Params = ["_self"]
    if fields:
        params.append("*")
    params.extend(
        Param(
            name=field.field.attribute,
            default=keep_local,
        )
        for field in fields
    )

    def field_to_arg_assigment(attr: str) -> LineSpan:
        return LineSpan.join(
            f"{attr}=_self.{attr} if {attr} is ", keep_local, f" else {attr}"
        )

    builder = BodyBuilder()
    builder.append_ln(
        "return ",
        Expr.local("Frozen", frozen_class),
        "(",
        LineSpan.join(
            *(field_to_arg_assigment(field.field.attribute) for field in fields),
            separator=", ",
        ),
        ")",
    )

    return make_function(
        name="replace",
        params=params,
        body=builder.build(),
    )


def _make_to_mutable_fn(
    mutable_class: type,
    simple_class: type,
    fields: Sequence[_Field],
) -> Callable[[Any], Any]:
    """
    Returns the implementation of the to_mutable() method of the frozen class.
    """
    builder = BodyBuilder()
    # Create an instance of the simple class. We'll later change its __class__ attr.
    builder.append_ln(
        "ret = ",
        Expr.local("Simple", simple_class),
        "()",
    )
    for field in fields:
        attribute = field.field.attribute
        builder.append_ln("ret.", attribute, " = self.", attribute)
    builder.append_ln("ret._unrecognized = self._unrecognized")
    builder.append_ln(
        "ret.__class__ = ",
        Expr.local("mutable_class", mutable_class),
    )
    builder.append_ln("return ret")
    return make_function(
        name="to_mutable",
        params=["self"],
        body=builder.build(),
    )


def _make_to_frozen_fn(
    frozen_class: type,
    simple_class: type,
    fields: Sequence[_Field],
) -> Callable[[Any], Any]:
    """
    Returns the implementation of the to_frozen() method of the mutable class.
    """

    builder = BodyBuilder()
    # Create an instance of the simple class. We'll later change its __class__ attr.
    builder.append_ln(
        "ret = ",
        Expr.local("Simple", simple_class),
        "()",
    )
    for field in fields:
        attribute = field.field.attribute
        builder.append_ln(
            "ret.",
            attribute,
            " = ",
            field.type.to_frozen_expr(f"self.{attribute}"),
        )

    # Set the _unrecognized field.
    builder.append_ln("ret._unrecognized = self._unrecognized")

    def array_len_expr() -> Expr:
        exprs: list[ExprLike] = []
        # Fields are sorted by number.
        for field in reversed(fields):
            attr_expr = f"ret.{field.field.attribute}"
            exprs.append(
                LineSpan.join(
                    f"{field.field.number + 1} if ",
                    field.type.is_not_default_expr(attr_expr, attr_expr),
                    " else ",
                )
            )
        exprs.append("0")
        return Expr.join(*exprs)

    # Set the _unrecognized field.
    builder.append_ln("ret._unrecognized = self._unrecognized")
    # Set array length.
    builder.append_ln("ret._array_len = ", array_len_expr())

    builder.append_ln(
        "ret.__class__ = ",
        Expr.local("Frozen", frozen_class),
    )
    builder.append_ln("return ret")
    return make_function(
        name="to_frozen",
        params=["self"],
        body=builder.build(),
    )


def _make_eq_fn(
    fields: Sequence[_Field],
) -> Callable[[Any], Any]:
    """
    Returns the implementation of the __eq__() method of the frozen class.
    """

    builder = BodyBuilder()
    builder.append_ln("if other is self:")
    builder.append_ln("  return True")
    builder.append_ln("if other.__class__ is self.__class__:")
    operands: list[ExprLike]
    if fields:

        def get_attribute(f: _Field) -> str:
            return f.field.attribute

        operands = [
            Expr.join(f"self.{get_attribute(f)} == other.{get_attribute(f)}")
            for f in fields
        ]
    else:
        operands = ["True"]
    builder.append_ln("  return ", Expr.join(*operands, separator=" and "))
    builder.append_ln("return ", Expr.local("NotImplemented", NotImplemented))
    return make_function(
        name="__eq__",
        params=["self", "other"],
        body=builder.build(),
    )


def _make_hash_fn(
    fields: Sequence[_Field],
    record_hash: int,
) -> Callable[[Any], Any]:
    """
    Returns the implementation of the __hash__() method of the frozen class.
    """

    components: list[ExprLike] = []
    components.append(str(record_hash))
    for field in fields:
        components.append(f"self.{field.field.attribute}")
    return make_function(
        name="__hash__",
        params=["self"],
        body=[Line.join("return hash((", Expr.join(*components, separator=", "), "))")],
    )


def _make_repr_fn(fields: Sequence[_Field]) -> Callable[[Any], str]:
    """
    Returns the implementation of the __repr__() method of both the frozen class and the
    mutable class.
    """

    builder = BodyBuilder()
    builder.append_ln("if self is getattr(self.__class__, 'DEFAULT', None):")
    builder.append_ln("  return f'{self.__class__.__qualname__}.DEFAULT'")
    builder.append_ln("assignments = []")
    builder.append_ln("any_complex = False")
    builder.append_ln("is_mutable = self.__class__.__name__ == 'Mutable'")
    repr_local = Expr.local("repr", repr_impl)
    for field in fields:
        attribute = field.field.attribute
        # is_not_default_expr only works on a frozen expression.
        builder.append_ln("r = ", repr_local, f"(self.{attribute})")
        builder.append_ln(f"assignments.append(f'{attribute}={{r.indented}}')")
        builder.append_ln("any_complex = any_complex or r.complex")
    builder.append_ln("if len(assignments) <= 1 and not any_complex:")
    builder.append_ln("  body = ''.join(assignments)")
    builder.append_ln("else:")
    builder.append_ln("  body = '\\n' + ''.join(f'  {a},\\n' for a in assignments)")
    builder.append_ln("return f'{self.__class__.__qualname__}({body})'")

    return make_function(
        name="__repr__",
        params=["self"],
        body=builder.build(),
    )


def _make_to_dense_json_fn(
    fields: Sequence[_Field], num_slots_incl_removed: int
) -> Callable[[Any], Any]:
    builder = BodyBuilder()
    builder.append_ln(
        "l = (self._unrecognized.adjusted_json_array_len if self._unrecognized else None) or self._array_len"
    )
    builder.append_ln("ret = [0] * l")
    for field in fields:
        builder.append_ln(f"if l <= {field.field.number}:")
        builder.append_ln("  return ret")
        builder.append_ln(
            f"ret[{field.field.number}] = ",
            field.type.to_json_expr(
                f"self.{field.field.attribute}",
                readable=False,
            ),
        )
    builder.append_ln(f"if {num_slots_incl_removed} < l:")
    builder.append_ln(f"  ret[{num_slots_incl_removed}:] = self._unrecognized.json")
    builder.append_ln("return ret")
    return make_function(
        name="to_dense_json",
        params=["self"],
        body=builder.build(),
    )


def _make_to_readable_json_fn(fields: Sequence[_Field]) -> Callable[[Any], Any]:
    builder = BodyBuilder()
    builder.append_ln("ret = {}")
    for field in fields:
        attr_expr = f"self.{field.field.attribute}"
        builder.append_ln(
            "if ",
            field.type.is_not_default_expr(attr_expr, attr_expr),
            ":",
        )
        builder.append_ln(
            f'  ret["{field.field.name}"] = ',
            field.type.to_json_expr(
                attr_expr,
                readable=True,
            ),
        )
    builder.append_ln("return ret")
    return make_function(
        name="to_readable_json",
        params=["self"],
        body=builder.build(),
    )


def _make_encode_fn(
    fields: Sequence[_Field],
    num_slots_incl_removed: int,
) -> Callable[[Any, bytearray], None]:
    builder = BodyBuilder()
    builder.append_ln(
        "l = (value._unrecognized.adjusted_bytes_array_len if ",
        "value._unrecognized else None) or value._array_len",
    )
    builder.append_ln("if l < 4:")
    builder.append_ln("  buffer.append(246 + l)")
    builder.append_ln("else:")
    builder.append_ln("  buffer.append(250)")
    builder.append_ln(
        "  ",
        Expr.local("_encode_length_prefix", encode_length_prefix),
        "(l, buffer)",
    )
    last_number = -1
    for field in fields:
        number = field.field.number
        builder.append_ln(f"if l <= {number}:")
        builder.append_ln("  return")
        missing_slots = number - last_number - 1
        if missing_slots >= 1:
            # There are removed fields between last_number and number.
            zeros = "\\0" * (missing_slots)
            builder.append_ln(f"buffer.extend(b'{zeros}')")
        builder.append_ln(
            Expr.local("encode?", field.type.encode_fn()),
            f"(value.{field.field.attribute}, buffer)",
        )
        last_number = number
    builder.append_ln(f"if l <= {num_slots_incl_removed}:")
    builder.append_ln("  return")
    num_slots_excl_removed = last_number + 1
    if num_slots_excl_removed < num_slots_incl_removed:
        missing_slots = num_slots_incl_removed - num_slots_excl_removed
        zeros = "\\0" * (missing_slots)
        builder.append_ln(f"buffer.extend(b'{zeros}')")
    builder.append_ln("buffer.extend(value._unrecognized.raw_bytes)")
    return make_function(
        name="encode",
        params=["value, buffer"],
        body=builder.build(),
    )


def _make_from_json_fn(
    frozen_class: type,
    simple_class: type,
    fields: Sequence[_Field],
    removed_numbers: tuple[int, ...],
    num_slots_incl_removed: int,
) -> Callable[[Any], Any]:
    builder = BodyBuilder()
    builder.append_ln("if not json:")
    builder.append_ln("  return ", Expr.local("DEFAULT", frozen_class.DEFAULT))
    builder.append_ln("ret = ", Expr.local("Simple", simple_class), "()")
    builder.append_ln(
        "if ",
        Expr.local("isinstance", isinstance),
        "(json, ",
        Expr.local("list", list),
        "):",
    )
    # JSON array (dense flavor)
    builder.append_ln(
        "  array_len = ",
        Expr.local("len", len),
        "(json)",
    )
    for field in fields:
        number = field.field.number
        item_expr = f"json[{number}]"
        builder.append_ln(
            f"  ret.{field.field.attribute} = ",
            field.type.default_expr(),
            f" if array_len <= {number} else ",
            field.type.from_json_expr(item_expr, "keep_unrecognized_values"),
        )
    if fields:
        num_slots_excl_removed = fields[-1].field.number + 1
    else:
        num_slots_excl_removed = 0
    builder.append_ln(
        f"  if array_len <= {num_slots_incl_removed} or not keep_unrecognized_values:"
    )
    builder.append_ln("    ret._unrecognized = None")
    builder.append_ln("  else:")
    builder.append_ln(
        "    ret._unrecognized = ",
        Expr.local("UnrecognizedFields", _UnrecognizedFields.from_json),
        "(json=",
        Expr.local("deepcopy", copy.deepcopy),
        f"(json[{num_slots_incl_removed}:]), adjusted_json_array_len=array_len)",
    )
    builder.append_ln(
        "  ret._array_len = ",
        _adjust_array_len_expr(
            "array_len",
            removed_numbers=removed_numbers,
            num_slots_excl_removed=num_slots_excl_removed,
        ),
    )

    builder.append_ln("else:")
    builder.append_ln("  array_len = 0")
    # JSON object (readable flavor)
    for field in fields:
        name = field.field.name
        lvalue = f"ret.{field.field.attribute}"
        builder.append_ln(f'  if "{name}" in json:')
        builder.append_ln(f"    array_len = {field.field.number + 1}")
        builder.append_ln(
            f"    {lvalue} = ",
            field.type.from_json_expr(f'json["{name}"]', "keep_unrecognized_values"),
        )
        builder.append_ln("  else:")
        builder.append_ln(f"    {lvalue} = ", field.type.default_expr())
    # Drop unrecognized fields in readable mode.
    builder.append_ln("  ret._unrecognized = None")
    builder.append_ln("  ret._array_len = array_len")

    builder.append_ln("ret.__class__ = ", Expr.local("Frozen", frozen_class))
    builder.append_ln("return ret")

    return make_function(
        name="from_json",
        params=["json", "keep_unrecognized_values"],
        body=builder.build(),
    )


def _make_decode_fn(
    frozen_class: type,
    simple_class: type,
    fields: Sequence[_Field],
    removed_numbers: tuple[int, ...],
    num_slots_incl_removed: int,
) -> Callable[[ByteStream], Any]:
    builder = BodyBuilder()
    builder.append_ln("wire = stream.buffer[stream.position]")
    builder.append_ln("stream.position += 1")
    builder.append_ln("if wire in (0, 246):")
    builder.append_ln("  return ", Expr.local("DEFAULT", frozen_class.DEFAULT))
    builder.append_ln("elif wire == 250:")
    builder.append_ln(
        "  array_len = ",
        Expr.local("decode_int64", decode_int64),
        "(stream)",
    )
    builder.append_ln("else:")
    builder.append_ln("  array_len = wire - 246")
    # Create an instance of the simple class. We'll later change its __class__ attr.
    builder.append_ln(
        "ret = ",
        Expr.local("Simple", simple_class),
        "()",
    )
    last_number = -1
    for field in fields:
        number = field.field.number
        for removed_number in range(last_number + 1, number):
            builder.append_ln(f"if {removed_number} < array_len:")
            builder.append_ln(
                "  ",
                Expr.local("decode_unused", decode_unused),
                "(stream)",
            )
        builder.append_ln(
            f"ret.{field.field.attribute} = ",
            field.type.default_expr(),
            f" if array_len <= {number} else ",
            Expr.local("decode?", field.type.decode_fn()),
            "(stream)",
        )
        last_number = number
    num_slots_excl_removed = last_number + 1

    builder.append_ln(f"if array_len > {num_slots_excl_removed}:")
    builder.append_ln(
        f"  if array_len > {num_slots_incl_removed} and stream.keep_unrecognized_values:"
    )
    for _ in range(num_slots_incl_removed - num_slots_excl_removed):
        builder.append_ln(
            "    ", Expr.local("decode_unused", decode_unused), "(stream)"
        )
    builder.append_ln("    start_offset = stream.position")
    builder.append_ln(f"    for _ in range(array_len - {num_slots_incl_removed}):")
    builder.append_ln("      ", Expr.local("decode_unused", decode_unused), "(stream)")
    builder.append_ln("    end_offset = stream.position")
    builder.append_ln(
        "    ret._unrecognized = ",
        Expr.local("UnrecognizedFields", _UnrecognizedFields.from_bytes),
        "(raw_bytes=stream.buffer[start_offset:end_offset], adjusted_bytes_array_len=array_len)",
    )
    builder.append_ln("  else:")
    builder.append_ln(f"    for _ in range(array_len - {num_slots_excl_removed}):")
    builder.append_ln("      ", Expr.local("decode_unused", decode_unused), "(stream)")
    builder.append_ln("    ret._unrecognized = None")
    builder.append_ln("else:")
    builder.append_ln("  ret._unrecognized = None")

    builder.append_ln(
        "ret._array_len = ",
        _adjust_array_len_expr(
            "array_len",
            removed_numbers=removed_numbers,
            num_slots_excl_removed=num_slots_excl_removed,
        ),
    )

    builder.append_ln(
        "ret.__class__ = ",
        Expr.local("Frozen", frozen_class),
    )
    builder.append_ln("return ret")
    return make_function(
        name="decode",
        params=["stream"],
        body=builder.build(),
    )


def _adjust_array_len_expr(
    var: str,
    removed_numbers: tuple[int, ...],
    num_slots_excl_removed: int,
) -> str:
    """
    When parsing a dense JSON or decoding a binary string, we can reuse the array length
    in the decoded struct, but we need to account for possibly newly-removed fields. The
    last field of the adjusted array length cannot be a removed field.
    """
    removed_numbers_set = set(removed_numbers)
    table: list[int] = [0]
    last_len = 0
    for i in range(0, num_slots_excl_removed - 1):
        if i in removed_numbers_set:
            table.append(last_len)
        else:
            table.append(i + 1)
            last_len = i + 1
    table_tuple = tuple(table)
    return f"{table_tuple}[{var}] if {var} < {num_slots_excl_removed} else {num_slots_excl_removed}"


def _init_default(default: Any, fields: Sequence[_Field]) -> None:
    for field in fields:
        attribute = field.field.attribute
        get_field_default = make_function(
            name="get_default",
            params=(),
            body=(Line.join("return ", field.type.default_expr()),),
        )
        object.__setattr__(default, attribute, get_field_default())
    object.__setattr__(default, "_unrecognized", None)
    object.__setattr__(default, "_array_len", 0)


def _make_mutable_getter(field: _Field) -> Callable[[Any], Any]:
    # Two cases: the field either has struct type or array type.
    attribute = field.field.attribute
    builder = BodyBuilder()
    if isinstance(field.type, StructAdapter):
        frozen_class = field.type.gen_class
        mutable_class = frozen_class.Mutable
        builder.append_ln(
            f"if self.{attribute}.__class__ is ",
            Expr.local("mutable_class", mutable_class),
            ":",
        )
        builder.append_ln(f"  return self.{attribute}")
        builder.append_ln(
            f"if self.{attribute}.__class__ is ",
            Expr.local("frozen_class", frozen_class),
            ":",
        )
        builder.append_ln(f"  self.{attribute} = self.{attribute}.to_mutable()")
        builder.append_ln(f"  return self.{attribute}")
        expected = f"{frozen_class.__qualname__} or {mutable_class.__qualname__}"
        found = f"self.{attribute}.__class__.__name__"
        builder.append_ln(
            "raise ",
            Expr.local("TypeError", TypeError),
            f"(f'expected: {expected}; found: {{{found}}}')",
        )
    else:
        builder.append_ln(f"if not isinstance(self.{attribute}, list):")
        builder.append_ln(f"  self.{attribute} = list(self.{attribute})")
        builder.append_ln(f"return self.{attribute}")
    return make_function(
        name=f"mutable_{field.field.name}",
        params=["self"],
        body=builder.build(),
    )


def _name_private_is_frozen_attr(record_id: str) -> str:
    record_name = _spec.RecordId.parse(record_id).name
    hex_hash = hex(abs(hash(record_id)))[:6]
    return f"_is_{record_name}_{hex_hash}"


@dataclass(frozen=True)
class _UnrecognizedFields:
    __slots__ = (
        "json",
        "raw_bytes",
        "adjusted_json_array_len",
        "adjusted_bytes_array_len",
    )

    json: list[Any] | None
    raw_bytes: bytes | None
    adjusted_json_array_len: int | None
    adjusted_bytes_array_len: int | None

    @staticmethod
    def from_json(
        json: list[Any], adjusted_json_array_len: int
    ) -> "_UnrecognizedFields":
        return _UnrecognizedFields(
            json=json,
            raw_bytes=None,
            adjusted_json_array_len=adjusted_json_array_len,
            adjusted_bytes_array_len=None,
        )

    @staticmethod
    def from_bytes(
        raw_bytes: bytes, adjusted_bytes_array_len: int
    ) -> "_UnrecognizedFields":
        return _UnrecognizedFields(
            json=None,
            raw_bytes=raw_bytes,
            adjusted_json_array_len=None,
            adjusted_bytes_array_len=adjusted_bytes_array_len,
        )
