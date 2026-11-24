import dataclasses
import unittest
from typing import Any, cast

from skir import Serializer
from sqlalchemy import create_engine, select
from sqlalchemy.orm import DeclarativeBase, Mapped, Session, mapped_column

from skir_alchemy import DenseJson


@dataclasses.dataclass(frozen=True)
class Point:
    x: int
    y: int


class PointSerializer:
    def to_json(self, input: Point, *, readable: bool = False):
        del readable
        return [input.x, input.y]

    def from_json(self, json, keep_unrecognized_values: bool = False):
        del keep_unrecognized_values
        if not isinstance(json, list) or len(json) != 2:
            raise ValueError(f"Invalid dense JSON for Point: {json!r}")
        return Point(x=int(json[0]), y=int(json[1]))


class LoggingPointSerializer:
    """Wrapper serializer that logs from_json calls."""

    def __init__(self):
        self._call_log: list[bool] = []
        self._wrapped = PointSerializer()

    def to_json(self, input: Point, *, readable: bool = False):
        return self._wrapped.to_json(input, readable=readable)

    def from_json(self, json: Any, keep_unrecognized_values: bool = False) -> Point:
        self._call_log.append(keep_unrecognized_values)
        return self._wrapped.from_json(
            json, keep_unrecognized_values=keep_unrecognized_values
        )


class Base(DeclarativeBase):
    pass


class GeometryRow(Base):
    __tablename__ = "geometry"

    id: Mapped[int] = mapped_column(primary_key=True)
    point: Mapped[Point | None] = mapped_column(
        DenseJson(cast(Serializer[Point], PointSerializer()))
    )
    center: Mapped[Point | None] = mapped_column(
        DenseJson[Point](cast(Serializer[Point], PointSerializer())),
        nullable=True,
    )


class SkirJsonTypeTestCase(unittest.TestCase):
    def test_round_trip_using_serializer(self):
        engine = create_engine("sqlite+pysqlite:///:memory:")
        Base.metadata.create_all(engine)

        with Session(engine) as session:
            session.add(GeometryRow(id=1, point=Point(3, 7)))
            session.commit()

        with Session(engine) as session:
            fetched = session.scalar(select(GeometryRow).where(GeometryRow.id == 1))
            self.assertIsNotNone(fetched)
            assert fetched is not None
            self.assertEqual(fetched.point, Point(3, 7))

    def test_none_stays_none(self):
        engine = create_engine("sqlite+pysqlite:///:memory:")
        Base.metadata.create_all(engine)

        with Session(engine) as session:
            session.add(GeometryRow(id=2, point=None))
            session.commit()

        with Session(engine) as session:
            fetched = session.scalar(select(GeometryRow).where(GeometryRow.id == 2))
            self.assertIsNotNone(fetched)
            assert fetched is not None
            self.assertIsNone(fetched.point)

    def test_keep_unrecognized_values_parameter(self):
        """Test that keep_unrecognized_values parameter is passed to serializer."""
        logging_serializer = LoggingPointSerializer()

        # Create a fresh DeclarativeBase class for this test to avoid conflicts
        class TestBase(DeclarativeBase):
            pass

        class TestRowWithLogger(TestBase):
            __tablename__ = "test_row_logger"

            id: Mapped[int] = mapped_column(primary_key=True)
            point: Mapped[Point | None] = mapped_column(
                DenseJson[Point](
                    cast(Serializer[Point], logging_serializer),
                    keep_unrecognized_values=True,
                )
            )

        engine = create_engine("sqlite+pysqlite:///:memory:")
        TestBase.metadata.create_all(engine)

        with Session(engine) as session:
            session.add(TestRowWithLogger(id=1, point=Point(5, 9)))
            session.commit()

        logging_serializer._call_log.clear()

        with Session(engine) as session:
            fetched = session.scalar(
                select(TestRowWithLogger).where(TestRowWithLogger.id == 1)
            )
            self.assertIsNotNone(fetched)

        self.assertEqual(
            logging_serializer._call_log,
            [True],
            "keep_unrecognized_values should be True",
        )
