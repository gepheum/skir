enum Evaluated {
  Bool(Bool)
  Int32(Int)
  Int64(Int64)
  Hash64(UInt64)
  Float32(Float)
  Float64(Double)
  Timestamp(@client.Timestamp)
  String(String)
  Bytes(Bytes)
  BoolOptional(Bool?)
  Ints(@client.ImmutVector[Int])
  Point(@goldens.Point)
  Color(@goldens.Color)
  MyEnum(@goldens.MyEnum)
  EnumA(@goldens.EnumA)
  EnumB(@goldens.EnumB)
  KeyedArrays(@goldens.KeyedArrays)
  RecStruct(@goldens.RecStruct)
  RecEnum(@goldens.RecEnum)
} derive(@builtin.Eq, @debug.Debug)

fn parse_json_or_none(code : String) -> Json? {
  try {
    Some(@json.parse(code))
  } catch {
    _ => None
  }
}

fn bytes_to_ints(bytes : Bytes) -> Array[Int] {
  let out : Array[Int] = []
  for b in bytes.to_array() {
    out.push(b.to_int())
  }
  out
}

fn bytes_has_prefix(payload : Array[Int], prefix : Bytes) -> Bool {
  let expected = bytes_to_ints(prefix)
  if payload.length() < expected.length() {
    return false
  }
  for i in 0..<expected.length() {
    if payload[i] != expected[i] {
      return false
    }
  }
  true
}

fn string_matches_candidates(actual : String, expected : @client.ImmutVector[String]) -> Bool {
  for candidate in expected.iter() {
    if actual == candidate {
      return true
    }
  }
  false
}

fn json_matches_candidates(actual : String, expected : @client.ImmutVector[String]) -> Bool {
  if string_matches_candidates(actual, expected) {
    return true
  }
  let actual_json = parse_json_or_none(actual)
  match actual_json {
    Some(root) => {
      for candidate in expected.iter() {
        match parse_json_or_none(candidate) {
          Some(candidate_json) =>
            if root == candidate_json {
              return true
            }
          None => ()
        }
      }
      false
    }
    None => false
  }
}

fn bytes_matches_candidates(actual : Array[Int], expected : @client.ImmutVector[Bytes]) -> Bool {
  for candidate in expected.iter() {
    if actual == bytes_to_ints(candidate) {
      return true
    }
  }
  false
}

fn policy(keep_unrecognized : Bool) -> @client.UnrecognizedValues {
  if keep_unrecognized {
    @client.UnrecognizedValues::Keep
  } else {
    @client.UnrecognizedValues::Drop
  }
}

fn evaluate_string_expression(expr : @goldens.StringExpression) -> Result[String, String] {
  match expr {
    @goldens.StringExpression::Unknown(_) => Err("unknown string expression")
    @goldens.StringExpression::Literal(value) => Ok(value)
    @goldens.StringExpression::ToDenseJson(value) =>
      match evaluate_typed_value(value) {
        Ok(v) => Ok(evaluated_to_dense_json(v))
        Err(e) => Err(e)
      }
    @goldens.StringExpression::ToReadableJson(value) =>
      match evaluate_typed_value(value) {
        Ok(v) => Ok(evaluated_to_readable_json(v))
        Err(e) => Err(e)
      }
  }
}

fn evaluate_bytes_expression(expr : @goldens.BytesExpression) -> Result[Array[Int], String] {
  match expr {
    @goldens.BytesExpression::Unknown(_) => Err("unknown bytes expression")
    @goldens.BytesExpression::Literal(value) => Ok(bytes_to_ints(value))
    @goldens.BytesExpression::ToBytes(value) =>
      match evaluate_typed_value(value) {
        Ok(v) => Ok(evaluated_to_bytes(v))
        Err(e) => Err(e)
      }
  }
}

fn evaluated_to_dense_json(value : Evaluated) -> String {
  match value {
    Evaluated::Bool(v) => @client.bool_serializer().to_dense_json_code(v)
    Evaluated::Int32(v) => @client.int32_serializer().to_dense_json_code(v)
    Evaluated::Int64(v) => @client.int64_serializer().to_dense_json_code(v)
    Evaluated::Hash64(v) => @client.hash64_serializer().to_dense_json_code(v)
    Evaluated::Float32(v) => @client.float32_serializer().to_dense_json_code(v)
    Evaluated::Float64(v) => @client.float64_serializer().to_dense_json_code(v)
    Evaluated::Timestamp(v) => @client.timestamp_serializer().to_dense_json_code(v)
    Evaluated::String(v) => @client.string_serializer().to_dense_json_code(v)
    Evaluated::Bytes(v) => @client.bytes_serializer().to_dense_json_code(v)
    Evaluated::BoolOptional(v) => @client.optional_serializer(@client.bool_serializer()).to_dense_json_code(v)
    Evaluated::Ints(v) => @client.vector_serializer(@client.int32_serializer()).to_dense_json_code(v)
    Evaluated::Point(v) => @goldens.Point::serializer().to_dense_json_code(v)
    Evaluated::Color(v) => @goldens.Color::serializer().to_dense_json_code(v)
    Evaluated::MyEnum(v) => @goldens.MyEnum::serializer().to_dense_json_code(v)
    Evaluated::EnumA(v) => @goldens.EnumA::serializer().to_dense_json_code(v)
    Evaluated::EnumB(v) => @goldens.EnumB::serializer().to_dense_json_code(v)
    Evaluated::KeyedArrays(v) => @goldens.KeyedArrays::serializer().to_dense_json_code(v)
    Evaluated::RecStruct(v) => @goldens.RecStruct::serializer().to_dense_json_code(v)
    Evaluated::RecEnum(v) => @goldens.RecEnum::serializer().to_dense_json_code(v)
  }
}

fn evaluated_to_readable_json(value : Evaluated) -> String {
  match value {
    Evaluated::Bool(v) => @client.bool_serializer().to_readable_json(v).stringify()
    Evaluated::Int32(v) => @client.int32_serializer().to_readable_json(v).stringify()
    Evaluated::Int64(v) => @client.int64_serializer().to_readable_json(v).stringify()
    Evaluated::Hash64(v) => @client.hash64_serializer().to_readable_json(v).stringify()
    Evaluated::Float32(v) => @client.float32_serializer().to_readable_json(v).stringify()
    Evaluated::Float64(v) => @client.float64_serializer().to_readable_json(v).stringify()
    Evaluated::Timestamp(v) => @client.timestamp_serializer().to_readable_json(v).stringify()
    Evaluated::String(v) => @client.string_serializer().to_readable_json(v).stringify()
    Evaluated::Bytes(v) => @client.bytes_serializer().to_readable_json(v).stringify()
    Evaluated::BoolOptional(v) => @client.optional_serializer(@client.bool_serializer()).to_readable_json(v).stringify()
    Evaluated::Ints(v) => @client.vector_serializer(@client.int32_serializer()).to_readable_json(v).stringify()
    Evaluated::Point(v) => @goldens.Point::serializer().to_readable_json(v).stringify()
    Evaluated::Color(v) => @goldens.Color::serializer().to_readable_json(v).stringify()
    Evaluated::MyEnum(v) => @goldens.MyEnum::serializer().to_readable_json(v).stringify()
    Evaluated::EnumA(v) => @goldens.EnumA::serializer().to_readable_json(v).stringify()
    Evaluated::EnumB(v) => @goldens.EnumB::serializer().to_readable_json(v).stringify()
    Evaluated::KeyedArrays(v) => @goldens.KeyedArrays::serializer().to_readable_json(v).stringify()
    Evaluated::RecStruct(v) => @goldens.RecStruct::serializer().to_readable_json(v).stringify()
    Evaluated::RecEnum(v) => @goldens.RecEnum::serializer().to_readable_json(v).stringify()
  }
}

fn evaluated_to_bytes(value : Evaluated) -> Array[Int] {
  match value {
    Evaluated::Bool(v) => @client.bool_serializer().to_bytes(v)
    Evaluated::Int32(v) => @client.int32_serializer().to_bytes(v)
    Evaluated::Int64(v) => @client.int64_serializer().to_bytes(v)
    Evaluated::Hash64(v) => @client.hash64_serializer().to_bytes(v)
    Evaluated::Float32(v) => @client.float32_serializer().to_bytes(v)
    Evaluated::Float64(v) => @client.float64_serializer().to_bytes(v)
    Evaluated::Timestamp(v) => @client.timestamp_serializer().to_bytes(v)
    Evaluated::String(v) => @client.string_serializer().to_bytes(v)
    Evaluated::Bytes(v) => @client.bytes_serializer().to_bytes(v)
    Evaluated::BoolOptional(v) => @client.optional_serializer(@client.bool_serializer()).to_bytes(v)
    Evaluated::Ints(v) => @client.vector_serializer(@client.int32_serializer()).to_bytes(v)
    Evaluated::Point(v) => @goldens.Point::serializer().to_bytes(v)
    Evaluated::Color(v) => @goldens.Color::serializer().to_bytes(v)
    Evaluated::MyEnum(v) => @goldens.MyEnum::serializer().to_bytes(v)
    Evaluated::EnumA(v) => @goldens.EnumA::serializer().to_bytes(v)
    Evaluated::EnumB(v) => @goldens.EnumB::serializer().to_bytes(v)
    Evaluated::KeyedArrays(v) => @goldens.KeyedArrays::serializer().to_bytes(v)
    Evaluated::RecStruct(v) => @goldens.RecStruct::serializer().to_bytes(v)
    Evaluated::RecEnum(v) => @goldens.RecEnum::serializer().to_bytes(v)
  }
}

fn evaluated_to_type_descriptor_json(value : Evaluated) -> String {
  match value {
    Evaluated::Bool(_) => @client.bool_serializer().type_descriptor().as_json().stringify()
    Evaluated::Int32(_) => @client.int32_serializer().type_descriptor().as_json().stringify()
    Evaluated::Int64(_) => @client.int64_serializer().type_descriptor().as_json().stringify()
    Evaluated::Hash64(_) => @client.hash64_serializer().type_descriptor().as_json().stringify()
    Evaluated::Float32(_) => @client.float32_serializer().type_descriptor().as_json().stringify()
    Evaluated::Float64(_) => @client.float64_serializer().type_descriptor().as_json().stringify()
    Evaluated::Timestamp(_) => @client.timestamp_serializer().type_descriptor().as_json().stringify()
    Evaluated::String(_) => @client.string_serializer().type_descriptor().as_json().stringify()
    Evaluated::Bytes(_) => @client.bytes_serializer().type_descriptor().as_json().stringify()
    Evaluated::BoolOptional(_) => @client.optional_serializer(@client.bool_serializer()).type_descriptor().as_json().stringify()
    Evaluated::Ints(_) => @client.vector_serializer(@client.int32_serializer()).type_descriptor().as_json().stringify()
    Evaluated::Point(_) => @goldens.Point::serializer().type_descriptor().as_json().stringify()
    Evaluated::Color(_) => @goldens.Color::serializer().type_descriptor().as_json().stringify()
    Evaluated::MyEnum(_) => @goldens.MyEnum::serializer().type_descriptor().as_json().stringify()
    Evaluated::EnumA(_) => @goldens.EnumA::serializer().type_descriptor().as_json().stringify()
    Evaluated::EnumB(_) => @goldens.EnumB::serializer().type_descriptor().as_json().stringify()
    Evaluated::KeyedArrays(_) => @goldens.KeyedArrays::serializer().type_descriptor().as_json().stringify()
    Evaluated::RecStruct(_) => @goldens.RecStruct::serializer().type_descriptor().as_json().stringify()
    Evaluated::RecEnum(_) => @goldens.RecEnum::serializer().type_descriptor().as_json().stringify()
  }
}

fn evaluated_from_json(value : Evaluated, json : String, keep_unrecognized : Bool) -> Result[Evaluated, String] {
  let p = policy(keep_unrecognized)
  match value {
    Evaluated::Bool(_) => @client.bool_serializer().from_json_code(json, unrecognized_values=p).map(fn(v) { Evaluated::Bool(v) })
    Evaluated::Int32(_) => @client.int32_serializer().from_json_code(json, unrecognized_values=p).map(fn(v) { Evaluated::Int32(v) })
    Evaluated::Int64(_) => @client.int64_serializer().from_json_code(json, unrecognized_values=p).map(fn(v) { Evaluated::Int64(v) })
    Evaluated::Hash64(_) => @client.hash64_serializer().from_json_code(json, unrecognized_values=p).map(fn(v) { Evaluated::Hash64(v) })
    Evaluated::Float32(_) => @client.float32_serializer().from_json_code(json, unrecognized_values=p).map(fn(v) { Evaluated::Float32(v) })
    Evaluated::Float64(_) => @client.float64_serializer().from_json_code(json, unrecognized_values=p).map(fn(v) { Evaluated::Float64(v) })
    Evaluated::Timestamp(_) => @client.timestamp_serializer().from_json_code(json, unrecognized_values=p).map(fn(v) { Evaluated::Timestamp(v) })
    Evaluated::String(_) => @client.string_serializer().from_json_code(json, unrecognized_values=p).map(fn(v) { Evaluated::String(v) })
    Evaluated::Bytes(_) => @client.bytes_serializer().from_json_code(json, unrecognized_values=p).map(fn(v) { Evaluated::Bytes(v) })
    Evaluated::BoolOptional(_) => @client.optional_serializer(@client.bool_serializer()).from_json_code(json, unrecognized_values=p).map(fn(v) { Evaluated::BoolOptional(v) })
    Evaluated::Ints(_) => @client.vector_serializer(@client.int32_serializer()).from_json_code(json, unrecognized_values=p).map(fn(v) { Evaluated::Ints(v) })
    Evaluated::Point(_) => @goldens.Point::serializer().from_json_code(json, unrecognized_values=p).map(fn(v) { Evaluated::Point(v) })
    Evaluated::Color(_) => @goldens.Color::serializer().from_json_code(json, unrecognized_values=p).map(fn(v) { Evaluated::Color(v) })
    Evaluated::MyEnum(_) => @goldens.MyEnum::serializer().from_json_code(json, unrecognized_values=p).map(fn(v) { Evaluated::MyEnum(v) })
    Evaluated::EnumA(_) => @goldens.EnumA::serializer().from_json_code(json, unrecognized_values=p).map(fn(v) { Evaluated::EnumA(v) })
    Evaluated::EnumB(_) => @goldens.EnumB::serializer().from_json_code(json, unrecognized_values=p).map(fn(v) { Evaluated::EnumB(v) })
    Evaluated::KeyedArrays(_) => @goldens.KeyedArrays::serializer().from_json_code(json, unrecognized_values=p).map(fn(v) { Evaluated::KeyedArrays(v) })
    Evaluated::RecStruct(_) => @goldens.RecStruct::serializer().from_json_code(json, unrecognized_values=p).map(fn(v) { Evaluated::RecStruct(v) })
    Evaluated::RecEnum(_) => @goldens.RecEnum::serializer().from_json_code(json, unrecognized_values=p).map(fn(v) { Evaluated::RecEnum(v) })
  }
}

fn evaluated_from_bytes(value : Evaluated, bytes : Array[Int], keep_unrecognized : Bool) -> Result[Evaluated, String] {
  let p = policy(keep_unrecognized)
  match value {
    Evaluated::Bool(_) => @client.bool_serializer().from_bytes(bytes, unrecognized_values=p).map(fn(v) { Evaluated::Bool(v) })
    Evaluated::Int32(_) => @client.int32_serializer().from_bytes(bytes, unrecognized_values=p).map(fn(v) { Evaluated::Int32(v) })
    Evaluated::Int64(_) => @client.int64_serializer().from_bytes(bytes, unrecognized_values=p).map(fn(v) { Evaluated::Int64(v) })
    Evaluated::Hash64(_) => @client.hash64_serializer().from_bytes(bytes, unrecognized_values=p).map(fn(v) { Evaluated::Hash64(v) })
    Evaluated::Float32(_) => @client.float32_serializer().from_bytes(bytes, unrecognized_values=p).map(fn(v) { Evaluated::Float32(v) })
    Evaluated::Float64(_) => @client.float64_serializer().from_bytes(bytes, unrecognized_values=p).map(fn(v) { Evaluated::Float64(v) })
    Evaluated::Timestamp(_) => @client.timestamp_serializer().from_bytes(bytes, unrecognized_values=p).map(fn(v) { Evaluated::Timestamp(v) })
    Evaluated::String(_) => @client.string_serializer().from_bytes(bytes, unrecognized_values=p).map(fn(v) { Evaluated::String(v) })
    Evaluated::Bytes(_) => @client.bytes_serializer().from_bytes(bytes, unrecognized_values=p).map(fn(v) { Evaluated::Bytes(v) })
    Evaluated::BoolOptional(_) => @client.optional_serializer(@client.bool_serializer()).from_bytes(bytes, unrecognized_values=p).map(fn(v) { Evaluated::BoolOptional(v) })
    Evaluated::Ints(_) => @client.vector_serializer(@client.int32_serializer()).from_bytes(bytes, unrecognized_values=p).map(fn(v) { Evaluated::Ints(v) })
    Evaluated::Point(_) => @goldens.Point::serializer().from_bytes(bytes, unrecognized_values=p).map(fn(v) { Evaluated::Point(v) })
    Evaluated::Color(_) => @goldens.Color::serializer().from_bytes(bytes, unrecognized_values=p).map(fn(v) { Evaluated::Color(v) })
    Evaluated::MyEnum(_) => @goldens.MyEnum::serializer().from_bytes(bytes, unrecognized_values=p).map(fn(v) { Evaluated::MyEnum(v) })
    Evaluated::EnumA(_) => @goldens.EnumA::serializer().from_bytes(bytes, unrecognized_values=p).map(fn(v) { Evaluated::EnumA(v) })
    Evaluated::EnumB(_) => @goldens.EnumB::serializer().from_bytes(bytes, unrecognized_values=p).map(fn(v) { Evaluated::EnumB(v) })
    Evaluated::KeyedArrays(_) => @goldens.KeyedArrays::serializer().from_bytes(bytes, unrecognized_values=p).map(fn(v) { Evaluated::KeyedArrays(v) })
    Evaluated::RecStruct(_) => @goldens.RecStruct::serializer().from_bytes(bytes, unrecognized_values=p).map(fn(v) { Evaluated::RecStruct(v) })
    Evaluated::RecEnum(_) => @goldens.RecEnum::serializer().from_bytes(bytes, unrecognized_values=p).map(fn(v) { Evaluated::RecEnum(v) })
  }
}

fn evaluate_typed_value(input : @goldens.TypedValue) -> Result[Evaluated, String] {
  match input {
    @goldens.TypedValue::Unknown(_) => Err("unknown typed value")
    @goldens.TypedValue::Bool(v) => Ok(Evaluated::Bool(v))
    @goldens.TypedValue::Int32(v) => Ok(Evaluated::Int32(v))
    @goldens.TypedValue::Int64(v) => Ok(Evaluated::Int64(v))
    @goldens.TypedValue::Hash64(v) => Ok(Evaluated::Hash64(v))
    @goldens.TypedValue::Float32(v) => Ok(Evaluated::Float32(v))
    @goldens.TypedValue::Float64(v) => Ok(Evaluated::Float64(v))
    @goldens.TypedValue::Timestamp(v) => Ok(Evaluated::Timestamp(v))
    @goldens.TypedValue::String(v) => Ok(Evaluated::String(v))
    @goldens.TypedValue::Bytes(v) => Ok(Evaluated::Bytes(v))
    @goldens.TypedValue::BoolOptional(v) => Ok(Evaluated::BoolOptional(v))
    @goldens.TypedValue::Ints(v) => Ok(Evaluated::Ints(v))
    @goldens.TypedValue::Point(v) => Ok(Evaluated::Point(v))
    @goldens.TypedValue::Color(v) => Ok(Evaluated::Color(v))
    @goldens.TypedValue::MyEnum(v) => Ok(Evaluated::MyEnum(v))
    @goldens.TypedValue::EnumA(v) => Ok(Evaluated::EnumA(v))
    @goldens.TypedValue::EnumB(v) => Ok(Evaluated::EnumB(v))
    @goldens.TypedValue::KeyedArrays(v) => Ok(Evaluated::KeyedArrays(v))
    @goldens.TypedValue::RecStruct(v) => Ok(Evaluated::RecStruct(v))
    @goldens.TypedValue::RecEnum(v) => Ok(Evaluated::RecEnum(v))
    @goldens.TypedValue::RoundTripDenseJson(v) =>
      match evaluate_typed_value(v) {
        Ok(evaluated) => evaluated_from_json(evaluated, evaluated_to_dense_json(evaluated), false)
        Err(e) => Err(e)
      }
    @goldens.TypedValue::RoundTripReadableJson(v) =>
      match evaluate_typed_value(v) {
        Ok(evaluated) => evaluated_from_json(evaluated, evaluated_to_readable_json(evaluated), false)
        Err(e) => Err(e)
      }
    @goldens.TypedValue::RoundTripBytes(v) =>
      match evaluate_typed_value(v) {
        Ok(evaluated) => evaluated_from_bytes(evaluated, evaluated_to_bytes(evaluated), false)
        Err(e) => Err(e)
      }
    @goldens.TypedValue::PointFromJsonKeepUnrecognized(v) =>
      match evaluate_string_expression(v) {
        Ok(code) => @goldens.Point::serializer().from_json_code(code, unrecognized_values=policy(true)).map(fn(value) { Evaluated::Point(value) })
        Err(e) => Err(e)
      }
    @goldens.TypedValue::PointFromJsonDropUnrecognized(v) =>
      match evaluate_string_expression(v) {
        Ok(code) => @goldens.Point::serializer().from_json_code(code, unrecognized_values=policy(false)).map(fn(value) { Evaluated::Point(value) })
        Err(e) => Err(e)
      }
    @goldens.TypedValue::PointFromBytesKeepUnrecognized(v) =>
      match evaluate_bytes_expression(v) {
        Ok(bytes) => @goldens.Point::serializer().from_bytes(bytes, unrecognized_values=policy(true)).map(fn(value) { Evaluated::Point(value) })
        Err(e) => Err(e)
      }
    @goldens.TypedValue::PointFromBytesDropUnrecognized(v) =>
      match evaluate_bytes_expression(v) {
        Ok(bytes) => @goldens.Point::serializer().from_bytes(bytes, unrecognized_values=policy(false)).map(fn(value) { Evaluated::Point(value) })
        Err(e) => Err(e)
      }
    @goldens.TypedValue::ColorFromJsonKeepUnrecognized(v) =>
      match evaluate_string_expression(v) {
        Ok(code) => @goldens.Color::serializer().from_json_code(code, unrecognized_values=policy(true)).map(fn(value) { Evaluated::Color(value) })
        Err(e) => Err(e)
      }
    @goldens.TypedValue::ColorFromJsonDropUnrecognized(v) =>
      match evaluate_string_expression(v) {
        Ok(code) => @goldens.Color::serializer().from_json_code(code, unrecognized_values=policy(false)).map(fn(value) { Evaluated::Color(value) })
        Err(e) => Err(e)
      }
    @goldens.TypedValue::ColorFromBytesKeepUnrecognized(v) =>
      match evaluate_bytes_expression(v) {
        Ok(bytes) => @goldens.Color::serializer().from_bytes(bytes, unrecognized_values=policy(true)).map(fn(value) { Evaluated::Color(value) })
        Err(e) => Err(e)
      }
    @goldens.TypedValue::ColorFromBytesDropUnrecognized(v) =>
      match evaluate_bytes_expression(v) {
        Ok(bytes) => @goldens.Color::serializer().from_bytes(bytes, unrecognized_values=policy(false)).map(fn(value) { Evaluated::Color(value) })
        Err(e) => Err(e)
      }
    @goldens.TypedValue::MyEnumFromJsonKeepUnrecognized(v) =>
      match evaluate_string_expression(v) {
        Ok(code) => @goldens.MyEnum::serializer().from_json_code(code, unrecognized_values=policy(true)).map(fn(value) { Evaluated::MyEnum(value) })
        Err(e) => Err(e)
      }
    @goldens.TypedValue::MyEnumFromJsonDropUnrecognized(v) =>
      match evaluate_string_expression(v) {
        Ok(code) => @goldens.MyEnum::serializer().from_json_code(code, unrecognized_values=policy(false)).map(fn(value) { Evaluated::MyEnum(value) })
        Err(e) => Err(e)
      }
    @goldens.TypedValue::MyEnumFromBytesKeepUnrecognized(v) =>
      match evaluate_bytes_expression(v) {
        Ok(bytes) => @goldens.MyEnum::serializer().from_bytes(bytes, unrecognized_values=policy(true)).map(fn(value) { Evaluated::MyEnum(value) })
        Err(e) => Err(e)
      }
    @goldens.TypedValue::MyEnumFromBytesDropUnrecognized(v) =>
      match evaluate_bytes_expression(v) {
        Ok(bytes) => @goldens.MyEnum::serializer().from_bytes(bytes, unrecognized_values=policy(false)).map(fn(value) { Evaluated::MyEnum(value) })
        Err(e) => Err(e)
      }
    @goldens.TypedValue::EnumAFromJsonKeepUnrecognized(v) =>
      match evaluate_string_expression(v) {
        Ok(code) => @goldens.EnumA::serializer().from_json_code(code, unrecognized_values=policy(true)).map(fn(value) { Evaluated::EnumA(value) })
        Err(e) => Err(e)
      }
    @goldens.TypedValue::EnumAFromJsonDropUnrecognized(v) =>
      match evaluate_string_expression(v) {
        Ok(code) => @goldens.EnumA::serializer().from_json_code(code, unrecognized_values=policy(false)).map(fn(value) { Evaluated::EnumA(value) })
        Err(e) => Err(e)
      }
    @goldens.TypedValue::EnumAFromBytesKeepUnrecognized(v) =>
      match evaluate_bytes_expression(v) {
        Ok(bytes) => @goldens.EnumA::serializer().from_bytes(bytes, unrecognized_values=policy(true)).map(fn(value) { Evaluated::EnumA(value) })
        Err(e) => Err(e)
      }
    @goldens.TypedValue::EnumAFromBytesDropUnrecognized(v) =>
      match evaluate_bytes_expression(v) {
        Ok(bytes) => @goldens.EnumA::serializer().from_bytes(bytes, unrecognized_values=policy(false)).map(fn(value) { Evaluated::EnumA(value) })
        Err(e) => Err(e)
      }
    @goldens.TypedValue::EnumBFromJsonKeepUnrecognized(v) =>
      match evaluate_string_expression(v) {
        Ok(code) => @goldens.EnumB::serializer().from_json_code(code, unrecognized_values=policy(true)).map(fn(value) { Evaluated::EnumB(value) })
        Err(e) => Err(e)
      }
    @goldens.TypedValue::EnumBFromJsonDropUnrecognized(v) =>
      match evaluate_string_expression(v) {
        Ok(code) => @goldens.EnumB::serializer().from_json_code(code, unrecognized_values=policy(false)).map(fn(value) { Evaluated::EnumB(value) })
        Err(e) => Err(e)
      }
    @goldens.TypedValue::EnumBFromBytesKeepUnrecognized(v) =>
      match evaluate_bytes_expression(v) {
        Ok(bytes) => @goldens.EnumB::serializer().from_bytes(bytes, unrecognized_values=policy(true)).map(fn(value) { Evaluated::EnumB(value) })
        Err(e) => Err(e)
      }
    @goldens.TypedValue::EnumBFromBytesDropUnrecognized(v) =>
      match evaluate_bytes_expression(v) {
        Ok(bytes) => @goldens.EnumB::serializer().from_bytes(bytes, unrecognized_values=policy(false)).map(fn(value) { Evaluated::EnumB(value) })
        Err(e) => Err(e)
      }
  }
}

fn verify_reserialize_value(assertion : @goldens.Assertion_ReserializeValue) -> String? {
  let evaluated =
    match evaluate_typed_value(assertion.value) {
      Ok(v) => v
      Err(e) => return Some("evaluate:" + e)
    }

  let dense = evaluated_to_dense_json(evaluated)
  if !json_matches_candidates(dense, assertion.expected_dense_json) {
    return Some("dense_json")
  }

  let readable = evaluated_to_readable_json(evaluated)
  if !json_matches_candidates(readable, assertion.expected_readable_json) {
    return Some("readable_json")
  }

  let bytes = evaluated_to_bytes(evaluated)
  if !bytes_matches_candidates(bytes, assertion.expected_bytes) {
    return Some("bytes")
  }

  for candidate in assertion.expected_dense_json.iter() {
    match evaluated_from_json(evaluated, candidate, false) {
      Ok(parsed) => if parsed != evaluated { return Some("roundtrip_dense_json") }
      Err(_) => return Some("roundtrip_dense_json")
    }
  }
  for candidate in assertion.expected_readable_json.iter() {
    match evaluated_from_json(evaluated, candidate, false) {
      Ok(parsed) => if parsed != evaluated { return Some("roundtrip_readable_json") }
      Err(_) => return Some("roundtrip_readable_json")
    }
  }
  for candidate in assertion.alternative_jsons.iter() {
    let code =
      match evaluate_string_expression(candidate) {
        Ok(v) => v
        Err(_) => return Some("alternative_json_eval")
      }
    match evaluated_from_json(evaluated, code, false) {
      Ok(parsed) => if parsed != evaluated { return Some("alternative_json") }
      Err(_) => return Some("alternative_json")
    }
  }

  for candidate in assertion.expected_bytes.iter() {
    match evaluated_from_bytes(evaluated, bytes_to_ints(candidate), false) {
      Ok(parsed) => if parsed != evaluated { return Some("roundtrip_bytes") }
      Err(_) => return Some("roundtrip_bytes")
    }
  }
  for candidate in assertion.alternative_bytes.iter() {
    let encoded =
      match evaluate_bytes_expression(candidate) {
        Ok(v) => v
        Err(_) => return Some("alternative_bytes_eval")
      }
    match evaluated_from_bytes(evaluated, encoded, false) {
      Ok(parsed) => if parsed != evaluated { return Some("alternative_bytes") }
      Err(_) => return Some("alternative_bytes")
    }
  }

  match assertion.expected_type_descriptor {
    Some(expected) => {
      let actual = evaluated_to_type_descriptor_json(evaluated)
      let actual_json = parse_json_or_none(actual)
      let expected_json = parse_json_or_none(expected)
      match (actual_json, expected_json) {
        (Some(a), Some(b)) => if a != b { return Some("type_descriptor") }
        _ => if actual != expected { return Some("type_descriptor") }
      }
    }
    None => ()
  }

  None
}

fn verify_assertion(assertion : @goldens.Assertion) -> String? {
  match assertion {
    @goldens.Assertion::Unknown(_) => Some("unknown_assertion")
    @goldens.Assertion::BytesEqual(value) =>
      match (evaluate_bytes_expression(value.actual), evaluate_bytes_expression(value.expected)) {
        (Ok(actual), Ok(expected)) => if actual == expected { None } else { Some("bytes_equal") }
        _ => Some("bytes_equal")
      }
    @goldens.Assertion::BytesIn(value) =>
      match evaluate_bytes_expression(value.actual) {
        Ok(actual) => if bytes_matches_candidates(actual, value.expected) { None } else { Some("bytes_in") }
        Err(_) => Some("bytes_in")
      }
    @goldens.Assertion::StringEqual(value) =>
      match (evaluate_string_expression(value.actual), evaluate_string_expression(value.expected)) {
        (Ok(actual), Ok(expected)) => if actual == expected { None } else { Some("string_equal") }
        _ => Some("string_equal")
      }
    @goldens.Assertion::StringIn(value) =>
      match evaluate_string_expression(value.actual) {
        Ok(actual) => if string_matches_candidates(actual, value.expected) { None } else { Some("string_in") }
        Err(_) => Some("string_in")
      }
    @goldens.Assertion::ReserializeValue(value) => verify_reserialize_value(value)
    @goldens.Assertion::ReserializeLargeString(value) => {
      let builder = StringBuilder()
      for _ in 0..<value.num_chars {
        builder.write_char('x')
      }
      if bytes_has_prefix(@client.string_serializer().to_bytes(builder.to_string()), value.expected_byte_prefix) {
        None
      } else {
        Some("reserialize_large_string")
      }
    }
    @goldens.Assertion::ReserializeLargeArray(value) => {
      let items : Array[Int] = []
      for i in 0..<value.num_items {
        items.push(i)
      }
      let array = @immut_vector.Vector::from_array(items)
      if bytes_has_prefix(
        @client.vector_serializer(@client.int32_serializer()).to_bytes(array),
        value.expected_byte_prefix,
      ) {
        None
      } else {
        Some("reserialize_large_array")
      }
    }
    @goldens.Assertion::EnumAFromJsonIsConstant(value) => {
      let code =
        match evaluate_string_expression(value.actual) {
          Ok(v) => v
          Err(_) => return Some("enum_a_from_json")
        }
      match @goldens.EnumA::serializer().from_json_code(code, unrecognized_values=policy(value.keep_unrecognized)) {
        Ok(parsed) => if parsed == @goldens.EnumA::a() { None } else { Some("enum_a_from_json") }
        Err(_) => Some("enum_a_from_json")
      }
    }
    @goldens.Assertion::EnumAFromBytesIsConstant(value) => {
      let encoded =
        match evaluate_bytes_expression(value.actual) {
          Ok(v) => v
          Err(_) => return Some("enum_a_from_bytes")
        }
      match @goldens.EnumA::serializer().from_bytes(encoded, unrecognized_values=policy(value.keep_unrecognized)) {
        Ok(parsed) => if parsed == @goldens.EnumA::a() { None } else { Some("enum_a_from_bytes") }
        Err(_) => Some("enum_a_from_bytes")
      }
    }
    @goldens.Assertion::EnumBFromJsonIsWrapperB(value) => {
      let code =
        match evaluate_string_expression(value.actual) {
          Ok(v) => v
          Err(_) => return Some("enum_b_from_json")
        }
      match @goldens.EnumB::serializer().from_json_code(code, unrecognized_values=policy(value.keep_unrecognized)) {
        Ok(parsed) => if parsed == @goldens.EnumB::b(value.expected) { None } else { Some("enum_b_from_json") }
        Err(_) => Some("enum_b_from_json")
      }
    }
    @goldens.Assertion::EnumBFromBytesIsWrapperB(value) => {
      let encoded =
        match evaluate_bytes_expression(value.actual) {
          Ok(v) => v
          Err(_) => return Some("enum_b_from_bytes")
        }
      match @goldens.EnumB::serializer().from_bytes(encoded, unrecognized_values=policy(value.keep_unrecognized)) {
        Ok(parsed) => if parsed == @goldens.EnumB::b(value.expected) { None } else { Some("enum_b_from_bytes") }
        Err(_) => Some("enum_b_from_bytes")
      }
    }
  }
}

test "goldens_assertions" {
  let mut expected_test_number = 1000
  let failed_tests : Array[String] = []
  for unit_test in @goldens.unit_tests_const.iter() {
    if unit_test.test_number != expected_test_number {
      failed_tests.push(unit_test.test_number.to_string() + ":numbering")
    }
    match verify_assertion(unit_test.assertion) {
      Some(reason) => failed_tests.push(unit_test.test_number.to_string() + ":" + reason)
      None => ()
    }
    expected_test_number = expected_test_number + 1
  }
  if failed_tests.length() != 0 {
    panic()
  }
}
