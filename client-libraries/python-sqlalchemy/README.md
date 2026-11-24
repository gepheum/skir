# skir-sqlalchemy

Super lightweight bridge between Skir serializers and SQLAlchemy JSON columns.

## Install

```shell
pip install skir-sqlalchemy
```

## DenseJson

`DenseJson(serializer)` stores values of type `T` in a SQLAlchemy JSON column using Skir's dense JSON format.

- `serializer`: `skir_client.Serializer[T]`
- `keep_unrecognized_values`: forwarded to `serializer.from_json(...)`

### Example

```python
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column
from skir_alchemy import DenseJson
from geometry_skir import Point


class Base(DeclarativeBase):
    pass


class GeometryRow(Base):
    __tablename__ = "geometry"

    id: Mapped[int] = mapped_column(primary_key=True)
    point: Mapped[Point | None] = mapped_column(DenseJson(Point.serializer))
```
