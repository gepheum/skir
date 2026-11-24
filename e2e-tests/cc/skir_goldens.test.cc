#include <gtest/gtest.h>

#include <memory>
#include <string>
#include <vector>

#include "absl/status/status.h"
#include "absl/status/statusor.h"
#include "absl/strings/escaping.h"
#include "absl/strings/str_cat.h"
#include "absl/strings/string_view.h"
#include "absl/time/time.h"
#include "absl/types/optional.h"
#include "skir.h"
#include "skirout/@gepheum/skir-golden-tests/goldens.h"

namespace {

using ::skirout_external_gepheum_skir_golden_tests_goldens::Assertion;
using ::skirout_external_gepheum_skir_golden_tests_goldens::BytesExpression;
using ::skirout_external_gepheum_skir_golden_tests_goldens::StringExpression;
using ::skirout_external_gepheum_skir_golden_tests_goldens::UnitTest;

class TypedValue {
public:
  virtual ~TypedValue() = default;

  virtual std::string ToDenseJson() const = 0;
  virtual std::string ToReadableJson() const = 0;
  virtual skir::ByteString ToBytes() const = 0;
  virtual absl::StatusOr<std::unique_ptr<TypedValue>>
  RoundTripDenseJson() const = 0;
  virtual absl::StatusOr<std::unique_ptr<TypedValue>>
  RoundTripReadableJson() const = 0;
  virtual absl::StatusOr<std::unique_ptr<TypedValue>>
  RoundTripBytes() const = 0;

  virtual void CheckParse(absl::string_view bytes_or_json) const = 0;

  virtual const skir::reflection::TypeDescriptor &type_descriptor() const = 0;
};

template <typename T> class TypedValueImpl : public TypedValue {
public:
  explicit TypedValueImpl(const T &value) : value_(value) {}

  std::string ToDenseJson() const override { return skir::ToDenseJson(value_); }

  std::string ToReadableJson() const override {
    return skir::ToReadableJson(value_);
  }

  skir::ByteString ToBytes() const override { return skir::ToBytes(value_); }

  absl::StatusOr<std::unique_ptr<TypedValue>>
  RoundTripDenseJson() const override {
    const absl::StatusOr<T> parse_result = skir::Parse<T>(ToDenseJson());
    if (!parse_result.ok()) {
      return parse_result.status();
    }
    return std::make_unique<TypedValueImpl<T>>(*parse_result);
  }

  absl::StatusOr<std::unique_ptr<TypedValue>>
  RoundTripReadableJson() const override {
    const absl::StatusOr<T> parse_result = skir::Parse<T>(ToReadableJson());
    if (!parse_result.ok()) {
      return parse_result.status();
    }
    return std::make_unique<TypedValueImpl<T>>(*parse_result);
  }

  absl::StatusOr<std::unique_ptr<TypedValue>> RoundTripBytes() const override {
    const absl::StatusOr<T> parse_result =
        skir::Parse<T>(ToBytes().as_string());
    if (!parse_result.ok()) {
      return parse_result.status();
    }
    return std::make_unique<TypedValueImpl<T>>(*parse_result);
  }

  void CheckParse(absl::string_view bytes_or_json) const override {
    const absl::StatusOr<T> parse_result = skir::Parse<T>(bytes_or_json);
    EXPECT_EQ(parse_result.status(), absl::OkStatus());
    if (!parse_result.ok()) {
      return;
    }
    EXPECT_EQ(*parse_result, value_);
  }

  const skir::reflection::TypeDescriptor &type_descriptor() const override {
    return skir::reflection::GetTypeDescriptor<T>();
  }

private:
  T value_;
};

absl::StatusOr<std::string> EvalStringExpression(const StringExpression &expr);

absl::StatusOr<skir::ByteString>
EvalBytesExpression(const BytesExpression &expr);

absl::StatusOr<std::unique_ptr<TypedValue>> EvalTypedValue(
    const skirout_external_gepheum_skir_golden_tests_goldens::TypedValue
        &typed_value) {
  switch (typed_value.kind()) {
  case skirout_external_gepheum_skir_golden_tests_goldens::TypedValue::
      kind_type::kBoolWrapper:
    return std::make_unique<TypedValueImpl<bool>>(typed_value.as_bool());
  case skirout_external_gepheum_skir_golden_tests_goldens::TypedValue::
      kind_type::kInt32Wrapper:
    return std::make_unique<TypedValueImpl<int32_t>>(typed_value.as_int32());
  case skirout_external_gepheum_skir_golden_tests_goldens::TypedValue::
      kind_type::kInt64Wrapper:
    return std::make_unique<TypedValueImpl<int64_t>>(typed_value.as_int64());
  case skirout_external_gepheum_skir_golden_tests_goldens::TypedValue::
      kind_type::kHash64Wrapper:
    return std::make_unique<TypedValueImpl<uint64_t>>(typed_value.as_hash64());
  case skirout_external_gepheum_skir_golden_tests_goldens::TypedValue::
      kind_type::kFloat32Wrapper:
    return std::make_unique<TypedValueImpl<float>>(typed_value.as_float32());
  case skirout_external_gepheum_skir_golden_tests_goldens::TypedValue::
      kind_type::kFloat64Wrapper:
    return std::make_unique<TypedValueImpl<double>>(typed_value.as_float64());
  case skirout_external_gepheum_skir_golden_tests_goldens::TypedValue::
      kind_type::kTimestampWrapper:
    return std::make_unique<TypedValueImpl<absl::Time>>(
        typed_value.as_timestamp());
  case skirout_external_gepheum_skir_golden_tests_goldens::TypedValue::
      kind_type::kStringWrapper:
    return std::make_unique<TypedValueImpl<std::string>>(
        typed_value.as_string());
  case skirout_external_gepheum_skir_golden_tests_goldens::TypedValue::
      kind_type::kBytesWrapper:
    return std::make_unique<TypedValueImpl<skir::ByteString>>(
        skir::ByteString(typed_value.as_bytes()));
  case skirout_external_gepheum_skir_golden_tests_goldens::TypedValue::
      kind_type::kBoolOptionalWrapper:
    return std::make_unique<TypedValueImpl<absl::optional<bool>>>(
        typed_value.as_bool_optional());
  case skirout_external_gepheum_skir_golden_tests_goldens::TypedValue::
      kind_type::kIntsWrapper:
    return std::make_unique<TypedValueImpl<std::vector<int32_t>>>(
        typed_value.as_ints());
  case skirout_external_gepheum_skir_golden_tests_goldens::TypedValue::
      kind_type::kPointWrapper:
    return std::make_unique<TypedValueImpl<
        skirout_external_gepheum_skir_golden_tests_goldens::Point>>(
        typed_value.as_point());
  case skirout_external_gepheum_skir_golden_tests_goldens::TypedValue::
      kind_type::kColorWrapper:
    return std::make_unique<TypedValueImpl<
        skirout_external_gepheum_skir_golden_tests_goldens::Color>>(
        typed_value.as_color());
  case skirout_external_gepheum_skir_golden_tests_goldens::TypedValue::
      kind_type::kMyEnumWrapper:
    return std::make_unique<TypedValueImpl<
        skirout_external_gepheum_skir_golden_tests_goldens::MyEnum>>(
        typed_value.as_my_enum());
  case skirout_external_gepheum_skir_golden_tests_goldens::TypedValue::
      kind_type::kEnumAWrapper:
    return std::make_unique<TypedValueImpl<
        skirout_external_gepheum_skir_golden_tests_goldens::EnumA>>(
        typed_value.as_enum_a());
  case skirout_external_gepheum_skir_golden_tests_goldens::TypedValue::
      kind_type::kEnumBWrapper:
    return std::make_unique<TypedValueImpl<
        skirout_external_gepheum_skir_golden_tests_goldens::EnumB>>(
        typed_value.as_enum_b());
  case skirout_external_gepheum_skir_golden_tests_goldens::TypedValue::
      kind_type::kKeyedArraysWrapper:
    return std::make_unique<TypedValueImpl<
        skirout_external_gepheum_skir_golden_tests_goldens::KeyedArrays>>(
        typed_value.as_keyed_arrays());
  case skirout_external_gepheum_skir_golden_tests_goldens::TypedValue::
      kind_type::kRecStructWrapper:
    return std::make_unique<TypedValueImpl<
        skirout_external_gepheum_skir_golden_tests_goldens::RecStruct>>(
        typed_value.as_rec_struct());
  case skirout_external_gepheum_skir_golden_tests_goldens::TypedValue::
      kind_type::kRecEnumWrapper:
    return std::make_unique<TypedValueImpl<
        skirout_external_gepheum_skir_golden_tests_goldens::RecEnum>>(
        typed_value.as_rec_enum());
  case skirout_external_gepheum_skir_golden_tests_goldens::TypedValue::
      kind_type::kRoundTripDenseJsonWrapper: {
    const absl::StatusOr<std::unique_ptr<TypedValue>> other =
        EvalTypedValue(typed_value.as_round_trip_dense_json());
    if (!other.ok()) {
      return other.status();
    }
    return (*other)->RoundTripDenseJson();
  }
  case skirout_external_gepheum_skir_golden_tests_goldens::TypedValue::
      kind_type::kRoundTripReadableJsonWrapper: {
    const absl::StatusOr<std::unique_ptr<TypedValue>> other =
        EvalTypedValue(typed_value.as_round_trip_readable_json());
    if (!other.ok()) {
      return other.status();
    }
    return (*other)->RoundTripReadableJson();
  }
  case skirout_external_gepheum_skir_golden_tests_goldens::TypedValue::
      kind_type::kRoundTripBytesWrapper: {
    const absl::StatusOr<std::unique_ptr<TypedValue>> other =
        EvalTypedValue(typed_value.as_round_trip_bytes());
    if (!other.ok()) {
      return other.status();
    }
    return (*other)->RoundTripBytes();
  }
  case skirout_external_gepheum_skir_golden_tests_goldens::TypedValue::
      kind_type::kPointFromJsonKeepUnrecognizedWrapper: {
    const absl::StatusOr<std::string> string_expression = EvalStringExpression(
        typed_value.as_point_from_json_keep_unrecognized());
    if (!string_expression.ok()) {
      return string_expression.status();
    }
    const absl::StatusOr<
        skirout_external_gepheum_skir_golden_tests_goldens::Point>
        point = skir::Parse<
            skirout_external_gepheum_skir_golden_tests_goldens::Point>(
            *string_expression, skir::UnrecognizedValuesPolicy::kKeep);
    if (!point.ok()) {
      return point.status();
    }
    return std::make_unique<TypedValueImpl<
        skirout_external_gepheum_skir_golden_tests_goldens::Point>>(*point);
  }
  case skirout_external_gepheum_skir_golden_tests_goldens::TypedValue::
      kind_type::kPointFromJsonDropUnrecognizedWrapper: {
    const absl::StatusOr<std::string> string_expression = EvalStringExpression(
        typed_value.as_point_from_json_drop_unrecognized());
    if (!string_expression.ok()) {
      return string_expression.status();
    }
    const absl::StatusOr<
        skirout_external_gepheum_skir_golden_tests_goldens::Point>
        point = skir::Parse<
            skirout_external_gepheum_skir_golden_tests_goldens::Point>(
            *string_expression, skir::UnrecognizedValuesPolicy::kDrop);
    if (!point.ok()) {
      return point.status();
    }
    return std::make_unique<TypedValueImpl<
        skirout_external_gepheum_skir_golden_tests_goldens::Point>>(*point);
  }
  case skirout_external_gepheum_skir_golden_tests_goldens::TypedValue::
      kind_type::kPointFromBytesKeepUnrecognizedWrapper: {
    const absl::StatusOr<skir::ByteString> bytes_expression =
        EvalBytesExpression(
            typed_value.as_point_from_bytes_keep_unrecognized());
    if (!bytes_expression.ok()) {
      return bytes_expression.status();
    }
    const absl::StatusOr<
        skirout_external_gepheum_skir_golden_tests_goldens::Point>
        point = skir::Parse<
            skirout_external_gepheum_skir_golden_tests_goldens::Point>(
            bytes_expression->as_string(),
            skir::UnrecognizedValuesPolicy::kKeep);
    if (!point.ok()) {
      return point.status();
    }
    return std::make_unique<TypedValueImpl<
        skirout_external_gepheum_skir_golden_tests_goldens::Point>>(*point);
  }
  case skirout_external_gepheum_skir_golden_tests_goldens::TypedValue::
      kind_type::kPointFromBytesDropUnrecognizedWrapper: {
    const absl::StatusOr<skir::ByteString> bytes_expression =
        EvalBytesExpression(
            typed_value.as_point_from_bytes_drop_unrecognized());
    if (!bytes_expression.ok()) {
      return bytes_expression.status();
    }
    const absl::StatusOr<
        skirout_external_gepheum_skir_golden_tests_goldens::Point>
        point = skir::Parse<
            skirout_external_gepheum_skir_golden_tests_goldens::Point>(
            bytes_expression->as_string(),
            skir::UnrecognizedValuesPolicy::kDrop);
    if (!point.ok()) {
      return point.status();
    }
    return std::make_unique<TypedValueImpl<
        skirout_external_gepheum_skir_golden_tests_goldens::Point>>(*point);
  }
  case skirout_external_gepheum_skir_golden_tests_goldens::TypedValue::
      kind_type::kColorFromJsonKeepUnrecognizedWrapper: {
    const absl::StatusOr<std::string> string_expression = EvalStringExpression(
        typed_value.as_color_from_json_keep_unrecognized());
    if (!string_expression.ok()) {
      return string_expression.status();
    }
    const absl::StatusOr<
        skirout_external_gepheum_skir_golden_tests_goldens::Color>
        color = skir::Parse<
            skirout_external_gepheum_skir_golden_tests_goldens::Color>(
            *string_expression, skir::UnrecognizedValuesPolicy::kKeep);
    if (!color.ok()) {
      return color.status();
    }
    return std::make_unique<TypedValueImpl<
        skirout_external_gepheum_skir_golden_tests_goldens::Color>>(*color);
  }
  case skirout_external_gepheum_skir_golden_tests_goldens::TypedValue::
      kind_type::kColorFromJsonDropUnrecognizedWrapper: {
    const absl::StatusOr<std::string> string_expression = EvalStringExpression(
        typed_value.as_color_from_json_drop_unrecognized());
    if (!string_expression.ok()) {
      return string_expression.status();
    }
    const absl::StatusOr<
        skirout_external_gepheum_skir_golden_tests_goldens::Color>
        color = skir::Parse<
            skirout_external_gepheum_skir_golden_tests_goldens::Color>(
            *string_expression, skir::UnrecognizedValuesPolicy::kDrop);
    if (!color.ok()) {
      return color.status();
    }
    return std::make_unique<TypedValueImpl<
        skirout_external_gepheum_skir_golden_tests_goldens::Color>>(*color);
  }
  case skirout_external_gepheum_skir_golden_tests_goldens::TypedValue::
      kind_type::kColorFromBytesKeepUnrecognizedWrapper: {
    const absl::StatusOr<skir::ByteString> bytes_expression =
        EvalBytesExpression(
            typed_value.as_color_from_bytes_keep_unrecognized());
    if (!bytes_expression.ok()) {
      return bytes_expression.status();
    }
    const absl::StatusOr<
        skirout_external_gepheum_skir_golden_tests_goldens::Color>
        color = skir::Parse<
            skirout_external_gepheum_skir_golden_tests_goldens::Color>(
            bytes_expression->as_string(),
            skir::UnrecognizedValuesPolicy::kKeep);
    if (!color.ok()) {
      return color.status();
    }
    return std::make_unique<TypedValueImpl<
        skirout_external_gepheum_skir_golden_tests_goldens::Color>>(*color);
  }
  case skirout_external_gepheum_skir_golden_tests_goldens::TypedValue::
      kind_type::kColorFromBytesDropUnrecognizedWrapper: {
    const absl::StatusOr<skir::ByteString> bytes_expression =
        EvalBytesExpression(
            typed_value.as_color_from_bytes_drop_unrecognized());
    if (!bytes_expression.ok()) {
      return bytes_expression.status();
    }
    const absl::StatusOr<
        skirout_external_gepheum_skir_golden_tests_goldens::Color>
        color = skir::Parse<
            skirout_external_gepheum_skir_golden_tests_goldens::Color>(
            bytes_expression->as_string(),
            skir::UnrecognizedValuesPolicy::kDrop);
    if (!color.ok()) {
      return color.status();
    }
    return std::make_unique<TypedValueImpl<
        skirout_external_gepheum_skir_golden_tests_goldens::Color>>(*color);
  }
  case skirout_external_gepheum_skir_golden_tests_goldens::TypedValue::
      kind_type::kMyEnumFromJsonKeepUnrecognizedWrapper: {
    const absl::StatusOr<std::string> string_expression = EvalStringExpression(
        typed_value.as_my_enum_from_json_keep_unrecognized());
    if (!string_expression.ok()) {
      return string_expression.status();
    }
    const absl::StatusOr<
        skirout_external_gepheum_skir_golden_tests_goldens::MyEnum>
        my_enum = skir::Parse<
            skirout_external_gepheum_skir_golden_tests_goldens::MyEnum>(
            *string_expression, skir::UnrecognizedValuesPolicy::kKeep);
    if (!my_enum.ok()) {
      return my_enum.status();
    }
    return std::make_unique<TypedValueImpl<
        skirout_external_gepheum_skir_golden_tests_goldens::MyEnum>>(*my_enum);
  }
  case skirout_external_gepheum_skir_golden_tests_goldens::TypedValue::
      kind_type::kMyEnumFromJsonDropUnrecognizedWrapper: {
    const absl::StatusOr<std::string> string_expression = EvalStringExpression(
        typed_value.as_my_enum_from_json_drop_unrecognized());
    if (!string_expression.ok()) {
      return string_expression.status();
    }
    const absl::StatusOr<
        skirout_external_gepheum_skir_golden_tests_goldens::MyEnum>
        my_enum = skir::Parse<
            skirout_external_gepheum_skir_golden_tests_goldens::MyEnum>(
            *string_expression, skir::UnrecognizedValuesPolicy::kDrop);
    if (!my_enum.ok()) {
      return my_enum.status();
    }
    return std::make_unique<TypedValueImpl<
        skirout_external_gepheum_skir_golden_tests_goldens::MyEnum>>(*my_enum);
  }
  case skirout_external_gepheum_skir_golden_tests_goldens::TypedValue::
      kind_type::kMyEnumFromBytesKeepUnrecognizedWrapper: {
    const absl::StatusOr<skir::ByteString> bytes_expression =
        EvalBytesExpression(
            typed_value.as_my_enum_from_bytes_keep_unrecognized());
    if (!bytes_expression.ok()) {
      return bytes_expression.status();
    }
    const absl::StatusOr<
        skirout_external_gepheum_skir_golden_tests_goldens::MyEnum>
        my_enum = skir::Parse<
            skirout_external_gepheum_skir_golden_tests_goldens::MyEnum>(
            bytes_expression->as_string(),
            skir::UnrecognizedValuesPolicy::kKeep);
    if (!my_enum.ok()) {
      return my_enum.status();
    }
    return std::make_unique<TypedValueImpl<
        skirout_external_gepheum_skir_golden_tests_goldens::MyEnum>>(*my_enum);
  }
  case skirout_external_gepheum_skir_golden_tests_goldens::TypedValue::
      kind_type::kMyEnumFromBytesDropUnrecognizedWrapper: {
    const absl::StatusOr<skir::ByteString> bytes_expression =
        EvalBytesExpression(
            typed_value.as_my_enum_from_bytes_drop_unrecognized());
    if (!bytes_expression.ok()) {
      return bytes_expression.status();
    }
    const absl::StatusOr<
        skirout_external_gepheum_skir_golden_tests_goldens::MyEnum>
        my_enum = skir::Parse<
            skirout_external_gepheum_skir_golden_tests_goldens::MyEnum>(
            bytes_expression->as_string(),
            skir::UnrecognizedValuesPolicy::kDrop);
    if (!my_enum.ok()) {
      return my_enum.status();
    }
    return std::make_unique<TypedValueImpl<
        skirout_external_gepheum_skir_golden_tests_goldens::MyEnum>>(*my_enum);
  }
  case skirout_external_gepheum_skir_golden_tests_goldens::TypedValue::
      kind_type::kEnumAFromJsonKeepUnrecognizedWrapper: {
    const absl::StatusOr<std::string> string_expression = EvalStringExpression(
        typed_value.as_enum_a_from_json_keep_unrecognized());
    if (!string_expression.ok()) {
      return string_expression.status();
    }
    const absl::StatusOr<
        skirout_external_gepheum_skir_golden_tests_goldens::EnumA>
        enum_a = skir::Parse<
            skirout_external_gepheum_skir_golden_tests_goldens::EnumA>(
            *string_expression, skir::UnrecognizedValuesPolicy::kKeep);
    if (!enum_a.ok()) {
      return enum_a.status();
    }
    return std::make_unique<TypedValueImpl<
        skirout_external_gepheum_skir_golden_tests_goldens::EnumA>>(*enum_a);
  }
  case skirout_external_gepheum_skir_golden_tests_goldens::TypedValue::
      kind_type::kEnumAFromJsonDropUnrecognizedWrapper: {
    const absl::StatusOr<std::string> string_expression = EvalStringExpression(
        typed_value.as_enum_a_from_json_drop_unrecognized());
    if (!string_expression.ok()) {
      return string_expression.status();
    }
    const absl::StatusOr<
        skirout_external_gepheum_skir_golden_tests_goldens::EnumA>
        enum_a = skir::Parse<
            skirout_external_gepheum_skir_golden_tests_goldens::EnumA>(
            *string_expression, skir::UnrecognizedValuesPolicy::kDrop);
    if (!enum_a.ok()) {
      return enum_a.status();
    }
    return std::make_unique<TypedValueImpl<
        skirout_external_gepheum_skir_golden_tests_goldens::EnumA>>(*enum_a);
  }
  case skirout_external_gepheum_skir_golden_tests_goldens::TypedValue::
      kind_type::kEnumAFromBytesKeepUnrecognizedWrapper: {
    const absl::StatusOr<skir::ByteString> bytes_expression =
        EvalBytesExpression(
            typed_value.as_enum_a_from_bytes_keep_unrecognized());
    if (!bytes_expression.ok()) {
      return bytes_expression.status();
    }
    const absl::StatusOr<
        skirout_external_gepheum_skir_golden_tests_goldens::EnumA>
        enum_a = skir::Parse<
            skirout_external_gepheum_skir_golden_tests_goldens::EnumA>(
            bytes_expression->as_string(),
            skir::UnrecognizedValuesPolicy::kKeep);
    if (!enum_a.ok()) {
      return enum_a.status();
    }
    return std::make_unique<TypedValueImpl<
        skirout_external_gepheum_skir_golden_tests_goldens::EnumA>>(*enum_a);
  }
  case skirout_external_gepheum_skir_golden_tests_goldens::TypedValue::
      kind_type::kEnumAFromBytesDropUnrecognizedWrapper: {
    const absl::StatusOr<skir::ByteString> bytes_expression =
        EvalBytesExpression(
            typed_value.as_enum_a_from_bytes_drop_unrecognized());
    if (!bytes_expression.ok()) {
      return bytes_expression.status();
    }
    const absl::StatusOr<
        skirout_external_gepheum_skir_golden_tests_goldens::EnumA>
        enum_a = skir::Parse<
            skirout_external_gepheum_skir_golden_tests_goldens::EnumA>(
            bytes_expression->as_string(),
            skir::UnrecognizedValuesPolicy::kDrop);
    if (!enum_a.ok()) {
      return enum_a.status();
    }
    return std::make_unique<TypedValueImpl<
        skirout_external_gepheum_skir_golden_tests_goldens::EnumA>>(*enum_a);
  }
  case skirout_external_gepheum_skir_golden_tests_goldens::TypedValue::
      kind_type::kEnumBFromJsonKeepUnrecognizedWrapper: {
    const absl::StatusOr<std::string> string_expression = EvalStringExpression(
        typed_value.as_enum_b_from_json_keep_unrecognized());
    if (!string_expression.ok()) {
      return string_expression.status();
    }
    const absl::StatusOr<
        skirout_external_gepheum_skir_golden_tests_goldens::EnumB>
        enum_b = skir::Parse<
            skirout_external_gepheum_skir_golden_tests_goldens::EnumB>(
            *string_expression, skir::UnrecognizedValuesPolicy::kKeep);
    if (!enum_b.ok()) {
      return enum_b.status();
    }
    return std::make_unique<TypedValueImpl<
        skirout_external_gepheum_skir_golden_tests_goldens::EnumB>>(*enum_b);
  }
  case skirout_external_gepheum_skir_golden_tests_goldens::TypedValue::
      kind_type::kEnumBFromJsonDropUnrecognizedWrapper: {
    const absl::StatusOr<std::string> string_expression = EvalStringExpression(
        typed_value.as_enum_b_from_json_drop_unrecognized());
    if (!string_expression.ok()) {
      return string_expression.status();
    }
    const absl::StatusOr<
        skirout_external_gepheum_skir_golden_tests_goldens::EnumB>
        enum_b = skir::Parse<
            skirout_external_gepheum_skir_golden_tests_goldens::EnumB>(
            *string_expression, skir::UnrecognizedValuesPolicy::kDrop);
    if (!enum_b.ok()) {
      return enum_b.status();
    }
    return std::make_unique<TypedValueImpl<
        skirout_external_gepheum_skir_golden_tests_goldens::EnumB>>(*enum_b);
  }
  case skirout_external_gepheum_skir_golden_tests_goldens::TypedValue::
      kind_type::kEnumBFromBytesKeepUnrecognizedWrapper: {
    const absl::StatusOr<skir::ByteString> bytes_expression =
        EvalBytesExpression(
            typed_value.as_enum_b_from_bytes_keep_unrecognized());
    if (!bytes_expression.ok()) {
      return bytes_expression.status();
    }
    const absl::StatusOr<
        skirout_external_gepheum_skir_golden_tests_goldens::EnumB>
        enum_b = skir::Parse<
            skirout_external_gepheum_skir_golden_tests_goldens::EnumB>(
            bytes_expression->as_string(),
            skir::UnrecognizedValuesPolicy::kKeep);
    if (!enum_b.ok()) {
      return enum_b.status();
    }
    return std::make_unique<TypedValueImpl<
        skirout_external_gepheum_skir_golden_tests_goldens::EnumB>>(*enum_b);
  }
  case skirout_external_gepheum_skir_golden_tests_goldens::TypedValue::
      kind_type::kEnumBFromBytesDropUnrecognizedWrapper: {
    const absl::StatusOr<skir::ByteString> bytes_expression =
        EvalBytesExpression(
            typed_value.as_enum_b_from_bytes_drop_unrecognized());
    if (!bytes_expression.ok()) {
      return bytes_expression.status();
    }
    const absl::StatusOr<
        skirout_external_gepheum_skir_golden_tests_goldens::EnumB>
        enum_b = skir::Parse<
            skirout_external_gepheum_skir_golden_tests_goldens::EnumB>(
            bytes_expression->as_string(),
            skir::UnrecognizedValuesPolicy::kDrop);
    if (!enum_b.ok()) {
      return enum_b.status();
    }
    return std::make_unique<TypedValueImpl<
        skirout_external_gepheum_skir_golden_tests_goldens::EnumB>>(*enum_b);
  }
  case skirout_external_gepheum_skir_golden_tests_goldens::TypedValue::
      kind_type::kUnknown:
    return absl::InvalidArgumentError("Unknown TypedValue kind");
  }

  return absl::InvalidArgumentError("Unhandled TypedValue kind");
}

absl::StatusOr<std::string> EvalStringExpression(const StringExpression &expr) {
  switch (expr.kind()) {
  case StringExpression::kind_type::kLiteralWrapper:
    return expr.as_literal();
  case StringExpression::kind_type::kToDenseJsonWrapper: {
    const absl::StatusOr<std::unique_ptr<TypedValue>> typed_value =
        EvalTypedValue(expr.as_to_dense_json());
    if (!typed_value.ok()) {
      return typed_value.status();
    }
    return (*typed_value)->ToDenseJson();
  }
  case StringExpression::kind_type::kToReadableJsonWrapper: {
    const absl::StatusOr<std::unique_ptr<TypedValue>> typed_value =
        EvalTypedValue(expr.as_to_readable_json());
    if (!typed_value.ok()) {
      return typed_value.status();
    }
    return (*typed_value)->ToReadableJson();
  }
  case StringExpression::kind_type::kUnknown: {
    return absl::InvalidArgumentError("Unknown StringExpression kind");
  }
  }
}

// Helper function to evaluate a BytesExpression
absl::StatusOr<skir::ByteString>
EvalBytesExpression(const BytesExpression &expr) {
  switch (expr.kind()) {
  case BytesExpression::kind_type::kLiteralWrapper:
    return expr.as_literal();
  case BytesExpression::kind_type::kToBytesWrapper: {
    const absl::StatusOr<std::unique_ptr<TypedValue>> typed_value =
        EvalTypedValue(expr.as_to_bytes());
    if (!typed_value.ok()) {
      return typed_value.status();
    }
    return (*typed_value)->ToBytes();
  }
  case BytesExpression::kind_type::kUnknown: {
    return absl::InvalidArgumentError("Unknown BytesExpression kind");
  }
  }
}

// Helper to execute ReserializeValue assertion
void ExecuteReserializeValue(const Assertion::ReserializeValue &assertion) {
  const absl::StatusOr<std::unique_ptr<TypedValue>> typed_value =
      EvalTypedValue(assertion.value);
  EXPECT_EQ(typed_value.status(), absl::OkStatus());
  if (!typed_value.ok()) {
    return;
  }

  // Check dense JSON serialization
  {
    const std::string actual_dense_json = (*typed_value)->ToDenseJson();
    bool dense_json_matched = false;
    for (const auto &expected_json : assertion.expected_dense_json) {
      if (actual_dense_json == expected_json) {
        dense_json_matched = true;
        break;
      }
    }
    EXPECT_TRUE(dense_json_matched)
        << "Dense JSON mismatch. Actual: " << actual_dense_json
        << ", Expected one of: " << assertion.expected_dense_json.size()
        << " values";
  }

  // Check readable JSON serialization
  {
    const std::string actual_readable_json = (*typed_value)->ToReadableJson();
    bool readable_json_matched = false;
    for (const auto &expected_json : assertion.expected_readable_json) {
      if (actual_readable_json == expected_json) {
        readable_json_matched = true;
        break;
      }
    }
    EXPECT_TRUE(readable_json_matched)
        << "Readable JSON mismatch. Actual: " << actual_readable_json
        << ", Expected one of: " << assertion.expected_readable_json.size()
        << " values";
  }

  // Check deserialization
  {
    for (const auto &expected_json : assertion.expected_dense_json) {
      (*typed_value)->CheckParse(expected_json);
    }
    for (const auto &expected_json : assertion.expected_readable_json) {
      (*typed_value)->CheckParse(expected_json);
    }
    for (const auto &expected_bytes : assertion.expected_bytes) {
      (*typed_value)->CheckParse(expected_bytes.as_string());
    }
    for (const auto &alternative_json : assertion.alternative_jsons) {
      const absl::StatusOr<std::string> json =
          EvalStringExpression(alternative_json);
      EXPECT_EQ(json.status(), absl::OkStatus());
      if (json.ok()) {
        (*typed_value)->CheckParse(*json);
      }
    }
    for (const auto &alternative_bytes : assertion.alternative_bytes) {
      const absl::StatusOr<skir::ByteString> bytes =
          EvalBytesExpression(alternative_bytes);
      EXPECT_EQ(bytes.status(), absl::OkStatus());
      if (bytes.ok()) {
        (*typed_value)->CheckParse(bytes->as_string());
      }
    }
  }

  // Check bytes serialization
  {
    const skir::ByteString actual_bytes = (*typed_value)->ToBytes();
    bool bytes_matched = false;
    for (const auto &expected_bytes : assertion.expected_bytes) {
      if (actual_bytes == expected_bytes) {
        bytes_matched = true;
        break;
      }
    }
    EXPECT_TRUE(bytes_matched)
        << "Bytes serialization mismatch; actual: "
        << absl::BytesToHexString(actual_bytes.as_string());
  }

  // Make sure the encoded value can be skipped.
  for (const auto &expected_bytes : assertion.expected_bytes) {
    const skir::ByteString bytes = skir::ByteString(
        absl::StrCat("skir\xF8", expected_bytes.as_string().substr(4), "\x01"));
    const absl::StatusOr<
        skirout_external_gepheum_skir_golden_tests_goldens::Point>
        point = skir::Parse<
            skirout_external_gepheum_skir_golden_tests_goldens::Point>(
            bytes.as_string());
    EXPECT_EQ(point.status(), absl::OkStatus());
    if (point.ok()) {
      EXPECT_EQ(point->x, 1)
          << "Failed to skip value; input: "
          << absl::BytesToHexString(expected_bytes.as_string());
    }
  }

  // Check the type descriptor
  if (assertion.expected_type_descriptor.has_value()) {
    const skir::reflection::TypeDescriptor &actual_type_descriptor =
        (*typed_value)->type_descriptor();
    EXPECT_EQ(actual_type_descriptor.AsJson(),
              *assertion.expected_type_descriptor);
    const absl::StatusOr<skir::reflection::TypeDescriptor>
        parsed_type_descriptor = skir::reflection::TypeDescriptor::FromJson(
            *assertion.expected_type_descriptor);
    EXPECT_EQ(parsed_type_descriptor.status(), absl::OkStatus());
    if (parsed_type_descriptor.ok()) {
      EXPECT_EQ(parsed_type_descriptor->AsJson(),
                *assertion.expected_type_descriptor);
    }
  }
}

// Helper to execute ReserializeLargeString assertion
void ExecuteReserializeLargeString(
    const Assertion::ReserializeLargeString &assertion) {
  // Create a large string with num_chars characters
  const std::string large_string(assertion.num_chars, 'a');

  // Serialize to bytes
  const skir::ByteString serialized = skir::ToBytes(large_string);

  // Check that it starts with the expected prefix
  const skir::ByteString &expected_prefix = assertion.expected_byte_prefix;

  EXPECT_GE(serialized.as_string().length(),
            expected_prefix.as_string().length())
      << "Serialized bytes too short";

  const std::string actual_prefix = std::string(
      serialized.as_string().substr(0, expected_prefix.as_string().length()));
  EXPECT_EQ(actual_prefix, expected_prefix.as_string())
      << "Prefix mismatch for large string";
}

// Helper to execute ReserializeLargeArray assertion
void ExecuteReserializeLargeArray(
    const Assertion::ReserializeLargeArray &assertion) {
  // Create a large array with num_items elements
  std::vector<int32_t> large_array(assertion.num_items, 0);

  // Serialize to bytes
  skir::ByteString serialized = skir::ToBytes(large_array);

  // Check that it starts with the expected prefix
  const skir::ByteString expected_prefix = assertion.expected_byte_prefix;

  EXPECT_GE(serialized.as_string().length(),
            expected_prefix.as_string().length())
      << "Serialized bytes too short";

  std::string actual_prefix = std::string(
      serialized.as_string().substr(0, expected_prefix.as_string().length()));
  EXPECT_EQ(actual_prefix, expected_prefix.as_string())
      << "Prefix mismatch for large array";
}

void ExecuteBytesEqual(const Assertion::BytesEqual &assertion) {
  const absl::StatusOr<skir::ByteString> actual =
      EvalBytesExpression(assertion.actual);
  const absl::StatusOr<skir::ByteString> expected =
      EvalBytesExpression(assertion.expected);
  EXPECT_EQ(actual.status(), absl::OkStatus());
  EXPECT_EQ(expected.status(), absl::OkStatus());
  if (actual.ok() && expected.ok()) {
    EXPECT_EQ(*actual, *expected) << "Bytes not equal";
  }
}

void ExecuteBytesIn(const Assertion::BytesIn &assertion) {
  const absl::StatusOr<skir::ByteString> actual =
      EvalBytesExpression(assertion.actual);
  EXPECT_EQ(actual.status(), absl::OkStatus());
  if (!actual.ok()) {
    return;
  }
  bool found = false;
  for (const auto &expected : assertion.expected) {
    if (*actual == expected) {
      found = true;
      break;
    }
  }
  EXPECT_TRUE(found) << "Bytes not in expected set";
}

void ExecuteStringEqual(const Assertion::StringEqual &assertion) {
  const absl::StatusOr<std::string> actual =
      EvalStringExpression(assertion.actual);
  const absl::StatusOr<std::string> expected =
      EvalStringExpression(assertion.expected);
  EXPECT_EQ(actual.status(), absl::OkStatus());
  EXPECT_EQ(expected.status(), absl::OkStatus());
  if (actual.ok() && expected.ok()) {
    EXPECT_EQ(*actual, *expected) << "Strings not equal";
  }
}

void ExecuteStringIn(const Assertion::StringIn &assertion) {
  const absl::StatusOr<std::string> actual =
      EvalStringExpression(assertion.actual);
  EXPECT_EQ(actual.status(), absl::OkStatus());
  if (!actual.ok()) {
    return;
  }
  bool found = false;
  for (const auto &expected : assertion.expected) {
    if (*actual == expected) {
      found = true;
      break;
    }
  }
  EXPECT_TRUE(found) << "String not in expected set";
}

void ExecuteEnumAFromJsonIsConstant(
    const Assertion::EnumAFromJsonIsConstant &assertion) {
  const absl::StatusOr<std::string> actual =
      EvalStringExpression(assertion.actual);
  EXPECT_EQ(actual.status(), absl::OkStatus());
  if (!actual.ok()) {
    return;
  }
  const auto policy = assertion.keep_unrecognized
                          ? skir::UnrecognizedValuesPolicy::kKeep
                          : skir::UnrecognizedValuesPolicy::kDrop;
  const absl::StatusOr<
      skirout_external_gepheum_skir_golden_tests_goldens::EnumA>
      enum_a = skir::Parse<
          skirout_external_gepheum_skir_golden_tests_goldens::EnumA>(*actual,
                                                                     policy);
  EXPECT_EQ(enum_a.status(), absl::OkStatus());
  if (!enum_a.ok()) {
    return;
  }
  EXPECT_EQ(enum_a->kind(), skirout_external_gepheum_skir_golden_tests_goldens::
                                EnumA::kind_type::kAConst);
}

void ExecuteEnumAFromBytesIsConstant(
    const Assertion::EnumAFromBytesIsConstant &assertion) {
  const absl::StatusOr<skir::ByteString> actual =
      EvalBytesExpression(assertion.actual);
  EXPECT_EQ(actual.status(), absl::OkStatus());
  if (!actual.ok()) {
    return;
  }
  const auto policy = assertion.keep_unrecognized
                          ? skir::UnrecognizedValuesPolicy::kKeep
                          : skir::UnrecognizedValuesPolicy::kDrop;
  const absl::StatusOr<
      skirout_external_gepheum_skir_golden_tests_goldens::EnumA>
      enum_a = skir::Parse<
          skirout_external_gepheum_skir_golden_tests_goldens::EnumA>(
          actual->as_string(), policy);
  EXPECT_EQ(enum_a.status(), absl::OkStatus());
  if (!enum_a.ok()) {
    return;
  }
  EXPECT_EQ(enum_a->kind(), skirout_external_gepheum_skir_golden_tests_goldens::
                                EnumA::kind_type::kAConst);
}

void ExecuteEnumBFromJsonIsWrapperB(
    const Assertion::EnumBFromJsonIsWrapperB &assertion) {
  const absl::StatusOr<std::string> actual =
      EvalStringExpression(assertion.actual);
  EXPECT_EQ(actual.status(), absl::OkStatus());
  if (!actual.ok()) {
    return;
  }
  const auto policy = assertion.keep_unrecognized
                          ? skir::UnrecognizedValuesPolicy::kKeep
                          : skir::UnrecognizedValuesPolicy::kDrop;
  const absl::StatusOr<
      skirout_external_gepheum_skir_golden_tests_goldens::EnumB>
      enum_b = skir::Parse<
          skirout_external_gepheum_skir_golden_tests_goldens::EnumB>(*actual,
                                                                     policy);
  EXPECT_EQ(enum_b.status(), absl::OkStatus());
  if (!enum_b.ok()) {
    return;
  }
  EXPECT_TRUE(enum_b->is_b());
  if (enum_b->is_b()) {
    EXPECT_EQ(enum_b->as_b(), assertion.expected);
  }
}

void ExecuteEnumBFromBytesIsWrapperB(
    const Assertion::EnumBFromBytesIsWrapperB &assertion) {
  const absl::StatusOr<skir::ByteString> actual =
      EvalBytesExpression(assertion.actual);
  EXPECT_EQ(actual.status(), absl::OkStatus());
  if (!actual.ok()) {
    return;
  }
  const auto policy = assertion.keep_unrecognized
                          ? skir::UnrecognizedValuesPolicy::kKeep
                          : skir::UnrecognizedValuesPolicy::kDrop;
  const absl::StatusOr<
      skirout_external_gepheum_skir_golden_tests_goldens::EnumB>
      enum_b = skir::Parse<
          skirout_external_gepheum_skir_golden_tests_goldens::EnumB>(
          actual->as_string(), policy);
  EXPECT_EQ(enum_b.status(), absl::OkStatus());
  if (!enum_b.ok()) {
    return;
  }
  EXPECT_TRUE(enum_b->is_b());
  if (enum_b->is_b()) {
    EXPECT_EQ(enum_b->as_b(), assertion.expected);
  }
}

// Main test that runs all unit tests
TEST(SkirGoldensTest, AllTests) {
  const std::vector<UnitTest> &unit_tests =
      skirout_external_gepheum_skir_golden_tests_goldens::k_unit_tests();

  for (const UnitTest &test : unit_tests) {
    SCOPED_TRACE(absl::StrCat("Test number: ", test.test_number));

    const Assertion &assertion = test.assertion;

    switch (assertion.kind()) {
    case Assertion::kind_type::kReserializeValueWrapper:
      ExecuteReserializeValue(assertion.as_reserialize_value());
      break;

    case Assertion::kind_type::kReserializeLargeStringWrapper:
      ExecuteReserializeLargeString(assertion.as_reserialize_large_string());
      break;

    case Assertion::kind_type::kReserializeLargeArrayWrapper:
      ExecuteReserializeLargeArray(assertion.as_reserialize_large_array());
      break;

    case Assertion::kind_type::kBytesEqualWrapper:
      ExecuteBytesEqual(assertion.as_bytes_equal());
      break;

    case Assertion::kind_type::kBytesInWrapper:
      ExecuteBytesIn(assertion.as_bytes_in());
      break;

    case Assertion::kind_type::kStringEqualWrapper:
      ExecuteStringEqual(assertion.as_string_equal());
      break;

    case Assertion::kind_type::kStringInWrapper:
      ExecuteStringIn(assertion.as_string_in());
      break;

    case Assertion::kind_type::kEnumAFromJsonIsConstantWrapper:
      ExecuteEnumAFromJsonIsConstant(
          assertion.as_enum_a_from_json_is_constant());
      break;

    case Assertion::kind_type::kEnumAFromBytesIsConstantWrapper:
      ExecuteEnumAFromBytesIsConstant(
          assertion.as_enum_a_from_bytes_is_constant());
      break;

    case Assertion::kind_type::kEnumBFromJsonIsWrapperBWrapper:
      ExecuteEnumBFromJsonIsWrapperB(
          assertion.as_enum_b_from_json_is_wrapper_b());
      break;

    case Assertion::kind_type::kEnumBFromBytesIsWrapperBWrapper:
      ExecuteEnumBFromBytesIsWrapperB(
          assertion.as_enum_b_from_bytes_is_wrapper_b());
      break;

    case Assertion::kind_type::kUnknown:
      FAIL() << "Unknown assertion kind";
    }
  }
}

} // namespace
