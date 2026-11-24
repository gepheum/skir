/// Golden tests ported from the TypeScript test suite.
///
/// Runs all entries in the UNIT_TESTS constant generated from goldens.readonly.skir and
/// verifies each assertion.
#[cfg(test)]
mod tests {
    use crate::skir_client::{JsonFlavor, Serializer, UnrecognizedValues};
    use crate::skirout::base::external::gepheum::skir_golden_tests::goldens::unit_tests_const;
    use crate::skirout::base::external::gepheum::skir_golden_tests::goldens::{
        Assertion, Assertion_BytesEqual, Assertion_BytesIn, Assertion_EnumAFromBytesIsConstant,
        Assertion_EnumAFromJsonIsConstant, Assertion_EnumBFromBytesIsWrapperB,
        Assertion_EnumBFromJsonIsWrapperB, Assertion_ReserializeLargeArray,
        Assertion_ReserializeLargeString, Assertion_ReserializeValue, Assertion_StringEqual,
        Assertion_StringIn, BytesExpression, Color, EnumA, EnumB, KeyedArrays, MyEnum, Point,
        RecEnum, RecStruct, StringExpression, TypedValue,
    };

    // =========================================================================
    // EvaluatedValue — type-erased value + serializer
    // =========================================================================

    /// A type-erased bundle of a deserialised value and its serializer, used so
    /// that `evaluate_typed_value` can return values of different types.
    trait EvaluatedValue {
        fn to_bytes(&self) -> Vec<u8>;
        fn to_dense_json(&self) -> String;
        fn to_readable_json(&self) -> String;
        fn type_descriptor_json(&self) -> String;
        fn from_json_keep_unrecognized(
            &self,
            json: &str,
        ) -> Result<Box<dyn EvaluatedValue>, String>;
        fn from_json_drop_unrecognized(
            &self,
            json: &str,
        ) -> Result<Box<dyn EvaluatedValue>, String>;
        fn from_bytes_drop_unrecognized(
            &self,
            bytes: &[u8],
        ) -> Result<Box<dyn EvaluatedValue>, String>;
    }

    struct EvaluatedValueImpl<T: 'static + Clone> {
        value: T,
        serializer: Serializer<T>,
    }

    impl<T: 'static + Clone> EvaluatedValue for EvaluatedValueImpl<T> {
        fn to_bytes(&self) -> Vec<u8> {
            self.serializer.to_bytes(&self.value)
        }

        fn to_dense_json(&self) -> String {
            self.serializer.to_json(&self.value, JsonFlavor::Dense)
        }

        fn to_readable_json(&self) -> String {
            self.serializer.to_json(&self.value, JsonFlavor::Readable)
        }

        fn type_descriptor_json(&self) -> String {
            self.serializer.type_descriptor().as_json()
        }

        fn from_json_keep_unrecognized(
            &self,
            json: &str,
        ) -> Result<Box<dyn EvaluatedValue>, String> {
            let value = self.serializer.from_json(json, UnrecognizedValues::Keep)?;
            Ok(Box::new(EvaluatedValueImpl {
                value,
                serializer: self.serializer.clone(),
            }))
        }

        fn from_json_drop_unrecognized(
            &self,
            json: &str,
        ) -> Result<Box<dyn EvaluatedValue>, String> {
            let value = self.serializer.from_json(json, UnrecognizedValues::Drop)?;
            Ok(Box::new(EvaluatedValueImpl {
                value,
                serializer: self.serializer.clone(),
            }))
        }

        fn from_bytes_drop_unrecognized(
            &self,
            bytes: &[u8],
        ) -> Result<Box<dyn EvaluatedValue>, String> {
            let value = self
                .serializer
                .from_bytes(bytes, UnrecognizedValues::Drop)?;
            Ok(Box::new(EvaluatedValueImpl {
                value,
                serializer: self.serializer.clone(),
            }))
        }
    }

    fn ev<T: 'static + Clone>(value: T, serializer: Serializer<T>) -> Box<dyn EvaluatedValue> {
        Box::new(EvaluatedValueImpl { value, serializer })
    }

    // =========================================================================
    // Evaluate helpers
    // =========================================================================

    fn to_hex(bytes: &[u8]) -> String {
        bytes.iter().map(|b| format!("{:02x}", b)).collect()
    }

    fn evaluate_bytes(expr: &BytesExpression) -> Result<Vec<u8>, String> {
        match expr {
            BytesExpression::Literal(b) => Ok(b.clone()),
            BytesExpression::ToBytes(tv) => {
                let ev = evaluate_typed_value(tv)?;
                Ok(ev.to_bytes())
            }
            BytesExpression::Unknown(_) => Err("unknown BytesExpression variant".to_string()),
        }
    }

    fn evaluate_string(expr: &StringExpression) -> Result<String, String> {
        match expr {
            StringExpression::Literal(s) => Ok(s.clone()),
            StringExpression::ToDenseJson(tv) => {
                let ev = evaluate_typed_value(tv)?;
                Ok(ev.to_dense_json())
            }
            StringExpression::ToReadableJson(tv) => {
                let ev = evaluate_typed_value(tv)?;
                Ok(ev.to_readable_json())
            }
            StringExpression::Unknown(_) => Err("unknown StringExpression variant".to_string()),
        }
    }

    fn evaluate_typed_value(tv: &TypedValue) -> Result<Box<dyn EvaluatedValue>, String> {
        match tv {
            TypedValue::Bool(v) => Ok(ev(*v, Serializer::bool())),
            TypedValue::Int32(v) => Ok(ev(*v, Serializer::int32())),
            TypedValue::Int64(v) => Ok(ev(*v, Serializer::int64())),
            TypedValue::Hash64(v) => Ok(ev(*v, Serializer::hash64())),
            TypedValue::Float32(v) => Ok(ev(*v, Serializer::float32())),
            TypedValue::Float64(v) => Ok(ev(*v, Serializer::float64())),
            TypedValue::Timestamp(v) => Ok(ev(v.clone(), Serializer::timestamp())),
            TypedValue::String(v) => Ok(ev(v.clone(), Serializer::string())),
            TypedValue::Bytes(v) => Ok(ev(v.clone(), Serializer::bytes())),
            TypedValue::BoolOptional(v) => Ok(ev(*v, Serializer::optional(Serializer::bool()))),
            TypedValue::Ints(v) => Ok(ev(v.clone(), Serializer::array(Serializer::int32()))),
            TypedValue::Point(v) => Ok(ev((**v).clone(), Point::serializer())),
            TypedValue::Color(v) => Ok(ev((**v).clone(), Color::serializer())),
            TypedValue::MyEnum(v) => Ok(ev((**v).clone(), MyEnum::serializer())),
            TypedValue::EnumA(v) => Ok(ev((**v).clone(), EnumA::serializer())),
            TypedValue::EnumB(v) => Ok(ev((**v).clone(), EnumB::serializer())),
            TypedValue::KeyedArrays(v) => Ok(ev((**v).clone(), KeyedArrays::serializer())),
            TypedValue::RecStruct(v) => Ok(ev((**v).clone(), RecStruct::serializer())),
            TypedValue::RecEnum(v) => Ok(ev((**v).clone(), RecEnum::serializer())),
            TypedValue::RoundTripDenseJson(inner) => {
                let ev = evaluate_typed_value(inner)?;
                let json = ev.to_dense_json();
                ev.from_json_drop_unrecognized(&json)
            }
            TypedValue::RoundTripReadableJson(inner) => {
                let ev = evaluate_typed_value(inner)?;
                let json = ev.to_readable_json();
                ev.from_json_drop_unrecognized(&json)
            }
            TypedValue::RoundTripBytes(inner) => {
                let ev = evaluate_typed_value(inner)?;
                let bytes = ev.to_bytes();
                ev.from_bytes_drop_unrecognized(&bytes)
            }
            TypedValue::PointFromJsonKeepUnrecognized(expr) => {
                let json = evaluate_string(expr)?;
                let value = Point::serializer()
                    .from_json(&json, UnrecognizedValues::Keep)
                    .map_err(|e| format!("PointFromJsonKeepUnrecognized: {}", e))?;
                Ok(ev(value, Point::serializer()))
            }
            TypedValue::PointFromJsonDropUnrecognized(expr) => {
                let json = evaluate_string(expr)?;
                let value = Point::serializer()
                    .from_json(&json, UnrecognizedValues::Drop)
                    .map_err(|e| format!("PointFromJsonDropUnrecognized: {}", e))?;
                Ok(ev(value, Point::serializer()))
            }
            TypedValue::PointFromBytesKeepUnrecognized(expr) => {
                let bytes = evaluate_bytes(expr)?;
                let value = Point::serializer()
                    .from_bytes(&bytes, UnrecognizedValues::Keep)
                    .map_err(|e| format!("PointFromBytesKeepUnrecognized: {}", e))?;
                Ok(ev(value, Point::serializer()))
            }
            TypedValue::PointFromBytesDropUnrecognized(expr) => {
                let bytes = evaluate_bytes(expr)?;
                let value = Point::serializer()
                    .from_bytes(&bytes, UnrecognizedValues::Drop)
                    .map_err(|e| format!("PointFromBytesDropUnrecognized: {}", e))?;
                Ok(ev(value, Point::serializer()))
            }
            TypedValue::ColorFromJsonKeepUnrecognized(expr) => {
                let json = evaluate_string(expr)?;
                let value = Color::serializer()
                    .from_json(&json, UnrecognizedValues::Keep)
                    .map_err(|e| format!("ColorFromJsonKeepUnrecognized: {}", e))?;
                Ok(ev(value, Color::serializer()))
            }
            TypedValue::ColorFromJsonDropUnrecognized(expr) => {
                let json = evaluate_string(expr)?;
                let value = Color::serializer()
                    .from_json(&json, UnrecognizedValues::Drop)
                    .map_err(|e| format!("ColorFromJsonDropUnrecognized: {}", e))?;
                Ok(ev(value, Color::serializer()))
            }
            TypedValue::ColorFromBytesKeepUnrecognized(expr) => {
                let bytes = evaluate_bytes(expr)?;
                let value = Color::serializer()
                    .from_bytes(&bytes, UnrecognizedValues::Keep)
                    .map_err(|e| format!("ColorFromBytesKeepUnrecognized: {}", e))?;
                Ok(ev(value, Color::serializer()))
            }
            TypedValue::ColorFromBytesDropUnrecognized(expr) => {
                let bytes = evaluate_bytes(expr)?;
                let value = Color::serializer()
                    .from_bytes(&bytes, UnrecognizedValues::Drop)
                    .map_err(|e| format!("ColorFromBytesDropUnrecognized: {}", e))?;
                Ok(ev(value, Color::serializer()))
            }
            TypedValue::MyEnumFromJsonKeepUnrecognized(expr) => {
                let json = evaluate_string(expr)?;
                let value = MyEnum::serializer()
                    .from_json(&json, UnrecognizedValues::Keep)
                    .map_err(|e| format!("MyEnumFromJsonKeepUnrecognized: {}", e))?;
                Ok(ev(value, MyEnum::serializer()))
            }
            TypedValue::MyEnumFromJsonDropUnrecognized(expr) => {
                let json = evaluate_string(expr)?;
                let value = MyEnum::serializer()
                    .from_json(&json, UnrecognizedValues::Drop)
                    .map_err(|e| format!("MyEnumFromJsonDropUnrecognized: {}", e))?;
                Ok(ev(value, MyEnum::serializer()))
            }
            TypedValue::MyEnumFromBytesKeepUnrecognized(expr) => {
                let bytes = evaluate_bytes(expr)?;
                let value = MyEnum::serializer()
                    .from_bytes(&bytes, UnrecognizedValues::Keep)
                    .map_err(|e| format!("MyEnumFromBytesKeepUnrecognized: {}", e))?;
                Ok(ev(value, MyEnum::serializer()))
            }
            TypedValue::MyEnumFromBytesDropUnrecognized(expr) => {
                let bytes = evaluate_bytes(expr)?;
                let value = MyEnum::serializer()
                    .from_bytes(&bytes, UnrecognizedValues::Drop)
                    .map_err(|e| format!("MyEnumFromBytesDropUnrecognized: {}", e))?;
                Ok(ev(value, MyEnum::serializer()))
            }
            TypedValue::EnumAFromJsonKeepUnrecognized(expr) => {
                let json = evaluate_string(expr)?;
                let value = EnumA::serializer()
                    .from_json(&json, UnrecognizedValues::Keep)
                    .map_err(|e| format!("EnumAFromJsonKeepUnrecognized: {}", e))?;
                Ok(ev(value, EnumA::serializer()))
            }
            TypedValue::EnumAFromJsonDropUnrecognized(expr) => {
                let json = evaluate_string(expr)?;
                let value = EnumA::serializer()
                    .from_json(&json, UnrecognizedValues::Drop)
                    .map_err(|e| format!("EnumAFromJsonDropUnrecognized: {}", e))?;
                Ok(ev(value, EnumA::serializer()))
            }
            TypedValue::EnumAFromBytesKeepUnrecognized(expr) => {
                let bytes = evaluate_bytes(expr)?;
                let value = EnumA::serializer()
                    .from_bytes(&bytes, UnrecognizedValues::Keep)
                    .map_err(|e| format!("EnumAFromBytesKeepUnrecognized: {}", e))?;
                Ok(ev(value, EnumA::serializer()))
            }
            TypedValue::EnumAFromBytesDropUnrecognized(expr) => {
                let bytes = evaluate_bytes(expr)?;
                let value = EnumA::serializer()
                    .from_bytes(&bytes, UnrecognizedValues::Drop)
                    .map_err(|e| format!("EnumAFromBytesDropUnrecognized: {}", e))?;
                Ok(ev(value, EnumA::serializer()))
            }
            TypedValue::EnumBFromJsonKeepUnrecognized(expr) => {
                let json = evaluate_string(expr)?;
                let value = EnumB::serializer()
                    .from_json(&json, UnrecognizedValues::Keep)
                    .map_err(|e| format!("EnumBFromJsonKeepUnrecognized: {}", e))?;
                Ok(ev(value, EnumB::serializer()))
            }
            TypedValue::EnumBFromJsonDropUnrecognized(expr) => {
                let json = evaluate_string(expr)?;
                let value = EnumB::serializer()
                    .from_json(&json, UnrecognizedValues::Drop)
                    .map_err(|e| format!("EnumBFromJsonDropUnrecognized: {}", e))?;
                Ok(ev(value, EnumB::serializer()))
            }
            TypedValue::EnumBFromBytesKeepUnrecognized(expr) => {
                let bytes = evaluate_bytes(expr)?;
                let value = EnumB::serializer()
                    .from_bytes(&bytes, UnrecognizedValues::Keep)
                    .map_err(|e| format!("EnumBFromBytesKeepUnrecognized: {}", e))?;
                Ok(ev(value, EnumB::serializer()))
            }
            TypedValue::EnumBFromBytesDropUnrecognized(expr) => {
                let bytes = evaluate_bytes(expr)?;
                let value = EnumB::serializer()
                    .from_bytes(&bytes, UnrecognizedValues::Drop)
                    .map_err(|e| format!("EnumBFromBytesDropUnrecognized: {}", e))?;
                Ok(ev(value, EnumB::serializer()))
            }
            TypedValue::Unknown(_) => Err("unknown TypedValue variant".to_string()),
        }
    }

    // =========================================================================
    // Assertion evaluation
    // =========================================================================

    fn verify_assertion(assertion: &Assertion) -> Result<(), String> {
        match assertion {
            Assertion::BytesEqual(a) => verify_bytes_equal(a),
            Assertion::BytesIn(a) => verify_bytes_in(a),
            Assertion::StringEqual(a) => verify_string_equal(a),
            Assertion::StringIn(a) => verify_string_in(a),
            Assertion::ReserializeValue(a) => verify_reserialize_value(a),
            Assertion::ReserializeLargeString(a) => verify_reserialize_large_string(a),
            Assertion::ReserializeLargeArray(a) => verify_reserialize_large_array(a),
            Assertion::EnumAFromJsonIsConstant(a) => verify_enum_a_from_json_is_constant(a),
            Assertion::EnumAFromBytesIsConstant(a) => verify_enum_a_from_bytes_is_constant(a),
            Assertion::EnumBFromJsonIsWrapperB(a) => verify_enum_b_from_json_is_wrapper_b(a),
            Assertion::EnumBFromBytesIsWrapperB(a) => verify_enum_b_from_bytes_is_wrapper_b(a),
            Assertion::Unknown(_) => Err("unknown Assertion variant".to_string()),
        }
    }

    fn verify_enum_a_from_json_is_constant(
        a: &Assertion_EnumAFromJsonIsConstant,
    ) -> Result<(), String> {
        let actual = evaluate_string(&a.actual)?;
        let value = EnumA::serializer()
            .from_json(
                &actual,
                if a.keep_unrecognized {
                    UnrecognizedValues::Keep
                } else {
                    UnrecognizedValues::Drop
                },
            )
            .map_err(|e| format!("enum_a_from_json_is_constant parse error: {}", e))?;
        if !matches!(value, EnumA::A) {
            return Err(format!(
                "enum_a_from_json_is_constant mismatch\n  actual json: {:?}\n  expected: EnumA::A",
                actual
            ));
        }
        Ok(())
    }

    fn verify_enum_a_from_bytes_is_constant(
        a: &Assertion_EnumAFromBytesIsConstant,
    ) -> Result<(), String> {
        let actual = evaluate_bytes(&a.actual)?;
        let value = EnumA::serializer()
            .from_bytes(
                &actual,
                if a.keep_unrecognized {
                    UnrecognizedValues::Keep
                } else {
                    UnrecognizedValues::Drop
                },
            )
            .map_err(|e| format!("enum_a_from_bytes_is_constant parse error: {}", e))?;
        if !matches!(value, EnumA::A) {
            return Err(format!(
                "enum_a_from_bytes_is_constant mismatch\n  actual bytes: hex:{}\n  expected: EnumA::A",
                to_hex(&actual)
            ));
        }
        Ok(())
    }

    fn verify_enum_b_from_json_is_wrapper_b(
        a: &Assertion_EnumBFromJsonIsWrapperB,
    ) -> Result<(), String> {
        let actual = evaluate_string(&a.actual)?;
        let value = EnumB::serializer()
            .from_json(
                &actual,
                if a.keep_unrecognized {
                    UnrecognizedValues::Keep
                } else {
                    UnrecognizedValues::Drop
                },
            )
            .map_err(|e| format!("enum_b_from_json_is_wrapper_b parse error: {}", e))?;
        match value {
            EnumB::B(v) if v == a.expected => Ok(()),
            _ => Err(format!(
                "enum_b_from_json_is_wrapper_b mismatch\n  actual json: {:?}\n  expected: EnumB::B({:?})",
                actual, a.expected
            )),
        }
    }

    fn verify_enum_b_from_bytes_is_wrapper_b(
        a: &Assertion_EnumBFromBytesIsWrapperB,
    ) -> Result<(), String> {
        let actual = evaluate_bytes(&a.actual)?;
        let value = EnumB::serializer()
            .from_bytes(
                &actual,
                if a.keep_unrecognized {
                    UnrecognizedValues::Keep
                } else {
                    UnrecognizedValues::Drop
                },
            )
            .map_err(|e| format!("enum_b_from_bytes_is_wrapper_b parse error: {}", e))?;
        match value {
            EnumB::B(v) if v == a.expected => Ok(()),
            _ => Err(format!(
                "enum_b_from_bytes_is_wrapper_b mismatch\n  actual bytes: hex:{}\n  expected: EnumB::B({:?})",
                to_hex(&actual),
                a.expected
            )),
        }
    }

    fn verify_bytes_equal(a: &Assertion_BytesEqual) -> Result<(), String> {
        let actual = evaluate_bytes(&a.actual)?;
        let expected = evaluate_bytes(&a.expected)?;
        if actual != expected {
            return Err(format!(
                "bytes mismatch\n  actual:   hex:{}\n  expected: hex:{}",
                to_hex(&actual),
                to_hex(&expected)
            ));
        }
        Ok(())
    }

    fn verify_bytes_in(a: &Assertion_BytesIn) -> Result<(), String> {
        let actual = evaluate_bytes(&a.actual)?;
        let found = a.expected.iter().any(|exp| *exp == actual);
        if !found {
            let expected_hex = a
                .expected
                .iter()
                .map(|b| format!("hex:{}", to_hex(b)))
                .collect::<Vec<_>>()
                .join(" or ");
            return Err(format!(
                "bytes not in expected set\n  actual:   hex:{}\n  expected: {}",
                to_hex(&actual),
                expected_hex
            ));
        }
        Ok(())
    }

    fn verify_string_equal(a: &Assertion_StringEqual) -> Result<(), String> {
        let actual = evaluate_string(&a.actual)?;
        let expected = evaluate_string(&a.expected)?;
        if actual != expected {
            return Err(format!(
                "string mismatch\n  actual:   {:?}\n  expected: {:?}",
                actual, expected
            ));
        }
        Ok(())
    }

    fn verify_string_in(a: &Assertion_StringIn) -> Result<(), String> {
        let actual = evaluate_string(&a.actual)?;
        if !a.expected.contains(&actual) {
            let expected_list = a
                .expected
                .iter()
                .map(|s| format!("{:?}", s))
                .collect::<Vec<_>>()
                .join(" or ");
            return Err(format!(
                "string not in expected set\n  actual:   {:?}\n  expected: {}",
                actual, expected_list
            ));
        }
        Ok(())
    }

    fn verify_reserialize_value(input: &Assertion_ReserializeValue) -> Result<(), String> {
        // Build 4 input values: original + 3 round-trip variants
        let round_trips = [
            TypedValue::RoundTripDenseJson(Box::new(input.value.clone())),
            TypedValue::RoundTripReadableJson(Box::new(input.value.clone())),
            TypedValue::RoundTripBytes(Box::new(input.value.clone())),
        ];
        let all_values: Vec<&TypedValue> = std::iter::once(&input.value)
            .chain(round_trips.iter())
            .collect();

        for input_tv in &all_values {
            let result = (|| -> Result<(), String> {
                // Verify bytes
                let bytes_ev = evaluate_typed_value(input_tv)?;
                let actual_bytes = bytes_ev.to_bytes();
                let found_bytes = input.expected_bytes.iter().any(|exp| *exp == actual_bytes);
                if !found_bytes {
                    let expected_hex = input
                        .expected_bytes
                        .iter()
                        .map(|b| format!("hex:{}", to_hex(b)))
                        .collect::<Vec<_>>()
                        .join(" or ");
                    return Err(format!(
                        "bytes not in expected set\n  actual:   hex:{}\n  expected: {}",
                        to_hex(&actual_bytes),
                        expected_hex
                    ));
                }

                // Verify dense JSON
                let dense_json = evaluate_typed_value(input_tv)?.to_dense_json();
                if !input.expected_dense_json.contains(&dense_json) {
                    let expected_list = input
                        .expected_dense_json
                        .iter()
                        .map(|s| format!("{:?}", s))
                        .collect::<Vec<_>>()
                        .join(" or ");
                    return Err(format!(
                        "dense JSON not in expected set\n  actual:   {:?}\n  expected: {}",
                        dense_json, expected_list
                    ));
                }

                // Verify readable JSON
                let readable_json = evaluate_typed_value(input_tv)?.to_readable_json();
                if !input.expected_readable_json.contains(&readable_json) {
                    let expected_list = input
                        .expected_readable_json
                        .iter()
                        .map(|s| format!("{:?}", s))
                        .collect::<Vec<_>>()
                        .join(" or ");
                    return Err(format!(
                        "readable JSON not in expected set\n  actual:   {:?}\n  expected: {}",
                        readable_json, expected_list
                    ));
                }

                Ok(())
            })();
            if let Err(e) = result {
                return Err(format!("{}\n  (while evaluating round-trip variant)", e));
            }
        }

        // Verify that encoded values can be skipped during decoding.
        // Build a buffer: "skir" + 0xF8 + payload_without_magic + 0x01
        // The 0x01 encodes field 0 (x), value 1 for Point.
        // After decoding as Point, x must equal 1 (skipped unknown payload).
        for expected_bytes in &input.expected_bytes {
            let mut buf = Vec::with_capacity(expected_bytes.len() + 2);
            buf.extend_from_slice(b"skir");
            buf.push(248); // tag that causes decoder to skip the embedded value
            buf.extend_from_slice(&expected_bytes[4..]); // payload without "skir"
            buf.push(1); // encodes x = 1 for Point (field 0, small positive varint)
            let point = Point::serializer()
                .from_bytes(&buf, UnrecognizedValues::Drop)
                .map_err(|e| format!("skip-value test failed to parse Point: {}", e))?;
            if point.x != 1 {
                return Err(format!(
                    "skip-value test: expected point.x == 1, got {}",
                    point.x
                ));
            }
        }

        // Round-trip alternative JSONs through the canonical serializer
        let typed_ev = evaluate_typed_value(&input.value)?;
        for alt_json_expr in &input.alternative_jsons {
            let result = (|| -> Result<(), String> {
                let alt_json = evaluate_string(alt_json_expr)?;
                let round_tripped = typed_ev.from_json_keep_unrecognized(&alt_json)?;
                let round_trip_json = round_tripped.to_dense_json();
                if !input.expected_dense_json.contains(&round_trip_json) {
                    let expected_list = input
                        .expected_dense_json
                        .iter()
                        .map(|s| format!("{:?}", s))
                        .collect::<Vec<_>>()
                        .join(" or ");
                    return Err(format!(
                        "alternative JSON round-trip mismatch\n  got: {:?}\n  expected: {}",
                        round_trip_json, expected_list
                    ));
                }
                Ok(())
            })();
            if let Err(e) = result {
                if let Ok(alt_json) = evaluate_string(alt_json_expr) {
                    return Err(format!(
                        "{}\n  (while processing alternative JSON: {:?})",
                        e, alt_json
                    ));
                }
                return Err(e);
            }
        }

        // Round-trip expected dense and readable JSONs
        let all_expected_jsons: Vec<&String> = input
            .expected_dense_json
            .iter()
            .chain(input.expected_readable_json.iter())
            .collect();
        for alt_json in &all_expected_jsons {
            let result = (|| -> Result<(), String> {
                let round_tripped = typed_ev.from_json_keep_unrecognized(alt_json)?;
                let round_trip_json = round_tripped.to_dense_json();
                if !input.expected_dense_json.contains(&round_trip_json) {
                    let expected_list = input
                        .expected_dense_json
                        .iter()
                        .map(|s| format!("{:?}", s))
                        .collect::<Vec<_>>()
                        .join(" or ");
                    return Err(format!(
                        "expected JSON round-trip mismatch\n  got: {:?}\n  expected: {}",
                        round_trip_json, expected_list
                    ));
                }
                Ok(())
            })();
            if let Err(e) = result {
                return Err(format!(
                    "{}\n  (while processing expected JSON: {:?})",
                    e, alt_json
                ));
            }
        }

        // Round-trip alternative bytes
        for alt_bytes_expr in &input.alternative_bytes {
            let result = (|| -> Result<(), String> {
                let alt_bytes = evaluate_bytes(alt_bytes_expr)?;
                let round_tripped = typed_ev.from_bytes_drop_unrecognized(&alt_bytes)?;
                let round_trip_bytes = round_tripped.to_bytes();
                let found = input
                    .expected_bytes
                    .iter()
                    .any(|exp| *exp == round_trip_bytes);
                if !found {
                    let expected_hex = input
                        .expected_bytes
                        .iter()
                        .map(|b| format!("hex:{}", to_hex(b)))
                        .collect::<Vec<_>>()
                        .join(" or ");
                    return Err(format!(
                        "alternative bytes round-trip mismatch\n  got:      hex:{}\n  expected: {}",
                        to_hex(&round_trip_bytes),
                        expected_hex
                    ));
                }
                Ok(())
            })();
            if let Err(e) = result {
                if let Ok(alt_bytes) = evaluate_bytes(alt_bytes_expr) {
                    return Err(format!(
                        "{}\n  (while processing alternative bytes: hex:{})",
                        e,
                        to_hex(&alt_bytes)
                    ));
                }
                return Err(e);
            }
        }

        // Round-trip expected bytes
        for alt_bytes in &input.expected_bytes {
            let result = (|| -> Result<(), String> {
                let round_tripped = typed_ev.from_bytes_drop_unrecognized(alt_bytes)?;
                let round_trip_bytes = round_tripped.to_bytes();
                let found = input
                    .expected_bytes
                    .iter()
                    .any(|exp| *exp == round_trip_bytes);
                if !found {
                    let expected_hex = input
                        .expected_bytes
                        .iter()
                        .map(|b| format!("hex:{}", to_hex(b)))
                        .collect::<Vec<_>>()
                        .join(" or ");
                    return Err(format!(
                        "expected bytes round-trip mismatch\n  got:      hex:{}\n  expected: {}",
                        to_hex(&round_trip_bytes),
                        expected_hex
                    ));
                }
                Ok(())
            })();
            if let Err(e) = result {
                return Err(format!(
                    "{}\n  (while processing expected bytes: hex:{})",
                    e,
                    to_hex(alt_bytes)
                ));
            }
        }

        // Type descriptor check
        if let Some(expected_td) = &input.expected_type_descriptor {
            let actual_td = typed_ev.type_descriptor_json();
            if actual_td != *expected_td {
                return Err(format!(
                    "type descriptor mismatch\n  actual:   {:?}\n  expected: {:?}",
                    actual_td, expected_td
                ));
            }
            // Verify round-trip of the type descriptor itself
            let parsed =
                crate::skir_client::reflection::TypeDescriptor::parse_from_json(expected_td)
                    .map_err(|e| format!("failed to parse type descriptor: {}", e))?;
            let reparsed_td = parsed.as_json();
            if reparsed_td != *expected_td {
                return Err(format!(
                    "type descriptor round-trip mismatch\n  actual:   {:?}\n  expected: {:?}",
                    reparsed_td, expected_td
                ));
            }
        }

        Ok(())
    }

    fn verify_reserialize_large_string(
        input: &Assertion_ReserializeLargeString,
    ) -> Result<(), String> {
        let s: String = "a".repeat(input.num_chars as usize);
        let ser = Serializer::string();

        // Dense JSON round-trip
        {
            let json = ser.to_json(&s, JsonFlavor::Dense);
            let round_trip = ser
                .from_json(&json, UnrecognizedValues::Drop)
                .map_err(|e| format!("large string dense JSON round-trip: {}", e))?;
            if round_trip != s {
                return Err(format!(
                    "large string dense JSON round-trip mismatch\n  actual len: {}\n  expected len: {}",
                    round_trip.len(),
                    s.len()
                ));
            }
        }

        // Readable JSON round-trip
        {
            let json = ser.to_json(&s, JsonFlavor::Readable);
            let round_trip = ser
                .from_json(&json, UnrecognizedValues::Drop)
                .map_err(|e| format!("large string readable JSON round-trip: {}", e))?;
            if round_trip != s {
                return Err(format!(
                    "large string readable JSON round-trip mismatch\n  actual len: {}\n  expected len: {}",
                    round_trip.len(),
                    s.len()
                ));
            }
        }

        // Binary round-trip + prefix check
        {
            let bytes = ser.to_bytes(&s);
            let prefix = &input.expected_byte_prefix;
            if !bytes.starts_with(prefix.as_slice()) {
                return Err(format!(
                    "large string byte prefix mismatch\n  actual:   hex:{}\n  expected prefix: hex:{}...",
                    to_hex(&bytes[..bytes.len().min(prefix.len() + 8)]),
                    to_hex(prefix)
                ));
            }
            let round_trip = ser
                .from_bytes(&bytes, UnrecognizedValues::Drop)
                .map_err(|e| format!("large string bytes round-trip: {}", e))?;
            if round_trip != s {
                return Err(format!(
                    "large string bytes round-trip mismatch\n  actual len: {}\n  expected len: {}",
                    round_trip.len(),
                    s.len()
                ));
            }
        }

        Ok(())
    }

    fn verify_reserialize_large_array(
        input: &Assertion_ReserializeLargeArray,
    ) -> Result<(), String> {
        let n = input.num_items as usize;
        let array: Vec<i32> = vec![1_i32; n];
        let ser = Serializer::array(Serializer::int32());

        let is_correct = |v: &Vec<i32>| v.len() == n && v.iter().all(|&x| x == 1);

        // Dense JSON round-trip
        {
            let json = ser.to_json(&array, JsonFlavor::Dense);
            let round_trip = ser
                .from_json(&json, UnrecognizedValues::Drop)
                .map_err(|e| format!("large array dense JSON round-trip: {}", e))?;
            if !is_correct(&round_trip) {
                return Err(format!(
                    "large array dense JSON round-trip mismatch (len={}, all_ones={})",
                    round_trip.len(),
                    round_trip.iter().all(|&x| x == 1)
                ));
            }
        }

        // Readable JSON round-trip
        {
            let json = ser.to_json(&array, JsonFlavor::Readable);
            let round_trip = ser
                .from_json(&json, UnrecognizedValues::Drop)
                .map_err(|e| format!("large array readable JSON round-trip: {}", e))?;
            if !is_correct(&round_trip) {
                return Err(format!(
                    "large array readable JSON round-trip mismatch (len={}, all_ones={})",
                    round_trip.len(),
                    round_trip.iter().all(|&x| x == 1)
                ));
            }
        }

        // Binary round-trip + prefix check
        {
            let bytes = ser.to_bytes(&array);
            let prefix = &input.expected_byte_prefix;
            if !bytes.starts_with(prefix.as_slice()) {
                return Err(format!(
                    "large array byte prefix mismatch\n  actual:   hex:{}\n  expected prefix: hex:{}...",
                    to_hex(&bytes[..bytes.len().min(prefix.len() + 8)]),
                    to_hex(prefix)
                ));
            }
            let round_trip = ser
                .from_bytes(&bytes, UnrecognizedValues::Drop)
                .map_err(|e| format!("large array bytes round-trip: {}", e))?;
            if !is_correct(&round_trip) {
                return Err(format!(
                    "large array bytes round-trip mismatch (len={}, all_ones={})",
                    round_trip.len(),
                    round_trip.iter().all(|&x| x == 1)
                ));
            }
        }

        Ok(())
    }

    // =========================================================================
    // Test entry point
    // =========================================================================

    #[test]
    fn run_golden_tests() {
        let unit_tests = unit_tests_const();
        assert!(
            !unit_tests.is_empty(),
            "UNIT_TESTS constant is empty — golden test data failed to load"
        );

        // Verify test numbers are sequential
        let first_number = unit_tests[0].test_number;
        for (i, unit_test) in unit_tests.iter().enumerate() {
            let expected_number = first_number + i as i32;
            assert_eq!(
                unit_test.test_number, expected_number,
                "Test numbers are not sequential at test #{}: found {}, expected {}",
                i, unit_test.test_number, expected_number
            );
        }

        // Run each test, collecting all failures
        let mut failures: Vec<(i32, String)> = Vec::new();
        for unit_test in unit_tests {
            if let Err(e) = verify_assertion(&unit_test.assertion) {
                failures.push((
                    unit_test.test_number,
                    format!("Test #{}: {}", unit_test.test_number, e),
                ));
            }
        }

        if !failures.is_empty() {
            let msg = failures
                .iter()
                .map(|(_, msg)| msg.as_str())
                .collect::<Vec<_>>()
                .join("\n\n");
            panic!("{} golden test(s) failed:\n\n{}", failures.len(), msg);
        }
    }
}
