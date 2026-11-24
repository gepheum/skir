#include <string>
#include <type_traits>
#include <vector>

#include "absl/strings/ascii.h"
#include "absl/types/optional.h"
#include "skir.h"

// CapitalizeStrings recursively capitalizes all the strings found within a
// skir value.

template <typename T>
typename std::enable_if_t<!skir::reflection::IsRecord<T>()> CapitalizeStrings(
    T&);
void CapitalizeStrings(std::string& s);
template <typename T>
void CapitalizeStrings(std::vector<T>& vector);
template <typename T, typename GetKey>
void CapitalizeStrings(skir::keyed_items<T, GetKey>& vector);
template <typename T>
void CapitalizeStrings(absl::optional<T>& optional);
template <typename T>
typename std::enable_if_t<skir::reflection::IsStruct<T>()> CapitalizeStrings(
    T& record);
template <typename T>
typename std::enable_if_t<skir::reflection::IsEnum<T>()> CapitalizeStrings(
    T& record);

template <typename T>
typename std::enable_if_t<!skir::reflection::IsRecord<T>()> CapitalizeStrings(
    T&) {}

inline void CapitalizeStrings(std::string& s) { absl::AsciiStrToUpper(&s); }

template <typename T>
void CapitalizeStrings(std::vector<T>& vector) {
  for (T& value : vector) {
    CapitalizeStrings(value);
  }
}

template <typename T, typename GetKey>
void CapitalizeStrings(skir::keyed_items<T, GetKey>& vector) {
  for (T& value : vector) {
    CapitalizeStrings(value);
  }
}

template <typename T>
void CapitalizeStrings(absl::optional<T>& optional) {
  if (optional.has_value()) {
    CapitalizeStrings(*optional);
  }
}

template <typename T>
struct CapitalizeStringsVisitor {
  T& record;

  template <typename Getter, typename Value>
  void operator()(skir::reflection::struct_field<Getter, Value>) {
    CapitalizeStrings(Getter()(record));
  }

  template <typename Const>
  void operator()(skir::reflection::enum_const_variant<Const>) {}

  template <typename Option, typename Value>
  void operator()(skir::reflection::enum_wrapper_variant<Option, Value>) {
    auto* value = Option::get_or_null(record);
    if (value != nullptr) {
      CapitalizeStrings(*value);
    }
  }
};

template <typename T>
typename std::enable_if_t<skir::reflection::IsStruct<T>()> CapitalizeStrings(
    T& record) {
  skir::reflection::ForEachField<T>(CapitalizeStringsVisitor<T>{record});
}

template <typename T>
typename std::enable_if_t<skir::reflection::IsEnum<T>()> CapitalizeStrings(
    T& record) {
  skir::reflection::ForEachVariant<T>(CapitalizeStringsVisitor<T>{record});
}
