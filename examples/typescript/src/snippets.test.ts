// Unit test example using mocha and buckwheat.
// More info about buckwheat: https://github.com/gepheum/buckwheat
import { expect, near } from "buckwheat";
import { describe, it } from "mocha";
import { Timestamp } from "skir-client";
import { User } from "../skirout/user";

describe("skir unit test example", () => {
  const tarzan: User = User.create({
    userId: 123,
    name: "Tarzan",
    quote: "AAAAaAaAaAyAAAAaAaAaAyAAAAaAaAaA",
    pets: [
      {
        name: "Cheeta",
        heightInMeters: 1.67,
        picture: "🐒",
      },
    ],
    subscriptionStatus: {
      kind: "trial",
      value: {
        startTime: Timestamp.fromUnixMillis(1234),
      },
    },
  });

  it("expects struct to match", () => {
    expect(tarzan).toMatch({
      name: "Tarzan",
      quote: /^A/, // must start with the letter A
      pets: [
        {
          name: "Cheeta",
          heightInMeters: near(1.6, 0.1),
        },
      ],
      subscriptionStatus: {
        union: {
          kind: "trial",
          value: {
            startTime: Timestamp.fromUnixMillis(1234),
          },
        },
      },
      // `userId` is not specified so it can be anything
    });
  });
});
