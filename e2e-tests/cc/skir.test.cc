#include "skir.h"

#include <gtest/gtest.h>

#include <cstdint>
#include <limits>
#include <memory>
#include <type_traits>
#include <utility>

#include "absl/container/flat_hash_set.h"
#include "absl/status/status.h"
#include "absl/status/statusor.h"
#include "absl/strings/str_cat.h"
#include "absl/time/time.h"
#include "reserializer.testing.h"
#include "gmock/gmock.h"

namespace {
using ::skir_testing_internal::HexToBytes;
using ::skir_testing_internal::MakeReserializer;
using ::testing::ElementsAre;
using ::testing::IsEmpty;
using ::testing::IsTrue;
using ::testing::Pair;
using ::testing::UnorderedElementsAre;

TEST(SkirlibTest, RecZeroArgCtor) {
  const skir::rec<std::string> rec;
  EXPECT_EQ(*rec, "");
  const std::string &ref_a = *rec;
  EXPECT_EQ(ref_a, "");
  const std::string &ref_b = *rec;
  EXPECT_EQ(ref_b, "");
  EXPECT_EQ(&ref_a, &ref_b);
}

TEST(SkirlibTest, RecCopyCtor) {
  skir::rec<int> a;
  a = 3;
  skir::rec<int> b(a);
  EXPECT_EQ(*b, 3);
  const int value = *b;
  EXPECT_EQ(value, 3);
}

TEST(SkirlibTest, RecMoveCtor) {
  skir::rec<int> a = 3;
  skir::rec<int> b(std::move(a));
  EXPECT_EQ(*b, 3);
}

TEST(SkirlibTest, RecCopyValueCtor) {
  skir::rec<int> a(3);
  EXPECT_EQ(*a, 3);
}

TEST(SkirlibTest, RecMutableStarOperator) {
  skir::rec<int> a(3);
  *a = 4;
  *a = 5;
  EXPECT_EQ(*a, 5);
  EXPECT_EQ(a, skir::rec<int>(5));

  int i = *std::move(a);
  EXPECT_EQ(i, 5);
}

TEST(SkirlibTest, RecImplicitConversion) {
  skir::rec<int> a(3);
  int &i = a;
  EXPECT_EQ(i, 3);
  i = 4;
  EXPECT_EQ(*a, 4);

  const skir::rec<int> b(3);
  const int &j = b;
  EXPECT_EQ(j, 3);
}

TEST(SkirlibTest, RecAssignment) {
  skir::rec<int> a(3);
  a = skir::rec<int>();
  EXPECT_EQ(*a, 0);
  a = 4;
  EXPECT_EQ(*a, 4);
}

TEST(SkirlibTest, RecValueAssignment) {
  skir::rec<int> a(3);
  a = 4;
  EXPECT_EQ(*a, 4);
}

TEST(SkirlibTest, RecAbslHash) { absl::flat_hash_set<skir::rec<int>>(); }

struct get_id {
  template <typename T> auto &&operator()(T &&input) const {
    return std::forward<T>(input).id;
  }
};

struct User {
  std::string id;
  std::string name;

  bool operator==(const User &other) const {
    return id == other.id && name == other.name;
  }
};

TEST(SkirlibTest, MustInit) {
  skir::must_init<std::string> s = "foo";
  skir::must_init<absl::optional<std::string>> o = absl::nullopt;
  skir::must_init<std::vector<std::string>> empty = {};
  skir::must_init<std::vector<std::string>> v = {"foo"};
  skir::must_init<skir::keyed_items<User, get_id>> keyed_items = {};
}

template <typename H> H AbslHashValue(H h, const User &user) {
  return H::combine(std::move(h), user.id, user.name);
}

TEST(SkirLibTest, KeyedItemsFind) {
  skir::keyed_items<User, get_id> users;
  static_assert(
      std::is_same_v<skir::key_type<User, get_id>, absl::string_view>);
  EXPECT_EQ(users.size(), 0);
  EXPECT_EQ(users.empty(), true);
  EXPECT_EQ(users.find_or_null("id_0"), nullptr);
  users.push_back({
      .id = "id_0",
      .name = "name_0",
  });
  ASSERT_EQ(users.vector().size(), 1);
  EXPECT_EQ(users.find_or_null("id_0"), &users.vector()[0]);
  for (int i = 1; i < 10; ++i) {
    users.push_back({
        .id = absl::StrCat("id_", i),
        .name = absl::StrCat("name_", i),
    });
  }
  EXPECT_EQ(users.size(), 10);
  EXPECT_EQ(users.empty(), false);
  ASSERT_EQ(users.vector().size(), 10);
  for (int i = 0; i < 10; ++i) {
    EXPECT_EQ(users.find_or_null(absl::StrCat("id_", i)), &users.vector()[i]);
  }
  EXPECT_NE(users.find_or_null("id_9"), nullptr);
  EXPECT_EQ(users.find_or_null("id_10"), nullptr);
  users.reserve(200);
  EXPECT_NE(users.find_or_null("id_9"), nullptr);
  EXPECT_EQ(users.find_or_null("id_10"), nullptr);
  for (int i = 10; i < 1000; ++i) {
    users.push_back({
        .id = absl::StrCat("id_", i),
        .name = absl::StrCat("name_", i),
    });
  }
  for (int i = 0; i < 1000; ++i) {
    EXPECT_EQ(users.find_or_null(absl::StrCat("id_", i)), &users.vector()[i]);
  }
  users.push_back({
      .id = "id_500",
      .name = "Pierre",
  });
  EXPECT_EQ(users.find_or_default("id_500").name, "name_500");
  User default_user;
  default_user.name = "DEFAULT";
  EXPECT_EQ(users.find_or_default("id_500", default_user).name, "name_500");
  EXPECT_EQ(users.find_or_default("id_1000", default_user).name, "DEFAULT");
  for (int i = 1000; i < 1100; ++i) {
    EXPECT_EQ(users.find_or_null(absl::StrCat("id_", i)), nullptr);
  }
}

TEST(SkirLibTest, KeyedItemsInitializerList) {
  skir::keyed_items<User, get_id> users = {{
                                               .id = "a",
                                               .name = "Peter",
                                           },
                                           {
                                               .id = "b",
                                               .name = "John",
                                           }};
  ASSERT_EQ(users.size(), 2);
  EXPECT_EQ(users[1].name, "John");
  users = {{
      .id = "c",
      .name = "Julia",
  }};
  ASSERT_EQ(users.size(), 1);
  EXPECT_EQ(users[0].name, "Julia");
  EXPECT_EQ(users.find_or_null("b"), nullptr);
  EXPECT_EQ(users.find_or_default("c").name, "Julia");
}

TEST(SkirLibTest, KeyedItemsAssign) {
  skir::keyed_items<User, get_id> users;
  std::vector<User> vector = {{
      .id = "c",
      .name = "Julia",
  }};
  users.assign(vector.begin(), vector.end());
  EXPECT_EQ(users.find_or_default("c").name, "Julia");
}

TEST(SkirLibTest, KeyedItemsAppendRange) {
  skir::keyed_items<User, get_id> users = {{.id = "a"}};

  const std::vector<User> range_1 = {{.id = "b"}};
  const skir::keyed_items<User, get_id> range_2 = {{.id = "c"}};
  std::vector<User> range_3 = {{.id = "d"}};
  skir::keyed_items<User, get_id> range_4 = {{.id = "e"}};

  users.append_range(range_1);
  users.append_range(range_2);
  users.append_range(std::move(range_3));
  users.append_range(std::move(range_4));

  ASSERT_EQ(users.size(), 5);
  EXPECT_THAT(users,
              ElementsAre(User{.id = "a"}, User{.id = "b"}, User{.id = "c"},
                          User{.id = "d"}, User{.id = "e"}));
}

TEST(SkirLibTest, KeyedItemsAt) {
  skir::keyed_items<User, get_id> users = {{
                                               .id = "a",
                                               .name = "Peter",
                                           },
                                           {
                                               .id = "b",
                                               .name = "John",
                                           }};
  ASSERT_EQ(users.size(), 2);
  EXPECT_EQ(users[0].id, "a");
  EXPECT_EQ(users.at(1).name, "John");
  EXPECT_EQ(users.front().id, "a");
  EXPECT_EQ(users.back().name, "John");
}

TEST(SkirLibTest, KeyedItemsIterator) {
  skir::keyed_items<User, get_id> users = {{
                                               .id = "a",
                                               .name = "Peter",
                                           },
                                           {
                                               .id = "b",
                                               .name = "John",
                                           }};
  std::vector<User> vector;
  vector.assign(users.begin(), users.end());
  ASSERT_EQ(vector.size(), 2);
  EXPECT_EQ(vector[1].name, "John");
  vector.assign(users.cbegin(), users.cend());
  ASSERT_EQ(vector.size(), 2);
  EXPECT_EQ(vector[1].name, "John");
  vector.assign(users.rbegin(), users.rend());
  ASSERT_EQ(vector.size(), 2);
  EXPECT_EQ(vector[1].name, "Peter");
  vector.assign(users.crbegin(), users.crend());
  ASSERT_EQ(vector.size(), 2);
  EXPECT_EQ(vector[1].name, "Peter");
  vector.clear();
  for (const User &user : users) {
    vector.push_back(user);
  }
  ASSERT_EQ(vector.size(), 2);
  EXPECT_EQ(vector[1].name, "John");
}

TEST(SkirLibTest, KeyedItemsCapacity) {
  skir::keyed_items<User, get_id> users = {{
                                               .id = "a",
                                               .name = "Peter",
                                           },
                                           {
                                               .id = "b",
                                               .name = "John",
                                           }};
  users.reserve(30);
  EXPECT_GE(users.capacity(), 30);
  users.shrink_to_fit();
  EXPECT_GE(users.capacity(), 2);
  EXPECT_EQ(users.find_or_default("b").name, "John");
}

TEST(SkirLibTest, KeyedItemsClear) {
  skir::keyed_items<User, get_id> users = {{
                                               .id = "a",
                                               .name = "Peter",
                                           },
                                           {
                                               .id = "b",
                                               .name = "John",
                                           }};
  users.clear();
  EXPECT_TRUE(users.empty());
  EXPECT_EQ(users.find_or_default("b").name, "");
}

TEST(SkirLibTest, KeyedItemsSwap) {
  skir::keyed_items<User, get_id> users_1 = {{
      .id = "a",
      .name = "Peter",
  }};
  skir::keyed_items<User, get_id> users_2 = {{
      .id = "b",
      .name = "John",
  }};
  users_1.swap(users_2);
  ASSERT_EQ(users_1.size(), 1);
  EXPECT_EQ(users_1[0].id, "b");
  ASSERT_EQ(users_2.size(), 1);
  EXPECT_EQ(users_2[0].id, "a");
}

TEST(SkirLibTest, KeyedItemsSortByKey) {
  skir::keyed_items<User, get_id> users = {
      {
          .id = "a",
          .name = "Adam",
      },
      {
          .id = "c",
          .name = "Chris",
      },
      {
          .id = "b",
          .name = "Boo",
      },
  };
  users.sort_by_key();
  ASSERT_EQ(users.size(), 3);
  EXPECT_EQ(users[0].id, "a");
  EXPECT_EQ(users[1].id, "b");
  EXPECT_EQ(users[2].name, "Chris");
  EXPECT_EQ(users.find_or_default("c").name, "Chris");
}

TEST(SkirLibTest, KeyedItemsVectorGetter) {
  skir::keyed_items<User, get_id> users = {{
                                               .id = "a",
                                               .name = "Adam",
                                           },
                                           {
                                               .id = "c",
                                               .name = "Chris",
                                           }};
  static_assert(
      std::is_same_v<decltype(users.vector()), const std::vector<User> &>);

  std::vector<User> vector = std::move(users).vector();
  EXPECT_EQ(vector.size(), 2);
}

TEST(SkirLibTest, KeyedItemsVectorMutator) {
  skir::keyed_items<User, get_id> users = {{
      .id = "a",
      .name = "Adam",
  }};
  {
    skir::keyed_items<User, get_id>::vector_mutator vector_mutator =
        users.start_vector_mutation();
    vector_mutator->push_back({
        .id = "b",
        .name = "Bella",
    });
    ASSERT_EQ(vector_mutator->size(), 2);
    (*vector_mutator)[0].id = "c";
  }
  EXPECT_EQ(users.find_or_default("c").name, "Adam");
}

TEST(SkirLibTest, KeyedItemsHash) {
  absl::flat_hash_set<skir::keyed_items<User, get_id>> keyed_items_set;
  keyed_items_set.insert({{
      .id = "a",
      .name = "Adam",
  }});
  keyed_items_set.insert(skir::keyed_items<User, get_id>{});
  keyed_items_set.insert(skir::keyed_items<User, get_id>{});
  EXPECT_EQ(keyed_items_set.size(), 2);
}

struct JsonTokenizerResult {
  std::vector<char> json_code;
  std::unique_ptr<skir_internal::JsonTokenizer> tokenizer;
};

std::unique_ptr<JsonTokenizerResult>
MakeJsonTokenizer(const std::string &json_code) {
  auto result = std::make_unique<JsonTokenizerResult>();
  // Copy to a non-NULL-terminated vector.
  result->json_code = {json_code.begin(), json_code.end()};
  result->tokenizer = std::make_unique<skir_internal::JsonTokenizer>(
      result->json_code.data(),
      result->json_code.data() + result->json_code.size(),
      skir::UnrecognizedValuesPolicy::kKeep);
  return result;
}

TEST(SkirlibTest, JsonTokenizer) {
  auto tokenizer =
      MakeJsonTokenizer(" [ ] \n { } , : true false null 0 1 -1 3.14");
  EXPECT_EQ(tokenizer->tokenizer->Next(),
            skir_internal::JsonTokenType::kLeftSquareBracket);
  EXPECT_EQ(tokenizer->tokenizer->Next(),
            skir_internal::JsonTokenType::kRightSquareBracket);
  EXPECT_EQ(tokenizer->tokenizer->Next(),
            skir_internal::JsonTokenType::kLeftCurlyBracket);
  EXPECT_EQ(tokenizer->tokenizer->Next(),
            skir_internal::JsonTokenType::kRightCurlyBracket);
  EXPECT_EQ(tokenizer->tokenizer->Next(), skir_internal::JsonTokenType::kComma);
  EXPECT_EQ(tokenizer->tokenizer->Next(), skir_internal::JsonTokenType::kColon);
  EXPECT_EQ(tokenizer->tokenizer->Next(), skir_internal::JsonTokenType::kTrue);
  EXPECT_EQ(tokenizer->tokenizer->Next(), skir_internal::JsonTokenType::kFalse);
  EXPECT_EQ(tokenizer->tokenizer->Next(), skir_internal::JsonTokenType::kNull);
  EXPECT_EQ(tokenizer->tokenizer->Next(), skir_internal::JsonTokenType::kZero);
  EXPECT_EQ(tokenizer->tokenizer->state().uint_value, 0);
  EXPECT_EQ(tokenizer->tokenizer->Next(),
            skir_internal::JsonTokenType::kUnsignedInteger);
  EXPECT_EQ(tokenizer->tokenizer->state().uint_value, 1);
  EXPECT_EQ(tokenizer->tokenizer->Next(),
            skir_internal::JsonTokenType::kSignedInteger);
  EXPECT_EQ(tokenizer->tokenizer->state().int_value, -1);
  EXPECT_EQ(tokenizer->tokenizer->Next(), skir_internal::JsonTokenType::kFloat);
  EXPECT_EQ(tokenizer->tokenizer->state().float_value, 3.14);
}

TEST(SkirlibTest, ParseJsonString) {
  auto tokenizer = MakeJsonTokenizer("\"Foo\"");
  EXPECT_EQ(tokenizer->tokenizer->Next(),
            skir_internal::JsonTokenType::kString);
  EXPECT_EQ(tokenizer->tokenizer->state().string_value, "Foo");

  tokenizer = MakeJsonTokenizer(
      "\"Foo \\n\\r\\t\\f \\\\ \t \\\"\\' \\/ \\u0010 😊 \\uD801\\uDC01 \"");
  EXPECT_EQ(tokenizer->tokenizer->Next(),
            skir_internal::JsonTokenType::kString);
  EXPECT_EQ(tokenizer->tokenizer->state().string_value,
            "Foo \n\r\t\f \\ \t \"' / \x10 \xF0\x9F\x98\x8A \xF0\x90\x90\x81 ");

  tokenizer = MakeJsonTokenizer("\"\\u0000\"");
  EXPECT_EQ(tokenizer->tokenizer->Next(),
            skir_internal::JsonTokenType::kString);
  EXPECT_EQ(tokenizer->tokenizer->state().string_value, std::string({'\0'}));

  tokenizer = MakeJsonTokenizer("\"\xc3z\"");
  EXPECT_EQ(tokenizer->tokenizer->Next(),
            skir_internal::JsonTokenType::kString);
  EXPECT_EQ(tokenizer->tokenizer->state().string_value, "�z");
}

TEST(SkirlibTest, ParseJsonNumber) {
  auto tokenizer = MakeJsonTokenizer("3.14");
  EXPECT_EQ(tokenizer->tokenizer->Next(), skir_internal::JsonTokenType::kFloat);
  EXPECT_EQ(tokenizer->tokenizer->state().float_value, 3.14);
  tokenizer = MakeJsonTokenizer("0.0314E2");
  EXPECT_EQ(tokenizer->tokenizer->Next(), skir_internal::JsonTokenType::kFloat);
  EXPECT_EQ(tokenizer->tokenizer->state().float_value, 3.14);
  tokenizer = MakeJsonTokenizer("314E-2");
  EXPECT_EQ(tokenizer->tokenizer->Next(), skir_internal::JsonTokenType::kFloat);
  EXPECT_EQ(tokenizer->tokenizer->state().float_value, 3.14);
  tokenizer = MakeJsonTokenizer("31.4E-1");
  EXPECT_EQ(tokenizer->tokenizer->Next(), skir_internal::JsonTokenType::kFloat);
  EXPECT_EQ(tokenizer->tokenizer->state().float_value, 3.14);
  tokenizer = MakeJsonTokenizer("31400000000e-10");
  EXPECT_EQ(tokenizer->tokenizer->Next(), skir_internal::JsonTokenType::kFloat);
  EXPECT_EQ(tokenizer->tokenizer->state().float_value, 3.14);
  tokenizer = MakeJsonTokenizer("18446744073709551615");
  EXPECT_EQ(tokenizer->tokenizer->Next(),
            skir_internal::JsonTokenType::kUnsignedInteger);
  EXPECT_EQ(tokenizer->tokenizer->state().uint_value, 18446744073709551615U);
  tokenizer = MakeJsonTokenizer("18446744073709551616");
  EXPECT_EQ(tokenizer->tokenizer->Next(), skir_internal::JsonTokenType::kZero);
  tokenizer = MakeJsonTokenizer("-9223372036854775808");
  EXPECT_EQ(tokenizer->tokenizer->Next(),
            skir_internal::JsonTokenType::kSignedInteger);
  EXPECT_EQ(tokenizer->tokenizer->state().int_value,
            std::numeric_limits<int64_t>::min());
  tokenizer = MakeJsonTokenizer("-9223372036854775809");
  EXPECT_EQ(tokenizer->tokenizer->Next(),
            skir_internal::JsonTokenType::kSignedInteger);
  EXPECT_EQ(tokenizer->tokenizer->state().int_value,
            std::numeric_limits<int64_t>::max());
}

std::string RepeatStr(const std::string &input, int times) {
  if (times <= 0)
    return "";
  std::string result;
  result.reserve(input.length() * times);
  for (int i = 0; i < times; ++i) {
    result += input;
  }
  return result;
}

std::vector<int> RepeatVec(int item, int times) {
  if (times <= 0)
    return {};
  std::vector<int> result;
  result.reserve(times);
  for (int i = 0; i < times; ++i) {
    result.push_back(item);
  }
  return result;
}

TEST(SkirlibTest, ReserializeBool) {
  EXPECT_THAT(MakeReserializer(false)
                  .IsDefault()
                  .ExpectReadableJson("false")
                  .ExpectDenseJson("0")
                  .ExpectBytes("00")
                  .ExpectDebugString("false")
                  .AddAlternativeJson("0")
                  .AddAlternativeJson("0.0")
                  .AddAlternativeBytes("e900000000")
                  .AddAlternativeBytes("ea0000000000000000")
                  .AddAlternativeBytes("f000000000")
                  .AddAlternativeBytes("f10000000000000000")
                  .ExpectTypeDescriptorJson(
                      "{\n  \"type\": {\n    \"kind\": \"primitive\",\n    "
                      "\"value\": \"bool\"\n  },\n  \"records\": []\n}")
                  .Check()
                  .ok(),
              IsTrue());
  EXPECT_THAT(MakeReserializer(true)
                  .ExpectReadableJson("true")
                  .ExpectDenseJson("1")
                  .ExpectBytes("01")
                  .ExpectDebugString("true")
                  .AddAlternativeJson("1")
                  .AddAlternativeJson("0.5")
                  .Check()
                  .ok(),
              IsTrue());
}

TEST(SkirlibTest, ReserializeInt32) {
  EXPECT_THAT(MakeReserializer<int32_t>(0)
                  .IsDefault()
                  .ExpectReadableJson("0")
                  .ExpectDenseJson("0")
                  .ExpectDebugString("0")
                  .ExpectBytes("00")
                  .ExpectTypeDescriptorJson(
                      "{\n  \"type\": {\n    \"kind\": \"primitive\",\n    "
                      "\"value\": \"int32\"\n  },\n  \"records\": []\n}")
                  .Check()
                  .ok(),
              IsTrue());
  EXPECT_THAT(MakeReserializer<int32_t>(10)
                  .ExpectReadableJson("10")
                  .ExpectDenseJson("10")
                  .ExpectDebugString("10")
                  .ExpectBytes("0a")
                  .AddAlternativeBytes("e90a000000")
                  .Check()
                  .ok(),
              IsTrue());
  EXPECT_THAT(MakeReserializer<int32_t>(231).ExpectBytes("e7").Check().ok(),
              IsTrue());
  EXPECT_THAT(MakeReserializer<int32_t>(232).ExpectBytes("e8e800").Check().ok(),
              IsTrue());
  EXPECT_THAT(MakeReserializer<int32_t>(-1)
                  .ExpectReadableJson("-1")
                  .ExpectDenseJson("-1")
                  .ExpectDebugString("-1")
                  .ExpectBytes("ebff")
                  .Check()
                  .ok(),
              IsTrue());
  EXPECT_THAT(MakeReserializer<int32_t>(-256).ExpectBytes("eb00").Check().ok(),
              IsTrue());
  EXPECT_THAT(
      MakeReserializer<int32_t>(-257).ExpectBytes("ecfffe").Check().ok(),
      IsTrue());
  EXPECT_THAT(
      MakeReserializer<int32_t>(-65536).ExpectBytes("ec0000").Check().ok(),
      IsTrue());
  EXPECT_THAT(
      MakeReserializer<int32_t>(-65537).ExpectBytes("edfffffeff").Check().ok(),
      IsTrue());
  EXPECT_THAT(
      MakeReserializer<int32_t>(65535).ExpectBytes("e8ffff").Check().ok(),
      IsTrue());
  EXPECT_THAT(
      MakeReserializer<int32_t>(65536).ExpectBytes("e900000100").Check().ok(),
      IsTrue());
}

TEST(SkirlibTest, ReserializeInt64) {
  EXPECT_THAT(MakeReserializer<int64_t>(0)
                  .IsDefault()
                  .ExpectReadableJson("0")
                  .ExpectDenseJson("0")
                  .ExpectDebugString("0")
                  .ExpectBytes("00")
                  .ExpectTypeDescriptorJson(
                      "{\n  \"type\": {\n    \"kind\": \"primitive\",\n    "
                      "\"value\": \"int64\"\n  },\n  \"records\": []\n}")
                  .Check()
                  .ok(),
              IsTrue());
  EXPECT_THAT(MakeReserializer<int64_t>(10)
                  .ExpectReadableJson("10")
                  .ExpectDenseJson("10")
                  .ExpectDebugString("10")
                  .ExpectBytes("0a")
                  .AddAlternativeBytes("e90a000000")
                  .Check()
                  .ok(),
              IsTrue());
  EXPECT_THAT(MakeReserializer<int64_t>(231).ExpectBytes("e7").Check().ok(),
              IsTrue());
  EXPECT_THAT(MakeReserializer<int64_t>(232).ExpectBytes("e8e800").Check().ok(),
              IsTrue());
  EXPECT_THAT(MakeReserializer<int64_t>(-1)
                  .ExpectReadableJson("-1")
                  .ExpectDenseJson("-1")
                  .ExpectDebugString("-1")
                  .ExpectBytes("ebff")
                  .Check()
                  .ok(),
              IsTrue());
  EXPECT_THAT(MakeReserializer<int64_t>(-256).ExpectBytes("eb00").Check().ok(),
              IsTrue());
  EXPECT_THAT(
      MakeReserializer<int64_t>(-257).ExpectBytes("ecfffe").Check().ok(),
      IsTrue());
  EXPECT_THAT(
      MakeReserializer<int64_t>(-65536).ExpectBytes("ec0000").Check().ok(),
      IsTrue());
  EXPECT_THAT(
      MakeReserializer<int64_t>(-65537).ExpectBytes("edfffffeff").Check().ok(),
      IsTrue());
  EXPECT_THAT(
      MakeReserializer<int64_t>(65535).ExpectBytes("e8ffff").Check().ok(),
      IsTrue());
  EXPECT_THAT(
      MakeReserializer<int64_t>(65536).ExpectBytes("e900000100").Check().ok(),
      IsTrue());
  EXPECT_THAT(MakeReserializer<int64_t>(-2147483648)
                  .ExpectBytes("ed00000080")
                  .Check()
                  .ok(),
              IsTrue());
  EXPECT_THAT(MakeReserializer<int64_t>(-2147483649)
                  .ExpectBytes("eeffffff7fffffffff")
                  .Check()
                  .ok(),
              IsTrue());
  EXPECT_THAT(MakeReserializer<int64_t>(4294967295)
                  .ExpectBytes("e9ffffffff")
                  .Check()
                  .ok(),
              IsTrue());
  EXPECT_THAT(MakeReserializer<int64_t>(4294967296)
                  .ExpectBytes("ee0000000001000000")
                  .Check()
                  .ok(),
              IsTrue());
  EXPECT_THAT(MakeReserializer<int64_t>(-9007199254740991)
                  .ExpectDenseJson("-9007199254740991")
                  .ExpectReadableJson("-9007199254740991")
                  .Check()
                  .ok(),
              IsTrue());
  EXPECT_THAT(MakeReserializer<int64_t>(-9007199254740992)
                  .ExpectDenseJson("\"-9007199254740992\"")
                  .ExpectReadableJson("\"-9007199254740992\"")
                  .Check()
                  .ok(),
              IsTrue());
  EXPECT_THAT(MakeReserializer<int64_t>(9007199254740991)
                  .ExpectDenseJson("9007199254740991")
                  .ExpectReadableJson("9007199254740991")
                  .Check()
                  .ok(),
              IsTrue());
  EXPECT_THAT(MakeReserializer<int64_t>(9007199254740992)
                  .ExpectDenseJson("\"9007199254740992\"")
                  .ExpectReadableJson("\"9007199254740992\"")
                  .Check()
                  .ok(),
              IsTrue());
}

TEST(SkirlibTest, ReserializeUint64) {
  EXPECT_THAT(MakeReserializer<uint64_t>(0)
                  .IsDefault()
                  .ExpectReadableJson("0")
                  .ExpectDenseJson("0")
                  .ExpectDebugString("0")
                  .ExpectBytes("00")
                  .ExpectTypeDescriptorJson(
                      "{\n  \"type\": {\n    \"kind\": \"primitive\",\n    "
                      "\"value\": \"hash64\"\n  },\n  \"records\": []\n}")
                  .Check()
                  .ok(),
              IsTrue());
  EXPECT_THAT(MakeReserializer<uint64_t>(10)
                  .ExpectReadableJson("10")
                  .ExpectDenseJson("10")
                  .ExpectDebugString("10")
                  .ExpectBytes("0a")
                  .AddAlternativeBytes("e90a000000")
                  .Check()
                  .ok(),
              IsTrue());
  EXPECT_THAT(MakeReserializer<uint64_t>(231).ExpectBytes("e7").Check().ok(),
              IsTrue());
  EXPECT_THAT(
      MakeReserializer<uint64_t>(232).ExpectBytes("e8e800").Check().ok(),
      IsTrue());
  EXPECT_THAT(
      MakeReserializer<uint64_t>(65535).ExpectBytes("e8ffff").Check().ok(),
      IsTrue());
  EXPECT_THAT(
      MakeReserializer<uint64_t>(65536).ExpectBytes("e900000100").Check().ok(),
      IsTrue());
  EXPECT_THAT(MakeReserializer<uint64_t>(4294967295)
                  .ExpectBytes("e9ffffffff")
                  .Check()
                  .ok(),
              IsTrue());
  EXPECT_THAT(MakeReserializer<uint64_t>(4294967296)
                  .ExpectBytes("ea0000000001000000")
                  .Check()
                  .ok(),
              IsTrue());
  EXPECT_THAT(MakeReserializer<uint64_t>(9007199254740991)
                  .ExpectDenseJson("9007199254740991")
                  .ExpectReadableJson("9007199254740991")
                  .Check()
                  .ok(),
              IsTrue());
  EXPECT_THAT(MakeReserializer<uint64_t>(9007199254740992)
                  .ExpectDenseJson("\"9007199254740992\"")
                  .ExpectReadableJson("\"9007199254740992\"")
                  .Check()
                  .ok(),
              IsTrue());
}

TEST(SkirlibTest, ReserializeFloat32) {
  EXPECT_THAT(MakeReserializer<float>(0.0)
                  .IsDefault()
                  .ExpectReadableJson("0")
                  .ExpectDenseJson("0")
                  .ExpectDebugString("0")
                  .ExpectBytes("00")
                  .ExpectTypeDescriptorJson(
                      "{\n  \"type\": {\n    \"kind\": \"primitive\",\n    "
                      "\"value\": \"float32\"\n  },\n  \"records\": []\n}")
                  .Check()
                  .ok(),
              IsTrue());
  EXPECT_THAT(MakeReserializer<float>(-0.0)
                  .IsDefault()
                  .ExpectReadableJson("-0")
                  .ExpectDenseJson("-0")
                  .ExpectDebugString("-0")
                  .ExpectBytes("00")
                  .Check()
                  .ok(),
              IsTrue());
  EXPECT_THAT(MakeReserializer<float>(1.0)
                  .ExpectReadableJson("1")
                  .ExpectDenseJson("1")
                  .ExpectDebugString("1")
                  .ExpectBytes("f00000803f")
                  .Check()
                  .ok(),
              IsTrue());
  EXPECT_THAT(MakeReserializer<float>(3.14)
                  .ExpectReadableJson("3.14")
                  .ExpectDenseJson("3.14")
                  .ExpectDebugString("3.14")
                  .ExpectBytes("f0c3f54840")
                  .Check()
                  .ok(),
              IsTrue());
  EXPECT_THAT(MakeReserializer(std::numeric_limits<float>::max())
                  .ExpectReadableJson("3.40282e+38")
                  .ExpectDenseJson("3.40282e+38")
                  .ExpectDebugString("3.40282e+38")
                  .ExpectBytes("f0ffff7f7f")
                  .WithIdentity([](float input) {
                    return absl::StrCat(input) ==
                           absl::StrCat(std::numeric_limits<float>::max());
                  })
                  .Check()
                  .ok(),
              IsTrue());
  EXPECT_THAT(MakeReserializer(std::numeric_limits<float>::infinity())
                  .ExpectReadableJson("\"Infinity\"")
                  .ExpectDenseJson("\"Infinity\"")
                  .ExpectDebugString("std::numeric_limits<float>::infinity()")
                  .ExpectBytes("f00000807f")
                  .Check()
                  .ok(),
              IsTrue());
  EXPECT_THAT(MakeReserializer(-std::numeric_limits<float>::infinity())
                  .ExpectReadableJson("\"-Infinity\"")
                  .ExpectDenseJson("\"-Infinity\"")
                  .ExpectDebugString("-std::numeric_limits<float>::infinity()")
                  .ExpectBytes("f0000080ff")
                  .Check()
                  .ok(),
              IsTrue());
  EXPECT_THAT(MakeReserializer(std::numeric_limits<float>::quiet_NaN())
                  .ExpectReadableJson("\"NaN\"")
                  .ExpectDenseJson("\"NaN\"")
                  .ExpectDebugString("std::numeric_limits<float>::quiet_NaN()")
                  .ExpectBytes("f00000c07f")
                  .WithIdentity([](float input) { return input != input; })
                  .Check()
                  .ok(),
              IsTrue());
}

TEST(SkirlibTest, ReserializeFloat64) {
  EXPECT_THAT(MakeReserializer<double>(0.0)
                  .IsDefault()
                  .ExpectReadableJson("0")
                  .ExpectDenseJson("0")
                  .ExpectDebugString("0")
                  .ExpectBytes("00")
                  .ExpectTypeDescriptorJson(
                      "{\n  \"type\": {\n    \"kind\": \"primitive\",\n    "
                      "\"value\": \"float64\"\n  },\n  \"records\": []\n}")
                  .Check()
                  .ok(),
              IsTrue());
  EXPECT_THAT(MakeReserializer<double>(-0.0)
                  .IsDefault()
                  .ExpectReadableJson("-0")
                  .ExpectDenseJson("-0")
                  .ExpectDebugString("-0")
                  .ExpectBytes("00")
                  .Check()
                  .ok(),
              IsTrue());
  EXPECT_THAT(MakeReserializer<double>(1.0)
                  .ExpectReadableJson("1")
                  .ExpectDenseJson("1")
                  .ExpectDebugString("1")
                  .ExpectBytes("f1000000000000f03f")
                  .Check()
                  .ok(),
              IsTrue());
  EXPECT_THAT(MakeReserializer<double>(3.14)
                  .ExpectReadableJson("3.14")
                  .ExpectDenseJson("3.14")
                  .ExpectDebugString("3.14")
                  .ExpectBytes("f11f85eb51b81e0940")
                  .Check()
                  .ok(),
              IsTrue());
  EXPECT_THAT(MakeReserializer(std::numeric_limits<double>::max())
                  .ExpectReadableJson("1.79769e+308")
                  .ExpectDenseJson("1.79769e+308")
                  .ExpectDebugString("1.79769e+308")
                  .ExpectBytes("f1ffffffffffffef7f")
                  .WithIdentity([](double input) {
                    return absl::StrCat(input) ==
                           absl::StrCat(std::numeric_limits<double>::max());
                  })
                  .Check()
                  .ok(),
              IsTrue());
  EXPECT_THAT(MakeReserializer(std::numeric_limits<double>::infinity())
                  .ExpectReadableJson("\"Infinity\"")
                  .ExpectDenseJson("\"Infinity\"")
                  .ExpectDebugString("std::numeric_limits<double>::infinity()")
                  .ExpectBytes("f1000000000000f07f")
                  .Check()
                  .ok(),
              IsTrue());
  EXPECT_THAT(MakeReserializer(-std::numeric_limits<double>::infinity())
                  .ExpectReadableJson("\"-Infinity\"")
                  .ExpectDenseJson("\"-Infinity\"")
                  .ExpectDebugString("-std::numeric_limits<double>::infinity()")
                  .ExpectBytes("f1000000000000f0ff")
                  .Check()
                  .ok(),
              IsTrue());
  EXPECT_THAT(MakeReserializer(std::numeric_limits<double>::quiet_NaN())
                  .ExpectReadableJson("\"NaN\"")
                  .ExpectDenseJson("\"NaN\"")
                  .ExpectDebugString("std::numeric_limits<double>::quiet_NaN()")
                  .ExpectBytes("f1000000000000f87f")
                  .WithIdentity([](float input) { return input != input; })
                  .Check()
                  .ok(),
              IsTrue());
}

TEST(SkirlibTest, ReserializeTimestamp) {
  EXPECT_THAT(
      MakeReserializer(absl::UnixEpoch())
          .IsDefault()
          .ExpectReadableJson("{\n  \"unix_millis\": 0,\n  \"formatted\": "
                              "\"1970-01-01T00:00:00.000Z\"\n}")
          .ExpectDenseJson("0")
          .ExpectDebugString(
              "absl::FromUnixMillis(0 /* 1970-01-01T00:00:00.000Z */)")
          .ExpectBytes("00")
          .ExpectTypeDescriptorJson(
              "{\n  \"type\": {\n    \"kind\": \"primitive\",\n    \"value\": "
              "\"timestamp\"\n  },\n  \"records\": []\n}")
          .Check()
          .ok(),
      IsTrue());
  EXPECT_THAT(MakeReserializer(absl::FromUnixMillis(1738619881001))
                  .ExpectReadableJson(
                      "{\n  \"unix_millis\": 1738619881001,\n  \"formatted\": "
                      "\"2025-02-03T21:58:01.001Z\"\n}")
                  .ExpectDenseJson("1738619881001")
                  .ExpectDebugString("absl::FromUnixMillis(1738619881001 /* "
                                     "2025-02-03T21:58:01.001Z */)")
                  .ExpectBytes("ef2906d2cd94010000")
                  .Check()
                  .ok(),
              IsTrue());
  EXPECT_THAT(
      MakeReserializer(absl::FromUnixMillis(-8640000000000000))
          .ExpectReadableJson(
              "{\n  \"unix_millis\": -8640000000000000,\n  "
              "\"formatted\": \"-271821-04-20T00:00:00.000Z\"\n}")
          .ExpectDenseJson("-8640000000000000")
          .ExpectDebugString("absl::FromUnixMillis(-8640000000000000 "
                             "/* -271821-04-20T00:00:00.000Z */)")
          .ExpectBytes("ef0000243df74de1ff")
          .AddAlternativeJson("-8640000000000001")
          .AddAlternativeJson("{\n  \"unix_millis\": -8640000000000001}")
          .AddAlternativeJson(
              "{\"foo\": true, \"unix_millis\": -8640000000000001}")
          .Check()
          .ok(),
      IsTrue());
  EXPECT_THAT(MakeReserializer(skir::kMinEncodedTimestamp)
                  .ExpectDenseJson("-8640000000000000")
                  .Check()
                  .ok(),
              IsTrue());
  EXPECT_THAT(MakeReserializer(absl::FromUnixMillis(8640000000000000))
                  .ExpectReadableJson(
                      "{\n  \"unix_millis\": 8640000000000000,\n  "
                      "\"formatted\": \"275760-09-13T00:00:00.000Z\"\n}")
                  .ExpectDenseJson("8640000000000000")
                  .ExpectDebugString("absl::FromUnixMillis(8640000000000000 /* "
                                     "275760-09-13T00:00:00.000Z */)")
                  .ExpectBytes("ef0000dcc208b21e00")
                  .AddAlternativeJson("8640000000000001")
                  .AddAlternativeJson("{\n  \"unix_millis\": 8640000000000001}")
                  .AddAlternativeJson(
                      "{\"foo\": true, \"unix_millis\": 8640000000000001}")
                  .AddAlternativeBytes("ee0000dcc208b21e00")
                  .AddAlternativeBytes("ee0000dcc208b21e01")
                  .Check()
                  .ok(),
              IsTrue());
  EXPECT_THAT(MakeReserializer(skir::kMaxEncodedTimestamp)
                  .ExpectDenseJson("8640000000000000")
                  .Check()
                  .ok(),
              IsTrue());
}

TEST(SkirlibTest, ReserializeString) {
  EXPECT_THAT(MakeReserializer(std::string(""))
                  .IsDefault()
                  .ExpectReadableJson("\"\"")
                  .ExpectDenseJson("\"\"")
                  .ExpectDebugString("\"\"")
                  .ExpectBytes("f2")
                  .AddAlternativeJson("0")
                  .AddAlternativeBytes("00")
                  .ExpectTypeDescriptorJson(
                      "{\n  \"type\": {\n    \"kind\": \"primitive\",\n    "
                      "\"value\": \"string\"\n  },\n  \"records\": []\n}")
                  .Check()
                  .ok(),
              IsTrue());
  EXPECT_THAT(MakeReserializer(std::string("pokémon"))
                  .ExpectReadableJson("\"pokémon\"")
                  .ExpectDenseJson("\"pokémon\"")
                  .ExpectDebugString("\"pokémon\"")
                  .ExpectBytes("f308706f6bc3a96d6f6e")
                  .Check()
                  .ok(),
              IsTrue());
  EXPECT_THAT(MakeReserializer(std::string("\"\n"))
                  .ExpectReadableJson("\"\\\"\\n\"")
                  .ExpectDenseJson("\"\\\"\\n\"")
                  .ExpectDebugString("\"\\\"\\n\"")
                  .ExpectBytes("f302220a")
                  .Check()
                  .ok(),
              IsTrue());
  EXPECT_THAT(MakeReserializer(std::string("é")).Check().ok(), IsTrue());
  EXPECT_THAT(MakeReserializer(RepeatStr("a", 77)).Check().ok(), IsTrue());
  EXPECT_THAT(MakeReserializer(RepeatStr("a", 78)).Check().ok(), IsTrue());
  EXPECT_THAT(MakeReserializer(RepeatStr("a", 21845)).Check().ok(), IsTrue());
  EXPECT_THAT(MakeReserializer(RepeatStr("a", 21846)).Check().ok(), IsTrue());
}

TEST(SkirlibTest, ReserializeBytes) {
  EXPECT_THAT(MakeReserializer(skir::ByteString())
                  .IsDefault()
                  .ExpectReadableJson("\"hex:\"")
                  .ExpectDenseJson("\"\"")
                  .ExpectDebugString("skir::ByteString({})")
                  .ExpectBytes("f4")
                  .AddAlternativeBytes("00")
                  .AddAlternativeJson("0")
                  .ExpectTypeDescriptorJson(
                      "{\n  \"type\": {\n    \"kind\": \"primitive\",\n    "
                      "\"value\": \"bytes\"\n  },\n  \"records\": []\n}")
                  .Check()
                  .ok(),
              IsTrue());
  EXPECT_THAT(MakeReserializer(skir::ByteString({0, 0x08, 0xFF}))
                  .ExpectReadableJson("\"hex:0008ff\"")
                  .ExpectDenseJson("\"AAj/\"")
                  .ExpectDebugString("skir::ByteString({0x00, 0x08, 0xFF})")
                  .ExpectBytes("f5030008ff")
                  .Check()
                  .ok(),
              IsTrue());
}

TEST(SkirlibTest, ReserializeArray) {
  EXPECT_THAT(
      MakeReserializer(std::vector<bool>{})
          .IsDefault()
          .ExpectReadableJson("[]")
          .ExpectDenseJson("[]")
          .ExpectDebugString("{}")
          .ExpectBytes("f6")
          .AddAlternativeBytes("00")
          .AddAlternativeJson("0")
          .ExpectTypeDescriptorJson(
              "{\n  \"type\": {\n    \"kind\": \"array\",\n    \"value\": {\n  "
              "    \"item\": {\n        \"kind\": \"primitive\",\n        "
              "\"value\": \"bool\"\n      }\n    }\n  },\n  \"records\": []\n}")
          .Check()
          .ok(),
      IsTrue());
  EXPECT_THAT(MakeReserializer(std::vector<bool>{true})
                  .ExpectReadableJson("[\n  true\n]")
                  .ExpectDenseJson("[1]")
                  .ExpectDebugString("{\n  true,\n}")
                  .ExpectBytes("f701")
                  .Check()
                  .ok(),
              IsTrue());
  EXPECT_THAT(MakeReserializer(std::vector<bool>{true, false})
                  .ExpectReadableJson("[\n  true,\n  false\n]")
                  .ExpectDenseJson("[1,0]")
                  .ExpectDebugString("{\n  true,\n  false,\n}")
                  .ExpectBytes("f80100")
                  .Check()
                  .ok(),
              IsTrue());
  EXPECT_THAT(MakeReserializer(std::vector<bool>{true, false, false})
                  .ExpectReadableJson("[\n  true,\n  false,\n  false\n]")
                  .ExpectDenseJson("[1,0,0]")
                  .ExpectDebugString("{\n  true,\n  false,\n  false,\n}")
                  .ExpectBytes("f9010000")
                  .Check()
                  .ok(),
              IsTrue());
  EXPECT_THAT(
      MakeReserializer(std::vector<bool>{true, false, false, true})
          .ExpectReadableJson("[\n  true,\n  false,\n  false,\n  true\n]")
          .ExpectDenseJson("[1,0,0,1]")
          .ExpectDebugString("{\n  true,\n  false,\n  false,\n  true,\n}")
          .ExpectBytes("fa0401000001")
          .Check()
          .ok(),
      IsTrue());
  EXPECT_THAT(MakeReserializer(RepeatVec(10, 300))
                  .ExpectBytes(absl::StrCat("fae82c01", RepeatStr("0a", 300)))
                  .Check()
                  .ok(),
              IsTrue());
  EXPECT_THAT(MakeReserializer(std::vector<std::vector<std::vector<bool>>>{
                                   {{true}, {true, false}, {}},
                                   {},
                               })
                  .ExpectReadableJson(
                      "[\n  [\n    [\n      true\n    ],\n    [\n      true,\n "
                      "     false\n    ],\n    []\n  ],\n  []\n]")
                  .ExpectDenseJson("[[[1],[1,0],[]],[]]")
                  .ExpectDebugString(
                      "{\n  {\n    {\n      true,\n    },\n    {\n      "
                      "true,\n      false,\n    },\n    {},\n  },\n  {},\n}")
                  .ExpectBytes("f8f9f701f80100f6f6")
                  .Check()
                  .ok(),
              IsTrue());
}

TEST(SkirlibTest, ReserializeOptional) {
  EXPECT_THAT(MakeReserializer(absl::optional<bool>())
                  .IsDefault()
                  .ExpectReadableJson("null")
                  .ExpectDenseJson("null")
                  .ExpectDebugString("absl::nullopt")
                  .ExpectBytes("ff")
                  .ExpectTypeDescriptorJson(
                      "{\n  \"type\": {\n    \"kind\": \"optional\",\n    "
                      "\"value\": {\n      \"kind\": \"primitive\",\n      "
                      "\"value\": \"bool\"\n    }\n  },\n  \"records\": []\n}")
                  .Check()
                  .ok(),
              IsTrue());
  EXPECT_THAT(MakeReserializer(absl::make_optional(false))
                  .ExpectReadableJson("false")
                  .ExpectDenseJson("0")
                  .ExpectDebugString("absl::make_optional(false)")
                  .ExpectBytes("00")
                  .Check()
                  .ok(),
              IsTrue());
  EXPECT_THAT(MakeReserializer(absl::make_optional(true))
                  .ExpectReadableJson("true")
                  .ExpectDenseJson("1")
                  .ExpectDebugString("absl::make_optional(true)")
                  .ExpectBytes("01")
                  .Check()
                  .ok(),
              IsTrue());
}

TEST(SkirlibTest, JsonStringEscapingAndUtf8Validation) {
  EXPECT_EQ(skir::ToDenseJson("é"), "\"é\"");
  EXPECT_EQ(skir::ToDenseJson("\n\r\t\"\f'"), "\"\\n\\r\\t\\\"\\f'\"");
  EXPECT_EQ(skir::ToDenseJson("\x01\x1A"), "\"\\u0001\\u001A\"");
  EXPECT_EQ(skir::ToDenseJson("pokémon"), "\"pokémon\"");
  EXPECT_EQ(skir::ToDenseJson("这是什么"), "\"这是什么\"");
  EXPECT_EQ(skir::ToDenseJson("\xf0\x90\x8c\xbc"), "\"𐌼\"");
  EXPECT_EQ(skir::ToDenseJson(std::string({'\0', '\0'})), "\"\\u0000\\u0000\"");
  // Invalid UTF-8 sequences, from https://stackoverflow.com/questions/1301402
  EXPECT_EQ(skir::ToDenseJson("\xc3z"), "\"�z\"");
  EXPECT_EQ(skir::ToDenseJson("\xc3\xc3"), "\"��\"");
  EXPECT_EQ(skir::ToDenseJson("\xc3\xa1\xa1"), "\"�\"");
  EXPECT_EQ(skir::ToDenseJson("\xa0\xa1"), "\"�\"");
  EXPECT_EQ(skir::ToDenseJson("\xe2\x28\xa1"), "\"�(�\"");
  EXPECT_EQ(skir::ToDenseJson("\xe2\x82\x28"), "\"�(\"");
  EXPECT_EQ(skir::ToDenseJson("\xf0\x28\x8c\xbc"), "\"�(�\"");
  EXPECT_EQ(skir::ToDenseJson("\xf0\x90\x28\xbc"), "\"�(�\"");
  EXPECT_EQ(skir::ToDenseJson("\xf0\x28\x8c\x28"), "\"�(�(\"");
  EXPECT_EQ(skir::ToDenseJson("\xf8\xa1\xa1\xa1\xa1"), "\"�\"");
  EXPECT_EQ(skir::ToDenseJson("\xfc\xa1\xa1\xa1\xa1\xa1"), "\"�\"");
}

TEST(SkirlibTest, DebugStringEscapingAndUtf8Validation) {
  EXPECT_EQ(skir_internal::ToDebugString("\n\r\t\"\f'"),
            "\"\\n\\r\\t\\\"\\f'\"");
  EXPECT_EQ(skir_internal::ToDebugString("\x01\x1A"), "\"\\x01\\x1A\"");
  EXPECT_EQ(skir_internal::ToDebugString("pokémon"), "\"pokémon\"");
  EXPECT_EQ(skir_internal::ToDebugString("这是什么"), "\"这是什么\"");
  EXPECT_EQ(skir_internal::ToDebugString("\xf0\x90\x8c\xbc"), "\"𐌼\"");
  EXPECT_EQ(skir_internal::ToDebugString(std::string({'\0', '\0'})),
            "\"\\0\\0\"");
  // Invalid UTF-8 sequences, from https://stackoverflow.com/questions/1301402
  EXPECT_EQ(skir_internal::ToDebugString("\xc3z"), "\"\\xC3z\"");
  EXPECT_EQ(skir_internal::ToDebugString("\xc3\xc3"), "\"\\xC3\\xC3\"");
  EXPECT_EQ(skir_internal::ToDebugString("\xc3\xa1\xa1"),
            "\"\\xC3\\xA1\\xA1\"");
  EXPECT_EQ(skir_internal::ToDebugString("\xa0\xa1"), "\"\\xA0\\xA1\"");
  EXPECT_EQ(skir_internal::ToDebugString("\xe2\x28\xa1"), "\"\\xE2(\\xA1\"");
  EXPECT_EQ(skir_internal::ToDebugString("\xe2\x82\x28"), "\"\\xE2\\x82(\"");
  EXPECT_EQ(skir_internal::ToDebugString("\xf0\x28\x8c\xbc"),
            "\"\\xF0(\\x8C\\xBC\"");
  EXPECT_EQ(skir_internal::ToDebugString("\xf0\x90\x28\xbc"),
            "\"\\xF0\\x90(\\xBC\"");
  EXPECT_EQ(skir_internal::ToDebugString("\xf0\x28\x8c\x28"),
            "\"\\xF0(\\x8C(\"");
  EXPECT_EQ(skir_internal::ToDebugString("\xf8\xa1\xa1\xa1\xa1"),
            "\"\\xF8\\xA1\\xA1\\xA1\\xA1\"");
  EXPECT_EQ(skir_internal::ToDebugString("\xfc\xa1\xa1\xa1\xa1\xa1"),
            "\"\\xFC\\xA1\\xA1\\xA1\\xA1\\xA1\"");
}

TEST(SkirlibTest, ParseJsonReturnsError) {
  EXPECT_EQ(skir::Parse<int32_t>("[]").status(),
            absl::UnknownError(
                "error while parsing JSON: expected: number; found: '['"));
  EXPECT_EQ(skir::Parse<int32_t>("").status(),
            absl::UnknownError(
                "error while parsing JSON: expected: number; found: end"));
  EXPECT_EQ(skir::Parse<std::vector<int32_t>>("[").status(),
            absl::UnknownError(
                "error while parsing JSON: expected: number; found: end"));
  EXPECT_EQ(skir::Parse<int32_t>("\"NaN\"").status(),
            absl::UnknownError("can't parse number from JSON string"));
  EXPECT_EQ(skir::Parse<float>("{}").status(),
            absl::UnknownError(
                "error while parsing JSON: expected: number; found: '{'"));
  EXPECT_EQ(skir::Parse<float>("{").status(),
            absl::UnknownError(
                "error while parsing JSON: expected: number; found: '{'"));
  EXPECT_EQ(skir::Parse<float>("3.").status(),
            absl::UnknownError(
                "error while parsing JSON at position 2: expected: digit"));
  EXPECT_EQ(skir::Parse<float>("-").status(),
            absl::UnknownError(
                "error while parsing JSON at position 1: expected: digit"));
  EXPECT_EQ(skir::Parse<float>("3E+").status(),
            absl::UnknownError(
                "error while parsing JSON at position 3: expected: digit"));
  EXPECT_EQ(skir::Parse<float>("3E").status(),
            absl::UnknownError(
                "error while parsing JSON at position 2: expected: digit"));
  EXPECT_EQ(
      skir::Parse<float>(" <").status(),
      absl::UnknownError(
          "error while parsing JSON at position 1: expected: JSON token"));
  EXPECT_EQ(skir::Parse<std::string>("\"foo").status(),
            absl::UnknownError(
                "error while parsing JSON: unterminated string literal"));
  EXPECT_EQ(skir::Parse<std::vector<int32_t>>("[1 2]").status(),
            absl::UnknownError(
                "error while parsing JSON: expected: ','; found: number"));
  EXPECT_EQ(skir::Parse<absl::Time>("{1:2}").status(),
            absl::UnknownError(
                "error while parsing JSON: expected: string; found: number"));
  EXPECT_EQ(skir::Parse<absl::Time>("{\"foo\" 2}").status(),
            absl::UnknownError(
                "error while parsing JSON: expected: ':'; found: number"));
  EXPECT_EQ(skir::Parse<absl::Time>("{\"foo\": }").status(),
            absl::UnknownError(
                "error while parsing JSON: expected: value; found: '}'"));
  EXPECT_EQ(
      skir::Parse<skir::ByteString>("3").status(),
      absl::UnknownError(
          "error while parsing JSON: expected: Base64 string; found: number"));
  EXPECT_EQ(
      skir::Parse<skir::ByteString>("\"?\"").status(),
      absl::UnknownError("error while parsing JSON: not a Base64 string"));
  EXPECT_EQ(
      skir::Parse<skir::ByteString>("\"\\").status(),
      absl::UnknownError(
          "error while parsing JSON at position 2: expected: escape sequence"));
}

TEST(SkirlibTest, ParseBytesReturnsError) {
  EXPECT_FALSE(
      skir::Parse<int32_t>(HexToBytes("e9ffffff").value()).status().ok());
  EXPECT_FALSE(skir::Parse<int32_t>(HexToBytes("").value()).status().ok());
  EXPECT_FALSE(
      skir::Parse<float>(HexToBytes("f00000c0").value()).status().ok());
  EXPECT_FALSE(
      skir::Parse<std::vector<int32_t>>(HexToBytes("").value()).status().ok());
  EXPECT_FALSE(skir::Parse<std::vector<int32_t>>(HexToBytes("f9").value())
                   .status()
                   .ok());
  EXPECT_FALSE(skir::Parse<std::vector<int32_t>>(HexToBytes("f90a0b").value())
                   .status()
                   .ok());
  EXPECT_FALSE(skir::Parse<std::vector<int32_t>>(HexToBytes("fa").value())
                   .status()
                   .ok());
  // NaN
  EXPECT_FALSE(
      skir::Parse<std::vector<int32_t>>(HexToBytes("f00000c07f").value())
          .status()
          .ok());
  // Infinity
  EXPECT_FALSE(
      skir::Parse<std::vector<int64_t>>(HexToBytes("f00000807f").value())
          .status()
          .ok());
  // -Infinity
  EXPECT_FALSE(
      skir::Parse<std::vector<int64_t>>(HexToBytes("f0000080ff").value())
          .status()
          .ok());
}

TEST(SkirlibTest, HttpHeaders) {
  skir::service::HttpHeaders headers;
  headers.Insert("accept", "A");
  headers.Insert("Accept", "B");
  headers.Insert("origin", "C");
  EXPECT_THAT(headers.Get("ACCEPT"), ElementsAre("A", "B"));
  EXPECT_THAT(headers.Get("Z"), IsEmpty());
  EXPECT_THAT(headers.GetLast("accept"), "B");
  EXPECT_THAT(headers.GetLast("origin"), "C");
  EXPECT_THAT(headers.GetLast("Z"), "");
  EXPECT_THAT(headers.map(),
              UnorderedElementsAre(Pair("accept", ElementsAre("A", "B")),
                                   Pair("origin", ElementsAre("C"))));
}

TEST(Skirlib, DecodeUrlQueryString) {
  const auto decoded_url =
      skir::service::DecodeUrlQueryString("%D1%88%D0%B5%D0%BB%D0%BB%D1%8B +");
  ASSERT_THAT(decoded_url.ok(), IsTrue());
  EXPECT_THAT(*decoded_url, "шеллы  ");
  EXPECT_THAT(skir::service::DecodeUrlQueryString("%3"),
              absl::InvalidArgumentError("Invalid escape sequence"));
  EXPECT_THAT(skir::service::DecodeUrlQueryString("%4z"),
              absl::InvalidArgumentError("Invalid escape sequence"));
}

} // namespace
