# typed: strict
# frozen_string_literal: true

require "minitest/autorun"
require "sorbet-runtime"
require "skir"
require_relative "../skirout/constants_skir"
require_relative "../skirout/enums_skir"
require_relative "../skirout/full_name_skir"
require_relative "../skirout/methods_skir"
require_relative "../skirout/quest_collection_skir"
require_relative "../skirout/structs_skir"
require_relative "../skirout/user_skir"
require_relative "../skirout/external/gepheum/skir_fantasy_game_example/fantasy_game_skir"

class SkiroutTest < Minitest::Test
  extend T::Sig

  FullName = Skirout::FullNameSkir::FullName
  Weekday = Skirout::EnumsSkir::Weekday
  JsonValue = Skirout::EnumsSkir::JsonValue
  EmptyEnum = Skirout::EnumsSkir::EmptyEnum
  Color = Skirout::StructsSkir::Color
  Foo = Skirout::StructsSkir::Foo
  Item = Skirout::StructsSkir::Item
  Items = Skirout::StructsSkir::Items
  NameCollision = Skirout::StructsSkir::NameCollision
  Triangle = Skirout::StructsSkir::Triangle
  True_ = Skirout::StructsSkir::True_
  EnumWithStructField = Skirout::EnumsSkir::EnumWithStructField

  sig { void }
  def test_full_name
    full_name = FullName.new(first_name: "Tyler", last_name: "Fibonacci")
    assert_equal "Tyler", full_name.first_name
    assert_equal "Fibonacci", full_name.last_name
    assert_equal '["Tyler","Fibonacci"]', FullName.serializer.to_json_code(full_name)
  end

  sig { void }
  def test_partial_full_name
    full_name = FullName.partial(first_name: "Tyler")
    assert_equal "Tyler", full_name.first_name
    assert_equal "", full_name.last_name
    assert_equal '["Tyler"]', FullName.serializer.to_json_code(full_name)
  end

  sig { void }
  def test_full_name_replace
    full_name = FullName.new(first_name: "Tyler", last_name: "Smith")
    full_name = full_name.replace(last_name: "Fibonacci")
    assert_equal "Tyler", full_name.first_name
    assert_equal "Fibonacci", full_name.last_name
  end

  sig { void }
  def test_full_name_mutable
    full_name = FullName::Mutable.new(first_name: "Tyler")
    full_name.last_name = "Fibonacci"
    assert_equal '["Tyler","Fibonacci"]', FullName.serializer.to_json_code(full_name.to_frozen)
  end

  sig { void }
  def test_nested_struct
    bar = Foo::Bar.partial(bar: "Bar")
    assert_nil bar.foos
    assert_equal "Bar", bar.bar
  end

  sig { void }
  def test_deserialize_unknown_on_empty_enum
    assert_equal EmptyEnum::UNKNOWN, EmptyEnum.serializer.from_json_code('"UNKNOWN"')
  end

  sig { void }
  def test_triangle_default
    assert_equal Color::DEFAULT, Triangle::DEFAULT.color
    assert_equal [], Triangle::DEFAULT.points
  end

  sig { void }
  def test_struct_with_name_conflicts
    t = True_.partial(self_: [])
    assert_equal [], t.self_
  end

  sig { void }
  def test_keyed_arrays
    items = Items.partial(
      array_with_enum_key: [
        Item.partial(weekday: Weekday::MONDAY, bool: true),
        Item.partial(weekday: Weekday::TUESDAY, bool: true)
      ]
    )
    assert_equal(
      Item.partial(weekday: Weekday::TUESDAY, bool: true),
      items.array_with_enum_key.find("TUESDAY")
    )
    assert_nil items.array_with_enum_key.find("WEDNESDAY")
  end

  sig { void }
  def test_constant
    assert_equal(
      JsonValue.wrap_array(
        [
          JsonValue.wrap_boolean(true),
          JsonValue.wrap_number(2.5),
          JsonValue.wrap_string(["", "        foo", "        bar"].join("\n")),
          JsonValue.wrap_object(
            [
              JsonValue::Pair.new(name: "foo", value: JsonValue::NULL)
            ]
          )
        ]
      ),
      Skirout::ConstantsSkir::ONE_CONSTANT
    )
  end

  sig { void }
  def test_name_collision
    s = NameCollision.partial(serializer_: true)
    assert_equal true, s.serializer_
  end

  sig { void }
  def test_method
    assert_equal "MyProcedure", Skirout::MethodsSkir::MyProcedure.name
    assert_equal "My procedure", Skirout::MethodsSkir::MyProcedure.doc
  end

  sig { params(val: EnumWithStructField).returns(String) }
  def describe_enum_with_struct_field(val)
    u = val.union
    case u
    when EnumWithStructField::V_UNKNOWN
      "unknown"
    when EnumWithStructField::V_s
      # Sorbet statically narrows u.value to EnumWithStructField::S
      s_val = T.let(u.value, EnumWithStructField::S)
      "s:#{s_val.x},#{s_val.y}"
    else
      T.absurd(u)
    end
  end

  sig { void }
  def test_exhaustive_enum_pattern_matching
    assert_equal "unknown", describe_enum_with_struct_field(EnumWithStructField::UNKNOWN)
    s_inst = EnumWithStructField.create_s(x: 1.5, y: 2.5)
    assert_equal "s:1.5,2.5", describe_enum_with_struct_field(s_inst)
  end

  sig { void }
  def test_external
    refute_nil Skirout::QuestCollectionSkir::QuestCollection::DEFAULT
    refute_nil Skirout::External::Gepheum::SkirFantasyGameExample::FantasyGameSkir::Quest::DEFAULT
  end
end
