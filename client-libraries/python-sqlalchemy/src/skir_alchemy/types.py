from __future__ import annotations

from typing import Any, Generic, TypeAlias, TypeVar

from skir import Serializer
from sqlalchemy.engine.interfaces import Dialect
from sqlalchemy.types import JSON, TypeDecorator

_T = TypeVar("_T")

_JsonValue: TypeAlias = Any


class DenseJson(TypeDecorator[_T | None], Generic[_T]):
    """Persist values as JSON using Skir's dense JSON encoding.

    Uses skir.Serializer[T] to convert between Python values and dense JSON.

        Example:
            from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column
            from skir_alchemy import DenseJson
            from geometry_skir import Point

            class Base(DeclarativeBase):
                pass

            class GeometryRow(Base):
                __tablename__ = "geometry"

                id: Mapped[int] = mapped_column(primary_key=True)
                point: Mapped[Point | None] = mapped_column(DenseJson(Point.serializer))
    """

    impl = JSON
    cache_ok = True

    def __init__(
        self,
        serializer: Serializer[_T],
        *,
        keep_unrecognized_values: bool = False,
    ):
        super().__init__()
        self._serializer = serializer
        self._keep_unrecognized_values = keep_unrecognized_values

    def load_dialect_impl(self, dialect: Dialect):
        return dialect.type_descriptor(JSON(none_as_null=False))

    def process_bind_param(
        self, value: _T | None, dialect: Dialect
    ) -> _JsonValue | None:
        if value is None:
            return None
        return self._serializer.to_json(value, readable=False)

    def process_result_value(
        self, value: _JsonValue | None, dialect: Dialect
    ) -> _T | None:
        if value is None:
            return None
        return self._serializer.from_json(
            value, keep_unrecognized_values=self._keep_unrecognized_values
        )
