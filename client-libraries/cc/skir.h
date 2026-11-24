// Skir client library

#ifndef SKIR_SKIR_H_VERSION
#define SKIR_SKIR_H_VERSION 20251220

#include <algorithm>
#include <cmath>
#include <cstddef>
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <initializer_list>
#include <iostream>
#include <limits>
#include <memory>
#include <sstream>
#include <string>
#include <tuple>
#include <type_traits>
#include <utility>
#include <variant>
#include <vector>

#include "absl/base/nullability.h"
#include "absl/container/flat_hash_map.h"
#include "absl/hash/hash.h"
#include "absl/log/absl_check.h"
#include "absl/log/die_if_null.h"
#include "absl/status/status.h"
#include "absl/status/statusor.h"
#include "absl/strings/match.h"
#include "absl/strings/str_cat.h"
#include "absl/strings/str_join.h"
#include "absl/strings/str_replace.h"
#include "absl/strings/string_view.h"
#include "absl/time/time.h"
#include "absl/types/optional.h"

namespace skir_internal {
class ByteSink;
struct RecAdapter;

template <typename T, typename Getter>
using getter_value_type = std::remove_const_t<
    std::remove_reference_t<decltype(Getter()(std::declval<T &>()))>>;
} // namespace skir_internal

namespace skir {

// What to do with unrecognized fields and variants when parsing a skir value
// from JSON or binary data.
// Pick kKeep if the input JSON or binary string comes from a trusted program
// which might have been built from more recent source files.
// Always pick kDrop if the input JSON or binary string might come from a
// malicious user.
//
// Default: kDrop
enum class UnrecognizedValuesPolicy { kDrop, kKeep };

// A string of bytes.
//
// Skir uses std::string exclusively for UTF-8 string, and  ByteString for
// binary data.
class ByteString {
public:
  ByteString() = default;

  ByteString(absl::string_view str)
      : data_(CopyData(str)), length_(str.length()) {}

  ByteString(std::initializer_list<uint8_t> bytes)
      : ByteString(
            absl::string_view((const char *)bytes.begin(), bytes.size())) {}

  ByteString(const ByteString &other) : ByteString(other.as_string()) {}
  ByteString(ByteString &&other) : data_(other.data_), length_(other.length_) {
    other.data_ = nullptr;
    other.length_ = 0;
  }

  ~ByteString() { FreeData(); }

  ByteString &operator=(absl::string_view other) {
    FreeData();
    data_ = CopyData(other);
    length_ = other.length();
    return *this;
  }
  ByteString &operator=(const ByteString &other) {
    return (*this) = other.as_string();
  }
  ByteString &operator=(ByteString &&other) {
    FreeData();
    data_ = other.data_;
    length_ = other.length_;
    other.data_ = nullptr;
    other.length_ = 0;
    return *this;
  }

  absl::string_view as_string() const & {
    return absl::string_view((const char *)data_, length_);
  }

  std::string as_string() const && {
    return std::string((const char *)data_, length_);
  }

  size_t length() const { return length_; }

  bool empty() const { return length_ == 0; }

  bool operator==(const ByteString &other) const {
    return as_string() == other.as_string();
  }
  bool operator!=(const ByteString &other) const {
    return as_string() != other.as_string();
  }

private:
  static_assert(sizeof(char) == 1);

  ByteString(const uint8_t *absl_nonnull data, size_t length)
      : data_(data), length_(length) {}

  const uint8_t *absl_nonnull data_ = nullptr;
  size_t length_ = 0;

  void FreeData() const {
    if (data_ != nullptr) {
      delete[] data_;
    }
  }

  static uint8_t *absl_nullable CopyData(absl::string_view str) {
    if (str.empty())
      return nullptr;
    uint8_t *result = new uint8_t[str.length()];
    std::memcpy(result, (const uint8_t *)str.data(), str.length());
    return result;
  }

  friend class ::skir_internal::ByteSink;
};

template <typename H> H AbslHashValue(H h, const ByteString &byte_string) {
  return H::combine(std::move(h), byte_string.as_string());
}

template <typename T, typename GetKey>
using key_type =
    std::conditional_t<std::is_same<skir_internal::getter_value_type<T, GetKey>,
                                    std::string>::value,
                       absl::string_view,
                       skir_internal::getter_value_type<T, GetKey>>;

// A vector-like container that stores items of type T and allows for fast
// lookups by key using a hash table. The key is extracted from each item
// using a user-provided GetKey function.
//
// Example:
//   keyed_items<User, skirout::get_id> users;
//   users.push_back({.id = 1, .name = "Alice"});
//   users.push_back({.id = 2, .name = "Bob"});
//   const User* user = users.find_or_null(1);  // returns pointer to Alice
//
// If multiple items in the container have the same key, only the last one can
// be found when calling find_or_null() or find_or_default().
//
// Accessors, such as at(), operator[], front(), and back() all return constant
// references. Once you have pushed a value into the container, the only way to
// modify the item is to use a vector_mutator, which is obtained by calling
// start_vector_mutation(). The vector_mutator lets you access the underlying
// std::vector<T> and modify it. While the vector mutation is in progress, you
// must not access the keyed_items. When the vector_mutator is destroyed, all
// the items in the vector are rehashed, which runs in O(N).
//
// Example:
//   keyed_items<User, skirout::get_id> users;
//   users.push_back({.id = 1, .name = "Alice"});
//   users.push_back({.id = 2, .name = "Bob"});
//
//   {
//      auto mutator = users.start_vector_mutation();
//      for (User& user : *mutator) {
//        user.name = absl:::AsciiStrToLower(user.name);
//      }
//   }
//
//   // Okay to access `users` here because the vector_mutator has been
//   // destroyed.
//
//   assert(users.find_or_default(1).name == "alice");
//
// The as_vector() method returns a constant reference to the underlying
// std::vector<T>.
template <typename T, typename GetKey> class keyed_items {
public:
  using value_type = T;
  using get_key = GetKey;
  using iterator = typename std::vector<T>::const_iterator;
  using const_iterator = typename std::vector<T>::const_iterator;
  using reverse_iterator = typename std::vector<T>::const_reverse_iterator;
  using const_reverse_iterator =
      typename std::vector<T>::const_reverse_iterator;

  keyed_items() = default;

  keyed_items(const keyed_items &other)
      : vector_(other.vector_), slots_bytes_(other.slots_bytes_),
        slot_type_(other.slot_type_) {
    ABSL_CHECK(!other.being_mutated_);
  }

  keyed_items(keyed_items &&other)
      : vector_(std::move(other.vector_)),
        slots_bytes_(std::move(other.slots_bytes_)),
        slot_type_(other.slot_type_) {
    ABSL_CHECK(!other.being_mutated_);
  }

  template <typename InputIt>
  keyed_items(InputIt first, InputIt last) : vector_(first, last) {
    Rehash();
  }

  keyed_items(std::initializer_list<T> init) : vector_(std::move(init)) {
    Rehash();
  }

  keyed_items(std::vector<T> vector) : vector_(std::move(vector)) { Rehash(); }

  ~keyed_items() { ABSL_CHECK(!being_mutated_); }

  keyed_items &operator=(const keyed_items &other) {
    ABSL_CHECK(!being_mutated_);
    ABSL_CHECK(!other.being_mutated_);
    vector_ = other.vector_;
    slots_bytes_ = other.slots_bytes_;
    slot_type_ = other.slot_type_;
    return *this;
  }

  keyed_items &operator=(keyed_items &&other) {
    ABSL_CHECK(!being_mutated_);
    ABSL_CHECK(!other.being_mutated_);
    vector_ = std::move(other.vector_);
    slots_bytes_ = std::move(other.slots_bytes_);
    slot_type_ = std::move(other.slot_type_);
    return *this;
  }

  keyed_items &operator=(std::vector<T> other) {
    ABSL_CHECK(!being_mutated_);
    vector_ = std::move(other);
    Rehash();
    return *this;
  }

  keyed_items &operator=(std::initializer_list<T> init) {
    ABSL_CHECK(!being_mutated_);
    vector_ = std::vector<T>(std::move(init));
    Rehash();
    return *this;
  }

  template <typename InputIt> void assign(InputIt first, InputIt last) {
    ABSL_CHECK(!being_mutated_);
    vector_ = std::vector<T>(first, last);
    Rehash();
  }

  const T &at(size_t index) const { return vector().at(index); }
  const T &operator[](size_t index) const { return vector()[index]; }
  const T &front() const { return vector().front(); }
  const T &back() const { return vector().back(); }

  auto begin() const { return vector().begin(); }
  auto cbegin() const { return begin(); }
  auto end() const { return vector().end(); }
  auto cend() const { return end(); }

  auto rbegin() const { return vector().rbegin(); }
  auto crbegin() const { return rbegin(); }
  auto rend() const { return vector().rend(); }
  auto crend() const { return rend(); }

  bool empty() const { return vector_.empty(); }
  size_t size() const { return vector_.size(); }

  void reserve(size_t new_cap) {
    ABSL_CHECK(!being_mutated_);
    vector_.reserve(new_cap);
    MaybeRehash();
  }

  size_t capacity() const { return vector().capacity(); }

  void shrink_to_fit() {
    ABSL_CHECK(!being_mutated_);
    vector_.shrink_to_fit();
    MaybeRehash();
  }

  void clear() {
    ABSL_CHECK(!being_mutated_);
    vector_.clear();
    Rehash();
  }

  void push_back(T value) {
    ABSL_CHECK(!being_mutated_);
    vector_.push_back(std::move(value));
    if (MaybeRehash())
      return;
    const size_t next_index = vector_.size();
    using key_type = key_type<T, GetKey>;
    const uint32_t key_hash = absl::Hash<key_type>{}(GetKey()(vector_.back()));
    PutSlot(key_hash, next_index, slot_type_);
  }

  void append_range(const keyed_items<T, GetKey> &rg) { append_range_impl(rg); }
  void append_range(keyed_items<T, GetKey> &&rg) {
    append_range_impl(std::move(rg));
  }
  void append_range(const std::vector<T> &rg) { append_range_impl(rg); }
  void append_range(std::vector<T> &&rg) { append_range_impl(std::move(rg)); }

  void swap(keyed_items &other) noexcept {
    ABSL_CHECK(!being_mutated_);
    ABSL_CHECK(!other.being_mutated_);
    vector_.swap(other.vector_);
    slots_bytes_.swap(other.slots_bytes_);
    std::swap(slot_type_, other.slot_type_);
  }

  // Returns a pointer to the last item with the given key or nullptr if no such
  // item exists.
  template <typename K>
  const T *absl_nullable find_or_null(const K &key) const {
    return find_or_null_impl(key_type<T, GetKey>(key));
  }

  // Returns the last item with the given key or a constant reference to a
  // zero-initialized T if no such item exists.
  //
  // In some cases, this can help you write more succint code than if you were
  // using find_or_null. For example, instead of:
  //
  //   if (users.find_or_null(id) != nullptr &&
  //       !users.find_or_null(id)->name.empty()) { ... }
  //
  // you can write:
  //
  //   if (!users.find_or_default(id).name.empty()) { ... }
  template <typename K> const T &find_or_default(const K &key) const {
    return find_or_default_impl(key_type<T, GetKey>(key));
  }

  // Returns the last item with the given key or default_value if no such item
  // exists.
  template <typename K>
  const T &find_or_default(const K &key, const T &default_value) const {
    return find_or_default_impl(key_type<T, GetKey>(key), default_value);
  }

  void sort_by_key() {
    ABSL_CHECK(!being_mutated_);
    std::sort(vector_.begin(), vector_.end(),
              [](const T &a, const T &b) { return GetKey()(a) < GetKey()(b); });
    Rehash();
  }

  const std::vector<T> &vector() const & { return vector_; }
  std::vector<T> vector() && { return std::move(vector_); }

  bool operator==(const keyed_items &other) const {
    return vector() == other.vector();
  }
  bool operator!=(const keyed_items &other) const {
    return vector() != other.vector();
  }

  class vector_mutator {
  public:
    vector_mutator(const vector_mutator &) = delete;
    vector_mutator(vector_mutator &&) = delete;
    vector_mutator &operator=(const vector_mutator &) = delete;
    vector_mutator &operator=(vector_mutator &&) = delete;

    ~vector_mutator() {
      keyed_items_.Rehash();
      keyed_items_.being_mutated_ = false;
    }

    std::vector<T> &operator*() & { return keyed_items_.vector_; }
    std::vector<T> *absl_nonnull operator->() & {
      return &keyed_items_.vector_;
    }

    std::vector<T> &operator*() && = delete;
    std::vector<T> *absl_nonnull operator->() && = delete;

  private:
    vector_mutator(keyed_items *absl_nonnull keyed_items)
        : keyed_items_(*keyed_items) {}

    keyed_items &keyed_items_;

    friend class keyed_items;
  };

  // Starts a vector mutation which will stay active until the vector_mutator
  // is destroyed. While the vector_mutator is active, you must not call any
  // method on the keyed_items.
  // See class-level documentation.
  vector_mutator start_vector_mutation() & {
    ABSL_CHECK(!being_mutated_);
    being_mutated_ = true;
    return vector_mutator(this);
  }

  vector_mutator start_vector_mutation() && = delete;

private:
  std::vector<T> vector_;
  std::vector<uint8_t> slots_bytes_;
  enum class SlotType {
    kUint8,
    kUint16,
    kUint32,
    kHash64,
  };
  SlotType slot_type_ = SlotType::kUint8;
  bool being_mutated_ = false;

  bool MaybeRehash() {
    const size_t capacity = vector_.capacity();
    const SlotType slot_type = GetSlotType(capacity);
    const size_t num_slots_bytes = GetNumSlotsBytes(capacity, slot_type);
    if (slot_type == slot_type_ && num_slots_bytes == slots_bytes_.size())
      return false;
    Rehash(slot_type, num_slots_bytes);
    return true;
  }

  void Rehash() {
    const size_t capacity = vector_.capacity();
    const SlotType slot_type = GetSlotType(capacity);
    const size_t num_slots_bytes = GetNumSlotsBytes(capacity, slot_type);
    Rehash(slot_type, num_slots_bytes);
  }

  void Rehash(SlotType slot_type, size_t num_slots_bytes) {
    using key_type = key_type<T, GetKey>;
    slot_type_ = slot_type;
    slots_bytes_ = std::vector<uint8_t>(num_slots_bytes);
    for (size_t i = 0; i < vector_.size();) {
      const value_type &item = vector_[i];
      const uint32_t key_hash = absl::Hash<key_type>{}(GetKey()(item));
      ++i;
      PutSlot(key_hash, i, slot_type);
    }
  }

  void PutSlot(uint32_t key_hash, size_t next_index, SlotType slot_type) {
    switch (slot_type) {
    case SlotType::kUint8:
      PutSlot<uint8_t>(key_hash, next_index);
      break;
    case SlotType::kUint16:
      PutSlot<uint16_t>(key_hash, next_index);
      break;
    case SlotType::kUint32:
      PutSlot<uint32_t>(key_hash, next_index);
      break;
    case SlotType::kHash64:
      PutSlot<uint64_t>(key_hash, next_index);
      break;
    }
  }

  template <typename SlotIntType>
  void PutSlot(uint32_t key_hash, size_t next_index) {
    const size_t num_slots = slots_bytes_.size() / sizeof(SlotIntType);
    SlotIntType *slots = (SlotIntType *)slots_bytes_.data();
    size_t slot_index = key_hash % num_slots;
    while (true) {
      SlotIntType &slot = slots[slot_index];
      if (slot == 0) {
        slot = next_index;
        break;
      }
      if (++slot_index == num_slots) {
        slot_index = 0;
      }
    }
  }

  template <typename Range> void append_range_impl(const Range &range) {
    reserve(capacity() + range.size());
    for (const T &e : range) {
      push_back(T(e));
    }
  }

  template <typename Range> void append_range_impl(Range &&range) {
    reserve(capacity() + range.size());
    for (const T &e : range) {
      push_back(std::move(const_cast<T &>(e)));
    }
  }

  template <typename K> const T *absl_nullable find_or_null_impl(K key) const {
    static_assert(std::is_same_v<K, key_type<T, GetKey>>);
    ABSL_CHECK(!being_mutated_);
    if (vector_.empty())
      return nullptr;
    const uint32_t key_hash = absl::Hash<K>{}(key);
    switch (slot_type_) {
    case SlotType::kUint8:
      return FindOrNull<uint8_t>(key, key_hash);
    case SlotType::kUint16:
      return FindOrNull<uint16_t>(key, key_hash);
    case SlotType::kUint32:
      return FindOrNull<uint32_t>(key, key_hash);
    default:
      return FindOrNull<uint64_t>(key, key_hash);
    }
  }

  template <typename SlotIntType, typename K>
  const T *absl_nullable FindOrNull(K key, uint32_t key_hash) const {
    static_assert(std::is_same_v<K, key_type<T, GetKey>>);
    const size_t num_slots = slots_bytes_.size() / sizeof(SlotIntType);
    SlotIntType *slots = (SlotIntType *)slots_bytes_.data();
    size_t slot_index = key_hash % num_slots;
    while (true) {
      const SlotIntType slot = slots[slot_index];
      if (slot == 0)
        return nullptr;
      const T &candidate = vector_[slot - 1];
      if (GetKey()(candidate) == key)
        return &candidate;
      if (++slot_index == num_slots) {
        slot_index = 0;
      }
    }
  }

  template <typename K> const T &find_or_default_impl(K key) const {
    static_assert(std::is_same_v<K, key_type<T, GetKey>>);
    static const T *kDefaultValue = new T{};
    return find_or_default_impl(key, *kDefaultValue);
  }

  template <typename K>
  const T &find_or_default_impl(K key, const T &default_value) const {
    static_assert(std::is_same_v<K, key_type<T, GetKey>>);
    const T *ptr = find_or_null_impl(key);
    return ptr != nullptr ? *ptr : default_value;
  }

  SlotType GetSlotType(size_t capacity) {
    if (capacity <= std::numeric_limits<uint8_t>::max()) {
      return SlotType::kUint8;
    } else if (capacity <= std::numeric_limits<uint16_t>::max()) {
      return SlotType::kUint16;
    } else if (capacity <= std::numeric_limits<uint32_t>::max()) {
      return SlotType::kUint32;
    } else {
      return SlotType::kHash64;
    }
  }

  // Returns the new size of slots_bytes_ for the given vector_'s capactiy.
  static size_t GetNumSlotsBytes(size_t capacity, SlotType slot_type) {
    constexpr int kNumSlotsPerItem = 2;
    switch (slot_type) {
    case SlotType::kUint8:
      return capacity * kNumSlotsPerItem;
    case SlotType::kUint16:
      return capacity * kNumSlotsPerItem * 2;
    case SlotType::kUint32:
      if (std::is_same_v<size_t, uint32_t> &&
          capacity >
              std::numeric_limits<uint32_t>::max() / (kNumSlotsPerItem * 4)) {
        return std::numeric_limits<uint32_t>::max();
      }
      return capacity * kNumSlotsPerItem * 4;
    default:
      return capacity * kNumSlotsPerItem * 8;
    }
  }

  friend class vector_mutator;
};

template <typename H, typename T, typename GetKey>
H AbslHashValue(H h, const keyed_items<T, GetKey> &keyed_items) {
  return H::combine(std::move(h), keyed_items.vector());
}

// A wrapper around a heap-allocated value of type T.
// In its zero-initialized state, the behavior of operator*() depends on whether
// it is called on a const rec<T> or a mutable rec<T>:
//   - On a const rec<T>, operator*() returns a constant reference to a static
//     zero-initialized T
//   - On a mutable rec<T>, operator*() assigns a zero-initialized T to the rec
//     and returns a mutable reference to it. The rec is no longer in a
//     zero-initialized state.
//
// The skir C++ code generator can chose to make the field of a generated struct
// type a rec<T> instead of a T if T is a recursive type.
//
// For example:
//
//   struct Foo {
//     // Foo foo;  // <- does not compile: a struct cannot contain itself
//     rec<Foo> foo;
//     std::string name;
//   };
//
// The word 'rec' stands for 'recursive'.
template <typename T> class rec {
public:
  using value_type = T;

  rec() = default;
  rec(const rec &other) {
    if (other.value_ != nullptr) {
      value_ = std::make_unique<T>(*other.value_);
    }
  }
  rec(rec &&other) = default;
  rec(T value) : value_(std::make_unique<T>(std::move(value))) {}

  const T &operator*() const {
    if (value_ != nullptr) {
      return *value_;
    } else {
      static const T *const default_value = new T();
      return *default_value;
    }
  }

  T &operator*() {
    if (value_ != nullptr) {
      return *value_;
    } else {
      return *(value_ = std::make_unique<T>());
    }
  }

  operator const T &() const { return **this; }
  operator T &() { return **this; }

  const T *absl_nonnull operator->() const { return &(**this); }
  T *absl_nonnull operator->() { return &(**this); }

  rec &operator=(const rec &other) {
    if (other.value_ != nullptr) {
      value_ = std::make_unique<T>(*other.value_);
    } else {
      value_ = nullptr;
    }
    return *this;
  }

  rec &operator=(rec &&other) = default;

  rec &operator=(T other) {
    value_ = std::make_unique<T>(std::move(other));
    return *this;
  }

  bool operator==(const rec &other) const {
    return (value_ == nullptr && other.value_ == nullptr) || **this == *other;
  }
  bool operator!=(const rec &other) const { return !operator==(other); }

private:
  std::unique_ptr<T> value_;

  friend struct ::skir_internal::RecAdapter;
};

template <typename T> rec<T> make_rec(T value) {
  return rec<T>(std::move(value));
}

template <typename O, typename T>
std::ostream &operator<<(std::ostream &os, const rec<T> &input) {
  return os << *input;
}

template <typename T> class must_init {
public:
  using value_type = T;

  template <typename Value> must_init(Value value) {
    value_ = std::move(value);
  }

  T operator*() && { return std::move(value_); }

private:
  T value_;
};

template <typename T> class must_init<std::vector<T>> {
public:
  using value_type = std::vector<T>;
  must_init(value_type value) { value_ = std::move(value); }
  must_init(std::initializer_list<T> l) : must_init(value_type(std::move(l))) {}
  value_type operator*() && { return std::move(value_); }

private:
  value_type value_;
};

template <typename T, typename GetKey>
class must_init<skir::keyed_items<T, GetKey>> {
public:
  using value_type = skir::keyed_items<T, GetKey>;
  must_init(value_type value) { value_ = std::move(value); }
  must_init(std::initializer_list<T> l) : must_init(value_type(std::move(l))) {}
  value_type operator*() && { return std::move(value_); }

private:
  value_type value_;
};

struct identity {
  template <typename T> T &&operator()(T &&t) const {
    return std::forward<T>(t);
  }
};

template <typename other = identity> struct get_kind {
  using other_type = other;

  static constexpr absl::string_view kFieldName = "kind";

  template <typename E> auto operator()(const E &e) const {
    return other()(e).kind();
  }
};

namespace reflection {

enum class PrimitiveType {
  kBool,
  kInt32,
  kInt64,
  kHash64,
  kFloat32,
  kFloat64,
  kTimestamp,
  kString,
  kBytes,
};

struct OptionalType;
struct ArrayType;
struct RecordType;

using Type = std::variant<PrimitiveType, OptionalType, ArrayType, RecordType>;

struct OptionalType {
  skir::rec<Type> other;
};

struct ArrayType {
  skir::rec<Type> item;
  std::string key_extractor;
};

struct RecordType {
  std::string record_id;
};

struct Field {
  std::string name;
  int number{};
  Type type;
  std::string doc;
};

struct Variant {
  std::string name;
  int number{};
  // Present if this variant wraps a value.
  std::optional<Type> type;
  std::string doc;
};

struct get_name {
  template <typename FieldOrVariant>
  const std::string &operator()(const FieldOrVariant &f) {
    return f.name;
  }
};

// Definition of a skir struct.
struct Struct {
  std::string id;
  std::string doc;
  keyed_items<Field, get_name> fields;
  std::vector<int> removed_numbers;
};

// Definition of a skir struct.
struct Enum {
  std::string id;
  std::string doc;
  keyed_items<Variant, get_name> variants;
  std::vector<int> removed_numbers;
};

using Record = std::variant<Struct, Enum>;

struct get_id {
  const std::string &operator()(const Record &record) const {
    return std::visit([](const auto &r) -> const std::string & { return r.id; },
                      record);
  }
};

// Describes a skir type. Contains the definition of all the structs and enums
// referenced from the type.
//
// A TypeDescriptor can be serialized to JSON with AsJson(), and deserialized
// from JSON with FromJson().
struct TypeDescriptor {
  Type type;
  keyed_items<Record, get_id> records;

  std::string AsJson() const;

  static absl::StatusOr<TypeDescriptor> FromJson(absl::string_view json);
};

using RecordRegistry = keyed_items<Record, get_id>;

// For static reflection: represents a field of a skir struct.
// See `skir::reflection::ForEachField`
template <typename Getter, typename Value> struct struct_field {
  using getter_type = Getter;
  using value_type = Value;
};

// For static reflection: represents a constant variant of a skir enum.
// See `skir::reflection::ForEachVariant`
template <typename Const> struct enum_const_variant {
  using const_type = Const;
};

// For static reflection: represents a wrapper variant of a skir enum.
// See `skir::reflection::ForEachVariant`
template <typename Option, typename Value> struct enum_wrapper_variant {
  using option_type = Option;
  using value_type = Value;
};

} // namespace reflection

namespace service {

// HTTP status codes for errors.
enum class HttpErrorCode {
  k400_BadRequest = 400,
  k401_Unauthorized = 401,
  k402_PaymentRequired = 402,
  k403_Forbidden = 403,
  k404_NotFound = 404,
  k405_MethodNotAllowed = 405,
  k406_NotAcceptable = 406,
  k407_ProxyAuthenticationRequired = 407,
  k408_RequestTimeout = 408,
  k409_Conflict = 409,
  k410_Gone = 410,
  k411_LengthRequired = 411,
  k412_PreconditionFailed = 412,
  k413_ContentTooLarge = 413,
  k414_UriTooLong = 414,
  k415_UnsupportedMediaType = 415,
  k416_RangeNotSatisfiable = 416,
  k417_ExpectationFailed = 417,
  k418_ImATeapot = 418,
  k421_MisdirectedRequest = 421,
  k422_UnprocessableContent = 422,
  k423_Locked = 423,
  k424_FailedDependency = 424,
  k425_TooEarly = 425,
  k426_UpgradeRequired = 426,
  k428_PreconditionRequired = 428,
  k429_TooManyRequests = 429,
  k431_RequestHeaderFieldsTooLarge = 431,
  k451_UnavailableForLegalReasons = 451,
  k500_InternalServerError = 500,
  k501_NotImplemented = 501,
  k502_BadGateway = 502,
  k503_ServiceUnavailable = 503,
  k504_GatewayTimeout = 504,
  k505_HttpVersionNotSupported = 505,
  k506_VariantAlsoNegotiates = 506,
  k507_InsufficientStorage = 507,
  k508_LoopDetected = 508,
  k510_NotExtended = 510,
  k511_NetworkAuthenticationRequired = 511,
};

// Represents an error with a specific HTTP status code.
// Use this as a return type from service methods when you want to control the
// HTTP error code sent to clients. For generic errors where the default 500
// status code is acceptable, use absl::Status instead.
struct Error {
  HttpErrorCode code = HttpErrorCode::k500_InternalServerError;
  std::string message;
};

// Represents either a successful Response or an Error with a specific HTTP
// status code. Use this as the return type for service methods when you need
// fine-grained control over HTTP error codes. For simple error handling where
// generic HTTP status codes are sufficient, use absl::StatusOr<Response>
// instead.
template <typename Response> class ErrorOr {
public:
  ErrorOr() = default;
  ErrorOr(const ErrorOr &) = default;
  ErrorOr(ErrorOr &&) = default;

  ErrorOr(Response response) : variant_(std::move(response)) {}
  ErrorOr(Error error) : variant_(std::move(error)) {}
  ErrorOr(absl::StatusOr<Response> response_or_error) {
    (*this) = std::move(response_or_error);
  }

  ErrorOr &operator=(const ErrorOr &) = default;
  ErrorOr &operator=(ErrorOr &&) = default;

  ErrorOr &operator=(Response response) {
    variant_ = std::move(response);
    return *this;
  }
  ErrorOr &operator=(Error error) {
    variant_ = std::move(error);
    return *this;
  }
  ErrorOr &operator=(absl::StatusOr<Response> response_or_error) {
    if (response_or_error.ok()) {
      variant_ = *std::move(response_or_error);
    } else {
      variant_ = Error{
          HttpErrorCode::k500_InternalServerError,
          absl::StrCat("server error: ", response_or_error.status().message())};
    }
    return *this;
  }

  bool ok() const { return std::holds_alternative<Response>(variant_); }

  const std::variant<Response, Error> &variant() const { return variant_; }
  std::variant<Response, Error> &variant() { return variant_; }

private:
  using variant_type = std::variant<Response, Error>;
  variant_type variant_;
};

// Raw response returned by the server.
struct RawResponse {
  std::string data;
  int status_code{};
  std::string content_type;

  absl::StatusOr<std::string> AsStatus() && {
    if (status_code >= 200 && status_code < 300) {
      return std::move(data);
    }
    return absl::UnknownError(std::move(data));
  }
};

class HttpHeaders {
public:
  HttpHeaders() = default;
  HttpHeaders(const HttpHeaders &) = default;
  HttpHeaders(HttpHeaders &&) = default;

  HttpHeaders &operator=(const HttpHeaders &) = default;
  HttpHeaders &operator=(HttpHeaders &&) = default;

  // Appends `value` to the vector of values associated with the given name
  // converted to lowercase.
  void Insert(absl::string_view name, absl::string_view value);

  // Returns the vector of values associated with the given name converted to
  // lowercase. If there is no value associated with the given name, returns an
  // empty vector.
  const std::vector<std::string> &Get(absl::string_view name) const;

  // Returns the last value associated with the given name converted to
  // lowercase, or an empty string if there is none.
  absl::string_view GetLast(absl::string_view name) const;

  // Returns a map view of this HttpHeaders object.
  const absl::flat_hash_map<std::string, std::vector<std::string>> &
  map() const {
    return map_;
  }

private:
  absl::flat_hash_map<std::string, std::vector<std::string>> map_;
};

// Options for handling service requests.
struct ServiceOptions {
  UnrecognizedValuesPolicy unrecognized_values =
      UnrecognizedValuesPolicy::kDrop;
  std::string studio_app_js_url =
      "https://cdn.jsdelivr.net/npm/skir-studio/dist/skir-studio-standalone.js";
};

// Sends RPCs to a SkirRPC service.
class Client {
public:
  virtual ~Client() = default;

  virtual absl::StatusOr<std::string>
  operator()(absl::string_view request_data,
             const HttpHeaders &request_headers) const = 0;
};

} // namespace service
} // namespace skir

namespace skir_internal {

skir::service::RawResponse MakeOkJsonResponse(std::string data);
skir::service::RawResponse MakeOkHtmlResponse(std::string data);
skir::service::RawResponse MakeBadRequestResponse(std::string data);
skir::service::RawResponse MakeServerErrorResponse(std::string data,
                                                   int status_code);

template <typename T> T &get(T &input) { return input; }
template <typename T> T &get(skir::rec<T> &input) { return *input; }
template <typename T> const T &get(const skir::rec<T> &input) { return *input; }

template <typename Struct, typename Getter>
using struct_field =
    skir::reflection::struct_field<Getter, getter_value_type<Struct, Getter>>;

template <typename Enum, typename Option>
using enum_wrapper_variant = skir::reflection::enum_wrapper_variant<
    Option, std::remove_const_t<std::remove_pointer_t<
                decltype(Option::get_or_null(std::declval<Enum &>()))>>>;

struct NewLine {
public:
  const std::string &Indent() {
    new_line_ += {' ', ' '};
    return new_line_;
  }

  const std::string &Dedent() {
    new_line_.resize(new_line_.length() - 2);
    return new_line_;
  }

  const std::string &operator*() const { return new_line_; }

private:
  std::string new_line_ = "\n";
};

struct DenseJson {
  std::string out;
};

struct ReadableJson {
  std::string out;
  NewLine new_line;
};

struct DebugString {
  std::string out;
  NewLine new_line;
};

class ByteSink {
public:
  ByteSink() = default;
  ByteSink(const ByteSink &) = delete;
  ByteSink(ByteSink &&) = delete;

  ~ByteSink() {
    if (data_ != nullptr) {
      delete[] data_;
    }
  }

  ByteSink &operator=(const ByteSink &other) = delete;
  ByteSink &operator=(ByteSink &&other) = delete;

  size_t length() const { return pos_ - data_; }

  // Invalidated by anything that can change the capacity of the byte sink.
  uint8_t *absl_nonnull data() { return data_; }
  // Invalidated by anything that can change the capacity of the byte sink.
  const uint8_t *absl_nonnull data() const { return data_; }

  // Invalidated by anything that can change the capacity of the byte sink.
  uint8_t *absl_nonnull pos() { return pos_; }
  // The given pointer must be in the [data, data + length] range.
  void set_pos(uint8_t *absl_nonnull pos) { pos_ = pos; }

  // Prepares for N bytes to be pushed with PushUnsafe().
  void Prepare(size_t n) {
    if (n <= capacity_left())
      return;
    const size_t len = length();
    capacity_ += std::max(capacity_, n);
    uint8_t *new_data = new uint8_t[capacity_];
    std::memcpy(new_data, data_, len);
    delete[] data_;
    data_ = new_data;
    pos_ = data_ + len;
  }

  void PushUnsafe(uint8_t byte) { *(pos_++) = byte; }

  template <typename Byte, typename... Bytes>
  void PushUnsafe(uint8_t first, Byte second, Bytes... tail) {
    PushUnsafe(first);
    PushUnsafe(second, tail...);
  }

  template <typename... Bytes> void Push(uint8_t first, Bytes... tail) {
    Prepare(1 + sizeof...(tail));
    PushUnsafe(first, tail...);
  }

  void PushNUnsafe(const uint8_t *absl_nonnull src, size_t n) {
    std::memcpy((pos_ += n) - n, src, n);
  }

  void PushN(const uint8_t *absl_nonnull src, size_t n) {
    Prepare(n);
    PushNUnsafe(src, n);
  }

  void PushRangeUnsafe(const uint8_t *absl_nonnull begin,
                       const uint8_t *absl_nonnull end) {
    PushNUnsafe(begin, end - begin);
  }

  void PushRange(const uint8_t *absl_nonnull begin,
                 const uint8_t *absl_nonnull end) {
    PushN(begin, end - begin);
  }

  void PopN(size_t n) { pos_ -= n; }

  ::skir::ByteString ToByteString() && {
    ::skir::ByteString byte_string(data_, length());
    // To prevent the ByteString destructor from deleting the array.
    data_ = nullptr;
    return byte_string;
  }

private:
  static constexpr size_t kDefaultCapacity = 16;
  size_t capacity_ = kDefaultCapacity;
  uint8_t *absl_nonnull data_ = new uint8_t[kDefaultCapacity];
  uint8_t *absl_nonnull pos_ = data_;

  size_t capacity_left() const { return capacity_ - length(); }
};

struct ByteSource {
  ByteSource(const uint8_t *absl_nonnull begin, size_t length)
      : pos(begin), end(begin + length) {}
  ByteSource(const char *absl_nonnull begin, size_t length)
      : ByteSource((const uint8_t *)begin, length) {}

  const uint8_t *absl_nonnull pos;
  const uint8_t *absl_nonnull const end;
  bool keep_unrecognized_values = false;
  bool error = false;

  size_t num_bytes_left() const { return end - pos; }

  uint8_t ReadWire() {
    if (pos < end) {
      return *(pos++);
    } else {
      RaiseError();
      return 0;
    }
  }

  // Same as ReadWire, but does not increment pos.
  uint8_t PeekWire() {
    if (pos < end) {
      return *pos;
    } else {
      RaiseError();
      return 0;
    }
  }

  bool TryAdvance(size_t n) {
    if ((pos += n) <= end)
      return true;
    RaiseError();
    return false;
  }

  void CheckEnd() {
    if (pos > end) {
      RaiseError();
    }
  }

  void RaiseError() {
    pos = end;
    error = true;
  }
};

enum class JsonTokenType {
  kError = '!',
  kTrue = 't',
  kFalse = 'f',
  kNull = 'n',
  kZero = '0',
  kUnsignedInteger = '+',
  kSignedInteger = '-',
  kFloat = '.',
  kString = '"',
  kLeftSquareBracket = '[',
  kRightSquareBracket = ']',
  kLeftCurlyBracket = '{',
  kRightCurlyBracket = '}',
  kComma = ',',
  kColon = ':',
  kStrEnd = '\0',
};

class JsonTokenizer {
public:
  JsonTokenizer(const char *absl_nonnull json_code_begin,
                const char *absl_nonnull json_code_end,
                skir::UnrecognizedValuesPolicy unrecognized_values)
      : keep_unrecognized_values_(unrecognized_values ==
                                  skir::UnrecognizedValuesPolicy::kKeep) {
    state_.begin = json_code_begin;
    state_.end = json_code_end;
    state_.pos = json_code_begin;
  }

  JsonTokenizer(const JsonTokenizer &) = delete;
  JsonTokenizer(JsonTokenizer &&) = delete;
  JsonTokenizer &operator=(const JsonTokenizer &) = delete;
  JsonTokenizer &operator=(JsonTokenizer &&) = delete;

  JsonTokenType Next();

  struct State {
    const char *absl_nullable begin = nullptr;
    const char *absl_nullable end = nullptr;
    // End position of the last token read, or 'begin' if no token was read.
    const char *absl_nullable pos = nullptr;
    // Begin position of the last token read, or nullptr if no token was read.
    const char *absl_nullable token_begin = nullptr;
    absl::Status status = absl::OkStatus();
    JsonTokenType token_type = JsonTokenType::kStrEnd;
    int64_t int_value = 0;
    uint64_t uint_value = 0;
    double float_value = 0.0;
    std::string string_value;

    size_t chars_left() const { return end - pos; }

    char NextCharOrNull() { return ++pos < end ? *pos : '\0'; }

    void PushError(absl::string_view message);
    void PushErrorAtPosition(absl::string_view expected);
    void PushUnexpectedTokenError(absl::string_view expected);
  };

  State &mutable_state() { return state_; }
  const State &state() const { return state_; }

  const bool keep_unrecognized_values() const {
    return keep_unrecognized_values_;
  }

private:
  const bool keep_unrecognized_values_;
  State state_;
};

void SkipValue(JsonTokenizer &tokenizer);

class JsonArrayCloser {
public:
  explicit JsonArrayCloser(DenseJson *absl_nonnull json) : json_(json->out) {}
  ~JsonArrayCloser() { json_ += ']'; }

private:
  std::string &json_;
};

class JsonArrayReader {
public:
  explicit JsonArrayReader(JsonTokenizer *absl_nonnull tokenizer);
  bool NextElement();
  JsonTokenizer &tokenizer() { return tokenizer_; }

private:
  JsonTokenizer &tokenizer_;
  bool zero_state_ = true;
};

class JsonObjectReader {
public:
  explicit JsonObjectReader(JsonTokenizer *absl_nonnull tokenizer);

  bool NextEntry();

  // Name component of the current entry.
  // Invalidated when NextEntry() is called.
  const std::string &name() const { return name_; }

private:
  JsonTokenizer &tokenizer_;
  std::string name_;
  bool zero_state_ = true;
};

void SkipValue(ByteSource &source);

void AppendArrayPrefix(size_t length, ByteSink &out);

void ParseArrayPrefix(ByteSource &source, uint32_t &length);

template <typename T> struct skir_type {};

struct BoolAdapter {
  static bool IsDefault(bool input) { return !input; }

  static void Append(bool input, DenseJson &out) {
    out.out += input ? '1' : '0';
  }

  static void Append(bool input, ReadableJson &out) {
    AppendTrueOrFalse(input, out.out);
  }

  static void Append(bool input, DebugString &out) {
    AppendTrueOrFalse(input, out.out);
  }

  static void Append(bool input, ByteSink &out) { out.Push(input ? 1 : 0); }

  static void Parse(JsonTokenizer &tokenizer, bool &out);

  static void Parse(ByteSource &source, bool &out);

  static skir::reflection::Type GetType(skir_type<bool>) {
    return skir::reflection::PrimitiveType::kBool;
  }

  static void RegisterRecords(skir_type<bool>,
                              skir::reflection::RecordRegistry &) {}

  static constexpr bool IsStruct() { return false; }
  static constexpr bool IsEnum() { return false; }

private:
  static void AppendTrueOrFalse(bool input, std::string &out) {
    if (input) {
      out += {'t', 'r', 'u', 'e'};
    } else {
      out += {'f', 'a', 'l', 's', 'e'};
    }
  }
};

struct Int32Adapter {
  static bool IsDefault(int32_t input) { return !input; }

  template <typename Out> static void Append(int32_t input, Out &out) {
    absl::StrAppend(&out.out, input);
  }

  static void Append(int32_t input, ByteSink &out);

  static void Parse(JsonTokenizer &tokenizer, int32_t &out);
  static void Parse(ByteSource &source, int32_t &out);

  static skir::reflection::Type GetType(skir_type<int32_t>) {
    return skir::reflection::PrimitiveType::kInt32;
  }

  static void RegisterRecords(skir_type<int32_t>,
                              skir::reflection::RecordRegistry &) {}

  static constexpr bool IsStruct() { return false; }
  static constexpr bool IsEnum() { return false; }
};

constexpr int64_t kMinSafeJavascriptInt = -9007199254740991; // -(2 ^ 53 - 1)
constexpr int64_t kMaxSafeJavascriptInt = 9007199254740991;  // 2 ^ 53 - 1

struct Int64Adapter {
  static bool IsDefault(int64_t input) { return !input; }

  template <typename Out> static void Append(int64_t input, Out &out) {
    if (skir_internal::kMinSafeJavascriptInt <= input &&
        input <= skir_internal::kMaxSafeJavascriptInt) {
      absl::StrAppend(&out.out, input);
    } else {
      out.out += '"';
      absl::StrAppend(&out.out, input);
      out.out += '"';
    }
  }

  static void Append(int64_t input, DebugString &out) {
    absl::StrAppend(&out.out, input);
  }

  static void Append(int64_t input, ByteSink &out);
  static void Parse(JsonTokenizer &tokenizer, int64_t &out);
  static void Parse(ByteSource &source, int64_t &out);

  static skir::reflection::Type GetType(skir_type<int64_t>) {
    return skir::reflection::PrimitiveType::kInt64;
  }

  static void RegisterRecords(skir_type<int64_t>,
                              skir::reflection::RecordRegistry &) {}

  static constexpr bool IsStruct() { return false; }
  static constexpr bool IsEnum() { return false; }
};

struct Hash64Adapter {
  static bool IsDefault(uint64_t input) { return !input; }

  template <typename Out> static void Append(uint64_t input, Out &out) {
    if (input <= skir_internal::kMaxSafeJavascriptInt) {
      absl::StrAppend(&out.out, input);
    } else {
      out.out += '"';
      absl::StrAppend(&out.out, input);
      out.out += '"';
    }
  }

  static void Append(int64_t input, DebugString &out) {
    absl::StrAppend(&out.out, input);
  }

  static void Append(uint64_t input, ByteSink &out);
  static void Parse(JsonTokenizer &tokenizer, uint64_t &out);
  static void Parse(ByteSource &source, uint64_t &out);

  static skir::reflection::Type GetType(skir_type<uint64_t>) {
    return skir::reflection::PrimitiveType::kHash64;
  }

  static void RegisterRecords(skir_type<uint64_t>,
                              skir::reflection::RecordRegistry &) {}

  static constexpr bool IsStruct() { return false; }
  static constexpr bool IsEnum() { return false; }
};

template <typename float_or_double>
void AppendJsonForFloat(float_or_double input, std::string &out) {
  if (std::isfinite(input)) {
    absl::StrAppend(&out, input);
  } else if (std::isinf(input)) {
    if (input < 0) {
      out += {'"', '-', 'I', 'n', 'f', 'i', 'n', 'i', 't', 'y', '"'};
    } else {
      out += {'"', 'I', 'n', 'f', 'i', 'n', 'i', 't', 'y', '"'};
    }
  } else {
    out += {'"', 'N', 'a', 'N', '"'};
  }
}

struct Float32Adapter {
  static bool IsDefault(float input) { return !input; }

  template <typename Out> static void Append(float input, Out &out) {
    AppendJsonForFloat(input, out.out);
  }

  static void Append(float input, DebugString &out) {
    if (std::isfinite(input)) {
      absl::StrAppend(&out.out, input);
    } else if (std::isinf(input)) {
      if (input < 0) {
        out.out += "-std::numeric_limits<float>::infinity()";
      } else {
        out.out += "std::numeric_limits<float>::infinity()";
      }
    } else {
      out.out += "std::numeric_limits<float>::quiet_NaN()";
    }
  }

  static void Append(float input, ByteSink &out);
  static void Parse(JsonTokenizer &tokenizer, float &out);
  static void Parse(ByteSource &source, float &out);

  static skir::reflection::Type GetType(skir_type<float>) {
    return skir::reflection::PrimitiveType::kFloat32;
  }

  static void RegisterRecords(skir_type<float>,
                              skir::reflection::RecordRegistry &) {}

  static constexpr bool IsStruct() { return false; }
  static constexpr bool IsEnum() { return false; }
};

struct Float64Adapter {
  static bool IsDefault(double input) { return !input; }

  template <typename Out> static void Append(double input, Out &out) {
    AppendJsonForFloat(input, out.out);
  }

  static void Append(double input, DebugString &out) {
    if (std::isfinite(input)) {
      absl::StrAppend(&out.out, input);
    } else if (std::isinf(input)) {
      if (input < 0) {
        out.out += "-std::numeric_limits<double>::infinity()";
      } else {
        out.out += "std::numeric_limits<double>::infinity()";
      }
    } else {
      out.out += "std::numeric_limits<double>::quiet_NaN()";
    }
  }

  static void Append(double input, ByteSink &out);
  static void Parse(JsonTokenizer &tokenizer, double &out);
  static void Parse(ByteSource &source, double &out);

  static skir::reflection::Type GetType(skir_type<double>) {
    return skir::reflection::PrimitiveType::kFloat64;
  }

  static void RegisterRecords(skir_type<double>,
                              skir::reflection::RecordRegistry &) {}

  static constexpr bool IsStruct() { return false; }
  static constexpr bool IsEnum() { return false; }
};

struct TimestampAdapter {
  static bool IsDefault(absl::Time input) { return !absl::ToUnixMillis(input); }

  static void Append(absl::Time input, DenseJson &out);
  static void Append(absl::Time input, ReadableJson &out);
  static void Append(absl::Time input, DebugString &out);
  static void Append(absl::Time input, ByteSink &out);
  static void Parse(JsonTokenizer &tokenizer, absl::Time &out);
  static void Parse(ByteSource &source, absl::Time &out);

  static skir::reflection::Type GetType(skir_type<absl::Time>) {
    return skir::reflection::PrimitiveType::kTimestamp;
  }

  static void RegisterRecords(skir_type<absl::Time>,
                              skir::reflection::RecordRegistry &) {}

  static constexpr bool IsStruct() { return false; }
  static constexpr bool IsEnum() { return false; }
};

struct StringAdapter {
  static bool IsDefault(const std::string &input) { return input.empty(); }

  template <typename Out>
  static void Append(const std::string &input, Out &out) {
    AppendJson(input, out.out);
  }

  static void AppendJson(const std::string &input, std::string &out);
  static void Append(const std::string &input, DebugString &out);
  static void Append(const std::string &input, ByteSink &out);
  static void Parse(JsonTokenizer &tokenizer, std::string &out);
  static void Parse(ByteSource &source, std::string &out);

  static skir::reflection::Type GetType(skir_type<std::string>) {
    return skir::reflection::PrimitiveType::kString;
  }

  static void RegisterRecords(skir_type<std::string>,
                              skir::reflection::RecordRegistry &) {}

  static constexpr bool IsStruct() { return false; }
  static constexpr bool IsEnum() { return false; }
};

struct BytesAdapter {
  static bool IsDefault(const skir::ByteString &input) { return input.empty(); }

  static void Append(const skir::ByteString &, DenseJson &out);
  static void Append(const skir::ByteString &, ReadableJson &out);
  static void Append(const skir::ByteString &input, DebugString &out);
  static void Append(const skir::ByteString &input, ByteSink &out);
  static void Parse(JsonTokenizer &tokenizer, skir::ByteString &out);
  static void Parse(ByteSource &source, skir::ByteString &out);

  static skir::reflection::Type GetType(skir_type<skir::ByteString>) {
    return skir::reflection::PrimitiveType::kBytes;
  }

  static void RegisterRecords(skir_type<skir::ByteString>,
                              skir::reflection::RecordRegistry &) {}

  static constexpr bool IsStruct() { return false; }
  static constexpr bool IsEnum() { return false; }
};

template <typename T> void GetAdapter(skir_type<T>) {
  static_assert(false, "not a skir type");
}

inline BoolAdapter GetAdapter(skir_type<bool>);
inline Int32Adapter GetAdapter(skir_type<int32_t>);
inline Int64Adapter GetAdapter(skir_type<int64_t>);
inline Hash64Adapter GetAdapter(skir_type<uint64_t>);
inline Float32Adapter GetAdapter(skir_type<float>);
inline Float64Adapter GetAdapter(skir_type<double>);
inline TimestampAdapter GetAdapter(skir_type<absl::Time>);
inline StringAdapter GetAdapter(skir_type<std::string>);
inline BytesAdapter GetAdapter(skir_type<skir::ByteString>);

// =============================================================================
// BEGIN serialization of type descriptors
// =============================================================================

struct ReflectionTypeAdapter {
  static bool IsDefault(const skir::reflection::Type &input) { return false; }
  static void Append(const skir::reflection::Type &input, ReadableJson &out);
  static void Parse(JsonTokenizer &tokenizer, skir::reflection::Type &out);
};

struct ReflectionPrimitiveTypeAdapter {
  static bool IsDefault(skir::reflection::PrimitiveType input) { return false; }
  static void Append(skir::reflection::PrimitiveType input, ReadableJson &out);
  static void Parse(JsonTokenizer &tokenizer,
                    skir::reflection::PrimitiveType &out);
};

struct ReflectionOptionalTypeAdapter {
  static bool IsDefault(const skir::reflection::OptionalType &input) {
    return false;
  }
  static void Append(const skir::reflection::OptionalType &input,
                     ReadableJson &out);
  static void Parse(JsonTokenizer &tokenizer,
                    skir::reflection::OptionalType &out);
};

struct ReflectionArrayTypeAdapter {
  static bool IsDefault(const skir::reflection::ArrayType &input) {
    return false;
  }
  static void Append(const skir::reflection::ArrayType &input,
                     ReadableJson &out);
  static void Parse(JsonTokenizer &tokenizer, skir::reflection::ArrayType &out);
};

struct ReflectionRecordTypeAdapter {
  static bool IsDefault(const skir::reflection::RecordType &input) {
    return false;
  }
  static void Append(const skir::reflection::RecordType &input,
                     ReadableJson &out);
  static void Parse(JsonTokenizer &tokenizer,
                    skir::reflection::RecordType &out);
};

struct ReflectionFieldAdapter {
  static bool IsDefault(const skir::reflection::Field &) { return false; }
  static void Append(const skir::reflection::Field &input, ReadableJson &out);
  static void Parse(JsonTokenizer &tokenizer, skir::reflection::Field &out);
};

struct ReflectionVariantAdapter {
  static bool IsDefault(const skir::reflection::Variant &) { return false; }
  static void Append(const skir::reflection::Variant &input, ReadableJson &out);
  static void Parse(JsonTokenizer &tokenizer, skir::reflection::Variant &out);
};

struct ReflectionRecordAdapter {
  static bool IsDefault(const skir::reflection::Record &input) { return false; }
  static void Append(const skir::reflection::Record &input, ReadableJson &out);
  static void Parse(JsonTokenizer &tokenizer, skir::reflection::Record &out);
};

struct ReflectionTypeDescriptorAdapter {
  static bool IsDefault(const skir::reflection::TypeDescriptor &input) {
    return false;
  }
  static void Append(const skir::reflection::TypeDescriptor &input,
                     ReadableJson &out);
  static void Parse(JsonTokenizer &tokenizer,
                    skir::reflection::TypeDescriptor &out);
};

inline ReflectionTypeAdapter GetAdapter(skir_type<skir::reflection::Type>);
inline ReflectionPrimitiveTypeAdapter
    GetAdapter(skir_type<skir::reflection::PrimitiveType>);
inline ReflectionOptionalTypeAdapter
    GetAdapter(skir_type<skir::reflection::OptionalType>);
inline ReflectionArrayTypeAdapter
    GetAdapter(skir_type<skir::reflection::ArrayType>);
inline ReflectionRecordTypeAdapter
    GetAdapter(skir_type<skir::reflection::RecordType>);
inline ReflectionFieldAdapter GetAdapter(skir_type<skir::reflection::Field>);
inline ReflectionVariantAdapter
    GetAdapter(skir_type<skir::reflection::Variant>);
inline ReflectionRecordAdapter GetAdapter(skir_type<skir::reflection::Record>);
inline ReflectionTypeDescriptorAdapter
    GetAdapter(skir_type<skir::reflection::TypeDescriptor>);

// =============================================================================
// END serialization of type descriptors
// =============================================================================

template <typename T> using TypeAdapter = decltype(GetAdapter(skir_type<T>()));

template <typename T> bool IsDefault(const T &input) {
  return TypeAdapter<T>::IsDefault(input);
}
template <typename T, typename Out> void Append(const T &input, Out &out) {
  TypeAdapter<T>::Append(input, out);
}
template <typename Source, typename T> void Parse(Source &source, T &out) {
  TypeAdapter<T>::Parse(source, out);
}
template <typename T> skir::reflection::Type GetType() {
  return TypeAdapter<T>::GetType(skir_type<T>());
}

template <typename T>
void RegisterRecords(skir::reflection::RecordRegistry &registry) {
  TypeAdapter<T>::RegisterRecords(skir_type<T>(), registry);
}

template <typename T> std::string ToDebugString(const T &input) {
  static_assert(!std::is_pointer<T>::value,
                "Can't pass a pointer to ToDebugString");
  skir_internal::DebugString result;
  Append(input, result);
  return result.out;
}

inline std::string ToDebugString(const char *absl_nonnull input) {
  return ToDebugString(std::string(input));
}

template <typename T> std::false_type is_optional(T) {
  return std::false_type();
}
template <typename T> std::true_type is_optional(absl::optional<T>) {
  return std::true_type();
}

struct OptionalAdapter {
  template <typename T> static bool IsDefault(const absl::optional<T> &input) {
    static_assert(
        std::is_same<decltype(is_optional(T())), std::false_type>::value);
    return !input.has_value();
  }

  template <typename T, typename Out>
  static void Append(const absl::optional<T> &input, Out &out) {
    if (input.has_value()) {
      TypeAdapter<T>::Append(*input, out);
    } else {
      out.out += {'n', 'u', 'l', 'l'};
    }
  }

  template <typename T>
  static void Append(const absl::optional<T> &input, DebugString &out) {
    if (input.has_value()) {
      out.out += "absl::make_optional(";
      TypeAdapter<T>::Append(*input, out);
      out.out += ')';
    } else {
      out.out += "absl::nullopt";
    }
  }

  template <typename T>
  static void Append(const absl::optional<T> &input, ByteSink &out) {
    if (input.has_value()) {
      TypeAdapter<T>::Append(*input, out);
    } else {
      out.Push(255);
    }
  }

  template <typename T>
  static void Parse(JsonTokenizer &tokenizer, absl::optional<T> &out) {
    if (tokenizer.state().token_type == JsonTokenType::kNull) {
      tokenizer.Next();
    } else {
      skir_internal::Parse(tokenizer, out.emplace());
    }
  }

  template <typename T>
  static void Parse(ByteSource &source, absl::optional<T> &out) {
    if (source.PeekWire() == 255) {
      ++(source.pos);
    } else {
      TypeAdapter<T>::Parse(source, out.emplace());
    }
  }

  template <typename T>
  static skir::reflection::Type GetType(skir_type<absl::optional<T>>) {
    return skir::reflection::OptionalType{skir_internal::GetType<T>()};
  }

  template <typename T>
  static void RegisterRecords(skir_type<absl::optional<T>>,
                              skir::reflection::RecordRegistry &registry) {
    skir_internal::RegisterRecords<T>(registry);
  }

  static constexpr bool IsStruct() { return false; }
  static constexpr bool IsEnum() { return false; }
};

template <typename T>
inline OptionalAdapter GetAdapter(skir_type<absl::optional<T>>);

template <typename GetKey> void MakeKeyChain(std::vector<std::string> &out) {
  using other_type = typename GetKey::other_type;
  MakeKeyChain<other_type>(out);
  out.emplace_back(GetKey::kFieldName);
}
template <>
inline void MakeKeyChain<skir::identity>(std::vector<std::string> &out) {}

struct ArrayAdapter {
  template <typename Input> static bool IsDefault(const Input &input) {
    return input.empty();
  }

  template <typename Input>
  static void Append(const Input &input, DenseJson &out) {
    using T = typename Input::value_type;
    if (input.empty()) {
      out.out += {'[', ']'};
    } else {
      out.out += '[';
      TypeAdapter<T>::Append(input[0], out);
      for (size_t i = 1; i < input.size(); ++i) {
        out.out += ',';
        TypeAdapter<T>::Append(input[i], out);
      }
      out.out += ']';
    }
  }

  template <typename Input>
  static void Append(const Input &input, ReadableJson &out) {
    using T = typename Input::value_type;
    if (input.empty()) {
      out.out += {'[', ']'};
    } else {
      out.out += '[';
      out.out += out.new_line.Indent();
      TypeAdapter<T>::Append(input[0], out);
      for (size_t i = 1; i < input.size(); ++i) {
        out.out += ',';
        out.out += *out.new_line;
        TypeAdapter<T>::Append(input[i], out);
      }
      out.out += out.new_line.Dedent();
      out.out += ']';
    }
  }

  template <typename Input>
  static void Append(const Input &input, DebugString &out) {
    using T = typename Input::value_type;
    if (input.empty()) {
      out.out += {'{', '}'};
    } else {
      out.out += '{';
      out.new_line.Indent();
      for (const T &element : input) {
        out.out += *out.new_line;
        TypeAdapter<T>::Append(element, out);
        out.out += ',';
      }
      out.out += out.new_line.Dedent();
      out.out += '}';
    }
  }

  template <typename Input>
  static void Append(const Input &input, ByteSink &out) {
    using T = typename Input::value_type;
    AppendArrayPrefix(input.size(), out);
    for (const T &item : input) {
      TypeAdapter<T>::Append(item, out);
    }
  }

  template <typename Out>
  static void Parse(JsonTokenizer &tokenizer, Out &out) {
    switch (tokenizer.state().token_type) {
    case JsonTokenType::kLeftSquareBracket:
      break;
    case JsonTokenType::kZero:
      tokenizer.Next();
      return;
    default:
      tokenizer.mutable_state().PushErrorAtPosition("'['");
    }
    JsonArrayReader array_reader(&tokenizer);
    while (array_reader.NextElement()) {
      ParseAndPush(tokenizer, out);
    }
  }

  template <typename Out> static void Parse(ByteSource &source, Out &out) {
    uint32_t length = 0;
    ParseArrayPrefix(source, length);
    if (source.num_bytes_left() < length) {
      return source.RaiseError();
    };
    out.reserve(length);
    for (size_t i = 0; i < length; ++i) {
      if (source.error)
        return;
      ParseAndPush(source, out);
    }
  }

  template <typename T>
  static skir::reflection::Type GetType(skir_type<std::vector<T>>) {
    return skir::reflection::ArrayType{skir_internal::GetType<T>()};
  }

  template <typename T, typename GetKey>
  static skir::reflection::Type
  GetType(skir_type<skir::keyed_items<T, GetKey>>) {
    std::vector<std::string> key_chain;
    MakeKeyChain<GetKey>(key_chain);
    return skir::reflection::ArrayType{skir_internal::GetType<T>(),
                                       absl::StrJoin(key_chain, ".")};
  }

  template <typename T>
  static void RegisterRecords(skir_type<T>,
                              skir::reflection::RecordRegistry &registry) {
    skir_internal::RegisterRecords<typename T::value_type>(registry);
  }

  static constexpr bool IsStruct() { return false; }
  static constexpr bool IsEnum() { return false; }

private:
  template <typename Source>
  static void ParseAndPush(Source &source, std::vector<bool> &out) {
    bool item{};
    BoolAdapter::Parse(source, item);
    out.push_back(item);
  }

  template <typename Source, typename T>
  static void ParseAndPush(Source &source, std::vector<T> &out) {
    T &item = out.emplace_back();
    TypeAdapter<T>::Parse(source, item);
  }

  template <typename Source, typename T, typename GetKey>
  static void ParseAndPush(Source &source, skir::keyed_items<T, GetKey> &out) {
    T item{};
    TypeAdapter<T>::Parse(source, item);
    out.push_back(std::move(item));
  }
};

template <typename T> inline ArrayAdapter GetAdapter(skir_type<std::vector<T>>);

template <typename T, typename GetKey>
inline ArrayAdapter GetAdapter(skir_type<skir::keyed_items<T, GetKey>>);

struct RecAdapter {
  template <typename T> static bool IsDefault(const skir::rec<T> &input) {
    return input.value_ == nullptr || TypeAdapter<T>::IsDefault(*input);
  }

  template <typename T>
  static void Append(const skir::rec<T> &input, DenseJson &out) {
    if (input.value_ == nullptr) {
      out.out += {'[', ']'};
    } else {
      TypeAdapter<T>::Append(*input, out);
    }
  }

  template <typename T>
  static void Append(const skir::rec<T> &input, ReadableJson &out) {
    if (input.value_ == nullptr) {
      out.out += {'{', '}'};
    } else {
      TypeAdapter<T>::Append(*input, out);
    }
  }

  template <typename T>
  static void Append(const skir::rec<T> &input, DebugString &out) {
    if (input.value_ == nullptr) {
      out.out += {'{', '}'};
    } else {
      TypeAdapter<T>::Append(*input, out);
    }
  }

  template <typename T>
  static void Append(const skir::rec<T> &input, ByteSink &out) {
    if (input.value_ == nullptr) {
      out.Push(246);
    } else {
      TypeAdapter<T>::Append(*input, out);
    }
  }

  template <typename T>
  static void Parse(JsonTokenizer &tokenizer, skir::rec<T> &out) {
    TypeAdapter<T>::Parse(tokenizer, *out);
  }

  template <typename T>
  static void Parse(ByteSource &source, skir::rec<T> &out) {
    return TypeAdapter<T>::Parse(source, *out);
  }

  template <typename T>
  static skir::reflection::Type GetType(skir_type<skir::rec<T>>) {
    return skir_internal::GetType<T>();
  }

  template <typename T>
  static void RegisterRecords(skir_type<skir::rec<T>>,
                              skir::reflection::RecordRegistry &registry) {
    skir_internal::RegisterRecords<T>(registry);
  }

  static constexpr bool IsStruct() { return false; }
  static constexpr bool IsEnum() { return false; }
};

template <typename T> inline RecAdapter GetAdapter(skir_type<skir::rec<T>>);

class JsonObjectWriter {
public:
  JsonObjectWriter(ReadableJson *absl_nonnull out) : out_(*out) {}

  ~JsonObjectWriter() {
    if (has_content_) {
      out_.out += out_.new_line.Dedent();
      out_.out += '}';
    } else {
      out_.out += {'{', '}'};
    }
  }

  template <typename T>
  JsonObjectWriter &Write(const char *absl_nonnull field_name, const T &value) {
    if (!TypeAdapter<T>::IsDefault(value)) {
      WriteEvenIfDefault(field_name, value);
    }
    return *this;
  }

  template <typename T>
  JsonObjectWriter &WriteEvenIfDefault(const char *absl_nonnull field_name,
                                       const T &value) {
    struct value_writer {
      const T &value_;

      void operator()(ReadableJson &out) const {
        TypeAdapter<T>::Append(value_, out);
      }
    };
    return WriteImpl(field_name, value_writer{value});
  }

  JsonObjectWriter &Write(const char *absl_nonnull field_name,
                          const ReadableJson &value) {
    struct value_writer {
      const ReadableJson &value_;

      void operator()(ReadableJson &out) const {
        out.out += absl::StrReplaceAll(value_.out, {{"\n", *out.new_line}});
      }
    };
    return WriteImpl(field_name, value_writer{value});
  }

  template <typename value_writer_t>
  JsonObjectWriter &WriteImpl(const char *absl_nonnull field_name,
                              value_writer_t value_writer) {
    if (has_content_) {
      out_.out += ',';
      out_.out += *out_.new_line;
    } else {
      out_.out += "{";
      out_.out += out_.new_line.Indent();
      has_content_ = true;
    }
    out_.out += '"';
    out_.out += field_name;
    out_.out += "\": ";
    value_writer(out_);
    return *this;
  }

private:
  ReadableJson &out_;
  bool has_content_ = false;
};

class StructJsonObjectParserImpl {
public:
  template <typename T, typename field_value>
  void AddField(const std::string &name,
                field_value T::*absl_nonnull data_member) {
    fields_[name] = std::make_unique<FieldImpl<T, field_value>>(data_member);
  }

  void Parse(JsonTokenizer &tokenizer, void *absl_nonnull out) const;

private:
  struct Field {
    virtual ~Field() = default;
    virtual void Parse(JsonTokenizer &tokenizer,
                       void *absl_nonnull out) const = 0;
  };
  absl::flat_hash_map<std::string, std::unique_ptr<Field>> fields_;

  template <typename T, typename field_value> struct FieldImpl : public Field {
    FieldImpl(field_value T::*absl_nonnull data_member)
        : data_member_(data_member) {}
    void Parse(JsonTokenizer &tokenizer,
               void *absl_nonnull out) const override {
      ::skir_internal::Parse(tokenizer, static_cast<T *>(out)->*data_member_);
    }
    field_value T::*absl_nonnull const data_member_;
  };
};

template <typename T> class StructJsonObjectParser {
public:
  template <typename field_value>
  StructJsonObjectParser *absl_nonnull
  AddField(const std::string &name, field_value T::*absl_nonnull data_member) {
    impl_.AddField<T>(name, data_member);
    return this;
  }

  void Parse(JsonTokenizer &tokenizer, T &out) const {
    impl_.Parse(tokenizer, &out);
  }

private:
  StructJsonObjectParserImpl impl_;
};

class EnumJsonObjectParserImpl {
public:
  template <typename T, typename WrapperType>
  void AddVariant(const std::string &name) {
    variants_[name] = std::make_unique<VariantImpl<T, WrapperType>>();
  }

  template <typename T, typename ValueType>
  void AddVariantAsVariant(const std::string &name) {
    variants_[name] = std::make_unique<VariantAsVariantImpl<T, ValueType>>();
  }

  void Parse(JsonTokenizer &tokenizer, void *absl_nonnull out) const;

private:
  struct Variant {
    virtual ~Variant() = default;
    virtual void Parse(JsonTokenizer &tokenizer,
                       void *absl_nonnull out) const = 0;
  };
  absl::flat_hash_map<std::string, std::unique_ptr<Variant>> variants_;

  template <typename T, typename WrapperType>
  struct VariantImpl : public Variant {
    void Parse(JsonTokenizer &tokenizer,
               void *absl_nonnull out) const override {
      WrapperType wrapper;
      ::skir_internal::Parse(tokenizer, wrapper.value);
      *static_cast<T *>(out) = std::move(wrapper);
    }
  };

  template <typename T, typename ValueType>
  struct VariantAsVariantImpl : public Variant {
    void Parse(JsonTokenizer &tokenizer,
               void *absl_nonnull out) const override {
      ValueType value;
      ::skir_internal::Parse(tokenizer, value);
      *static_cast<T *>(out) = std::move(value);
    }
  };
};

template <typename T> class EnumJsonObjectParser {
public:
  template <typename WrapperType>
  EnumJsonObjectParser *absl_nonnull AddVariant(const std::string &name) {
    impl_.AddVariant<T, WrapperType>(name);
    return this;
  }

  template <typename ValueType>
  EnumJsonObjectParser *absl_nonnull
  AddVariantAsVariant(const std::string &name) {
    impl_.AddVariantAsVariant<T, ValueType>(name);
    return this;
  }

  void Parse(JsonTokenizer &tokenizer, T &out) const {
    impl_.Parse(tokenizer, &out);
  }

private:
  EnumJsonObjectParserImpl impl_;
};

class EnumJsonArrayParser {
public:
  EnumJsonArrayParser(JsonTokenizer *absl_nonnull tokenizer);

  int ReadNumber();
  void Finish();

private:
  JsonTokenizer &tokenizer_;
};

class DebugObjectWriter {
public:
  DebugObjectWriter(DebugString *absl_nonnull out) : out_(*out) {}

  ~DebugObjectWriter() {
    if (has_content_) {
      out_.out += out_.new_line.Dedent();
      out_.out += '}';
    } else {
      out_.out += {'{', '}'};
    }
  }

  template <typename T>
  DebugObjectWriter &Write(const char *absl_nonnull field_name,
                           const T &value) {
    if (!TypeAdapter<T>::IsDefault(value)) {
      if (has_content_) {
        out_.out += *out_.new_line;
      } else {
        out_.out += "{";
        out_.out += out_.new_line.Indent();
        has_content_ = true;
      }
      out_.out += '.';
      out_.out += field_name;
      out_.out += ": ";
      TypeAdapter<T>::Append(value, out_);
      out_.out += ',';
    }
    return *this;
  }

private:
  DebugString &out_;
  bool has_content_ = false;
};

std::pair<bool, int32_t> ParseEnumPrefix(ByteSource &source);

enum class UnrecognizedFormat {
  kUnknown,
  kDenseJson,
  kBytes,
};

class UnrecognizedValues {
public:
  void ParseFrom(JsonTokenizer &tokenizer);
  void ParseFrom(ByteSource &source);
  void AppendTo(DenseJson &out) const;
  void AppendTo(ByteSink &out) const;

private:
  ByteSink bytes_;
  std::vector<uint32_t> array_lengths_;
};

struct UnrecognizedFieldsData {
  UnrecognizedFormat format = UnrecognizedFormat::kUnknown;
  uint32_t array_len = 0;
  UnrecognizedValues values;
};

template <typename Adapter> struct UnrecognizedFields {
private:
  std::shared_ptr<UnrecognizedFieldsData> data;
  friend Adapter;
};

struct UnrecognizedVariant {
  UnrecognizedFormat format = UnrecognizedFormat::kUnknown;
  int32_t number = 0;
  // Null if just a number with no value.
  std::shared_ptr<UnrecognizedValues> value;

  UnrecognizedValues &emplace_value() {
    return *(value = std::make_shared<UnrecognizedValues>());
  }
};

void AppendUnrecognizedVariant(const UnrecognizedVariant *absl_nullable input,
                               DenseJson &out);
void AppendUnrecognizedVariant(const UnrecognizedVariant *absl_nullable input,
                               ByteSink &out);

void ParseUnrecognizedFields(JsonArrayReader &array_reader, size_t num_slots,
                             size_t num_slots_incl_removed,
                             std::shared_ptr<UnrecognizedFieldsData> &out);

void ParseUnrecognizedFields(ByteSource &source, size_t array_len,
                             size_t num_slots, size_t num_slots_incl_removed,
                             std::shared_ptr<UnrecognizedFieldsData> &out);

template <typename HttplibHeaders>
void SkirToHttplibHeaders(const skir::service::HttpHeaders &input,
                          HttplibHeaders &out) {
  for (const auto &[name, values] : input.map()) {
    for (const absl::string_view value : values) {
      out.insert({std::string(name), std::string(value)});
    }
  }
}

template <typename HttplibHeaders>
skir::service::HttpHeaders HttplibToSkirHeaders(const HttplibHeaders &input) {
  skir::service::HttpHeaders result;
  for (const auto &[name, value] : input) {
    result.Insert(name, value);
  }
  return result;
}

template <typename MethodsTuple, std::size_t... Indices>
constexpr bool unique_method_numbers_impl(std::index_sequence<Indices...>) {
  constexpr std::array<int64_t, sizeof...(Indices)> numbers = {
      std::get<Indices>(MethodsTuple()).kNumber...};
  for (std::size_t i = 0; i < sizeof...(Indices); ++i) {
    for (std::size_t j = i + 1; j < sizeof...(Indices); ++j) {
      if (numbers[i] == numbers[j]) {
        return false;
      }
    }
  }
  return true;
}

template <typename MethodsTuple> constexpr bool unique_method_numbers() {
  return unique_method_numbers_impl<MethodsTuple>(
      std::make_index_sequence<std::tuple_size_v<MethodsTuple>>{});
}

template <typename MethodsTuple> void assert_unique_method_numbers() {
  static_assert(unique_method_numbers<MethodsTuple>(),
                "Method numbers are not unique");
}

} // namespace skir_internal

namespace skir {

// Deserializes a skir value.
// The input string can either be:
//   - the JSON returned by skir::ToDenseJson or skir::ToReadableJson
//   - the bytes returned by skir::ToBytes
template <typename T>
absl::StatusOr<T> Parse(absl::string_view bytes_or_json,
                        UnrecognizedValuesPolicy unrecognized_values =
                            UnrecognizedValuesPolicy::kDrop) {
  T result{};
  if (bytes_or_json.length() >= 4 && bytes_or_json[0] == 's' &&
      bytes_or_json[1] == 'k' && bytes_or_json[2] == 'i' &&
      bytes_or_json[3] == 'r') {
    bytes_or_json = bytes_or_json.substr(4);
    skir_internal::ByteSource byte_source(bytes_or_json.data(),
                                          bytes_or_json.length());
    byte_source.keep_unrecognized_values =
        unrecognized_values == UnrecognizedValuesPolicy::kKeep;
    skir_internal::Parse(byte_source, result);
    if (byte_source.error || byte_source.pos < byte_source.end) {
      return absl::UnknownError("error while decoding skir value from bytes");
    }
  } else {
    skir_internal::JsonTokenizer tokenizer(
        bytes_or_json.begin(), bytes_or_json.end(), unrecognized_values);
    tokenizer.Next();
    skir_internal::Parse(tokenizer, result);
    if (tokenizer.state().token_type != skir_internal::JsonTokenType::kStrEnd) {
      tokenizer.mutable_state().PushUnexpectedTokenError("end");
    }
    const absl::Status status = tokenizer.state().status;
    if (!status.ok())
      return status;
  }
  return result;
}

// Serializes the given value to dense JSON format.
template <typename T> std::string ToDenseJson(const T &input) {
  static_assert(!std::is_pointer<T>::value,
                "Can't pass a pointer to ToDenseJson");
  skir_internal::DenseJson dense_json;
  Append(input, dense_json);
  return std::move(dense_json).out;
}

inline std::string ToDenseJson(const char *absl_nonnull input) {
  return ToDenseJson(std::string(input));
}

// Serializes the given value to readable JSON format.
template <typename T> std::string ToReadableJson(const T &input) {
  static_assert(!std::is_pointer<T>::value,
                "Can't pass a pointer to ToReadableJson");
  skir_internal::ReadableJson readable_json;
  Append(input, readable_json);
  return std::move(readable_json).out;
}

inline std::string ToReadableJson(const char *absl_nonnull input) {
  return ToReadableJson(std::string(input));
}

// Serializes the given value to binary format.
template <typename T> ByteString ToBytes(const T &input) {
  static_assert(!std::is_pointer<T>::value, "Can't pass a pointer to ToBytes");
  skir_internal::ByteSink byte_sink;
  byte_sink.Push('s', 'k', 'i', 'r');
  Append(input, byte_sink);
  return std::move(byte_sink).ToByteString();
}

inline ByteString ToBytes(const char *absl_nonnull input) {
  return ToBytes(std::string(input));
}

// Minimum absl::Time encodable as a skir timestamp.
// Equal to 100M days before the Unix EPOCH.
constexpr absl::Time kMinEncodedTimestamp =
    absl::FromUnixMillis(-8640000000000000);
// Maximum absl::Time encodable as a skir timestamp.
// Equal to 100M days before the Unix EPOCH.
constexpr absl::Time kMaxEncodedTimestamp =
    absl::FromUnixMillis(8640000000000000);

template <typename H, typename T> H AbslHashValue(H h, const rec<T> &rec) {
  if (::skir_internal::RecAdapter::IsDefault(rec)) {
    return H::combine(std::move(h), -6387689);
  } else {
    return H::combine(std::move(h), *rec);
  }
}

namespace reflection {

template <typename T> const TypeDescriptor &GetTypeDescriptor() {
  static const TypeDescriptor *result = []() -> const TypeDescriptor * {
    RecordRegistry registry;
    skir_internal::RegisterRecords<T>(registry);
    return new TypeDescriptor{skir_internal::GetType<T>(), std::move(registry)};
  }();
  return *result;
}

template <typename T> constexpr bool IsStruct() {
  return skir_internal::TypeAdapter<T>::IsStruct();
}

template <typename T> constexpr bool IsEnum() {
  return skir_internal::TypeAdapter<T>::IsEnum();
}

template <typename T> constexpr bool IsRecord() {
  return IsStruct<T>() || IsEnum<T>();
}

// Calls f(field) for each field in the skir-generated datatype.
// The type of the single argument passed to f is struct_field.
template <typename Record, typename F> void ForEachField(F &&f) {
  static_assert(IsStruct<Record>());
  std::apply(
      [&f](auto &&...x) {
        (static_cast<void>(f(std::forward<decltype(x)>(x))), ...);
      },
      typename skir_internal::TypeAdapter<Record>::fields_tuple());
}

// Calls f(variant) for each variant in the skir-generated datatype.
// The type of the single argument passed to f is either enum_const_variant
// or enum_wrapper_variant.
template <typename Record, typename F> void ForEachVariant(F &&f) {
  static_assert(IsEnum<Record>());
  std::apply(
      [&f](auto &&...x) {
        (static_cast<void>(f(std::forward<decltype(x)>(x))), ...);
      },
      typename skir_internal::TypeAdapter<Record>::variants_tuple());
}

} // namespace reflection
} // namespace skir

namespace skir_internal {

struct RequestBody {
  std::string method_name;
  absl::optional<int64_t> method_number;
  bool readable = true;
  absl::string_view request_data;

  absl::Status Parse(absl::string_view request_body);
};

struct MethodDescriptor {
  absl::string_view name;
  int64_t number = 0;
  ReadableJson request_descriptor_json;
  ReadableJson response_descriptor_json;
  std::string doc;
};

template <typename Method>
MethodDescriptor MakeMethodDescriptor(Method method) {
  MethodDescriptor result;
  result.name = Method::kMethodName;
  result.number = Method::kNumber;
  result.request_descriptor_json.out =
      skir::reflection::GetTypeDescriptor<typename Method::request_type>()
          .AsJson();
  result.response_descriptor_json.out =
      skir::reflection::GetTypeDescriptor<typename Method::response_type>()
          .AsJson();
  result.doc = Method::kDoc;
  return result;
}

struct MethodList {
  std::vector<MethodDescriptor> methods;
};

struct MethodDescriptorAdapter {
  static bool IsDefault(const MethodDescriptor &input) { return false; }
  static void Append(const MethodDescriptor &input, ReadableJson &out);
};

struct MethodListAdapter {
  static bool IsDefault(const MethodList &input) { return false; }
  static void Append(const MethodList &input, ReadableJson &out);
};

inline MethodDescriptorAdapter GetAdapter(skir_type<MethodDescriptor>);
inline MethodListAdapter GetAdapter(skir_type<MethodList>);

std::string GetStudioHtml(absl::string_view studio_app_js_url);

template <typename ServiceImpl, typename RequestMeta> class HandleRequestOp {
public:
  HandleRequestOp(ServiceImpl *absl_nonnull service_impl,
                  absl::string_view request_body,
                  const skir::service::ServiceOptions *absl_nonnull options,
                  const RequestMeta *absl_nonnull request_meta)
      : service_impl_(*service_impl), request_body_(request_body),
        options_(*options), request_meta_(*request_meta) {}

  skir::service::RawResponse Run() {
    if (request_body_ == "list") {
      MethodList method_list;
      std::apply(
          [&](auto... method) {
            (method_list.methods.push_back(MakeMethodDescriptor(method)), ...);
          },
          typename ServiceImpl::methods());
      ReadableJson json;
      MethodListAdapter::Append(method_list, json);
      return skir_internal::MakeOkJsonResponse(json.out);
    } else if (request_body_ == "" || request_body_ == "studio") {
      return skir_internal::MakeOkHtmlResponse(
          GetStudioHtml(options_.studio_app_js_url));
    }

    if (const absl::Status status = request_body_parsed_.Parse(request_body_);
        !status.ok()) {
      return skir_internal::MakeBadRequestResponse(
          absl::StrCat("bad request: ", status.message()));
    }

    std::apply(
        [&](auto... method) {
          (static_cast<void>(MaybeInvokeMethod(method)), ...);
        },
        typename ServiceImpl::methods());
    if (raw_response_.has_value()) {
      return std::move(*raw_response_);
    }
    return skir_internal::MakeBadRequestResponse(absl::StrCat(
        "bad request: method not found: ", request_body_parsed_.method_name,
        "; number: ", request_body_parsed_.method_number.value_or(-1)));
  }

private:
  ServiceImpl &service_impl_;
  const absl::string_view request_body_;
  const skir::service::ServiceOptions &options_;
  const RequestMeta &request_meta_;

  RequestBody request_body_parsed_;

  absl::optional<skir::service::RawResponse> raw_response_;

  template <typename Method> void MaybeInvokeMethod(Method method) {
    using MethodType = decltype(method);
    using RequestType = typename MethodType::request_type;
    using ResponseType = typename MethodType::response_type;
    if (request_body_parsed_.method_number.has_value()) {
      if (MethodType::kNumber != *request_body_parsed_.method_number)
        return;
    } else {
      if (MethodType::kMethodName != request_body_parsed_.method_name)
        return;
    }
    if (raw_response_.has_value()) {
      // Should only happen if multiple methods have the same name and the
      // request does not specify the method number. We should probably return
      // an error in this case.
      return;
    }
    absl::StatusOr<RequestType> request = skir::Parse<RequestType>(
        request_body_parsed_.request_data, options_.unrecognized_values);
    if (!request.ok()) {
      raw_response_ = skir_internal::MakeBadRequestResponse(
          absl::StrCat("bad request: ", request.status().message()));
      return;
    }
    skir::service::ErrorOr<ResponseType> response_or_error =
        service_impl_(method, std::move(*request), request_meta_);
    if (!response_or_error.ok()) {
      auto &error = std::get<skir::service::Error>(response_or_error.variant());
      raw_response_ = skir_internal::MakeServerErrorResponse(
          std::move(error.message), int(error.code));
      return;
    }
    const auto &response = std::get<ResponseType>(response_or_error.variant());
    if (request_body_parsed_.readable) {
      raw_response_ =
          skir_internal::MakeOkJsonResponse(skir::ToReadableJson(response));
    } else {
      raw_response_ =
          skir_internal::MakeOkJsonResponse(skir::ToDenseJson(response));
    }
  }
};

template <typename HttplibClientPtr>
class HttplibClient : public skir::service::Client {
public:
  HttplibClient(HttplibClientPtr client, std::string query_path)
      : client_(std::move(ABSL_DIE_IF_NULL(client))), query_path_(query_path) {}

  absl::StatusOr<std::string>
  operator()(absl::string_view request_data,
             const skir::service::HttpHeaders &request_headers) const {
    auto headers =
        decltype(std::declval<HttplibClientPtr>()->Get("")->headers)();
    SkirToHttplibHeaders(request_headers, headers);
    auto result =
        client_->Post(query_path_, headers, request_data.data(),
                      request_data.length(), "text/plain; charset=utf-8");
    if (result) {
      const int status_code = result->status;
      if (200 <= status_code && status_code <= 299) {
        // OK status.
        return std::move(result->body);
      } else {
        const std::string content_type =
            result->get_header_value("Content-Type");
        const bool body_is_text =
            content_type == "text/plain" ||
            absl::StartsWith(content_type, "text/plain ") ||
            absl::StartsWith(content_type, "text/plain;");
        return absl::UnknownError(absl::StrCat(
            "HTTP response status ", status_code, body_is_text ? ": " : "",
            body_is_text ? result->body : ""));
      }
    } else {
      // HTTP error.
      std::stringstream ss;
      ss << "HTTP error: " << result.error();
      return {absl::UnknownError(ss.str())};
    }
  }

private:
  const HttplibClientPtr client_;
  const std::string query_path_;
};

} // namespace skir_internal

namespace skir {
namespace service {

// On the server side, parses the content of a user request and invokes the
// appropriate method on the given service implementation.
//
// ServiceImpl must satisfy the following requirements:
//   1. It must have a public `methods` type alias which resolves to a tuple of
// //     method types.
//   2. For each method, it must have a member function with this signature:
//
//        absl::StatusOr<typename Method::response_type> operator()(
//            Method method,
//            typename Method::request_type request,
//            const HttpHeaders& request_headers);
//
//      Or, if you want to specify a specific HTTP status code other than 500
//      in case of an error, use ErrorOr<typename Method::response_type>
//      instead of absl::StatusOr<typename Method::response_type>.
//
// For example:
//
//   class MyServiceImpl {
//    public:
//     using methods = std::tuple<
//          skirout_methods::ListUsers,
//          skirout_methods::GetUser>;
//
//     absl::StatusOr<skirout_methods::ListUsersResponse> operator()(
//         skirout_methods::ListUsers,
//         skirout_methods::ListUsersRequest request,
//         const HttpHeaders& request_headers) const {
//       ...
//     }
//
//     absl::StatusOr<skirout_methods::GetUserResponse> operator()(
//         skirout_methods::GetUser,
//         skirout_methods::GetUserRequest request,
//         const HttpHeaders& request_headers) const {
//       ...
//     }
//   };
//
// If you are using cpp-httplib (https://github.com/yhirose/cpp-httplib) as
// your server library, you don't need to call HandleRequest, you can simply
// call InstallServiceOnHttplibServer. If you are using another server library,
// call HandleRequest in the logic for installing a SkirRPC service on your
// server.
//
// If the request is a GET request, pass in the decoded query string as the
// request's body. The query string is the part of the URL after '?', and it can
// be decoded with DecodeUrlQueryString.
template <typename ServiceImpl>
RawResponse HandleRequest(ServiceImpl &service_impl,
                          absl::string_view request_body,
                          const HttpHeaders &request_headers,
                          const ServiceOptions &options = {}) {
  skir_internal::assert_unique_method_numbers<typename ServiceImpl::methods>();
  return skir_internal::HandleRequestOp(&service_impl, request_body, &options,
                                        &request_headers)
      .Run();
}

// Decodes the given query string encoded with Javascript's
// encodeURIComponent functon.
// For example: "foo%20%3F%3D%23" -> "foo ?=#"
absl::StatusOr<std::string>
DecodeUrlQueryString(absl::string_view encoded_query_string);

// Installs a SkirRPC service on the given httplib::Server at the given query
// path. The httplib::Server type is referred to as a template parameter so as
// not to make cpp-httplib a dependency of skir.
//
// ServiceImpl must satisfy the requirements outlined in the documentation for
// HandleRequest.
template <typename HttplibServer, typename ServiceImpl>
void InstallServiceOnHttplibServer(HttplibServer &server,
                                   absl::string_view query_path,
                                   std::shared_ptr<ServiceImpl> service_impl,
                                   const ServiceOptions &options = {}) {
  ABSL_CHECK_NE(service_impl, nullptr);
  const typename HttplibServer::Handler handler = //
      [service_impl, options](const auto &req, auto &resp) {
        const HttpHeaders request_headers =
            skir_internal::HttplibToSkirHeaders(req.headers);
        absl::string_view request_body;
        std::string decoded_query_string;
        if (!req.body.empty()) {
          request_body = req.body;
        } else {
          const absl::string_view target = req.target;
          absl::string_view query_string;
          const size_t index_of_question_mark = target.find('?');
          if (index_of_question_mark != absl::string_view::npos) {
            query_string = target.substr(index_of_question_mark + 1);
          }
          decoded_query_string =
              DecodeUrlQueryString(query_string).value_or("");
          request_body = decoded_query_string;
        }
        RawResponse raw_response = HandleRequest(*service_impl, request_body,
                                                 request_headers, options);

        resp.set_content(std::move(raw_response.data),
                         std::string(raw_response.content_type));
        resp.status = raw_response.status_code;
      };
  server.Get(std::string(query_path), handler);
  server.Post(std::string(query_path), handler);
}

// Invokes the given method on a remote server through an RPC.
// Returns an error status if there was a network error or if the server
// returned an error.
template <typename Method>
absl::StatusOr<typename Method::response_type>
InvokeRemote(const Client &client, Method method,
             const typename Method::request_type &request,
             const HttpHeaders &request_headers = {}) {
  const std::string request_data = absl::StrCat(
      Method::kMethodName, ":", Method::kNumber, "::", ToDenseJson(request));
  absl::StatusOr<std::string> response_data =
      client(request_data, request_headers);
  if (!response_data.ok()) {
    return std::move(response_data).status();
  }
  return Parse<typename Method::response_type>(*response_data,
                                               UnrecognizedValuesPolicy::kKeep);
}

// Returns a client for sending RPCs to a SkirRPC service via the given
// httplib::Client.
// The httplib::Client type is referred to as a template parameter so as not to
// make cpp-httplib a dependency of skir.
//
// If you are not using cpp-httplib, you can write your own Client
// implementation.
template <typename HttplibClient>
std::unique_ptr<Client> MakeHttplibClient(HttplibClient *absl_nonnull client,
                                          absl::string_view query_path) {
  return std::make_unique<skir_internal::HttplibClient<HttplibClient *>>(
      client, std::string(query_path));
};

// Returns a client for sending RPCs to a SkirRPC service via the given
// httplib::Client.
// The httplib::Client type is referred to as a template parameter so as not to
// make cpp-httplib a dependency of skir.
//
// If you are not using cpp-httplib, you can write your own Client
// implementation.
template <typename HttplibClient>
std::unique_ptr<Client> MakeHttplibClient(std::unique_ptr<HttplibClient> client,
                                          absl::string_view query_path) {
  return std::make_unique<
      skir_internal::HttplibClient<std::unique_ptr<HttplibClient>>>(
      std::move(client), std::string(query_path));
};

} // namespace service
} // namespace skir

#endif
