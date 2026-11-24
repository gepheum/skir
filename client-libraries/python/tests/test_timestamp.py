import dataclasses
import unittest
from datetime import datetime, timedelta, timezone
from typing import Any
from zoneinfo import ZoneInfo

from skir import Timestamp


class TimestampTestCase(unittest.TestCase):
    def test_getters(self):
        ts = Timestamp(unix_millis=200)
        self.assertEqual(ts.unix_millis, 200)
        self.assertEqual(ts.unix_seconds, 0.2)

    def test_from_unix_millis(self):
        ts = Timestamp.from_unix_millis(200)
        self.assertEqual(ts.unix_millis, 200)

    def test_from_unix_seconds(self):
        ts = Timestamp.from_unix_seconds(200)
        self.assertEqual(ts.unix_millis, 200000)

    def test_from_datetime(self):
        ts = Timestamp.from_datetime(datetime.fromtimestamp(200, tz=timezone.utc))
        self.assertEqual(ts.unix_millis, 200000)
        ts = Timestamp.from_datetime(
            datetime.fromtimestamp(200, tz=ZoneInfo("America/New_York"))
        )
        self.assertEqual(ts.unix_millis, 200000)
        ts = Timestamp.from_datetime(datetime.fromtimestamp(200))
        self.assertEqual(ts.unix_millis, 200000)
        ts = Timestamp.from_datetime(datetime.min)
        ts = Timestamp.from_datetime(datetime.max)

    def test_epoch(self):
        self.assertEqual(Timestamp.EPOCH.unix_millis, 0)

    def round_millis(self):
        unix_millis: Any = 200.8
        ts = Timestamp(unix_millis=unix_millis)
        self.assertEqual(ts.unix_millis, 201)

    def test_lower_bound(self):
        ts = Timestamp(unix_millis=-(10**20))
        self.assertEqual(ts.unix_millis, -8640000000000000)
        self.assertEqual(ts.unix_millis, Timestamp.MIN.unix_millis)

    def test_upper_bound(self):
        ts = Timestamp(unix_millis=10**20)
        self.assertEqual(ts.unix_millis, 8640000000000000)
        self.assertEqual(ts.unix_millis, Timestamp.MAX.unix_millis)

    def test_now(self):
        ts = Timestamp.now()
        now_as_dt = datetime.now(tz=timezone.utc)
        self.assertGreater(ts.unix_seconds, now_as_dt.timestamp() - 100)
        self.assertLess(ts.unix_seconds, now_as_dt.timestamp() + 100)

    def test_eq(self):
        self.assertEqual(
            Timestamp.from_unix_millis(2),
            Timestamp.from_unix_millis(2),
        )
        self.assertNotEqual(
            Timestamp.from_unix_millis(2),
            Timestamp.from_unix_millis(3),
        )

    def test_ordering(self):
        self.assertLess(
            Timestamp.from_unix_millis(2),
            Timestamp.from_unix_millis(3),
        )
        self.assertGreater(
            Timestamp.from_unix_millis(3),
            Timestamp.from_unix_millis(2),
        )

    def test_immutable(self):
        try:
            setattr(Timestamp.MIN, "unix_millis", 3)
            self.fail("Expected to fail with FrozenInstanceError")
        except dataclasses.FrozenInstanceError:
            pass

    def test_to_datetime(self):
        self.assertEqual(
            Timestamp.from_unix_seconds(200).to_datetime_or_raise(),
            datetime.fromtimestamp(200, tz=timezone.utc),
        )
        Timestamp.from_datetime(datetime.min + timedelta(days=1)).to_datetime_or_raise()
        Timestamp.from_datetime(datetime.max - timedelta(days=1)).to_datetime_or_raise()

    def test_to_datetime_out_of_bound(self):
        try:
            Timestamp.MIN.to_datetime_or_raise()
            self.fail("Expected to fail with OverflowError or ValueError")
        except Exception:
            pass
        self.assertEqual(
            Timestamp.MIN.to_datetime_or_limit(),
            datetime.min.replace(tzinfo=timezone.utc),
        )
        self.assertEqual(
            Timestamp.MAX.to_datetime_or_limit(),
            datetime.max.replace(tzinfo=timezone.utc),
        )

    def test_add_timedelta(self):
        ts = Timestamp.from_unix_seconds(200)
        actual: Timestamp = ts + timedelta(seconds=2, microseconds=3)
        self.assertEqual(actual, Timestamp.from_unix_seconds(202))

    def test_subtract_timedelta(self):
        ts = Timestamp.from_unix_seconds(200)
        actual: Timestamp = ts - timedelta(seconds=2, microseconds=3)
        self.assertEqual(actual, Timestamp.from_unix_seconds(198))

    def test_subtract_timestamp(self):
        a = Timestamp.from_unix_seconds(200)
        b = Timestamp.from_unix_seconds(104)
        actual: timedelta = a - b
        self.assertEqual(actual, timedelta(seconds=96))

    def test_repr(self):
        a = Timestamp.from_unix_seconds(123456789)
        self.assertEqual(
            repr(a),
            "Timestamp(\n  unix_millis=123456789000,\n  _formatted='1973-11-29T21:33:09.000Z',\n)",
        )
        self.assertEqual(
            str(a),
            "Timestamp(\n  unix_millis=123456789000,\n  _formatted='1973-11-29T21:33:09.000Z',\n)",
        )

    def test_repr_when_out_of_bounds(self):
        self.assertEqual(
            repr(Timestamp.MIN),
            "Timestamp(unix_millis=-8640000000000000)",
        )
