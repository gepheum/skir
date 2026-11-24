#ifndef SKIR_RESERIALIZER_TESTING_H
#define SKIR_RESERIALIZER_TESTING_H

#include <functional>
#include <string>
#include <utility>
#include <vector>

#include "absl/container/flat_hash_set.h"
#include "absl/status/status.h"
#include "absl/status/statusor.h"
#include "absl/strings/match.h"
#include "absl/strings/str_cat.h"
#include "absl/strings/str_join.h"
#include "absl/strings/str_replace.h"
#include "absl/strings/string_view.h"
#include "absl/strings/strip.h"
#include "absl/types/optional.h"
#include "skir.h"

namespace skir_testing_internal {
struct Utils {
  static absl::StatusOr<std::string> HexToBytes(absl::string_view hex_string) {
    const auto hex_digit_to_int = [](char c) {
      if ('0' <= c && c <= '9') {
        return c - '0';
      } else if ('a' <= c && c <= 'f') {
        return c - 'a' + 10;
      }
      return -1;
    };
    const size_t num_bytes = hex_string.length() / 2;
    std::string bytes = "skir";
    bytes.reserve(4 + num_bytes);
    for (size_t i = 0; i < num_bytes; ++i) {
      const int hi = hex_digit_to_int(hex_string[2 * i]);
      const int lo = hex_digit_to_int(hex_string[2 * i + 1]);
      if (hi < 0 || lo < 0) {
        return absl::UnknownError("not a hexadecimal string");
      }
      bytes.push_back((hi << 4) | lo);
    }
    return bytes;
  }
};

inline absl::StatusOr<std::string> HexToBytes(absl::string_view hex_string) {
  return Utils::HexToBytes(hex_string);
}

namespace reserializer {

class ErrorSink {
public:
  void Push(absl::string_view message,
            std::vector<std::pair<absl::string_view, absl::string_view>>
                context = {}) {
    std::string error = absl::StrCat(message);
    for (const auto &[property, value] : context) {
      absl::StrAppend(&error, "\n  ", property, ":\n    ",
                      absl::StrReplaceAll(value, {{"\n", "\n    "}}));
    }
    errors_.push_back(std::move(error));
  }

  const std::vector<std::string> errors() const { return errors_; }

private:
  std::vector<std::string> errors_;
};

struct ReserializerUtils {
  static std::string BytesToHex(absl::string_view bytes) {
    bytes = absl::StripPrefix(bytes, "skir");
    constexpr char kHexDigits[] = "0123456789abcdef";
    std::string result;
    result.reserve(bytes.length() * 2);
    for (size_t i = 0; i < bytes.length(); ++i) {
      const uint8_t byte = static_cast<uint8_t>(bytes[i]);
      result += {kHexDigits[(byte >> 4) & 0x0F], kHexDigits[byte & 0x0F]};
    }
    return result;
  }

  static absl::StatusOr<std::string> BytesToDenseJson(absl::string_view bytes) {
    if (!absl::StartsWith(bytes, "skir")) {
      return absl::UnknownError("missing skir prefix");
    }
    skir_internal::ByteSource source(bytes.data() + 4, bytes.length() - 4);
    skir_internal::UnrecognizedValues unrecognized_value;
    unrecognized_value.ParseFrom(source);
    if (source.error) {
      return absl::UnknownError("error while parsing bytes");
    }
    if (source.pos != source.end) {
      return absl::UnknownError(absl::StrCat(
          "source.pos != source.end; source.pos: ", (size_t)source.pos,
          "; source.end: ", (size_t)source.end));
    }
    skir_internal::DenseJson dense_json;
    unrecognized_value.AppendTo(dense_json);
    return dense_json.out;
  }

  static void CheckJsonValueIsSkippable(absl::string_view json,
                                        ErrorSink &errors) {
    // Copy to a non-NULL-terminated vector.
    std::vector<char> dense_json_chars(json.begin(), json.end());
    skir_internal::JsonTokenizer tokenizer(
        json.data(), json.data() + json.length(),
        skir::UnrecognizedValuesPolicy::kKeep);

    tokenizer.Next();
    skir_internal::SkipValue(tokenizer);
    if (!tokenizer.state().status.ok()) {
      errors.Push(
          "error while skipping JSON value",
          {{"error", tokenizer.state().status.ToString()}, {"json", json}});
    } else if (tokenizer.state().token_type !=
               skir_internal::JsonTokenType::kStrEnd) {
      errors.Push("error while skipping JSON value: "
                  "tokenizer.state().token_type != JsonTokenType::kStrEnd",
                  {{"json", json}});
    }
  }

  static void CheckBytesValueIsSkippable(absl::string_view bytes,
                                         ErrorSink &errors) {
    if (!absl::StartsWith(bytes, "skir")) {
      errors.Push(
          "missing skir prefix",
          {{"bytes", reserializer::ReserializerUtils::BytesToHex(bytes)}});
      return;
    }
    skir_internal::ByteSource source(bytes.data() + 4, bytes.length() - 4);
    skir_internal::SkipValue(source);
    if (source.error) {
      errors.Push(
          "error while skipping bytes value",
          {{"bytes", reserializer::ReserializerUtils::BytesToHex(bytes)}});
    } else if (source.pos != source.end) {
      errors.Push(
          "error while skipping bytes value: source.pos != source.end",
          {{"bytes", reserializer::ReserializerUtils::BytesToHex(bytes)}});
    }
  }
};
} // namespace reserializer

template <typename T> class Reserializer {
public:
  Reserializer(T subject) : subject_(std::move(subject)) {
    identity_ = [this](const T &input) { return input == subject_; };
  }

  Reserializer &IsDefault() {
    is_default_ = true;
    return *this;
  }

  Reserializer &ExpectDenseJson(absl::string_view json) {
    expected_dense_json_ = std::string(json);
    return *this;
  }

  Reserializer &ExpectReadableJson(absl::string_view json) {
    expected_readable_json_ = std::string(json);
    return *this;
  }

  Reserializer &ExpectBytes(absl::string_view bytes_hex) {
    expected_bytes_hex_ = std::string(bytes_hex);
    return *this;
  }

  Reserializer &ExpectDebugString(absl::string_view debug_string) {
    expected_debug_string_ = std::string(debug_string);
    return *this;
  }

  Reserializer &AddAlternativeJson(absl::string_view json) {
    alternative_jsons_.emplace_back(json);
    return *this;
  }

  Reserializer &AddAlternativeBytes(absl::string_view bytes_hex) {
    alternative_bytes_hex_.emplace_back(bytes_hex);
    return *this;
  }

  Reserializer &ExpectTypeDescriptorJson(absl::string_view json) {
    expected_type_descriptor_json_ = std::string(json);
    return *this;
  }

  template <typename Other>
  Reserializer &AddCompatibleSchema(absl::string_view schema_name) {
    CompatibleSchema &compatible_schema = compatible_schemas_.emplace_back();
    const std::string schema_name_str = compatible_schema.name =
        std::string(schema_name);
    compatible_schema.reencode_json_fn =
        [](const std::string &json) -> absl::StatusOr<std::string> {
      absl::StatusOr<Other> other =
          skir::Parse<Other>(json, skir::UnrecognizedValuesPolicy::kKeep);
      if (!other.ok())
        return other.status();
      return skir::ToDenseJson(*other);
    };
    compatible_schema.reencode_bytes_fn =
        [schema_name_str](
            const std::string &bytes) -> absl::StatusOr<std::string> {
      absl::StatusOr<Other> other =
          skir::Parse<Other>(bytes, skir::UnrecognizedValuesPolicy::kKeep);
      if (!other.ok())
        return other.status();
      return skir::ToBytes(*other).as_string();
    };
    return *this;
  }

  Reserializer &WithIdentity(std::function<bool(const T &)> identity) {
    identity_ = std::move(identity);
    return *this;
  }

  absl::Status Check() const {
    reserializer::ErrorSink errors;
    CheckDefault(errors);
    CheckDenseJson(errors);
    CheckReadableJson(errors);
    CheckBytes(errors);
    CheckDebugString(errors);
    CheckAlternativeJsons(errors);
    CheckAlternativeBytes(errors);
    CheckTypeDescriptor(errors);
    if (errors.errors().empty()) {
      return absl::OkStatus();
    } else {
      return absl::UnknownError(absl::StrJoin(errors.errors(), "\n"));
    }
    // Just to make sure that T has a hash function.
    absl::flat_hash_set<T> set;
    set.insert(subject_);
    return absl::OkStatus();
  }

private:
  const T subject_;
  bool is_default_ = false;
  absl::optional<std::string> expected_dense_json_;
  absl::optional<std::string> expected_readable_json_;
  absl::optional<std::string> expected_bytes_hex_;
  absl::optional<std::string> expected_debug_string_;
  std::vector<std::string> alternative_jsons_;
  std::vector<std::string> alternative_bytes_hex_;
  absl::optional<std::string> expected_type_descriptor_json_;
  struct CompatibleSchema {
    std::string name;
    std::function<absl::StatusOr<std::string>(const std::string &)>
        reencode_bytes_fn;
    std::function<absl::StatusOr<std::string>(const std::string &)>
        reencode_json_fn;
  };
  std::vector<CompatibleSchema> compatible_schemas_;
  std::function<bool(const T &)> identity_;

  void CheckDefault(reserializer::ErrorSink &errors) const {
    if (skir_internal::IsDefault(subject_) && !is_default_) {
      errors.Push("is default but IsDefault() was not called");
    } else if (!skir_internal::IsDefault(subject_) && is_default_) {
      errors.Push("is not default");
    }
  }

  void CheckDenseJson(reserializer::ErrorSink &errors) const {
    const std::string actual_dense_json = skir::ToDenseJson(subject_);

    if (expected_dense_json_.has_value() &&
        actual_dense_json != *expected_dense_json_) {
      errors.Push(
          "Dense JSON doesn't match",
          {{"expected", skir_internal::ToDebugString(*expected_dense_json_)},
           {"actual", skir_internal::ToDebugString(actual_dense_json)}});
      // Don't return.
    }

    absl::StatusOr<T> reserialized = skir::Parse<T>(actual_dense_json);
    if (!reserialized.ok()) {
      errors.Push("Parse(ToDenseJson()) returned an error",
                  {{"error", reserialized.status().ToString()},
                   {"json", actual_dense_json}});
      return;
    }

    if (!identity_(*reserialized)) {
      errors.Push("Parse(ToDenseJson()) doesn't match subject",
                  {{"expected", skir_internal::ToDebugString(subject_)},
                   {"actual", skir_internal::ToDebugString(*reserialized)}});
      return;
    }

    if (actual_dense_json.length() < 50) {
      // Let's try to parse all the possible substrings of actual_dense_json and
      // make sure we don't get a segmentation fault.
      for (size_t i = 0; i < actual_dense_json.length() - 1; ++i) {
        std::vector<char> chars;
        chars.insert(chars.end(), actual_dense_json.begin(),
                     actual_dense_json.begin() + i);
        skir::Parse<T>(absl::string_view(chars.data(), i)).IgnoreError();
      }
    }

    for (const CompatibleSchema &schema : compatible_schemas_) {
      const absl::StatusOr<std::string> reencoded_json =
          schema.reencode_json_fn(actual_dense_json);

      if (!reencoded_json.ok()) {
        errors.Push("Error while reencoding JSON",
                    {{"error", reencoded_json.status().ToString()},
                     {"original json", actual_dense_json},
                     {"schema", schema.name}});
        continue;
      }

      if (*reencoded_json != actual_dense_json) {
        errors.Push("Reencoded JSON doesn't match original JSON",
                    {{"expected", actual_dense_json},
                     {"actual", *reencoded_json},
                     {"schema", schema.name}});
      }

      reserializer::ReserializerUtils::CheckJsonValueIsSkippable(
          *reencoded_json, errors);
    }

    reserializer::ReserializerUtils::CheckJsonValueIsSkippable(
        actual_dense_json, errors);
  }

  void CheckReadableJson(reserializer::ErrorSink &errors) const {
    const std::string actual_readable_json = skir::ToReadableJson(subject_);

    if (expected_readable_json_.has_value() &&
        actual_readable_json != *expected_readable_json_) {
      errors.Push(
          "Readable JSON doesn't match",
          {{"expected", skir_internal::ToDebugString(*expected_readable_json_)},
           {"actual", skir_internal::ToDebugString(actual_readable_json)}});
      // Don't return.
    }

    const absl::StatusOr<T> reserialized = skir::Parse<T>(actual_readable_json);
    if (!reserialized.ok()) {
      errors.Push("Parse(ToReadableJson()) returned an error",
                  {{"error", reserialized.status().ToString()},
                   {"json", actual_readable_json}});
      return;
    }

    if (!identity_(*reserialized)) {
      errors.Push("Parse(ToReadableJson()) doesn't match subject",
                  {{"expected", skir_internal::ToDebugString(subject_)},
                   {"actual", skir_internal::ToDebugString(*reserialized)},
                   {"json", actual_readable_json}});
    }

    reserializer::ReserializerUtils::CheckJsonValueIsSkippable(
        actual_readable_json, errors);
  }

  void CheckBytes(reserializer::ErrorSink &errors) const {
    const std::string actual_bytes = skir::ToBytes(subject_).as_string();

    if (!absl::StartsWith(actual_bytes, "skir")) {
      errors.Push("missing skir prefix",
                  {{"bytes", reserializer::ReserializerUtils::BytesToHex(
                                 actual_bytes)}});
      return;
    }

    const std::string actual_bytes_hex =
        reserializer::ReserializerUtils::BytesToHex(actual_bytes);

    if (expected_bytes_hex_.has_value() &&
        actual_bytes_hex != *expected_bytes_hex_) {
      errors.Push(
          "Bytes don't match",
          {{"expected", skir_internal::ToDebugString(*expected_bytes_hex_)},
           {"actual", skir_internal::ToDebugString(actual_bytes_hex)}});
      // Don't return.
    }

    absl::StatusOr<T> reserialized = skir::Parse<T>(actual_bytes);
    if (!reserialized.ok()) {
      errors.Push("Parse(ToBytes()) returned an error",
                  {{"error", reserialized.status().ToString()},
                   {"bytes", actual_bytes_hex}});
      return;
    }

    if (!identity_(*reserialized)) {
      errors.Push("Parse(ToBytes()) doesn't match subject",
                  {{"expected", skir_internal::ToDebugString(subject_)},
                   {"actual", skir_internal::ToDebugString(*reserialized)},
                   {"bytes", actual_bytes_hex}});
      return;
    }

    if (actual_bytes.length() < 50) {
      // Let's try to parse all the possible substrings of actual_bytes and make
      // sure we don't get a segmentation fault.
      for (size_t i = 0; i < actual_bytes.length() - 1; ++i) {
        std::vector<char> substr;
        substr.insert(substr.end(), actual_bytes.begin(),
                      actual_bytes.begin() + i);
        skir::Parse<T>(absl::string_view(substr.data(), i)).IgnoreError();
      }
    }

    for (const CompatibleSchema &schema : compatible_schemas_) {
      const absl::StatusOr<std::string> reencoded_bytes =
          schema.reencode_bytes_fn(actual_bytes);

      if (!reencoded_bytes.ok()) {
        errors.Push("Error while reencoding bytes",
                    {{"error", reencoded_bytes.status().ToString()},
                     {"schema", schema.name}});
        continue;
      }

      if (*reencoded_bytes != actual_bytes) {
        errors.Push("Reencoded bytes don't match original bytes",
                    {{"expected", actual_bytes_hex},
                     {"actual", reserializer::ReserializerUtils::BytesToHex(
                                    *reencoded_bytes)},
                     {"schema", schema.name}});
      }

      reserializer::ReserializerUtils::CheckBytesValueIsSkippable(
          *reencoded_bytes, errors);
    }

    reserializer::ReserializerUtils::CheckBytesValueIsSkippable(actual_bytes,
                                                                errors);

    const absl::StatusOr<std::string> dense_json =
        reserializer::ReserializerUtils::BytesToDenseJson(actual_bytes);
    if (!dense_json.ok()) {
      errors.Push("BytesToDenseJson() returned an error",
                  {{"error", dense_json.status().ToString()},
                   {"bytes", actual_bytes_hex}});
      return;
    }

    reserialized = skir::Parse<T>(*dense_json);
    if (!reserialized.ok()) {
      errors.Push(
          "Parse(BytesToDenseJson(ToBytes())) returned an error",
          {{"error", reserialized.status().ToString()}, {"json", *dense_json}});
      return;
    }

    if (!identity_(*reserialized)) {
      errors.Push("Parse(BytesToDenseJson(ToBytes())) doesn't match subject",
                  {{"expected", skir_internal::ToDebugString(subject_)},
                   {"actual", skir_internal::ToDebugString(*reserialized)},
                   {"bytes", actual_bytes_hex},
                   {"json", *dense_json}});
    }
  }

  void CheckDebugString(reserializer::ErrorSink &errors) const {
    const std::string actual_debug_string =
        skir_internal::ToDebugString(subject_);
    if (expected_debug_string_.has_value() &&
        actual_debug_string != *expected_debug_string_) {
      errors.Push(
          "Debug string doesn't match",
          {{"expected", skir_internal::ToDebugString(*expected_debug_string_)},
           {"actual", skir_internal::ToDebugString(actual_debug_string)}});
    }
  }

  void CheckAlternativeJsons(reserializer::ErrorSink &errors) const {
    for (const std::string &alternative_json : alternative_jsons_) {
      reserializer::ReserializerUtils::CheckJsonValueIsSkippable(
          alternative_json, errors);

      const absl::StatusOr<T> deserialized = skir::Parse<T>(alternative_json);
      if (!deserialized.ok()) {
        errors.Push("Parse() returned an error",
                    {{"error", deserialized.status().ToString()},
                     {"json", alternative_json}});
        continue;
      }

      if (!identity_(*deserialized)) {
        errors.Push("Parse(json) doesn't match subject",
                    {{"expected", skir_internal::ToDebugString(subject_)},
                     {"actual", skir_internal::ToDebugString(*deserialized)},
                     {"json", alternative_json}});
      }
    }
  }

  void CheckAlternativeBytes(reserializer::ErrorSink &errors) const {
    for (const std::string &alternative_bytes_hex : alternative_bytes_hex_) {
      const absl::StatusOr<std::string> bytes =
          HexToBytes(alternative_bytes_hex);

      if (!bytes.ok()) {
        errors.Push(bytes.status().ToString());
        continue;
      }

      reserializer::ReserializerUtils::CheckBytesValueIsSkippable(*bytes,
                                                                  errors);

      const absl::StatusOr<T> deserialized = skir::Parse<T>(*bytes);
      if (!deserialized.ok()) {
        errors.Push("Parse() returned an error",
                    {{"error", deserialized.status().ToString()},
                     {"bytes", alternative_bytes_hex}});
        continue;
      }

      if (!identity_(*deserialized)) {
        errors.Push("Parse(bytes) doesn't match subject",
                    {{"expected", skir_internal::ToDebugString(subject_)},
                     {"actual", skir_internal::ToDebugString(*deserialized)},
                     {"bytes", alternative_bytes_hex}});
      }
    }
  }

  void CheckTypeDescriptor(reserializer::ErrorSink &errors) const {
    const std::string actual_type_descriptor_json =
        skir::reflection::GetTypeDescriptor<T>().AsJson();
    if (expected_type_descriptor_json_.has_value() &&
        actual_type_descriptor_json != *expected_type_descriptor_json_) {
      errors.Push(
          "Type descriptor JSON doesn't match",
          {{"expected",
            skir_internal::ToDebugString(*expected_type_descriptor_json_)},
           {"actual",
            skir_internal::ToDebugString(actual_type_descriptor_json)}});
      // Don't return.
    }

    absl::StatusOr<skir::reflection::TypeDescriptor> reserialized =
        skir::reflection::TypeDescriptor::FromJson(actual_type_descriptor_json);
    if (!reserialized.ok()) {
      errors.Push("TypeDescriptor::FromJson() returned an error",
                  {{"error", reserialized.status().ToString()},
                   {"json", actual_type_descriptor_json}});
      return;
    }

    const std::string reserialized_as_json = reserialized->AsJson();
    if (reserialized->AsJson() != actual_type_descriptor_json) {
      errors.Push(
          "TypeDescriptor::FromJson(TypeDescriptor::AsJson()) doesn't match "
          "subject",
          {{"expected",
            skir_internal::ToDebugString(actual_type_descriptor_json)},
           {"actual", skir_internal::ToDebugString(reserialized_as_json)}});
    }
  }
};

template <typename T> Reserializer<T> MakeReserializer(T subject) {
  return Reserializer<T>(std::move(subject));
}

} // namespace skir_testing_internal

#endif
