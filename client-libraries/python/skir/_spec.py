import enum
from dataclasses import dataclass
from typing import Optional, Union


class PrimitiveType(enum.Enum):
    BOOL = enum.auto()
    INT32 = enum.auto()
    INT64 = enum.auto()
    HASH64 = enum.auto()
    FLOAT32 = enum.auto()
    FLOAT64 = enum.auto()
    TIMESTAMP = enum.auto()
    STRING = enum.auto()
    BYTES = enum.auto()


@dataclass(frozen=True)
class ArrayType:
    item: "Type"
    key_attributes: tuple[str, ...] = ()


@dataclass(frozen=True)
class OptionalType:
    other: "Type"


Type = Union[PrimitiveType, ArrayType, OptionalType, str]


@dataclass(frozen=True)
class Field:
    """Field of a struct."""

    name: str
    number: int
    type: Type
    doc: str = ""
    has_mutable_getter: bool = False
    _attribute: str = ""  # If different from 'name'

    @property
    def attribute(self):
        return self._attribute or self.name


@dataclass(frozen=True)
class Struct:
    id: str
    doc: str = ""
    fields: tuple[Field, ...] = ()
    removed_numbers: tuple[int, ...] = ()
    _class_name: str = ""  # If different from the record name
    _class_qualname: str = ""  # If different from the qualified name of the record

    @property
    def class_name(self):
        return self._class_name or RecordId.parse(self.id).name

    @property
    def class_qualname(self):
        return self._class_qualname or RecordId.parse(self.id).qualname


@dataclass(frozen=True)
class ConstantVariant:
    """Constant variant of an enum."""

    name: str
    number: int
    doc: str = ""
    _attribute: str = ""  # If different from 'name'

    @property
    def attribute(self):
        return self._attribute or self.name


@dataclass(frozen=True)
class WrapperVariant:
    """Wrapper variant of an enum."""

    name: str
    number: int
    type: Type
    doc: str = ""


@dataclass(frozen=True)
class Enum:
    id: str
    doc: str = ""
    constant_variants: tuple[ConstantVariant, ...] = ()
    wrapper_variants: tuple[WrapperVariant, ...] = ()
    removed_numbers: tuple[int, ...] = ()
    _class_name: str = ""  # If different from the record name
    _class_qualname: str = ""  # If different from the qualified name of the record

    @property
    def class_name(self):
        return self._class_name or RecordId.parse(self.id).name

    @property
    def class_qualname(self):
        return self._class_qualname or RecordId.parse(self.id).qualname


Record = Union[Struct, Enum]


@dataclass(frozen=True)
class RecordId:
    record_id: str
    module_path: str
    name: str
    qualname: str
    name_parts: tuple[str, ...]

    @staticmethod
    def parse(record_id: str) -> "RecordId":
        colon_index = record_id.rfind(":")
        module_path = record_id[0:colon_index]
        qualname = record_id[colon_index + 1 :]
        name_parts = tuple(qualname.split("."))
        return RecordId(
            record_id=record_id,
            module_path=module_path,
            name=name_parts[-1],
            qualname=qualname,
            name_parts=name_parts,
        )

    @property
    def parent(self) -> Optional["RecordId"]:
        if len(self.name_parts) == 1:
            return None
        parent_name_parts = self.name_parts[0:-1]
        parent_qualname = ".".join(parent_name_parts)
        return RecordId(
            record_id=f"{self.module_path}:{parent_qualname}",
            module_path=self.module_path,
            name=parent_name_parts[-1],
            qualname=parent_qualname,
            name_parts=parent_name_parts,
        )


@dataclass(frozen=True)
class Method:
    name: str
    number: int
    request_type: Type
    response_type: Type
    doc: str = ""
    _var_name: str = ""  # If different from 'name'


@dataclass(frozen=True)
class Constant:
    name: str
    type: Type
    json_code: str
