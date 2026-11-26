# typed: false
# frozen_string_literal: true

require "minitest/autorun"
require "skir"

class ModuleInitializerTest < Minitest::Test
  def init_test_module
    mod = {}
    spec = Skir::Spec
    Skir::Internal.init_module(
      records: [
        spec::Struct.new(
          id: "my/module.skir:Point",
          doc: "A 2D point.",
          fields: [
            spec::Field.new(
              name: "x",
              number: 0,
              type: spec::PrimitiveType::FLOAT32,
              doc: "X coordinate."
            ),
            spec::Field.new(
              name: "y",
              number: 2,
              type: spec::PrimitiveType::FLOAT32
            )
          ],
          removed_numbers: [1]
        ),
        spec::Struct.new(
          id: "my/module.skir:Segment",
          fields: [
            spec::Field.new(
              name: "a",
              number: 0,
              type: "my/module.skir:Point",
              has_mutable_getter: true
            ),
            spec::Field.new(
              name: "bb",
              attribute: "b",
              number: 1,
              type: "my/module.skir:Point",
              has_mutable_getter: true
            ),
            spec::Field.new(
              name: "c",
              number: 2,
              type: spec::OptionalType.new("my/module.skir:Point"),
              has_mutable_getter: true
            )
          ]
        ),
        spec::Struct.new(
          id: "my/module.skir:Shape",
          fields: [
            spec::Field.new(
              name: "points",
              number: 0,
              type: spec::ArrayType.new("my/module.skir:Point"),
              has_mutable_getter: true
            )
          ]
        ),
        spec::Struct.new(
          id: "my/module.skir:Primitives",
          fields: [
            spec::Field.new(name: "bool", number: 0, type: spec::PrimitiveType::BOOL),
            spec::Field.new(name: "bytes", number: 1, type: spec::PrimitiveType::BYTES),
            spec::Field.new(name: "f32", number: 2, type: spec::PrimitiveType::FLOAT32),
            spec::Field.new(name: "f64", number: 3, type: spec::PrimitiveType::FLOAT64),
            spec::Field.new(name: "i32", number: 4, type: spec::PrimitiveType::INT32),
            spec::Field.new(name: "i64", number: 5, type: spec::PrimitiveType::INT64),
            spec::Field.new(name: "u64", number: 6, type: spec::PrimitiveType::HASH64),
            spec::Field.new(name: "s", number: 7, type: spec::PrimitiveType::STRING),
            spec::Field.new(name: "t", number: 8, type: spec::PrimitiveType::TIMESTAMP)
          ]
        ),
        spec::Enum.new(
          id: "my/module.skir:PrimaryColor",
          constant_variants: [
            spec::ConstantVariant.new(name: "RED", number: 10),
            spec::ConstantVariant.new(name: "GREEN", number: 20),
            spec::ConstantVariant.new(name: "BLUE", number: 30)
          ]
        ),
        spec::Enum.new(
          id: "my/module.skir:Status",
          constant_variants: [
            spec::ConstantVariant.new(name: "OK", number: 1)
          ],
          wrapper_variants: [
            spec::WrapperVariant.new(name: "error", number: 2, type: spec::PrimitiveType::STRING)
          ],
          removed_numbers: [1, 4]
        ),
        spec::Enum.new(
          id: "my/module.skir:JsonValue",
          doc: "A JSON value.",
          constant_variants: [
            spec::ConstantVariant.new(name: "NULL", number: 1)
          ],
          wrapper_variants: [
            spec::WrapperVariant.new(name: "bool", number: 2, type: spec::PrimitiveType::BOOL, doc: "A boolean value."),
            spec::WrapperVariant.new(name: "number", number: 3, type: spec::PrimitiveType::FLOAT64),
            spec::WrapperVariant.new(name: "string", number: 4, type: spec::PrimitiveType::STRING),
            spec::WrapperVariant.new(name: "array", number: 5, type: spec::ArrayType.new("my/module.skir:JsonValue")),
            spec::WrapperVariant.new(name: "object", number: 6, type: "my/module.skir:JsonValue.Object")
          ],
          removed_numbers: [100, 101]
        ),
        spec::Struct.new(
          id: "my/module.skir:JsonValue.Object",
          fields: [
            spec::Field.new(
              name: "entries",
              number: 0,
              type: spec::ArrayType.new("my/module.skir:JsonValue.ObjectEntry", ["name"])
            )
          ]
        ),
        spec::Struct.new(
          id: "my/module.skir:JsonValue.ObjectEntry",
          fields: [
            spec::Field.new(name: "name", number: 0, type: spec::PrimitiveType::STRING),
            spec::Field.new(name: "value", number: 1, type: "my/module.skir:JsonValue")
          ]
        ),
        spec::Struct.new(id: "my/module.skir:Parent", fields: []),
        spec::Enum.new(id: "my/module.skir:Parent.NestedEnum"),
        spec::Struct.new(
          id: "my/module.skir:Stuff",
          fields: [
            spec::Field.new(
              name: "enum_wrappers",
              number: 0,
              type: spec::ArrayType.new("my/module.skir:EnumWrapper", %w[status kind])
            )
          ]
        ),
        spec::Struct.new(
          id: "my/module.skir:EnumWrapper",
          fields: [
            spec::Field.new(name: "status", number: 0, type: "my/module.skir:Status")
          ]
        ),
        spec::Struct.new(
          id: "my/module.skir:Stuff.Overrides",
          class_name: "NameOverrides",
          class_qualname: "Stuff::NameOverrides",
          fields: [
            spec::Field.new(name: "x", attribute: "y", number: 0, type: spec::PrimitiveType::INT32)
          ]
        ),
        spec::Struct.new(
          id: "my/module.skir:Rec",
          fields: [
            spec::Field.new(name: "r", number: 0, type: "my/module.skir:Rec"),
            spec::Field.new(name: "x", number: 1, type: spec::PrimitiveType::INT32)
          ]
        ),
        spec::Struct.new(
          id: "my/module.skir:Foobar",
          fields: [
            spec::Field.new(name: "a", number: 1, type: spec::PrimitiveType::INT32),
            spec::Field.new(name: "b", number: 3, type: spec::PrimitiveType::INT32),
            spec::Field.new(name: "point", number: 4, type: "my/module.skir:Point")
          ],
          removed_numbers: [0, 2]
        )
      ],
      methods: [
        spec::Method.new(
          name: "FirstMethod",
          number: -300,
          request_type: "my/module.skir:Point",
          response_type: "my/module.skir:Shape",
          doc: "First method"
        ),
        spec::Method.new(
          name: "SecondMethod",
          number: -301,
          request_type: "my/module.skir:Point",
          response_type: "my/module.skir:Shape",
          var_name: "MethodVar"
        )
      ],
      constants: [
        spec::Constant.new(
          name: "C",
          type: "my/module.skir:Point",
          json_code: "[1.5, 0, 2.5]"
        )
      ],
      target: mod,
      record_id_to_adapter: {}
    )
    mod
  end

  def test_struct_basics
    mod = init_test_module
    point_cls = mod["Point"]
    point = point_cls.new(x: 1.5, y: 2.5)
    assert_equal 1.5, point.x
    assert_equal 2.5, point.y

    p2 = point_cls.partial(x: 1.5)
    assert_equal 1.5, p2.x
    assert_equal 0.0, p2.y

    p3 = point.replace(y: 3.5)
    assert_equal 1.5, p3.x
    assert_equal 3.5, p3.y

    mut = point.to_mutable
    mut.x = 4.0
    p4 = mut.to_frozen
    assert_equal 4.0, p4.x
    assert_equal 2.5, p4.y
    assert_same p4, p4.to_frozen

    assert_equal point_cls.new(x: 1.5, y: 2.5), point
    assert_equal point_cls.new(x: 1.5, y: 2.5).hash, point.hash
    refute_equal point_cls.new(x: 1.5, y: 3.0), point
    assert_equal point_cls.new(x: 0.0, y: 0.0), point_cls::DEFAULT
  end

  def test_point_json_and_unrecognized
    mod = init_test_module
    point_cls = mod["Point"]
    ser = point_cls.serializer
    point = point_cls.new(x: 1.5, y: 2.5)
    assert_equal [1.5, 0, 2.5], ser.to_json(point)
    assert_equal "[1.5,0,2.5]", ser.to_json_code(point)
    assert_equal({ "x" => 1.5, "y" => 2.5 }, ser.to_json(point, readable: true))
    assert_equal "{\n  \"x\": 1.5,\n  \"y\": 2.5\n}", ser.to_json_code(point, readable: true)

    assert_equal point, ser.from_json([1.5, 0, 2.5])
    assert_equal point, ser.from_json({ "x" => 1.5, "y" => 2.5 })
    assert_equal point_cls::DEFAULT, ser.from_json(0)

    # Keep unrecognized
    p_keep = ser.from_json([1.5, 1, 2.5, true], keep_unrecognized_values: true)
    assert_equal point, p_keep
    assert_equal [1.5, 0, 2.5, true], ser.to_json(p_keep)
    assert_equal [1.5, 0, 2.5, true], ser.to_json(p_keep.to_mutable.to_frozen)

    # Drop unrecognized
    p_drop = ser.from_json([1.5, 1, 2.5, true])
    assert_equal point, p_drop
    assert_equal [1.5, 0, 2.5], ser.to_json(p_drop)
  end

  def test_removed_fields_and_recursive_struct
    mod = init_test_module
    foobar_cls = mod["Foobar"]
    point_cls = mod["Point"]
    ser = foobar_cls.serializer

    fb = foobar_cls.partial
    assert_equal "[]", ser.to_json_code(fb)
    assert_equal fb, ser.from_json_code("[]")

    fb_a = foobar_cls.partial(a: 3)
    assert_equal "[0,3]", ser.to_json_code(fb_a)
    assert_equal fb_a, ser.from_json_code("[0,3.1]")

    fb_b = foobar_cls.new(a: 0, b: 3, point: point_cls::DEFAULT)
    assert_equal "[0,0,0,3]", ser.to_json_code(fb_b)

    rec_cls = mod["Rec"]
    r = rec_cls.partial(r: rec_cls.new(r: rec_cls::DEFAULT, x: 1))
    assert_equal "[[[],1]]", rec_cls.serializer.to_json_code(r)
    assert_equal r, rec_cls.serializer.from_json_code("[[[],1]]")
  end

  def test_enums
    mod = init_test_module
    primary_color_cls = mod["PrimaryColor"]
    unknown = primary_color_cls::UNKNOWN
    assert_equal "UNKNOWN", unknown.kind
    assert_nil unknown.value
    assert_same unknown, unknown.union
    assert_predicate unknown, :unknown?
    refute_predicate unknown, :present?
    assert_equal 0, primary_color_cls.serializer.to_json(unknown)
    assert_equal "unknown", primary_color_cls.serializer.to_json(unknown, readable: true)

    red = primary_color_cls::RED
    assert_equal "RED", red.kind
    assert_predicate red, :present?
    assert_equal 10, primary_color_cls.serializer.to_json(red)
    assert_equal "red", primary_color_cls.serializer.to_json(red, readable: true)

    status_cls = mod["Status"]
    err = status_cls.wrap_error("An error occurred")
    assert_equal "error", err.kind
    assert_equal "An error occurred", err.value
    assert_equal [2, "An error occurred"], status_cls.serializer.to_json(err)
    assert_equal({ "kind" => "error", "value" => "An error occurred" }, status_cls.serializer.to_json(err, readable: true))

    json_value_cls = mod["JsonValue"]
    entry_cls = json_value_cls::ObjectEntry
    obj = json_value_cls.create_object(
      entries: [entry_cls.new(name: "a", value: json_value_cls.wrap_string("b"))]
    )
    assert_equal "object", obj.kind
    assert_equal "b", obj.value.entries.find("a").value.value

    # Unrecognized enum variants
    ser = json_value_cls.serializer
    v_removed = ser.from_json(100, keep_unrecognized_values: true)
    assert_equal json_value_cls::UNKNOWN, v_removed
    assert_equal 0, ser.to_json(v_removed)

    v_unrec = ser.from_json(102, keep_unrecognized_values: true)
    assert_equal json_value_cls::UNKNOWN, v_unrec
    assert_equal 102, ser.to_json(v_unrec)

    v_unrec_arr = ser.from_json([102, true], keep_unrecognized_values: true)
    assert_equal json_value_cls::UNKNOWN, v_unrec_arr
    assert_equal [102, true], ser.to_json(v_unrec_arr)
  end

  def test_keyed_items_and_mutable_getters
    mod = init_test_module
    stuff_cls = mod["Stuff"]
    ew_cls = mod["EnumWrapper"]
    status_cls = mod["Status"]

    stuff = stuff_cls.new(
      enum_wrappers: [
        ew_cls.new(status: status_cls::OK),
        ew_cls.new(status: status_cls.wrap_error("an error")),
        ew_cls.new(status: status_cls::OK)
      ]
    )
    wrappers = stuff.enum_wrappers
    assert_instance_of Skir::KeyedItems, wrappers
    assert_same wrappers[2], wrappers.find("OK")
    assert_same wrappers[1], wrappers.find("error")
    assert_same ew_cls::DEFAULT, wrappers.find_or_default("UNKNOWN")

    # Passing a KeyedItems with the SAME key_fn reuses the instance
    stuff_same_key = stuff_cls.new(enum_wrappers: wrappers)
    assert_same wrappers, stuff_same_key.enum_wrappers

    # Passing a KeyedItems with a DIFFERENT key_fn creates a new KeyedItems with the target's key_fn
    different_keyed = Skir::KeyedItems.create(wrappers.to_a, ->(item) { item.status })
    stuff_rekeyed = stuff_cls.new(enum_wrappers: different_keyed)
    refute_same different_keyed, stuff_rekeyed.enum_wrappers
    assert_same wrappers[2], stuff_rekeyed.enum_wrappers.find("OK")

    segment_cls = mod["Segment"]
    point_cls = mod["Point"]
    seg = segment_cls.new(a: point_cls.new(x: 1.0, y: 2.0), b: point_cls.new(x: 3.0, y: 4.0), c: nil).to_mutable
    a = seg.mutable_a
    assert_instance_of point_cls::Mutable, a
    assert_same a, seg.mutable_a

    shape_cls = mod["Shape"]
    shape = shape_cls.new(points: [point_cls.new(x: 1.0, y: 2.0)]).to_mutable
    pts = shape.mutable_points
    assert_instance_of Array, pts
    refute_predicate pts, :frozen?
    assert_same pts, shape.mutable_points
  end

  def test_type_descriptors_and_binary
    mod = init_test_module
    json_value_cls = mod["JsonValue"]
    td = json_value_cls.serializer.type_descriptor
    assert_equal td, Skir::Reflection::TypeDescriptor.from_json(td.as_json)
    assert_equal td, Skir::Reflection::TypeDescriptor.from_json_code(td.as_json_code)

    point_cls = mod["Point"]
    empty_bytes = point_cls.serializer.to_bytes(point_cls.partial)
    assert_equal "736b6972f6", empty_bytes.unpack1("H*")
    assert_same point_cls::DEFAULT, point_cls.serializer.from_bytes(empty_bytes)

    p_unrec = point_cls.serializer.from_json([1.5, 0, 2.5, 100], keep_unrecognized_values: true)
    b_unrec = point_cls.serializer.to_bytes(p_unrec)
    restored_drop = point_cls.serializer.from_bytes(b_unrec)
    assert_equal [1.5, 0, 2.5], point_cls.serializer.to_json(restored_drop)
  end
end
