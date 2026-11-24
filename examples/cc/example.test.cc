// Unit tests examples
//
// Run with:
//   ctest --output-on-failure

#include <gtest/gtest.h>

#include "absl/time/time.h"
#include "gmock/gmock.h"
#include "skirout/user.h"
#include "skirout/user.testing.h"

TEST(ExampleTest, TestStruct) {
  using ::skirout_user::SubscriptionStatus;
  using ::skirout_user::User;
  using ::testing::skirout::StructIs;

  const User john = {
      .name = "John Doe",
      .pets =
          {
              {.height_in_meters = 1.67, .name = "Cheeta", .picture = "🐒"},
          },
      .quote = "Life is like a box of chocolates.",
      .user_id = 42,
  };

  EXPECT_THAT(john, (StructIs<User>{
                        // Only the specified fields are tested
                        .pets = testing::ElementsAre(StructIs<User::Pet>{
                            .height_in_meters = testing::FloatNear(1.7, 0.1),
                        }),
                        .quote = testing::StartsWith("Life is"),
                        .user_id = 42,
                    }));
}

TEST(ExampleTest, TestEnum) {
  using ::skirout_user::SubscriptionStatus;
  using ::testing::skirout::IsTrial;
  using ::testing::skirout::StructIs;

  SubscriptionStatus john_status = skirout::kFree;

  EXPECT_THAT(john_status, testing::Eq(skirout::kFree));

  SubscriptionStatus jade_status = SubscriptionStatus::wrap_trial(
      {.start_time = absl::FromUnixMillis(1743682787000)});

  EXPECT_THAT(jade_status, IsTrial());
  EXPECT_THAT(jade_status, IsTrial(StructIs<SubscriptionStatus::Trial>{
                               .start_time = testing::Gt(absl::UnixEpoch())}));
}
