#include <gtest/gtest.h>

#include <type_traits>

#include "absl/container/flat_hash_set.h"
#include "absl/status/status.h"
#include "absl/status/statusor.h"
#include "absl/strings/string_view.h"
#include "absl/types/optional.h"
#include "reserializer.testing.h"
#include "skir.h"
#include "skir.testing.h"
#include "skirout/constants.h"
#include "skirout/enums.h"
#include "skirout/enums.testing.h"
#include "skirout/full_name.h"
#include "skirout/methods.h"
#include "skirout/simple_enum.h"
#include "skirout/simple_enum.testing.h"
#include "skirout/structs.h"
#include "skirout/structs.testing.h"
#include "gmock/gmock.h"

namespace {
using ::skir_testing_internal::MakeReserializer;
using ::skirout_enums::EmptyEnum;
using ::skirout_enums::JsonValue;
using ::skirout_enums::Weekday;
using ::skirout_full_name::FullName;
using ::skirout_structs::Bundle;
using ::skirout_structs::CarOwner;
using ::skirout_structs::Empty;
using ::skirout_structs::EmptyWithRm1;
using ::skirout_structs::Item;
using ::skirout_structs::KeyedItems;
using ::skirout_structs::Rec;
using ::skirout_user::User;
using ::skirout_vehicles_car::Car;
using ::testing::ElementsAre;
using ::testing::IsFalse;
using ::testing::IsTrue;
using ::testing::Not;
using ::testing::Pair;
using ::testing::UnorderedElementsAre;

using StatusEnum = ::skirout_simple_enum::Status;

TEST(skiroutTest, StructEqAndHash) {
  absl::flat_hash_set<FullName> full_names;
  EXPECT_TRUE(
      full_names.insert(FullName{.first_name = "Osi", .last_name = "Daro"})
          .second);
  EXPECT_FALSE(
      full_names.insert(FullName{.first_name = "Osi", .last_name = "Daro"})
          .second);
  EXPECT_TRUE(full_names.insert(FullName{.first_name = "Osi"}).second);
  EXPECT_FALSE(full_names.insert(FullName{.first_name = "Osi"}).second);
  EXPECT_TRUE(full_names.insert(FullName{.last_name = "Daro"}).second);
  EXPECT_FALSE(full_names.insert(FullName{.last_name = "Daro"}).second);
  EXPECT_TRUE(full_names.insert(FullName{}).second);
  EXPECT_FALSE(full_names.insert(FullName{}).second);
}

TEST(skiroutTest, CreateWhole) {
  const CarOwner car_owner = CarOwner::whole{
      .car =
          Car::whole{
              .model = "Toyota",
              .owner = User{},
              .purchase_time = absl::FromUnixMillis(1000),
              .second_owner = absl::nullopt,
          },
      .owner =
          FullName::whole{
              .first_name = "Osi",
              .last_name = "Daro",
          },
  };
  EXPECT_EQ(car_owner,
            (CarOwner{.car =
                          {
                              .model = "Toyota",
                              .purchase_time = absl::FromUnixMillis(1000),
                          },
                      .owner = {
                          .first_name = "Osi",
                          .last_name = "Daro",
                      }}));
}

TEST(skiroutTest, CreateWholeAndUseStarOperator) {
  const auto car_owner = *CarOwner::whole{
      .car =
          Car::whole{
              .model = "Toyota",
              .owner = User{},
              .purchase_time = absl::FromUnixMillis(1000),
              .second_owner = absl::nullopt,
          },
      .owner =
          FullName::whole{
              .first_name = "Osi",
              .last_name = "Daro",
          },
  };
  EXPECT_EQ(car_owner,
            (CarOwner{.car =
                          {
                              .model = "Toyota",
                              .purchase_time = absl::FromUnixMillis(1000),
                          },
                      .owner = {
                          .first_name = "Osi",
                          .last_name = "Daro",
                      }}));
}

TEST(skiroutTest, ReserializeStruct) {
  EXPECT_THAT(
      MakeReserializer(FullName{})
          .IsDefault()
          .ExpectDenseJson("[]")
          .ExpectReadableJson("{}")
          .ExpectBytes("f6")
          .ExpectDebugString("{}")
          .ExpectTypeDescriptorJson(
              "{\n  \"type\": {\n    \"kind\": \"record\",\n    \"value\": "
              "\"full_name.skir:FullName\"\n  },\n  \"records\": [\n    {\n    "
              "  \"kind\": \"struct\",\n      \"id\": "
              "\"full_name.skir:FullName\",\n      \"doc\": \"The user's full  "
              "name\",\n      \"fields\": [\n        {\n          \"name\": "
              "\"first_name\",\n          \"number\": 1,\n          \"type\": "
              "{\n            \"kind\": \"primitive\",\n            \"value\": "
              "\"string\"\n          },\n          \"doc\": \"The first "
              "name\"\n        },\n        {\n          \"name\": "
              "\"last_name\",\n          \"number\": 4,\n          \"type\": "
              "{\n            \"kind\": \"primitive\",\n            \"value\": "
              "\"string\"\n          },\n          \"doc\": \"The last "
              "name\"\n        }\n      ],\n      \"removed_numbers\": [\n     "
              "   0,\n        2,\n        3,\n        5\n      ]\n    }\n  "
              "]\n}")
          .AddAlternativeBytes("00")
          .AddAlternativeJson("0")
          .Check()
          .ok(),
      IsTrue());
  EXPECT_THAT(
      MakeReserializer(FullName{
                           .first_name = "Osi",
                           .last_name = "Daro",
                       })
          .ExpectDenseJson("[0,\"Osi\",0,0,\"Daro\"]")
          .ExpectReadableJson(
              "{\n  \"first_name\": \"Osi\",\n  \"last_name\": \"Daro\"\n}")
          .ExpectBytes("fa0500f3034f73690000f3044461726f")
          .ExpectDebugString(
              "{\n  .first_name: \"Osi\",\n  .last_name: \"Daro\",\n}")
          .Check()
          .ok(),
      IsTrue());
  EXPECT_THAT(MakeReserializer(FullName{
                                   .first_name = "Osi",
                               })
                  .ExpectDenseJson("[0,\"Osi\"]")
                  .ExpectReadableJson("{\n  \"first_name\": \"Osi\"\n}")
                  .ExpectBytes("f800f3034f7369")
                  .ExpectDebugString("{\n  .first_name: \"Osi\",\n}")
                  .Check()
                  .ok(),
              IsTrue());
  EXPECT_THAT(MakeReserializer(FullName{
                                   .last_name = "Daro",
                               })
                  .ExpectDenseJson("[0,\"\",0,0,\"Daro\"]")
                  .ExpectReadableJson("{\n  \"last_name\": \"Daro\"\n}")
                  .ExpectBytes("fa0500f20000f3044461726f")
                  .ExpectDebugString("{\n  .last_name: \"Daro\",\n}")
                  .Check()
                  .ok(),
              IsTrue());
  EXPECT_THAT(
      MakeReserializer(CarOwner{
                           .car =
                               {
                                   .model = "Toyota",
                                   .purchase_time = absl::FromUnixMillis(1000),
                               },
                           .owner =
                               {
                                   .first_name = "Osi",
                                   .last_name = "Daro",
                               },
                       })
          .ExpectDenseJson("[[\"Toyota\",1000],[0,\"Osi\",0,0,\"Daro\"]]")
          .ExpectReadableJson(
              "{\n  \"car\": {\n    \"model\": \"Toyota\",\n    "
              "\"purchase_time\": {\n      \"unix_millis\": 1000,\n      "
              "\"formatted\": \"1970-01-01T00:00:01.000Z\"\n    }\n  },\n  "
              "\"owner\": {\n    \"first_name\": \"Osi\",\n    \"last_name\": "
              "\"Daro\"\n  }\n}")
          .ExpectBytes("f8f8f306546f796f7461efe803000000000000fa0500f3034f73690"
                       "000f3044461726f")
          .ExpectDebugString(
              "{\n  .car: {\n    .model: \"Toyota\",\n    .purchase_time: "
              "absl::FromUnixMillis(1000 /* 1970-01-01T00:00:01.000Z */),\n  "
              "},\n  .owner: {\n    .first_name: \"Osi\",\n    .last_name: "
              "\"Daro\",\n  },\n}")
          .AddCompatibleSchema<Empty>("Empty")
          .Check()
          .ok(),
      IsTrue());
  EXPECT_THAT(
      MakeReserializer(Bundle{
                           .f250 = true,
                       })
          .ExpectDenseJson(
              "[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,"
              "0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,"
              "0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,"
              "0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,"
              "0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,"
              "0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,"
              "0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,"
              "0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1]")
          .ExpectBytes(
              "fae8fb0000000000000000000000000000000000000000000000000000000000"
              "0000000000000000000000000000000000000000000000000000000000000000"
              "0000000000000000000000000000000000000000000000000000000000000000"
              "0000000000000000000000000000000000000000000000000000000000000000"
              "0000000000000000000000000000000000000000000000000000000000000000"
              "0000000000000000000000000000000000000000000000000000000000000000"
              "0000000000000000000000000000000000000000000000000000000000000000"
              "00000000000000000000000000000000000000000000000000000000000001")
          .AddCompatibleSchema<Empty>("Empty")
          .AddCompatibleSchema<EmptyWithRm1>("EmptyWithRm1")
          .Check()
          .ok(),
      IsTrue());
}

TEST(skiroutTest, ParseStructFromInvalidJson) {
  EXPECT_THAT(skir::Parse<FullName>("{ \"first_name\": 1 }").ok(), IsFalse());
  EXPECT_THAT(skir::Parse<FullName>("{ \"first_name\": [ }").ok(), IsFalse());
  EXPECT_THAT(skir::Parse<FullName>("{ first_name: 0 ").ok(), IsFalse());
}

TEST(skiroutTest, StatusEnumSimpleOps) {
  StatusEnum _ = StatusEnum();
  EXPECT_EQ(StatusEnum(), StatusEnum(skirout::kUnknown));
  EXPECT_EQ(StatusEnum(skirout::kUnknown), StatusEnum(skirout::kUnknown));
  EXPECT_EQ(StatusEnum(skirout::kUnknown), skirout::kUnknown);
  EXPECT_EQ(skirout::kUnknown, StatusEnum(skirout::kUnknown));
  EXPECT_NE(StatusEnum(skirout::kOk), StatusEnum(skirout::kUnknown));
  EXPECT_NE(StatusEnum(skirout::kOk), skirout::kUnknown);
  EXPECT_EQ(skirout::kOk, StatusEnum(skirout::kOk));
  EXPECT_EQ(skirout::kOk, StatusEnum(StatusEnum::kOk));
  EXPECT_EQ(StatusEnum(skirout::kOk), skirout::kOk);
  EXPECT_NE(skirout::kOk, StatusEnum(skirout::kUnknown));
  EXPECT_EQ(skirout::kOk, StatusEnum(skirout::kOk));
  EXPECT_NE(StatusEnum(skirout::kOk), skirout::kUnknown);
  EXPECT_NE(StatusEnum(skirout::kOk), skirout::kUnknown);
  StatusEnum e;
  EXPECT_EQ(e, skirout::kUnknown);
  EXPECT_EQ(e.kind(), StatusEnum::kind_type::kUnknown);
  e = skirout::kOk;
  EXPECT_EQ(e, skirout::kOk);
  EXPECT_EQ(e.kind(), StatusEnum::kind_type::kOkConst);
  e = StatusEnum::wrap_error("E");
  EXPECT_EQ(e.kind(), StatusEnum::kind_type::kErrorWrapper);
  ASSERT_TRUE(e.is_error());
  EXPECT_EQ(e.as_error(), "E");
  e.as_error() = "EE";
  EXPECT_EQ(e.as_error(), "EE");
  ASSERT_FALSE(StatusEnum().is_error());
}

TEST(skiroutTest, StatusEnumEqAndHash) {
  absl::flat_hash_set<StatusEnum> statuses;
  EXPECT_TRUE(statuses.insert(skirout::kUnknown).second);
  EXPECT_TRUE(statuses.insert(skirout::kOk).second);
  EXPECT_FALSE(statuses.insert(skirout::kOk).second);
  EXPECT_TRUE(statuses.insert(StatusEnum::wrap_error("E0")).second);
  EXPECT_TRUE(statuses.insert(StatusEnum::wrap_error("E1")).second);
  EXPECT_FALSE(statuses.insert(StatusEnum::wrap_error("E1")).second);
}

TEST(skiroutTest, StatusEnumVisitReturnsRef) {
  struct Visitor {
    std::string a;
    std::string b;
    std::string c;

    std::string &operator()(skirout::k_unknown) { return a; }
    std::string &operator()(skirout::k_ok) { return b; }
    std::string &operator()(StatusEnum::wrap_error_type) { return c; }
  };
  static_assert(
      std::is_same_v<decltype(StatusEnum().visit(Visitor())), std::string &>);
  Visitor visitor;
  static_assert(
      std::is_same_v<decltype(StatusEnum(skirout::kOk).visit(Visitor())),
                     std::string &>);
  visitor.b = "b";
  std::string &visit_result = StatusEnum(skirout::kOk).visit(visitor);
  EXPECT_EQ(&visit_result, &visitor.b);
}

TEST(skiroutTest, StatusEnumVisitExpectsConst) {
  struct Visitor {
    std::string e;

    void operator()(skirout::k_unknown) {}
    void operator()(skirout::k_ok) {}
    void operator()(const StatusEnum::wrap_error_type &error_wrapper) {
      e = error_wrapper.value;
    }
  };
  Visitor visitor;
  const StatusEnum status = StatusEnum::wrap_error("err");
  status.visit(visitor);
  EXPECT_EQ(visitor.e, "err");
}

TEST(skiroutTest, StatusEnumVisitExpectsMutable) {
  struct Visitor {
    std::string e;

    void operator()(skirout::k_unknown) {}
    void operator()(skirout::k_ok) {}
    void operator()(StatusEnum::wrap_error_type &error_wrapper) {
      e.swap(error_wrapper.value);
    }
  };
  Visitor visitor;
  StatusEnum status = StatusEnum::wrap_error("err");
  status.visit(visitor);
  EXPECT_EQ(visitor.e, "err");
  EXPECT_EQ(status.is_error(), true);
  EXPECT_EQ(status.as_error(), "");
}

TEST(skiroutTest, ReserializeEnum) {
  EXPECT_THAT(
      MakeReserializer(StatusEnum())
          .IsDefault()
          .ExpectDenseJson("0")
          .ExpectReadableJson("\"unknown\"")
          .ExpectDebugString("skirout::kUnknown")
          .ExpectBytes("00")
          .ExpectTypeDescriptorJson(
              "{\n  \"type\": {\n    \"kind\": \"record\",\n    \"value\": "
              "\"simple_enum.skir:Status\"\n  },\n  \"records\": [\n    {\n    "
              "  \"kind\": \"enum\",\n      \"id\": "
              "\"simple_enum.skir:Status\",\n      \"variants\": [\n        "
              "{\n  "
              "        \"name\": \"ok\",\n          \"number\": 1\n        "
              "},\n        {\n          \"name\": \"error\",\n          "
              "\"number\": 2,\n          \"type\": {\n            \"kind\": "
              "\"primitive\",\n            \"value\": \"string\"\n          "
              "}\n        }\n      ]\n    }\n  ]\n}")
          .AddCompatibleSchema<EmptyEnum>("EmptyEnum")
          .Check()
          .ok(),
      IsTrue());
  EXPECT_THAT(MakeReserializer(StatusEnum(StatusEnum::kOk))
                  .ExpectDenseJson("1")
                  .ExpectReadableJson("\"ok\"")
                  .ExpectDebugString("skirout::kOk")
                  .ExpectBytes("01")
                  .AddCompatibleSchema<EmptyEnum>("EmptyEnum")
                  .Check()
                  .ok(),
              IsTrue());
  EXPECT_THAT(
      MakeReserializer(StatusEnum::wrap_error("E"))
          .ExpectDenseJson("[2,\"E\"]")
          .ExpectReadableJson(
              "{\n  \"kind\": \"error\",\n  \"value\": \"E\"\n}")
          .ExpectDebugString("::skirout::wrap_error(\"E\")")
          .ExpectBytes("fcf30145")
          .AddAlternativeJson("{\"foo\":1,\"value\":\"E\",\"kind\":\"error\"}")
          .AddCompatibleSchema<EmptyEnum>("EmptyEnum")
          .Check()
          .ok(),
      IsTrue());
  EXPECT_THAT(
      MakeReserializer(Weekday(Weekday::kUnknown)).IsDefault().Check().ok(),
      IsTrue());
  EXPECT_THAT(MakeReserializer(Weekday(Weekday::kMonday)).Check().ok(),
              IsTrue());
  EXPECT_THAT(MakeReserializer(JsonValue::wrap_boolean(true)).Check().ok(),
              IsTrue());
  EXPECT_THAT(
      MakeReserializer(EmptyEnum(EmptyEnum::kUnknown)).IsDefault().Check().ok(),
      IsTrue());
}

TEST(skiroutTest, KeyedItems) {
  KeyedItems s;
  s.array_with_int32_key.push_back({
      .int32 = 10,
      .string = "foo 10",
  });
  s.array_with_int32_key.push_back({
      .int32 = 11,
      .string = "foo 11",
  });
  s.array_with_int32_key.push_back({
      .int32 = 12,
      .string = "foo 12",
  });
  s.array_with_int32_key.push_back({
      .int32 = 12,
      .string = "foo 12",
  });
  s.array_with_int32_key.push_back({
      .int32 = 13,
      .string = "foo 13",
  });
  EXPECT_EQ(s.array_with_int32_key.find_or_default(12), (Item{
                                                            .int32 = 12,
                                                            .string = "foo 12",
                                                        }));
  EXPECT_EQ(s.array_with_int32_key.find_or_default(14), Item{});
  EXPECT_EQ(s.array_with_int32_key.find_or_null(14), nullptr);
  EXPECT_THAT(
      MakeReserializer(s)
          .ExpectTypeDescriptorJson(
              "{\n  \"type\": {\n    \"kind\": \"record\",\n    \"value\": "
              "\"structs.skir:KeyedItems\"\n  },\n  \"records\": [\n    {\n    "
              "  \"kind\": \"struct\",\n      \"id\": "
              "\"structs.skir:KeyedItems\",\n      \"fields\": [\n        {\n  "
              "        \"name\": \"array_with_bool_key\",\n          "
              "\"number\": 0,\n          \"type\": {\n            \"kind\": "
              "\"array\",\n            \"value\": {\n              \"item\": "
              "{\n                \"kind\": \"record\",\n                "
              "\"value\": \"structs.skir:Item\"\n              },\n            "
              "  \"key_extractor\": \"bool\"\n            }\n          }\n     "
              "   },\n        {\n          \"name\": "
              "\"array_with_string_key\",\n          \"number\": 1,\n          "
              "\"type\": {\n            \"kind\": \"array\",\n            "
              "\"value\": {\n              \"item\": {\n                "
              "\"kind\": \"record\",\n                \"value\": "
              "\"structs.skir:Item\"\n              },\n              "
              "\"key_extractor\": \"string\"\n            }\n          }\n     "
              "   },\n        {\n          \"name\": "
              "\"array_with_int32_key\",\n          \"number\": 2,\n          "
              "\"type\": {\n            \"kind\": \"array\",\n            "
              "\"value\": {\n              \"item\": {\n                "
              "\"kind\": \"record\",\n                \"value\": "
              "\"structs.skir:Item\"\n              },\n              "
              "\"key_extractor\": \"int32\"\n            }\n          }\n      "
              "  },\n        {\n          \"name\": "
              "\"array_with_int64_key\",\n          \"number\": 3,\n          "
              "\"type\": {\n            \"kind\": \"array\",\n            "
              "\"value\": {\n              \"item\": {\n                "
              "\"kind\": \"record\",\n                \"value\": "
              "\"structs.skir:Item\"\n              },\n              "
              "\"key_extractor\": \"int64\"\n            }\n          }\n      "
              "  },\n        {\n          \"name\": "
              "\"array_with_wrapper_key\",\n          \"number\": 4,\n         "
              " \"type\": {\n            \"kind\": \"array\",\n            "
              "\"value\": {\n              \"item\": {\n                "
              "\"kind\": \"record\",\n                \"value\": "
              "\"structs.skir:Item\"\n              },\n              "
              "\"key_extractor\": \"user.id\"\n            }\n          }\n    "
              "    },\n        {\n          \"name\": "
              "\"array_with_enum_key\",\n          \"number\": 5,\n          "
              "\"type\": {\n            \"kind\": \"array\",\n            "
              "\"value\": {\n              \"item\": {\n                "
              "\"kind\": \"record\",\n                \"value\": "
              "\"structs.skir:Item\"\n              },\n              "
              "\"key_extractor\": \"weekday.kind\"\n            }\n          "
              "}\n        },\n        {\n          \"name\": "
              "\"array_with_bytes_key\",\n          \"number\": 6,\n          "
              "\"type\": {\n            \"kind\": \"array\",\n            "
              "\"value\": {\n              \"item\": {\n                "
              "\"kind\": \"record\",\n                \"value\": "
              "\"structs.skir:Item\"\n              },\n              "
              "\"key_extractor\": \"bytes\"\n            }\n          }\n      "
              "  },\n        {\n          \"name\": "
              "\"array_with_timestamp_key\",\n          \"number\": 7,\n       "
              "   \"type\": {\n            \"kind\": \"array\",\n            "
              "\"value\": {\n              \"item\": {\n                "
              "\"kind\": \"record\",\n                \"value\": "
              "\"structs.skir:Item\"\n              },\n              "
              "\"key_extractor\": \"timestamp\"\n            }\n          }\n  "
              "      }\n      ]\n    },\n    {\n      \"kind\": \"struct\",\n  "
              "    \"id\": \"structs.skir:Item\",\n      \"fields\": [\n       "
              " {\n          \"name\": \"bool\",\n          \"number\": 0,\n   "
              "       \"type\": {\n            \"kind\": \"primitive\",\n      "
              "      \"value\": \"bool\"\n          }\n        },\n        {\n "
              "         \"name\": \"string\",\n          \"number\": 1,\n      "
              "    \"type\": {\n            \"kind\": \"primitive\",\n         "
              "   \"value\": \"string\"\n          }\n        },\n        {\n  "
              "        \"name\": \"int32\",\n          \"number\": 2,\n        "
              "  \"type\": {\n            \"kind\": \"primitive\",\n           "
              " \"value\": \"int32\"\n          }\n        },\n        {\n     "
              "     \"name\": \"int64\",\n          \"number\": 3,\n          "
              "\"type\": {\n            \"kind\": \"primitive\",\n            "
              "\"value\": \"int64\"\n          }\n        },\n        {\n      "
              "    \"name\": \"user\",\n          \"number\": 4,\n          "
              "\"type\": {\n            \"kind\": \"record\",\n            "
              "\"value\": \"structs.skir:Item.User\"\n          }\n        "
              "},\n        {\n          \"name\": \"weekday\",\n          "
              "\"number\": 5,\n          \"type\": {\n            \"kind\": "
              "\"record\",\n            \"value\": \"enums.skir:Weekday\"\n    "
              "      }\n        },\n        {\n          \"name\": "
              "\"bytes\",\n          \"number\": 6,\n          \"type\": {\n   "
              "         \"kind\": \"primitive\",\n            \"value\": "
              "\"bytes\"\n          }\n        },\n        {\n          "
              "\"name\": \"timestamp\",\n          \"number\": 7,\n          "
              "\"type\": {\n            \"kind\": \"primitive\",\n            "
              "\"value\": \"timestamp\"\n          }\n        }\n      ]\n    "
              "},\n    {\n      \"kind\": \"struct\",\n      \"id\": "
              "\"structs.skir:Item.User\",\n      \"fields\": [\n        {\n   "
              "       \"name\": \"id\",\n          \"number\": 0,\n          "
              "\"type\": {\n            \"kind\": \"primitive\",\n            "
              "\"value\": \"string\"\n          }\n        }\n      ]\n    "
              "},\n    {\n      \"kind\": \"enum\",\n      \"id\": "
              "\"enums.skir:Weekday\",\n      \"doc\": \"A day of the "
              "week\",\n      \"variants\": [\n        {\n          \"name\": "
              "\"monday\",\n          \"number\": 1\n        },\n        {\n   "
              "       \"name\": \"tuesday\",\n          \"number\": 2\n        "
              "},\n        {\n          \"name\": \"wednesday\",\n          "
              "\"number\": 3\n        },\n        {\n          \"name\": "
              "\"thursday\",\n          \"number\": 4\n        },\n        {\n "
              "         \"name\": \"friday\",\n          \"number\": 5\n       "
              " },\n        {\n          \"name\": \"saturday\",\n          "
              "\"number\": 6\n        },\n        {\n          \"name\": "
              "\"sunday\",\n          \"number\": 7\n        }\n      ]\n    "
              "}\n  ]\n}")
          .Check()
          .ok(),
      IsTrue());
}

TEST(skiroutTest, Constants) {
  skirout_constants::k_one_constant();
  EXPECT_EQ(skirout_constants::k_one_single_quoted_string(),
            std::string("\"\0Pokémon\n\"", 12));
}

TEST(skiroutTest, Methods) {
  using ::skirout_methods::MyProcedure;
  static_assert(std::is_same_v<typename MyProcedure::request_type,
                               skirout_structs::Point>);
  static_assert(std::is_same_v<typename MyProcedure::response_type,
                               skirout_enums::JsonValue>);
  constexpr int kNumber = MyProcedure::kNumber;
  EXPECT_EQ(kNumber, 674706602);
  constexpr absl::string_view kMethodName = MyProcedure::kMethodName;
  EXPECT_EQ(kMethodName, "MyProcedure");
}

TEST(skiroutTest, NestedRecordAlias) {
  static_assert(
      std::is_same_v<skirout_structs::Item::User, skirout_structs::Item_User>);
  static_assert(
      std::is_same_v<skirout_structs::Name::Name_, skirout_structs::Name_Name>);
  static_assert(std::is_same_v<skirout_structs::Name::Name_::Name,
                               skirout_structs::Name_Name_Name>);
  static_assert(std::is_same_v<skirout_enums::JsonValue::Pair,
                               skirout_enums::JsonValue_Pair>);
}

TEST(skiroutTest, StructMatcher) {
  const FullName full_name = {
      .first_name = "John",
      .last_name = "Doe",
  };
  EXPECT_THAT(full_name, (::testing::skirout::StructIs<FullName>{
                             .first_name = testing::StartsWith("J"),
                         }));

  const CarOwner car_owner = CarOwner::whole{
      .car =
          Car::whole{
              .model = "Toyota",
              .owner = User{},
              .purchase_time = absl::FromUnixMillis(1000),
              .second_owner = absl::nullopt,
          },
      .owner =
          FullName::whole{
              .first_name = "Osi",
              .last_name = "Daro",
          },
  };
  EXPECT_THAT(car_owner, (::testing::skirout::StructIs<CarOwner>{
                             .car =
                                 {
                                     .model = testing::StartsWith("To"),
                                     .purchase_time = testing::_,
                                     .second_owner = testing::Eq(absl::nullopt),
                                 },
                             .owner = {
                                 .first_name = "Osi",
                             }}));

  EXPECT_THAT((skirout_enums::WeekdayHolder{
                  .weekday = skirout_enums::Weekday::kFriday,
              }),
              (::testing::skirout::StructIs<skirout_enums::WeekdayHolder>{
                  .weekday = testing::Eq(skirout_enums::Weekday::kFriday),
              }));
}

TEST(skiroutTest, EnumValueMatcher) {
  EXPECT_THAT(StatusEnum::wrap_error("E"), ::testing::skirout::IsError());
  EXPECT_THAT(StatusEnum::wrap_error("E"),
              ::testing::skirout::IsError(::testing::StartsWith("E")));
}

struct FieldNameCollector {
  FieldNameCollector() = default;

  FieldNameCollector(const FieldNameCollector &) = delete;
  FieldNameCollector(FieldNameCollector &&) = delete;
  FieldNameCollector &operator=(const FieldNameCollector &) = delete;
  FieldNameCollector &operator=(FieldNameCollector &&) = delete;

  absl::flat_hash_set<absl::string_view> field_names;

  template <typename Getter, typename Value>
  void operator()(skir::reflection::struct_field<Getter, Value>) {
    field_names.insert(Getter::kFieldName);
  }

  template <typename Const>
  void operator()(skir::reflection::enum_const_variant<Const>) {
    field_names.insert(Const::kVariantName);
  }

  template <typename Option, typename Value>
  void operator()(skir::reflection::enum_wrapper_variant<Option, Value>) {
    field_names.insert(Option::kVariantName);
  }
};

TEST(skiroutTest, IsRecord) {
  static_assert(skir::reflection::IsStruct<User>());
  static_assert(!skir::reflection::IsStruct<Weekday>());
  static_assert(!skir::reflection::IsEnum<User>());
  static_assert(skir::reflection::IsEnum<Weekday>());
  static_assert(skir::reflection::IsRecord<User>());
  static_assert(skir::reflection::IsRecord<Weekday>());
  static_assert(!skir::reflection::IsRecord<std::string>());
}

TEST(skiroutTest, ForEachVariantOfEnum) {
  FieldNameCollector collector;
  skir::reflection::ForEachVariant<StatusEnum>(collector);
  EXPECT_THAT(collector.field_names,
              UnorderedElementsAre("unknown", "ok", "error"));

  // Just to make sure we can pass an rvalue.
  skir::reflection::ForEachVariant<StatusEnum>(FieldNameCollector());
}

TEST(skiroutTest, ForEachFieldOfStruct) {
  FieldNameCollector collector;
  skir::reflection::ForEachField<FullName>(collector);
  EXPECT_THAT(collector.field_names,
              UnorderedElementsAre("first_name", "last_name"));
}

TEST(skiroutTest, RecursiveStruct) {
  absl::flat_hash_set<Rec> recs;
  recs.insert(Rec{});
  recs.insert(Rec{});
  recs.insert(Rec{.b = true});
  EXPECT_THAT(recs.size(), 2);
  {
    Rec rec;
    rec.rec = Rec{};
    recs.insert(rec);
  }
  EXPECT_THAT(recs.size(), 2);
  {
    Rec rec;
    rec.rec = Rec{};
    rec.rec->rec = Rec{};
    rec.b = true;
    recs.insert(rec);
  }
  EXPECT_THAT(recs.size(), 2);
  {
    Rec rec;
    rec.rec = Rec{};
    rec.rec->rec = Rec{};
    rec.rec->rec->b = true;
    recs.insert(rec);
  }
  EXPECT_THAT(recs.size(), 3);
  {
    Rec rec;
    rec.rec->rec->b = true;
    rec.rec->rec->rec->rec->b = false;
    EXPECT_THAT(skir_internal::ToDebugString(rec),
                "{\n  .rec: {\n    .rec: {\n      .b: true,\n    },\n  },\n}");
  }
}

class FakeServiceImplWithMeta {
public:
  using methods =
      std::tuple<skirout_methods::MyProcedure, skirout_methods::ListUsers>;

  ::skirout_enums::JsonValue
  operator()(skirout_methods::MyProcedure, ::skirout_structs::Point request,
             const ::skir::service::HttpHeaders &request_headers) {
    return ::skirout_enums::JsonValue::wrap_number(request.x);
  }

  absl::StatusOr<skirout_methods::ListUsersResponse>
  operator()(skirout_methods::ListUsers,
             const ::skirout_methods::ListUsersRequest &request,
             const ::skir::service::HttpHeaders &request_headers) {
    return absl::UnknownError("unsupported");
  }
};

TEST(SkirlibTest, SkirService) {
  FakeServiceImplWithMeta service_impl;
  std::unique_ptr<skir::service::Client> client =
      skir::service::MakeClientForTesting(&service_impl);

  {
    skir::service::HttpHeaders request_headers;
    request_headers.Insert("origin", "foo");
    const absl::StatusOr<::skirout_enums::JsonValue> result =
        ::skir::service::InvokeRemote(*client, skirout_methods::MyProcedure(),
                                      skirout_structs::Point{.x = 1, .y = 2},
                                      request_headers);
    ASSERT_THAT(result.ok(), IsTrue());
    EXPECT_THAT(*result, ::skirout_enums::JsonValue::wrap_number(1.0));
  }
}

} // namespace
