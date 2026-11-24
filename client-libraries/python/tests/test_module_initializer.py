import dataclasses
import unittest
from typing import Any

from skir import KeyedItems, Method, Timestamp, _spec
from skir._module_initializer import init_module
from skir.reflection import TypeDescriptor


class ModuleInitializerTestCase(unittest.TestCase):
    def init_test_module(self) -> dict[str, Any]:
        globals: dict[str, Any] = {}
        init_module(
            records=(
                _spec.Struct(
                    id="my/module.skir:Point",
                    doc="A 2D point.",
                    fields=(
                        _spec.Field(
                            name="x",
                            number=0,
                            type=_spec.PrimitiveType.FLOAT32,
                            doc="X coordinate.",
                        ),
                        _spec.Field(
                            name="y",
                            number=2,
                            type=_spec.PrimitiveType.FLOAT32,
                        ),
                    ),
                    removed_numbers=(1,),
                ),
                _spec.Struct(
                    id="my/module.skir:Segment",
                    fields=(
                        _spec.Field(
                            name="a",
                            number=0,
                            type="my/module.skir:Point",
                            has_mutable_getter=True,
                        ),
                        _spec.Field(
                            name="bb",
                            _attribute="b",
                            number=1,
                            type="my/module.skir:Point",
                            has_mutable_getter=True,
                        ),
                        _spec.Field(
                            name="c",
                            number=2,
                            type=_spec.OptionalType("my/module.skir:Point"),
                            has_mutable_getter=True,
                        ),
                    ),
                ),
                _spec.Struct(
                    id="my/module.skir:Shape",
                    fields=(
                        _spec.Field(
                            name="points",
                            number=0,
                            type=_spec.ArrayType("my/module.skir:Point"),
                            has_mutable_getter=True,
                        ),
                    ),
                ),
                _spec.Struct(
                    id="my/module.skir:Primitives",
                    fields=(
                        _spec.Field(
                            name="bool",
                            number=0,
                            type=_spec.PrimitiveType.BOOL,
                        ),
                        _spec.Field(
                            name="bytes",
                            number=1,
                            type=_spec.PrimitiveType.BYTES,
                        ),
                        _spec.Field(
                            name="f32",
                            number=2,
                            type=_spec.PrimitiveType.FLOAT32,
                        ),
                        _spec.Field(
                            name="f64",
                            number=3,
                            type=_spec.PrimitiveType.FLOAT64,
                        ),
                        _spec.Field(
                            name="i32",
                            number=4,
                            type=_spec.PrimitiveType.INT32,
                        ),
                        _spec.Field(
                            name="i64",
                            number=5,
                            type=_spec.PrimitiveType.INT64,
                        ),
                        _spec.Field(
                            name="u64",
                            number=6,
                            type=_spec.PrimitiveType.HASH64,
                        ),
                        _spec.Field(
                            name="s",
                            number=7,
                            type=_spec.PrimitiveType.STRING,
                        ),
                        _spec.Field(
                            name="t",
                            number=8,
                            type=_spec.PrimitiveType.TIMESTAMP,
                        ),
                    ),
                ),
                _spec.Struct(
                    id="my/module.skir:After",
                    fields=(
                        _spec.Field(
                            name="points",
                            number=0,
                            type=_spec.ArrayType("my/module.skir:Point"),
                            has_mutable_getter=True,
                        ),
                    ),
                ),
                _spec.Enum(
                    id="my/module.skir:PrimaryColor",
                    constant_variants=(
                        _spec.ConstantVariant(
                            name="RED",
                            number=10,
                        ),
                        _spec.ConstantVariant(
                            name="GREEN",
                            number=20,
                        ),
                        _spec.ConstantVariant(
                            name="BLUE",
                            number=30,
                        ),
                    ),
                ),
                _spec.Enum(
                    id="my/module.skir:Status",
                    constant_variants=(
                        _spec.ConstantVariant(
                            name="OK",
                            number=1,
                        ),
                    ),
                    wrapper_variants=(
                        _spec.WrapperVariant(
                            name="error",
                            number=2,
                            type=_spec.PrimitiveType.STRING,
                        ),
                    ),
                    removed_numbers=(1, 4),
                ),
                _spec.Enum(
                    id="my/module.skir:JsonValue",
                    doc="A JSON value.",
                    constant_variants=(
                        _spec.ConstantVariant(
                            name="NULL",
                            number=1,
                        ),
                    ),
                    wrapper_variants=(
                        _spec.WrapperVariant(
                            name="bool",
                            number=2,
                            type=_spec.PrimitiveType.BOOL,
                            doc="A boolean value.",
                        ),
                        _spec.WrapperVariant(
                            name="number",
                            number=3,
                            type=_spec.PrimitiveType.FLOAT64,
                        ),
                        _spec.WrapperVariant(
                            name="string",
                            number=4,
                            type=_spec.PrimitiveType.STRING,
                        ),
                        _spec.WrapperVariant(
                            name="array",
                            number=5,
                            type=_spec.ArrayType("my/module.skir:JsonValue"),
                        ),
                        _spec.WrapperVariant(
                            name="object",
                            number=6,
                            type="my/module.skir:JsonValue.Object",
                        ),
                    ),
                    removed_numbers=(
                        100,
                        101,
                    ),
                ),
                _spec.Struct(
                    id="my/module.skir:JsonValue.Object",
                    fields=(
                        _spec.Field(
                            name="entries",
                            number=0,
                            type=_spec.ArrayType(
                                item="my/module.skir:JsonValue.ObjectEntry",
                                key_attributes=("name",),
                            ),
                        ),
                    ),
                ),
                _spec.Struct(
                    id="my/module.skir:JsonValue.ObjectEntry",
                    fields=(
                        _spec.Field(
                            name="name",
                            number=0,
                            type=_spec.PrimitiveType.STRING,
                        ),
                        _spec.Field(
                            name="value",
                            number=1,
                            type="my/module.skir:JsonValue",
                        ),
                    ),
                ),
                _spec.Struct(
                    id="my/module.skir:Parent",
                    fields=(),
                ),
                _spec.Enum(
                    id="my/module.skir:Parent.NestedEnum",
                ),
                _spec.Struct(
                    id="my/module.skir:Stuff",
                    fields=(
                        _spec.Field(
                            name="enum_wrappers",
                            number=0,
                            type=_spec.ArrayType(
                                item="my/module.skir:EnumWrapper",
                                key_attributes=(
                                    "status",
                                    "kind",
                                ),
                            ),
                        ),
                    ),
                ),
                _spec.Struct(
                    id="my/module.skir:EnumWrapper",
                    fields=(
                        _spec.Field(
                            name="status",
                            number=0,
                            type="my/module.skir:Status",
                        ),
                    ),
                ),
                _spec.Struct(
                    id="my/module.skir:Stuff.Overrides",
                    _class_name="NameOverrides",
                    _class_qualname="Stuff.NameOverrides",
                    fields=(
                        _spec.Field(
                            name="x",
                            _attribute="y",
                            number=0,
                            type=_spec.PrimitiveType.INT32,
                        ),
                    ),
                ),
                _spec.Struct(
                    id="my/module.skir:RecOuter",
                    fields=(
                        _spec.Field(
                            name="r",
                            number=0,
                            type="my/module.skir:RecOuter.RecInner",
                        ),
                    ),
                ),
                _spec.Struct(
                    id="my/module.skir:RecOuter.RecInner",
                    fields=(
                        _spec.Field(
                            name="r",
                            number=0,
                            type="my/module.skir:RecOuter",
                        ),
                    ),
                ),
                _spec.Struct(
                    id="my/module.skir:Rec",
                    fields=(
                        _spec.Field(
                            name="r",
                            number=0,
                            type="my/module.skir:Rec",
                        ),
                        _spec.Field(
                            name="x",
                            number=1,
                            type=_spec.PrimitiveType.INT32,
                        ),
                    ),
                ),
                _spec.Struct(
                    id="my/module.skir:Foobar",
                    fields=(
                        _spec.Field(
                            name="a",
                            number=1,
                            type=_spec.PrimitiveType.INT32,
                        ),
                        _spec.Field(
                            name="b",
                            number=3,
                            type=_spec.PrimitiveType.INT32,
                        ),
                        _spec.Field(
                            name="point",
                            number=4,
                            type="my/module.skir:Point",
                        ),
                    ),
                    removed_numbers=(0, 2),
                ),
            ),
            methods=(
                _spec.Method(
                    name="FirstMethod",
                    number=-300,
                    request_type="my/module.skir:Point",
                    response_type="my/module.skir:Shape",
                    doc="First method",
                ),
                _spec.Method(
                    name="SecondMethod",
                    number=-301,
                    request_type="my/module.skir:Point",
                    response_type="my/module.skir:Shape",
                    _var_name="MethodVar",
                ),
            ),
            constants=(
                _spec.Constant(
                    name="C",
                    type="my/module.skir:Point",
                    json_code="[1.5, 0, 2.5]",
                ),
            ),
            globals=globals,
            record_id_to_adapter={},
        )
        return globals

    def test_struct_getters(self):
        point_cls = self.init_test_module()["Point"]
        point = point_cls(x=1.5, y=2.5)
        self.assertEqual(point.x, 1.5)
        self.assertEqual(point.y, 2.5)

    def test_partial_static_factory_method(self):
        point_cls = self.init_test_module()["Point"]
        point = point_cls.partial(x=1.5)
        self.assertEqual(point.x, 1.5)
        self.assertEqual(point.y, 0.0)

    def test_replace(self):
        point_cls = self.init_test_module()["Point"]
        point = point_cls(x=1.5, y=2.5).replace(y=3.5)
        self.assertEqual(point.x, 1.5)
        self.assertEqual(point.y, 3.5)

    def test_to_mutable(self):
        point_cls = self.init_test_module()["Point"]
        point = point_cls(x=1.5, y=2.5)
        mutable = point.to_mutable()
        mutable.x = 4.0
        point = mutable.to_frozen()
        self.assertEqual(point.x, 4.0)
        self.assertEqual(point.y, 2.5)
        self.assertIs(point.to_frozen(), point)

    def test_struct_eq(self):
        point_cls = self.init_test_module()["Point"]
        a = point_cls(x=1.5, y=2.5)
        b = point_cls(x=1.5, y=2.5)
        c = point_cls(x=1.5, y=3.0)
        self.assertEqual(a, b)
        self.assertEqual(hash(a), hash(b))
        self.assertNotEqual(a, c)
        self.assertNotEqual(a, "foo")
        self.assertEqual(point_cls.partial(), point_cls(x=0.0, y=0.0))
        self.assertEqual(point_cls.DEFAULT, point_cls(x=0.0, y=0.0))

    def test_or_mutable(self):
        point_cls = self.init_test_module()["Point"]
        point_cls.OrMutable

    def test_primitives_default_values(self):
        primitives_cls = self.init_test_module()["Primitives"]
        a = primitives_cls(
            bool=False,
            bytes=b"",
            f32=0.0,
            f64=0,
            i32=0,
            i64=0,
            u64=0,
            t=Timestamp.EPOCH,
            s="",
        )
        b = primitives_cls.partial()
        self.assertEqual(a, b)
        self.assertEqual(hash(a), hash(b))

    def test_primitives_to_json(self):
        primitives_cls = self.init_test_module()["Primitives"]
        serializer = primitives_cls.serializer
        p = primitives_cls(
            bool=True,
            bytes=b"a",
            f32=3.14,
            f64=3.14,
            i32=1,
            i64=2,
            u64=3,
            t=Timestamp.from_unix_millis(4),
            s="",
        )
        self.assertEqual(serializer.to_json(p), [1, "YQ==", 3.14, 3.14, 1, 2, 3, "", 4])

    def test_primitives_from_json(self):
        primitives_cls = self.init_test_module()["Primitives"]
        serializer = primitives_cls.serializer
        json = [0] * 100
        self.assertEqual(serializer.from_json(json), primitives_cls.DEFAULT)
        self.assertEqual(
            serializer.from_json([1, "YQ==", 3.14, 3.14, 1, 2, 3, "", 4]),
            primitives_cls(
                bool=True,
                bytes=b"a",
                f32=3.14,
                f64=3.14,
                i32=1,
                i64=2,
                u64=3,
                t=Timestamp.from_unix_millis(4),
                s="",
            ),
        )

    def test_primitives_repr(self):
        primitives_cls = self.init_test_module()["Primitives"]
        p = primitives_cls(
            bool=True,
            bytes=b"a",
            f32=3.14,
            f64=3.14,
            i32=1,
            i64=2,
            u64=3,
            t=Timestamp.from_unix_millis(4),
            s="",
        )
        self.assertEqual(
            str(p),
            "Primitives(\n  bool=True,\n  bytes=b'a',\n  f32=3.14,\n  f64=3.14,\n  i32=1,\n  i64=2,\n  u64=3,\n  s='',\n  t=Timestamp(\n    unix_millis=4,\n    _formatted='1970-01-01T00:00:00.004Z',\n  ),\n)",  # noqa: E501
        )

    def test_from_json_converts_between_ints_and_floats(self):
        primitives_cls = self.init_test_module()["Primitives"]
        serializer = primitives_cls.serializer
        p = serializer.from_json([0, 0, 3])
        self.assertEqual(p.f32, 3.0)
        self.assertIsInstance(p.f32, float)
        p = serializer.from_json({"i32": 1.2})
        self.assertEqual(p.i32, 1)
        self.assertIsInstance(p.i32, int)

    def test_cannot_mutate_frozen_class(self):
        point_cls = self.init_test_module()["Point"]
        point = point_cls(x=1.5, y=2.5)
        try:
            point.x = 3.5
            self.fail("expected to raise FrozenInstanceError")
        except dataclasses.FrozenInstanceError:
            pass
        self.assertEqual(point.x, 1.5)

    def test_point_to_dense_json(self):
        point_cls = self.init_test_module()["Point"]
        serializer = point_cls.serializer
        point = point_cls(x=1.5, y=2.5)
        self.assertEqual(serializer.to_json(point), [1.5, 0, 2.5])
        self.assertEqual(serializer.to_json(point, readable=False), [1.5, 0, 2.5])
        self.assertEqual(serializer.to_json_code(point), "[1.5,0,2.5]")
        point = point_cls(x=1.5, y=0.0)
        self.assertEqual(serializer.to_json(point), [1.5])

    def test_point_to_readable_json(self):
        point_cls = self.init_test_module()["Point"]
        point = point_cls(x=1.5, y=2.5)
        json = point_cls.serializer.to_json(point, readable=True)
        self.assertEqual(json, {"x": 1.5, "y": 2.5})
        json_code = point_cls.serializer.to_json_code(point, readable=True)
        self.assertEqual(json_code, '{\n  "x": 1.5,\n  "y": 2.5\n}')

    def test_point_from_dense_json(self):
        point_cls = self.init_test_module()["Point"]
        serializer = point_cls.serializer
        self.assertEqual(serializer.from_json([1.5, 0, 2.5]), point_cls(x=1.5, y=2.5))
        self.assertEqual(serializer.from_json([1.5]), point_cls(x=1.5, y=0.0))
        self.assertEqual(serializer.from_json([0.0]), point_cls.DEFAULT)
        self.assertEqual(serializer.from_json(0), point_cls.DEFAULT)

    def test_point_from_readable_json(self):
        point_cls = self.init_test_module()["Point"]
        point = point_cls.serializer.from_json({"x": 1.5, "y": 2.5})
        self.assertEqual(point, point_cls(x=1.5, y=2.5))
        point = point_cls.serializer.from_json_code('{"x":1.5,"y":2.5}')
        self.assertEqual(point, point_cls(x=1.5, y=2.5))
        point = point_cls.serializer.from_json_code('{"x":1.5,"y":2.5,"z":[]}')
        self.assertEqual(point, point_cls(x=1.5, y=2.5))
        point = point_cls.serializer.from_json_code('{"x":1,"y":2}')
        self.assertEqual(point.x, 1.0)
        self.assertIsInstance(point.x, float)
        self.assertEqual(point._array_len, 3)

    def test_point_with_keep_unrecognized_values(self):
        point_cls = self.init_test_module()["Point"]
        serializer = point_cls.serializer
        point = serializer.from_json([1.5, 1, 2.5, True], keep_unrecognized_values=True)
        self.assertEqual(point, point_cls(x=1.5, y=2.5))
        self.assertEqual(serializer.to_json(point), [1.5, 0, 2.5, True])
        point = point.to_mutable().to_frozen()
        self.assertEqual(serializer.to_json(point), [1.5, 0, 2.5, True])

    def test_point_with_drop_unrecognized_fields(self):
        point_cls = self.init_test_module()["Point"]
        serializer = point_cls.serializer
        point = serializer.from_json([1.5, 1, 2.5, True])
        self.assertEqual(point, point_cls(x=1.5, y=2.5))
        self.assertEqual(serializer.to_json(point), [1.5, 0, 2.5])
        point = point.to_mutable().to_frozen()
        self.assertEqual(serializer.to_json(point), [1.5, 0, 2.5])

    def test_struct_to_dense_json_with_removed_fields(self):
        test_module = self.init_test_module()
        foobar_cls = test_module["Foobar"]
        point_cls = test_module["Point"]
        serializer = foobar_cls.serializer
        foobar = foobar_cls.partial()
        self.assertEqual(serializer.to_json_code(foobar), "[]")
        self.assertEqual(serializer.from_json_code("[]"), foobar)
        foobar = foobar_cls.partial(a=3)
        self.assertEqual(serializer.to_json_code(foobar), "[0,3]")
        self.assertEqual(serializer.from_json_code("[0,3]"), foobar)
        self.assertEqual(serializer.from_json_code("[0,3.1]"), foobar)
        foobar = foobar_cls(a=0, b=3, point=point_cls.DEFAULT)
        self.assertEqual(serializer.to_json_code(foobar), "[0,0,0,3]")
        self.assertEqual(serializer.from_json_code("[0,0,0,3]"), foobar)
        self.assertEqual(serializer.from_json_code("[0,0,0,3.1]"), foobar)
        foobar = foobar_cls.partial(point=point_cls.partial(x=2))
        self.assertEqual(serializer.to_json_code(foobar), "[0,0,0,0,[2.0]]")
        self.assertEqual(serializer.from_json_code("[0,0,0,0,[2.0]]"), foobar)

    def test_recursive_struct(self):
        rec_cls = self.init_test_module()["Rec"]
        r = rec_cls.partial(r=rec_cls(r=rec_cls.DEFAULT, x=1))
        serializer = rec_cls.serializer
        self.assertEqual(serializer.to_json_code(r), "[[[],1]]")
        self.assertEqual(serializer.from_json_code("[[[],1]]"), r)
        self.assertEqual(
            str(r), "Rec(\n  r=Rec(\n    r=Rec.DEFAULT,\n    x=1,\n  ),\n  x=0,\n)"
        )

    def test_struct_ctor_accepts_mutable_struct(self):
        module = self.init_test_module()
        segment_cls = module["Segment"]
        point_cls = module["Point"]
        segment = segment_cls(
            a=point_cls(x=1.0, y=2.0).to_mutable(),
            b=point_cls(x=3.0, y=4.0),
            c=None,
        )
        self.assertEqual(
            segment,
            segment_cls(
                a=point_cls(x=1.0, y=2.0),
                b=point_cls(x=3.0, y=4.0),
                c=None,
            ),
        )

    def test_struct_ctor_checks_type_of_struct_param(self):
        module = self.init_test_module()
        segment_cls = module["Segment"]
        try:
            segment_cls.partial(
                # Should be a Point
                a=segment_cls.DEFAULT,
            )
            self.fail("Expected to fail")
        except Exception as e:
            self.assertIn("Point", str(e))

    def test_struct_ctor_raises_error_if_unknown_arg(self):
        module = self.init_test_module()
        point_cls = module["Point"]
        try:
            point_cls(x=1, b=2, foo=4)
            self.fail("Expected to fail")
        except Exception:
            pass

    def test_struct_ctor_raises_error_if_missing_arg(self):
        module = self.init_test_module()
        point_cls = module["Point"]
        try:
            point_cls(x=1)
            self.fail("Expected to fail")
        except Exception:
            pass

    def test_to_frozen_checks_type_of_struct_field(self):
        module = self.init_test_module()
        segment_cls = module["Segment"]
        mutable = segment_cls.Mutable()
        mutable.a = segment_cls.DEFAULT  # Should be a Point
        try:
            mutable.to_frozen()
            self.fail("Expected to fail")
        except Exception as e:
            self.assertIn("Point", str(e))

    def test_struct_ctor_accepts_mutable_list(self):
        module = self.init_test_module()
        shape_cls = module["Shape"]
        point_cls = module["Point"]
        shape = shape_cls(
            points=[
                point_cls(x=1.0, y=2.0).to_mutable(),
                point_cls(x=3.0, y=4.0),
            ],
        )
        self.assertEqual(
            shape,
            shape_cls(
                points=(
                    point_cls(x=1.0, y=2.0),
                    point_cls(x=3.0, y=4.0),
                ),
            ),
        )

    def test_listuple_not_copied(self):
        module = self.init_test_module()
        shape_cls = module["Shape"]
        point_cls = module["Point"]
        shape = shape_cls(
            points=[
                point_cls(x=1.0, y=2.0),
                point_cls(x=3.0, y=4.0),
            ],
        )
        other_shape = shape.to_mutable().to_frozen()
        self.assertIsNot(other_shape, shape)
        self.assertIs(other_shape.points, shape.points)
        self.assertIsNot(other_shape.points.__class__, tuple)

    def test_single_empty_listuple_instance(self):
        module = self.init_test_module()
        shape_cls = module["Shape"]
        shape = shape_cls(
            points=[],
        )
        self.assertIs(shape.points, shape_cls(points=[]).points)
        self.assertIs(shape.points, shape.to_mutable().to_frozen().points)
        self.assertIsNot(shape.points, ())

    def test_optional(self):
        module = self.init_test_module()
        segment_cls = module["Segment"]
        point_cls = module["Point"]
        segment = segment_cls.partial(
            c=point_cls.Mutable(x=1.0, y=2.0),
        )
        other_segment = segment.to_mutable().to_frozen()
        self.assertEqual(
            other_segment,
            segment_cls.partial(
                c=point_cls(x=1.0, y=2.0),
            ),
        )

    def test_enum_unknown_constant(self):
        module = self.init_test_module()
        primary_color_cls = module["PrimaryColor"]
        unknown = primary_color_cls.UNKNOWN
        self.assertEqual(unknown.kind, "UNKNOWN")
        self.assertEqual(unknown.value, None)
        self.assertIs(unknown.union, unknown)
        serializer = primary_color_cls.serializer
        self.assertEqual(serializer.to_json(unknown), 0)
        self.assertEqual(serializer.to_json(unknown, readable=True), "unknown")
        self.assertFalse(bool(unknown))
        self.assertTrue(bool(primary_color_cls.RED))

    def test_enum_user_defined_constant(self):
        module = self.init_test_module()
        primary_color_cls = module["PrimaryColor"]
        red = primary_color_cls.RED
        self.assertEqual(red.kind, "RED")
        self.assertEqual(red.value, None)
        self.assertIs(red.union, red)
        serializer = primary_color_cls.serializer
        self.assertEqual(serializer.to_json(red), 10)
        self.assertEqual(serializer.to_json(red, readable=True), "red")

    def test_enum_wrap(self):
        module = self.init_test_module()
        status_cls = module["Status"]
        error = status_cls.wrap_error("An error occurred")
        self.assertEqual(error.kind, "error")
        self.assertEqual(error.value, "An error occurred")
        self.assertIs(error.union, error)
        serializer = status_cls.serializer
        self.assertEqual(serializer.to_json(error), [2, "An error occurred"])
        self.assertEqual(
            serializer.to_json(error, readable=True),
            {"kind": "error", "value": "An error occurred"},
        )

    def test_enum_kind(self):
        module = self.init_test_module()
        primary_color_cls = module["Status"]
        self.assertEqual(primary_color_cls.Kind, str)

    def test_enum_wrap_around_mutable_struct(self):
        module = self.init_test_module()
        json_value_cls = module["JsonValue"]
        json_object_cls = json_value_cls.Object
        json_object = json_value_cls.wrap_object(
            json_object_cls(entries=[]).to_mutable()
        )
        self.assertEqual(json_object.kind, "object")
        self.assertEqual(json_object.value, json_object_cls.DEFAULT)
        self.assertEqual(
            json_object, json_value_cls.wrap_object(json_object_cls.DEFAULT)
        )

    def test_enum_wrap_around_created_struct(self):
        module = self.init_test_module()
        json_value_cls = module["JsonValue"]
        json_object_entry_cls = json_value_cls.ObjectEntry
        json_object = json_value_cls.create_object(
            entries=[
                json_object_entry_cls(
                    name="a",
                    value=json_value_cls.wrap_string("b"),
                )
            ],
        )
        self.assertEqual(json_object.kind, "object")
        self.assertEqual(
            json_object.value.entries,
            (
                json_object_entry_cls(
                    name="a",
                    value=json_value_cls.wrap_string("b"),
                ),
            ),
        )

    def test_enum_to_json(self):
        module = self.init_test_module()
        status_cls = module["Status"]
        serializer = status_cls.serializer
        self.assertEqual(serializer.to_json(status_cls.UNKNOWN), 0)
        self.assertEqual(
            serializer.to_json(status_cls.UNKNOWN, readable=True), "unknown"
        )
        self.assertEqual(serializer.to_json(status_cls.OK), 1)
        self.assertEqual(serializer.to_json(status_cls.OK, readable=True), "ok")
        self.assertEqual(serializer.to_json(status_cls.OK, readable=False), 1)
        self.assertEqual(serializer.to_json(status_cls.wrap_error("E")), [2, "E"])
        self.assertEqual(
            serializer.to_json(status_cls.wrap_error("E"), readable=True),
            {"kind": "error", "value": "E"},
        )

    def test_enum_from_json(self):
        module = self.init_test_module()
        status_cls = module["Status"]
        serializer = status_cls.serializer
        self.assertEqual(serializer.from_json(0), status_cls.UNKNOWN)
        self.assertEqual(serializer.from_json("UNKNOWN"), status_cls.UNKNOWN)
        self.assertEqual(serializer.from_json(1), status_cls.OK)
        self.assertEqual(serializer.from_json("OK"), status_cls.OK)
        self.assertEqual(serializer.from_json([2, "E"]), status_cls.wrap_error("E"))
        self.assertEqual(
            serializer.from_json({"kind": "error", "value": "E"}),
            status_cls.wrap_error("E"),
        )

    def test_complex_enum_from_json(self):
        module = self.init_test_module()
        json_value_cls = module["JsonValue"]
        serializer = json_value_cls.serializer
        json_value = serializer.from_json(
            [
                5,
                [
                    0,
                    1,
                    [2, True],
                    [3, 3.14],
                    [4, "foo"],
                    [
                        6,
                        [["a", 0], ["b", 0]],
                    ],
                    [5, [[5, []]]],
                ],
            ]
        )
        self.assertEqual(
            json_value,
            json_value_cls.wrap_array(
                [
                    json_value_cls.UNKNOWN,
                    json_value_cls.NULL,
                    json_value_cls.wrap_bool(True),
                    json_value_cls.wrap_number(3.14),
                    json_value_cls.wrap_string("foo"),
                    json_value_cls.wrap_object(
                        json_value_cls.Object(
                            entries=[
                                json_value_cls.ObjectEntry.partial(),
                                json_value_cls.ObjectEntry.DEFAULT,
                            ],
                        )
                    ),
                    json_value_cls.wrap_array(
                        [
                            json_value_cls.wrap_array([]),
                        ]
                    ),
                ]
            ),
        )
        self.assertEqual(
            serializer.from_json(
                {
                    "kind": "array",
                    "value": [
                        "UNKNOWN",
                        "NULL",
                        {"kind": "bool", "value": True},
                        {"kind": "number", "value": 3.14},
                        {"kind": "string", "value": "foo"},
                        {"kind": "object", "value": {"entries": [{}, {}]}},
                        {"kind": "array", "value": [{"kind": "array", "value": []}]},
                    ],
                }
            ),
            json_value,
        )

    def test_struct_with_enum_field(self):
        json_value_cls = self.init_test_module()["JsonValue"]
        json_object_entry_cls = json_value_cls.ObjectEntry
        self.assertEqual(json_object_entry_cls.DEFAULT.value, json_value_cls.UNKNOWN)
        self.assertEqual(json_object_entry_cls.partial().value, json_value_cls.UNKNOWN)

    def test_enum_with_keep_unrecognized_values(self):
        json_value_cls = self.init_test_module()["JsonValue"]
        serializer = json_value_cls.serializer
        json_value = serializer.from_json(100, keep_unrecognized_values=True)  # removed
        self.assertEqual(json_value, json_value_cls.UNKNOWN)
        self.assertEqual(serializer.to_json(json_value), 0)
        json_value = serializer.from_json(
            [101, True], keep_unrecognized_values=True
        )  # removed
        self.assertEqual(json_value, json_value_cls.UNKNOWN)
        self.assertEqual(serializer.to_json(json_value), 0)
        json_value = serializer.from_json(
            102, keep_unrecognized_values=True
        )  # unrecognized
        self.assertEqual(json_value, json_value_cls.UNKNOWN)
        self.assertEqual(serializer.to_json(json_value), 102)
        json_value = serializer.from_json(
            [102, True], keep_unrecognized_values=True
        )  # unrecognized
        self.assertEqual(json_value, json_value_cls.UNKNOWN)
        self.assertEqual(serializer.to_json(json_value), [102, True])

    def test_enum_with_drop_unrecognized_fields(self):
        json_value_cls = self.init_test_module()["JsonValue"]
        serializer = json_value_cls.serializer
        json_value = serializer.from_json(100)  # removed
        self.assertEqual(json_value, json_value_cls.UNKNOWN)
        self.assertEqual(serializer.to_json(json_value), 0)
        json_value = serializer.from_json([101, True])  # removed
        self.assertEqual(json_value, json_value_cls.UNKNOWN)
        self.assertEqual(serializer.to_json(json_value), 0)
        json_value = serializer.from_json(102)  # unrecognized
        self.assertEqual(json_value, json_value_cls.UNKNOWN)
        self.assertEqual(serializer.to_json(json_value), 0)
        json_value = serializer.from_json([102, True])  # unrecognized
        self.assertEqual(json_value, json_value_cls.UNKNOWN)
        self.assertEqual(serializer.to_json(json_value), 0)

    def test_class_name(self):
        module = self.init_test_module()
        shape_cls = module["Shape"]
        json_value_cls = module["JsonValue"]
        json_object_cls = json_value_cls.Object
        self.assertEqual(shape_cls.__name__, "Shape")
        self.assertEqual(shape_cls.__qualname__, "Shape")
        self.assertEqual(json_value_cls.__name__, "JsonValue")
        self.assertEqual(json_value_cls.__qualname__, "JsonValue")
        self.assertEqual(json_object_cls.__name__, "Object")
        self.assertEqual(json_object_cls.__qualname__, "JsonValue.Object")

    def test_struct_repr(self):
        module = self.init_test_module()
        point_cls = module["Point"]
        self.assertEqual(
            repr(point_cls.partial(x=1.5)),
            "\n".join(
                [
                    "Point(",
                    "  x=1.5,",
                    "  y=0.0,",
                    ")",
                ]
            ),
        )
        self.assertEqual(
            repr(point_cls.partial(x=1.5).to_mutable()),
            "\n".join(
                [
                    "Point.Mutable(",
                    "  x=1.5,",
                    "  y=0.0,",
                    ")",
                ]
            ),
        )
        self.assertEqual(
            repr(point_cls(x=1.5, y=2.5)),
            "\n".join(
                [
                    "Point(",
                    "  x=1.5,",
                    "  y=2.5,",
                    ")",
                ]
            ),
        )
        self.assertEqual(
            repr(point_cls.partial()),
            "\n".join(
                [
                    "Point(",
                    "  x=0.0,",
                    "  y=0.0,",
                    ")",
                ]
            ),
        )
        self.assertEqual(
            repr(point_cls.DEFAULT),
            "Point.DEFAULT",
        )
        self.assertEqual(
            repr(point_cls.DEFAULT.to_mutable()),
            "\n".join(
                [
                    "Point.Mutable(",
                    "  x=0.0,",
                    "  y=0.0,",
                    ")",
                ]
            ),
        )
        shape_cls = module["Shape"]
        self.assertEqual(
            repr(shape_cls(points=[])),
            "Shape(points=[])",
        )
        self.assertEqual(
            repr(shape_cls(points=[]).to_mutable()),
            "Shape.Mutable(points=[])",
        )
        self.assertEqual(
            repr(shape_cls(points=[point_cls(x=1.5, y=0.0)])),
            "\n".join(
                [
                    "Shape(",
                    "  points=[",
                    "    Point(",
                    "      x=1.5,",
                    "      y=0.0,",
                    "    ),",
                    "  ],",
                    ")",
                ]
            ),
        )
        self.assertEqual(
            repr(
                shape_cls(
                    points=[
                        point_cls.partial(x=1.5),
                        point_cls.partial(y=2.5),
                    ],
                )
            ),
            "\n".join(
                [
                    "Shape(",
                    "  points=[",
                    "    Point(",
                    "      x=1.5,",
                    "      y=0.0,",
                    "    ),",
                    "    Point(",
                    "      x=0.0,",
                    "      y=2.5,",
                    "    ),",
                    "  ],",
                    ")",
                ]
            ),
        )
        self.assertEqual(
            repr(
                shape_cls.Mutable(
                    points=[
                        point_cls.partial(x=1.5),
                        point_cls.partial(y=2.5).to_mutable(),
                    ]
                )
            ),
            "\n".join(
                [
                    "Shape.Mutable(",
                    "  points=[",
                    "    Point(",
                    "      x=1.5,",
                    "      y=0.0,",
                    "    ),",
                    "    Point.Mutable(",
                    "      x=0.0,",
                    "      y=2.5,",
                    "    ),",
                    "  ],",
                    ")",
                ]
            ),
        )

    def test_enum_constant_repr(self):
        module = self.init_test_module()
        primary_color_cls = module["PrimaryColor"]
        parent_cls = module["Parent"]
        nested_enum_cls = parent_cls.NestedEnum
        self.assertEqual(repr(primary_color_cls.UNKNOWN), "PrimaryColor.UNKNOWN")
        self.assertEqual(repr(primary_color_cls.RED), "PrimaryColor.RED")
        self.assertEqual(repr(nested_enum_cls.UNKNOWN), "Parent.NestedEnum.UNKNOWN")

    def test_enum_value_repr(self):
        module = self.init_test_module()
        status_cls = module["Status"]
        json_value_cls = module["JsonValue"]
        json_object_cls = json_value_cls.Object
        self.assertEqual(
            repr(status_cls.wrap_error("An error")),
            "Status.wrap_error('An error')",
        )
        self.assertEqual(
            repr(status_cls.wrap_error("multiple\nlines\n")),
            "\n".join(
                [
                    "Status.wrap_error(",
                    "  '\\n'.join([",
                    "    'multiple',",
                    "    'lines',",
                    "    '',",
                    "  ])",
                    ")",
                ]
            ),
        )
        self.assertEqual(
            repr(json_value_cls.wrap_object(json_object_cls.DEFAULT)),
            "JsonValue.wrap_object(JsonValue.Object.DEFAULT)",
        )
        self.assertEqual(
            repr(json_value_cls.wrap_object(json_object_cls.partial())),
            "\n".join(
                [
                    "JsonValue.wrap_object(",
                    "  JsonValue.Object(entries=[])",
                    ")",
                ]
            ),
        )

    def test_find_in_keyed_items(self):
        json_value_cls = self.init_test_module()["JsonValue"]
        object_cls = json_value_cls.Object
        entry_cls = json_value_cls.ObjectEntry
        json_object = object_cls(
            entries=[
                entry_cls(
                    name="foo",
                    value=json_value_cls.wrap_string("value of foo"),
                ),
                entry_cls(
                    name="bar",
                    value=json_value_cls.wrap_string("value of bar #0"),
                ),
                entry_cls(
                    name="foobar",
                    value=json_value_cls.wrap_string("value of foobar"),
                ),
                entry_cls(
                    name="bar",
                    value=json_value_cls.wrap_string("value of bar #1"),
                ),
            ]
        )
        entries = json_object.entries
        self.assertIsInstance(entries, KeyedItems)
        self.assertIs(entries.find("foo"), entries[0])
        self.assertIs(entries.find("zoo"), None)
        self.assertIs(entries.find("bar"), entries[3])
        self.assertIs(entries.find_or_default("foo"), entries[0])
        self.assertIs(entries.find_or_default("zoo"), entry_cls.DEFAULT)
        serializer = json_value_cls.Object.serializer
        json_object = serializer.from_json_code("0")
        entries = json_object.entries
        self.assertIsInstance(entries, KeyedItems)
        self.assertIs(entries.find("zoo"), None)

    def test_find_in_keyed_items_with_complex_path(self):
        module = self.init_test_module()
        stuff_cls = module["Stuff"]
        enum_wrapper_cls = module["EnumWrapper"]
        status_cls = module["Status"]
        stuff = stuff_cls(
            enum_wrappers=[
                enum_wrapper_cls(
                    status=status_cls.OK,
                ),
                enum_wrapper_cls(
                    status=status_cls.wrap_error("an error"),
                ),
                enum_wrapper_cls(
                    status=status_cls.OK,
                ),
            ]
        )
        enum_wrappers = stuff.enum_wrappers
        self.assertIsInstance(enum_wrappers, KeyedItems)
        self.assertIs(enum_wrappers.find("OK"), enum_wrappers[2])
        self.assertIs(enum_wrappers.find("error"), enum_wrappers[1])
        self.assertIs(
            enum_wrappers.find_or_default("UNKNOWN"), enum_wrapper_cls.DEFAULT
        )
        enum_wrappers = stuff.to_mutable().to_frozen().enum_wrappers
        self.assertIs(enum_wrappers.find("error"), enum_wrappers[1])

    def test_name_overrides(self):
        name_overrides_cls = self.init_test_module()["Stuff"].NameOverrides
        name_overrides = name_overrides_cls(y=3)
        self.assertEqual(name_overrides.y, 3)
        self.assertEqual(name_overrides_cls.__name__, "NameOverrides")
        self.assertEqual(name_overrides_cls.__qualname__, "Stuff.NameOverrides")

    def test_mutable_getter_of_struct(self):
        module = self.init_test_module()
        segment_cls = module["Segment"]
        point_cls = module["Point"]
        segment = segment_cls(
            a=point_cls(x=1.0, y=2.0),
            b=point_cls(x=3.0, y=4.0),
            c=None,
        ).to_mutable()
        a = segment.mutable_a
        self.assertIsInstance(a, point_cls.Mutable)
        self.assertIs(segment.mutable_a, a)
        segment.a = "foo"
        try:
            segment.mutable_a()
            self.fail("Expected to fail")
        except TypeError as e:
            self.assertEqual(str(e), "expected: Point or Point.Mutable; found: str")

    def test_mutable_getter_of_array(self):
        module = self.init_test_module()
        shape_cls = module["Shape"]
        point_cls = module["Point"]
        shape = shape_cls(
            points=[
                point_cls(x=1.0, y=2.0),
                point_cls(x=3.0, y=4.0),
            ],
        ).to_mutable()
        points = shape.mutable_points
        self.assertIsInstance(points, list)
        self.assertIs(shape.mutable_points, points)

    def test_methods(self):
        module = self.init_test_module()
        first_method = module["FirstMethod"]
        self.assertEqual(
            first_method,
            Method(
                name="FirstMethod",
                number=-300,
                request_serializer=module["Point"].serializer,
                response_serializer=module["Shape"].serializer,
                doc="First method",
            ),
        )
        second_method = module["MethodVar"]
        self.assertEqual(
            second_method,
            Method(
                name="SecondMethod",
                number=-301,
                request_serializer=module["Point"].serializer,
                response_serializer=module["Shape"].serializer,
                doc="",
            ),
        )

    def test_constants(self):
        module = self.init_test_module()
        c = module["C"]
        Point = module["Point"]
        self.assertEqual(c, Point(x=1.5, y=2.5))

    def test_enum_type_descriptor(self):
        module = self.init_test_module()
        json_value_cls = module["JsonValue"]
        type_descriptor = json_value_cls.serializer.type_descriptor
        self.assertEqual(
            type_descriptor.as_json(),
            {
                "type": {"kind": "record", "value": "my/module.skir:JsonValue"},
                "records": [
                    {
                        "kind": "enum",
                        "id": "my/module.skir:JsonValue",
                        "doc": "A JSON value.",
                        "variants": [
                            {
                                "name": "null",
                                "number": 1,
                            },
                            {
                                "name": "bool",
                                "type": {"kind": "primitive", "value": "bool"},
                                "number": 2,
                                "doc": "A boolean value.",
                            },
                            {
                                "name": "number",
                                "type": {"kind": "primitive", "value": "float64"},
                                "number": 3,
                            },
                            {
                                "name": "string",
                                "type": {"kind": "primitive", "value": "string"},
                                "number": 4,
                            },
                            {
                                "name": "array",
                                "type": {
                                    "kind": "array",
                                    "value": {
                                        "item": {
                                            "kind": "record",
                                            "value": "my/module.skir:JsonValue",
                                        },
                                    },
                                },
                                "number": 5,
                            },
                            {
                                "name": "object",
                                "type": {
                                    "kind": "record",
                                    "value": "my/module.skir:JsonValue.Object",
                                },
                                "number": 6,
                            },
                        ],
                        "removed_numbers": [100, 101],
                    },
                    {
                        "kind": "struct",
                        "id": "my/module.skir:JsonValue.Object",
                        "fields": [
                            {
                                "name": "entries",
                                "type": {
                                    "kind": "array",
                                    "value": {
                                        "item": {
                                            "kind": "record",
                                            "value": "my/module.skir:JsonValue.ObjectEntry",
                                        },
                                        "key_extractor": "name",
                                    },
                                },
                                "number": 0,
                            }
                        ],
                    },
                    {
                        "kind": "struct",
                        "id": "my/module.skir:JsonValue.ObjectEntry",
                        "fields": [
                            {
                                "name": "name",
                                "type": {"kind": "primitive", "value": "string"},
                                "number": 0,
                            },
                            {
                                "name": "value",
                                "type": {
                                    "kind": "record",
                                    "value": "my/module.skir:JsonValue",
                                },
                                "number": 1,
                            },
                        ],
                    },
                ],
            },
        )
        self.assertEqual(
            str(TypeDescriptor.from_json(type_descriptor.as_json())),
            str(type_descriptor),
        )
        self.assertEqual(
            TypeDescriptor.from_json(type_descriptor.as_json()),
            type_descriptor,
        )

    def test_optional_type_descriptor(self):
        module = self.init_test_module()
        segment_cls = module["Segment"]
        type_descriptor = segment_cls.serializer.type_descriptor
        self.assertEqual(
            type_descriptor.as_json(),
            {
                "type": {"kind": "record", "value": "my/module.skir:Segment"},
                "records": [
                    {
                        "kind": "struct",
                        "id": "my/module.skir:Segment",
                        "fields": [
                            {
                                "name": "a",
                                "type": {
                                    "kind": "record",
                                    "value": "my/module.skir:Point",
                                },
                                "number": 0,
                            },
                            {
                                "name": "bb",
                                "type": {
                                    "kind": "record",
                                    "value": "my/module.skir:Point",
                                },
                                "number": 1,
                            },
                            {
                                "name": "c",
                                "type": {
                                    "kind": "optional",
                                    "value": {
                                        "kind": "record",
                                        "value": "my/module.skir:Point",
                                    },
                                },
                                "number": 2,
                            },
                        ],
                    },
                    {
                        "kind": "struct",
                        "id": "my/module.skir:Point",
                        "doc": "A 2D point.",
                        "fields": [
                            {
                                "name": "x",
                                "type": {"kind": "primitive", "value": "float32"},
                                "number": 0,
                                "doc": "X coordinate.",
                            },
                            {
                                "name": "y",
                                "type": {"kind": "primitive", "value": "float32"},
                                "number": 2,
                            },
                        ],
                        "removed_numbers": [1],
                    },
                ],
            },
        )
        self.assertEqual(
            str(TypeDescriptor.from_json(type_descriptor.as_json())),
            str(type_descriptor),
        )
        self.assertEqual(
            TypeDescriptor.from_json(type_descriptor.as_json()),
            type_descriptor,
        )

    def test_primitive_type_descriptor(self):
        module = self.init_test_module()
        segment_cls = module["Primitives"]
        type_descriptor = segment_cls.serializer.type_descriptor
        self.assertEqual(
            type_descriptor.as_json(),
            {
                "type": {"kind": "record", "value": "my/module.skir:Primitives"},
                "records": [
                    {
                        "kind": "struct",
                        "id": "my/module.skir:Primitives",
                        "fields": [
                            {
                                "name": "bool",
                                "type": {"kind": "primitive", "value": "bool"},
                                "number": 0,
                            },
                            {
                                "name": "bytes",
                                "type": {"kind": "primitive", "value": "bytes"},
                                "number": 1,
                            },
                            {
                                "name": "f32",
                                "type": {"kind": "primitive", "value": "float32"},
                                "number": 2,
                            },
                            {
                                "name": "f64",
                                "type": {"kind": "primitive", "value": "float64"},
                                "number": 3,
                            },
                            {
                                "name": "i32",
                                "type": {"kind": "primitive", "value": "int32"},
                                "number": 4,
                            },
                            {
                                "name": "i64",
                                "type": {"kind": "primitive", "value": "int64"},
                                "number": 5,
                            },
                            {
                                "name": "u64",
                                "type": {"kind": "primitive", "value": "hash64"},
                                "number": 6,
                            },
                            {
                                "name": "s",
                                "type": {"kind": "primitive", "value": "string"},
                                "number": 7,
                            },
                            {
                                "name": "t",
                                "type": {"kind": "primitive", "value": "timestamp"},
                                "number": 8,
                            },
                        ],
                    }
                ],
            },
        )
        self.assertEqual(
            str(TypeDescriptor.from_json(type_descriptor.as_json())),
            str(type_descriptor),
        )
        self.assertEqual(
            TypeDescriptor.from_json(type_descriptor.as_json()),
            type_descriptor,
        )

    def test_struct_binary_format_empty_struct(self):
        """Test binary encoding for empty struct (0 fields with non-default values)."""
        module = self.init_test_module()
        Point = module["Point"]

        # Empty struct should encode to wire 246 (0 fields)
        empty_point = Point.partial()
        empty_bytes = Point.serializer.to_bytes(empty_point)
        self.assertEqual(empty_bytes.hex(), "736b6972f6")  # skir + 246

        # Test roundtrip
        restored = Point.serializer.from_bytes(empty_bytes)
        self.assertEqual(restored, empty_point)
        self.assertIs(restored, Point.DEFAULT)

    def test_struct_binary_format_small_structs(self):
        """Test binary encoding for structs with 1-3 non-default fields."""
        module = self.init_test_module()
        Point = module["Point"]

        # One field (wire 247)
        one_field = Point.partial(x=1.0)
        one_bytes = Point.serializer.to_bytes(one_field)
        self.assertTrue(one_bytes.hex().startswith("736b6972f7"))  # skir + 247
        restored_one = Point.serializer.from_bytes(one_bytes)
        self.assertEqual(restored_one.x, 1.0)
        self.assertEqual(restored_one.y, 0.0)

        # Two fields (wire 248)
        two_fields = Point(x=1.0, y=2.0)
        two_bytes = Point.serializer.to_bytes(two_fields)
        self.assertEqual(two_fields._array_len, 3)
        self.assertTrue(
            two_bytes, b"skir\xf9\xf0\x00\x00\x80?\x00\xf0\x00\x00\x00@"
        )  # skir + 249
        restored_two = Point.serializer.from_bytes(two_bytes)
        self.assertEqual(restored_two._array_len, 3)
        self.assertEqual(restored_two.x, 1.0)
        self.assertEqual(restored_two.y, 2.0)

    def test_struct_binary_format_large_structs(self):
        """Test binary encoding for structs with more than 3 non-default fields."""
        module = self.init_test_module()
        Primitives = module["Primitives"]

        # Struct with many fields should use wire 250 + length prefix
        full_struct = Primitives(
            bool=True,
            bytes=b"test",
            f32=4.5,
            f64=2.71828,
            i32=42,
            i64=123456789,
            u64=987654321,
            s="hello",
            t=Timestamp.from_unix_millis(1000),
        )
        full_bytes = Primitives.serializer.to_bytes(full_struct)
        self.assertTrue(full_bytes.hex().startswith("736b6972fa"))  # skir + 250

        # Test roundtrip
        restored = Primitives.serializer.from_bytes(full_bytes)
        self.assertEqual(restored.bool, True)
        self.assertEqual(restored.bytes, b"test")
        self.assertAlmostEqual(restored.f32, 4.5, places=5)
        self.assertAlmostEqual(restored.f64, 2.71828, places=10)
        self.assertEqual(restored.i32, 42)
        self.assertEqual(restored.i64, 123456789)
        self.assertEqual(restored.u64, 987654321)
        self.assertEqual(restored.s, "hello")
        self.assertEqual(restored.t, Timestamp.from_unix_millis(1000))
        self.assertEqual(restored, full_struct)

    def test_struct_binary_with_optional_fields(self):
        """Test binary serialization of structs with optional fields."""
        module = self.init_test_module()
        Segment = module["Segment"]
        Point = module["Point"]

        # Test with optional field set to None
        seg_with_none = Segment(a=Point(x=1.0, y=2.0), b=Point(x=3.0, y=4.0), c=None)
        bytes_none = Segment.serializer.to_bytes(seg_with_none)
        restored_none = Segment.serializer.from_bytes(bytes_none)
        self.assertEqual(restored_none.a.x, 1.0)
        self.assertEqual(restored_none.a.y, 2.0)
        self.assertEqual(restored_none.b.x, 3.0)
        self.assertEqual(restored_none.b.y, 4.0)
        self.assertIsNone(restored_none.c)
        self.assertEqual(restored_none, seg_with_none)

        # Test with optional field set to a value
        seg_with_value = Segment(
            a=Point(x=1.0, y=2.0), b=Point(x=3.0, y=4.0), c=Point(x=5.0, y=6.0)
        )
        bytes_value = Segment.serializer.to_bytes(seg_with_value)
        restored_value = Segment.serializer.from_bytes(bytes_value)
        self.assertEqual(restored_value.a.x, 1.0)
        self.assertEqual(restored_value.a.y, 2.0)
        self.assertEqual(restored_value.b.x, 3.0)
        self.assertEqual(restored_value.b.y, 4.0)
        self.assertIsNotNone(restored_value.c)
        self.assertEqual(restored_value.c.x, 5.0)
        self.assertEqual(restored_value.c.y, 6.0)
        self.assertEqual(restored_value, seg_with_value)

    def test_struct_binary_with_nested_structs(self):
        """Test binary serialization of nested struct fields."""
        module = self.init_test_module()
        Segment = module["Segment"]
        Point = module["Point"]

        segment = Segment(
            a=Point(x=10.0, y=20.0), b=Point(x=30.0, y=40.0), c=Point(x=50.0, y=60.0)
        )

        # Binary roundtrip
        binary_bytes = Segment.serializer.to_bytes(segment)
        restored = Segment.serializer.from_bytes(binary_bytes)

        self.assertEqual(restored.a.x, 10.0)
        self.assertEqual(restored.a.y, 20.0)
        self.assertEqual(restored.b.x, 30.0)
        self.assertEqual(restored.b.y, 40.0)
        self.assertIsNotNone(restored.c)
        self.assertEqual(restored.c.x, 50.0)
        self.assertEqual(restored.c.y, 60.0)
        self.assertEqual(restored, segment)

    def test_struct_binary_with_array_fields(self):
        """Test binary serialization of structs with array fields."""
        module = self.init_test_module()
        Shape = module["Shape"]
        Point = module["Point"]

        # Test with empty array
        empty_shape = Shape(points=())
        empty_bytes = Shape.serializer.to_bytes(empty_shape)
        restored_empty = Shape.serializer.from_bytes(empty_bytes)
        self.assertEqual(len(restored_empty.points), 0)

        # Test with small array (1-3 elements)
        small_shape = Shape(points=(Point(x=1.0, y=2.0), Point(x=3.0, y=4.0)))
        small_bytes = Shape.serializer.to_bytes(small_shape)
        restored_small = Shape.serializer.from_bytes(small_bytes)
        self.assertEqual(len(restored_small.points), 2)
        self.assertEqual(restored_small.points[0].x, 1.0)
        self.assertEqual(restored_small.points[0].y, 2.0)
        self.assertEqual(restored_small.points[1].x, 3.0)
        self.assertEqual(restored_small.points[1].y, 4.0)

        # Test with larger array
        large_shape = Shape(
            points=(
                Point(x=1.0, y=2.0),
                Point(x=3.0, y=4.0),
                Point(x=5.0, y=6.0),
                Point(x=7.0, y=8.0),
                Point(x=9.0, y=10.0),
            )
        )
        large_bytes = Shape.serializer.to_bytes(large_shape)
        restored_large = Shape.serializer.from_bytes(large_bytes)
        self.assertEqual(len(restored_large.points), 5)
        for i, point in enumerate(restored_large.points):
            self.assertEqual(point.x, float(i * 2 + 1))
            self.assertEqual(point.y, float(i * 2 + 2))

    def test_struct_binary_default_values(self):
        """Test that default values are handled correctly in binary serialization."""
        module = self.init_test_module()
        Primitives = module["Primitives"]

        # All defaults
        default_struct = Primitives.DEFAULT
        default_bytes = Primitives.serializer.to_bytes(default_struct)

        # Should encode as empty struct (wire 246)
        self.assertTrue(default_bytes.hex().startswith("736b6972f6"))

        restored = Primitives.serializer.from_bytes(default_bytes)
        self.assertEqual(restored.bool, False)
        self.assertEqual(restored.bytes, b"")
        self.assertEqual(restored.f32, 0.0)
        self.assertEqual(restored.f64, 0.0)
        self.assertEqual(restored.i32, 0)
        self.assertEqual(restored.i64, 0)
        self.assertEqual(restored.u64, 0)
        self.assertEqual(restored.s, "")
        self.assertEqual(restored.t, Timestamp.from_unix_millis(0))
        self.assertEqual(restored, default_struct)

    def test_struct_binary_partial_defaults(self):
        """Test structs with some default and some non-default values."""
        module = self.init_test_module()
        Primitives = module["Primitives"]

        # Only set some fields
        partial_struct = Primitives(
            bool=False,  # default
            bytes=b"",  # default
            f32=0.0,  # default
            f64=0.0,  # default
            i32=42,  # non-default
            i64=0,  # default
            u64=0,  # default
            s="test",  # non-default
            t=Timestamp.from_unix_millis(0),  # default
        )

        partial_bytes = Primitives.serializer.to_bytes(partial_struct)
        restored = Primitives.serializer.from_bytes(partial_bytes)

        self.assertEqual(restored.bool, False)
        self.assertEqual(restored.bytes, b"")
        self.assertEqual(restored.f32, 0.0)
        self.assertEqual(restored.f64, 0.0)
        self.assertEqual(restored.i32, 42)
        self.assertEqual(restored.i64, 0)
        self.assertEqual(restored.u64, 0)
        self.assertEqual(restored.s, "test")
        self.assertEqual(restored.t, Timestamp.from_unix_millis(0))
        self.assertEqual(restored, partial_struct)

    def test_struct_binary_edge_case_values(self):
        """Test binary serialization with edge case values."""
        module = self.init_test_module()
        Primitives = module["Primitives"]

        # Test with edge case values
        edge_struct = Primitives(
            bool=True,
            bytes=b"\x00\xff",  # null byte and max byte
            f32=float("inf"),
            f64=float("-inf"),
            i32=2147483647,  # max int32
            i64=-9223372036854775808,  # min int64
            u64=18446744073709551615,  # max hash64
            s="\u0000\uffff",  # null char and max unicode
            t=Timestamp.from_unix_millis(-8640000000000000),  # min timestamp
        )

        edge_bytes = Primitives.serializer.to_bytes(edge_struct)
        restored = Primitives.serializer.from_bytes(edge_bytes)

        self.assertEqual(restored.bool, True)
        self.assertEqual(restored.bytes, b"\x00\xff")
        self.assertEqual(restored.f32, float("inf"))
        self.assertEqual(restored.f64, float("-inf"))
        self.assertEqual(restored.i32, 2147483647)
        self.assertEqual(restored.i64, -9223372036854775808)
        self.assertEqual(restored.u64, 18446744073709551615)
        self.assertEqual(restored.s, "\u0000\uffff")
        self.assertEqual(restored.t, Timestamp.from_unix_millis(-8640000000000000))
        self.assertEqual(restored, edge_struct)

    def test_struct_binary_complex_nested_structure(self):
        """Test binary serialization of complex nested structures."""
        module = self.init_test_module()
        Shape = module["Shape"]
        Point = module["Point"]

        # Create a complex shape with multiple points
        complex_shape = Shape(
            points=(
                Point(x=0.0, y=0.0),
                Point(x=100.0, y=0.0),
                Point(x=100.0, y=100.0),
                Point(x=0.0, y=100.0),
            )
        )

        # Binary roundtrip
        binary_bytes = Shape.serializer.to_bytes(complex_shape)
        restored = Shape.serializer.from_bytes(binary_bytes)

        self.assertEqual(restored, complex_shape)
        expected_coords = [(0.0, 0.0), (100.0, 0.0), (100.0, 100.0), (0.0, 100.0)]
        for i, (expected_x, expected_y) in enumerate(expected_coords):
            self.assertEqual(restored.points[i].x, expected_x)
            self.assertEqual(restored.points[i].y, expected_y)

    def test_struct_binary_multiple_roundtrips(self):
        """Test that multiple binary serialization roundtrips preserve data."""
        module = self.init_test_module()
        Point = module["Point"]

        original = Point(x=3.14159, y=2.71828)
        current = original

        # Do multiple roundtrips
        for _ in range(5):
            binary_bytes = Point.serializer.to_bytes(current)
            current = Point.serializer.from_bytes(binary_bytes)

        # Should still be equal (within floating point precision)
        self.assertAlmostEqual(current.x, original.x, places=5)
        self.assertAlmostEqual(current.y, original.y, places=5)

    def test_struct_binary_empty_vs_default(self):
        """Test that empty struct and struct with defaults produce same binary output."""
        module = self.init_test_module()
        Point = module["Point"]

        empty = Point.DEFAULT
        with_defaults = Point(x=0.0, y=0.0)

        empty_bytes = Point.serializer.to_bytes(empty)
        defaults_bytes = Point.serializer.to_bytes(with_defaults)

        # Both should produce identical binary output
        self.assertEqual(empty_bytes, defaults_bytes)

        # Both should roundtrip to equivalent objects
        restored_empty = Point.serializer.from_bytes(empty_bytes)
        restored_defaults = Point.serializer.from_bytes(defaults_bytes)

        self.assertEqual(restored_empty, restored_defaults)
        self.assertEqual(restored_empty.x, 0.0)
        self.assertEqual(restored_empty.y, 0.0)

    def test_struct_binary_with_drop_unrecognized_fields(self):
        """Test that keep_unrecognized_values=False (default) drops unrecognized fields in binary format."""
        module = self.init_test_module()
        Point = module["Point"]

        # Create a point with unrecognized fields via JSON
        point_from_json = Point.serializer.from_json(
            [1.5, 0, 2.5, 100], keep_unrecognized_values=True
        )
        # This point has unrecognized field at index 3
        self.assertEqual(Point.serializer.to_json(point_from_json), [1.5, 0, 2.5, 100])

        # Now convert to binary and back WITHOUT keep_unrecognized_values
        binary_bytes = Point.serializer.to_bytes(point_from_json)
        restored_drop = Point.serializer.from_bytes(binary_bytes)  # default is False

        # The unrecognized field should be dropped
        self.assertEqual(restored_drop.x, 1.5)
        self.assertEqual(restored_drop.y, 2.5)
        # Verify it round-trips through JSON WITHOUT the unrecognized field
        self.assertEqual(Point.serializer.to_json(restored_drop), [1.5, 0, 2.5])

        # Test that mutable roundtrip also drops unrecognized fields
        mutable = restored_drop.to_mutable().to_frozen()
        self.assertEqual(Point.serializer.to_json(mutable), [1.5, 0, 2.5])

    def test_struct_binary_format_with_removed_fields_drop_unrecognized(self):
        """Test binary format drops removed field data when keep_unrecognized_values=False."""
        module = self.init_test_module()
        Foobar = module["Foobar"]

        # Foobar has removed_numbers=(0, 2)
        # Create from JSON with data in removed field positions
        foobar_from_json = Foobar.serializer.from_json(
            [5, 10, 15, 20, [1.0]], keep_unrecognized_values=True
        )

        # Convert to binary and back WITHOUT keep_unrecognized_values
        binary_bytes = Foobar.serializer.to_bytes(foobar_from_json)
        restored = Foobar.serializer.from_bytes(binary_bytes)  # default drops

        # Verify the recognized fields are correct
        self.assertEqual(restored.a, 10)
        self.assertEqual(restored.b, 20)
        self.assertEqual(restored.point.x, 1.0)

        # Verify unrecognized/removed fields are dropped through JSON
        restored_json = Foobar.serializer.to_json(restored)
        # Should only have recognized fields, removed fields should be 0
        self.assertEqual(restored_json, [0, 10, 0, 20, [1.0]])

    def test_enum_binary_format_constants(self):
        """Test binary encoding for enum constant fields."""
        module = self.init_test_module()
        PrimaryColor = module["PrimaryColor"]

        # Test binary encoding for constant fields
        red_bytes = PrimaryColor.serializer.to_bytes(PrimaryColor.RED)
        self.assertEqual(red_bytes, b"skir\n")

        green_bytes = PrimaryColor.serializer.to_bytes(PrimaryColor.GREEN)
        self.assertTrue(green_bytes, b"skir\x02")

        blue_bytes = PrimaryColor.serializer.to_bytes(PrimaryColor.BLUE)
        self.assertEqual(blue_bytes, b"skir\x1e")

        # Test binary roundtrips
        self.assertEqual(
            PrimaryColor.serializer.from_bytes(red_bytes), PrimaryColor.RED
        )
        self.assertEqual(
            PrimaryColor.serializer.from_bytes(green_bytes), PrimaryColor.GREEN
        )
        self.assertEqual(
            PrimaryColor.serializer.from_bytes(blue_bytes), PrimaryColor.BLUE
        )

    def test_enum_binary_format_value_fields(self):
        """Test binary encoding for enum wrapper fields."""
        module = self.init_test_module()
        Status = module["Status"]

        # Test binary encoding for wrapper field
        error_status = Status.wrap_error("test error")
        error_bytes = Status.serializer.to_bytes(error_status)
        self.assertTrue(error_bytes.hex().startswith("736b6972"))  # skir prefix

        # Test binary roundtrip
        restored = Status.serializer.from_bytes(error_bytes)
        self.assertEqual(restored.kind, "error")
        self.assertEqual(restored.value, "test error")
        self.assertEqual(restored, error_status)

    def test_enum_binary_roundtrip_all_constant_types(self):
        """Test that all enum constant types roundtrip correctly through binary."""
        module = self.init_test_module()
        Status = module["Status"]

        constant_values = [Status.OK]

        for status in constant_values:
            # Test binary roundtrip
            binary_bytes = Status.serializer.to_bytes(status)
            restored = Status.serializer.from_bytes(binary_bytes)
            self.assertEqual(restored, status)

    def test_enum_binary_roundtrip_value_fields(self):
        """Test binary roundtrip for enum wrapper fields."""
        module = self.init_test_module()
        Status = module["Status"]

        # Test with various error messages
        test_cases = [
            "simple error",
            "error with\nnewlines",
            "",
            "error with special chars: \u0000\uffff",
        ]

        for error_msg in test_cases:
            error_status = Status.wrap_error(error_msg)
            binary_bytes = Status.serializer.to_bytes(error_status)
            restored = Status.serializer.from_bytes(binary_bytes)

            self.assertEqual(restored.kind, "error")
            self.assertEqual(restored.value, error_msg)
            self.assertEqual(restored, error_status)

    def test_enum_binary_unknown_constant(self):
        """Test binary encoding for unknown enum constant."""
        module = self.init_test_module()
        PrimaryColor = module["PrimaryColor"]

        # Test unknown constant
        unknown = PrimaryColor.UNKNOWN
        unknown_bytes = PrimaryColor.serializer.to_bytes(unknown)
        self.assertTrue(unknown_bytes.hex().startswith("736b6972"))

        # Roundtrip should return UNKNOWN
        restored = PrimaryColor.serializer.from_bytes(unknown_bytes)
        self.assertEqual(restored.kind, "UNKNOWN")
        self.assertEqual(restored, PrimaryColor.UNKNOWN)

    def test_enum_binary_complex_value_types(self):
        """Test binary serialization with complex enum value types."""
        module = self.init_test_module()
        JsonValue = module["JsonValue"]

        # Test with string value
        string_val = JsonValue.wrap_string("hello world")
        string_bytes = JsonValue.serializer.to_bytes(string_val)
        restored_string = JsonValue.serializer.from_bytes(string_bytes)
        self.assertEqual(restored_string.kind, "string")
        self.assertEqual(restored_string.value, "hello world")

        # Test with number value
        number_val = JsonValue.wrap_number(3.14159)
        number_bytes = JsonValue.serializer.to_bytes(number_val)
        restored_number = JsonValue.serializer.from_bytes(number_bytes)
        self.assertEqual(restored_number.kind, "number")
        self.assertAlmostEqual(restored_number.value, 3.14159, places=10)

        # Test with bool value
        bool_val = JsonValue.wrap_bool(True)
        bool_bytes = JsonValue.serializer.to_bytes(bool_val)
        restored_bool = JsonValue.serializer.from_bytes(bool_bytes)
        self.assertEqual(restored_bool.kind, "bool")
        self.assertEqual(restored_bool.value, True)

        # Test with NULL constant
        null_val = JsonValue.NULL
        null_bytes = JsonValue.serializer.to_bytes(null_val)
        restored_null = JsonValue.serializer.from_bytes(null_bytes)
        self.assertEqual(restored_null.kind, "NULL")
        self.assertEqual(restored_null, JsonValue.NULL)

    def test_enum_binary_nested_structures(self):
        """Test binary serialization of enums with nested struct values."""
        module = self.init_test_module()
        JsonValue = module["JsonValue"]
        JsonObjectEntry = JsonValue.ObjectEntry

        # Create an object with entries
        obj = JsonValue.create_object(
            entries=[
                JsonObjectEntry(name="key1", value=JsonValue.wrap_string("value1")),
                JsonObjectEntry(name="key2", value=JsonValue.wrap_number(42.0)),
                JsonObjectEntry(name="key3", value=JsonValue.wrap_bool(False)),
            ]
        )

        # Binary roundtrip
        obj_bytes = JsonValue.serializer.to_bytes(obj)
        restored = JsonValue.serializer.from_bytes(obj_bytes)

        self.assertEqual(restored.kind, "object")
        self.assertEqual(len(restored.value.entries), 3)
        self.assertEqual(restored.value.entries[0].name, "key1")
        self.assertEqual(restored.value.entries[0].value.kind, "string")
        self.assertEqual(restored.value.entries[0].value.value, "value1")
        self.assertEqual(restored.value.entries[1].name, "key2")
        self.assertEqual(restored.value.entries[1].value.kind, "number")
        self.assertEqual(restored.value.entries[1].value.value, 42.0)
        self.assertEqual(restored.value.entries[2].name, "key3")
        self.assertEqual(restored.value.entries[2].value.kind, "bool")
        self.assertEqual(restored.value.entries[2].value.value, False)

    def test_enum_binary_array_values(self):
        """Test binary serialization of enum with array wrapper fields."""
        module = self.init_test_module()
        JsonValue = module["JsonValue"]

        # Test with empty array
        empty_array = JsonValue.wrap_array([])
        empty_bytes = JsonValue.serializer.to_bytes(empty_array)
        restored_empty = JsonValue.serializer.from_bytes(empty_bytes)
        self.assertEqual(restored_empty.kind, "array")
        self.assertEqual(len(restored_empty.value), 0)

        # Test with array of mixed types
        mixed_array = JsonValue.wrap_array(
            [
                JsonValue.NULL,
                JsonValue.wrap_bool(True),
                JsonValue.wrap_number(3.14),
                JsonValue.wrap_string("test"),
            ]
        )
        mixed_bytes = JsonValue.serializer.to_bytes(mixed_array)
        restored_mixed = JsonValue.serializer.from_bytes(mixed_bytes)
        self.assertEqual(restored_mixed.kind, "array")
        self.assertEqual(len(restored_mixed.value), 4)
        self.assertEqual(restored_mixed.value[0], JsonValue.NULL)
        self.assertEqual(restored_mixed.value[1].kind, "bool")
        self.assertEqual(restored_mixed.value[1].value, True)
        self.assertEqual(restored_mixed.value[2].kind, "number")
        self.assertAlmostEqual(restored_mixed.value[2].value, 3.14, places=10)
        self.assertEqual(restored_mixed.value[3].kind, "string")
        self.assertEqual(restored_mixed.value[3].value, "test")

    def test_enum_binary_deeply_nested_arrays(self):
        """Test binary serialization with deeply nested array values."""
        module = self.init_test_module()
        JsonValue = module["JsonValue"]

        # Create nested arrays: [[[]]]
        inner_array = JsonValue.wrap_array([])
        middle_array = JsonValue.wrap_array([inner_array])
        outer_array = JsonValue.wrap_array([middle_array])

        outer_bytes = JsonValue.serializer.to_bytes(outer_array)
        restored = JsonValue.serializer.from_bytes(outer_bytes)

        self.assertEqual(restored.kind, "array")
        self.assertEqual(len(restored.value), 1)
        self.assertEqual(restored.value[0].kind, "array")
        self.assertEqual(len(restored.value[0].value), 1)
        self.assertEqual(restored.value[0].value[0].kind, "array")
        self.assertEqual(len(restored.value[0].value[0].value), 0)

    def test_enum_binary_multiple_roundtrips(self):
        """Test that multiple binary serialization roundtrips preserve enum data."""
        module = self.init_test_module()
        Status = module["Status"]

        original = Status.wrap_error("original error message")
        current = original

        # Do multiple roundtrips
        for _ in range(5):
            binary_bytes = Status.serializer.to_bytes(current)
            current = Status.serializer.from_bytes(binary_bytes)

        # Should still be equal
        self.assertEqual(current.kind, original.kind)
        self.assertEqual(current.value, original.value)
        self.assertEqual(current, original)

    def test_enum_binary_field_number_ranges(self):
        """Test that enum field numbers work correctly in binary format."""
        module = self.init_test_module()
        PrimaryColor = module["PrimaryColor"]

        # PrimaryColor has field numbers 10, 20, 30
        test_cases = [
            (PrimaryColor.RED, 10),
            (PrimaryColor.GREEN, 20),
            (PrimaryColor.BLUE, 30),
        ]

        for color, expected_number in test_cases:
            binary_bytes = PrimaryColor.serializer.to_bytes(color)
            restored = PrimaryColor.serializer.from_bytes(binary_bytes)
            self.assertEqual(restored, color)

    def test_enum_binary_consistency_across_formats(self):
        """Test that binary format produces consistent results."""
        module = self.init_test_module()
        Status = module["Status"]

        # Create the same enum value multiple times
        status1 = Status.wrap_error("test")
        status2 = Status.wrap_error("test")

        bytes1 = Status.serializer.to_bytes(status1)
        bytes2 = Status.serializer.to_bytes(status2)

        # Should produce identical binary output
        self.assertEqual(bytes1, bytes2)

        # Both should restore to equivalent values
        restored1 = Status.serializer.from_bytes(bytes1)
        restored2 = Status.serializer.from_bytes(bytes2)
        self.assertEqual(restored1, restored2)

    def test_enum_binary_edge_case_values(self):
        """Test enum binary serialization with edge case values."""
        module = self.init_test_module()
        Status = module["Status"]
        JsonValue = module["JsonValue"]

        # Test with empty string
        empty_error = Status.wrap_error("")
        empty_bytes = Status.serializer.to_bytes(empty_error)
        restored_empty = Status.serializer.from_bytes(empty_bytes)
        self.assertEqual(restored_empty.value, "")

        # Test with very long string
        long_error = Status.wrap_error("x" * 10000)
        long_bytes = Status.serializer.to_bytes(long_error)
        restored_long = Status.serializer.from_bytes(long_bytes)
        self.assertEqual(restored_long.value, "x" * 10000)

        # Test with special unicode characters
        unicode_error = Status.wrap_error("\u0000\uffff\U0001f600")
        unicode_bytes = Status.serializer.to_bytes(unicode_error)
        restored_unicode = Status.serializer.from_bytes(unicode_bytes)
        self.assertEqual(restored_unicode.value, "\u0000\uffff\U0001f600")

        # Test with extreme float values
        inf_val = JsonValue.wrap_number(float("inf"))
        inf_bytes = JsonValue.serializer.to_bytes(inf_val)
        restored_inf = JsonValue.serializer.from_bytes(inf_bytes)
        self.assertEqual(restored_inf.value, float("inf"))

        neg_inf_val = JsonValue.wrap_number(float("-inf"))
        neg_inf_bytes = JsonValue.serializer.to_bytes(neg_inf_val)
        restored_neg_inf = JsonValue.serializer.from_bytes(neg_inf_bytes)
        self.assertEqual(restored_neg_inf.value, float("-inf"))

    def test_enum_binary_mixed_enum_and_struct(self):
        """Test binary serialization when enums contain struct fields."""
        module = self.init_test_module()
        JsonValue = module["JsonValue"]
        JsonObject = JsonValue.Object
        JsonObjectEntry = JsonValue.ObjectEntry

        # Create complex nested structure
        complex_obj = JsonValue.wrap_object(
            JsonObject(
                entries=[
                    JsonObjectEntry(
                        name="nested",
                        value=JsonValue.wrap_object(
                            JsonObject(
                                entries=[
                                    JsonObjectEntry(
                                        name="inner",
                                        value=JsonValue.wrap_string("deep value"),
                                    )
                                ]
                            )
                        ),
                    )
                ]
            )
        )

        # Binary roundtrip
        complex_bytes = JsonValue.serializer.to_bytes(complex_obj)
        restored = JsonValue.serializer.from_bytes(complex_bytes)

        self.assertEqual(restored.kind, "object")
        self.assertEqual(len(restored.value.entries), 1)
        self.assertEqual(restored.value.entries[0].name, "nested")
        nested = restored.value.entries[0].value
        self.assertEqual(nested.kind, "object")
        self.assertEqual(len(nested.value.entries), 1)
        self.assertEqual(nested.value.entries[0].name, "inner")
        self.assertEqual(nested.value.entries[0].value.kind, "string")
        self.assertEqual(nested.value.entries[0].value.value, "deep value")


class EnumNameCaseCompatibilityTestCase(unittest.TestCase):
    """Tests that enum constant names are recognised in both UPPER_CASE and
    lower_case regardless of how the code generator spelled them.

    Condition 1 - serialisation: the lower_case name (as registered by the new
    generator) is used when emitting readable JSON.

    Condition 2 - parsing: both the registered name *and* its opposite casing
    are accepted when reading readable JSON, so that payloads from old
    (UPPER_CASE) serialisers remain usable after a generator upgrade.
    """

    def _make_module(self):
        """Create a small test module with lower_case-named enum variants."""
        from skir._module_initializer import init_module

        module: dict = {}
        init_module(
            records=(
                _spec.Enum(
                    id="test.skir:Color",
                    doc="",
                    constant_variants=(
                        _spec.ConstantVariant(name="red", number=1),
                        _spec.ConstantVariant(name="green", number=2),
                        _spec.ConstantVariant(name="blue", number=3),
                    ),
                ),
                _spec.Enum(
                    id="test.skir:Status",
                    doc="",
                    constant_variants=(),
                    wrapper_variants=(
                        _spec.WrapperVariant(
                            name="pending",
                            number=1,
                            type=_spec.PrimitiveType.STRING,
                        ),
                        _spec.WrapperVariant(
                            name="error",
                            number=2,
                            type=_spec.PrimitiveType.INT32,
                        ),
                    ),
                ),
            ),
            methods=(),
            constants=(),
            globals=module,
            record_id_to_adapter={},
        )
        return module

    # ── Condition 1: serialise using the registered (lower_case) name ─────────

    def test_serialises_lowercase_constant_to_lower_case_readable_json(self):
        module = self._make_module()
        Color = module["Color"]
        serializer = Color.serializer
        self.assertEqual(serializer.to_json(Color.red, readable=True), "red")
        self.assertEqual(serializer.to_json(Color.green, readable=True), "green")
        self.assertEqual(serializer.to_json(Color.blue, readable=True), "blue")

    # ── Condition 2: parse both UPPER_CASE and lower_case names ───────────────

    def test_parses_upper_case_constant_name(self):
        module = self._make_module()
        Color = module["Color"]
        serializer = Color.serializer
        # Simulate JSON from an old serializer that used UPPER_CASE names.
        result = serializer.from_json("RED")
        self.assertEqual(result, Color.red)

    def test_parses_lower_case_constant_name(self):
        module = self._make_module()
        Color = module["Color"]
        serializer = Color.serializer
        result = serializer.from_json("green")
        self.assertEqual(result, Color.green)

    def test_upper_case_and_lower_case_constant_names_yield_same_result(self):
        module = self._make_module()
        Color = module["Color"]
        serializer = Color.serializer
        from_upper = serializer.from_json("BLUE")
        from_lower = serializer.from_json("blue")
        self.assertEqual(from_upper, from_lower)
        self.assertEqual(from_upper, Color.blue)
