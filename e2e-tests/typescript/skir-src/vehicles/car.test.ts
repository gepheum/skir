import { expect } from "buckwheat";
import { describe, it } from "mocha";
import { Timestamp } from "skir-client";
import { SerializerTester } from "../../../node_modules/skir-client/dist/esm/serializer_tester.js";
import { Car } from "../../skirout/vehicles/car.js";

describe("Car", () => {
  it("TypeDescriptor#asJson()", () => {
    expect(Car.serializer.typeDescriptor.asJson()).toMatch({
      type: {
        kind: "record",
        value: "vehicles/car.skir:Car",
      },
      records: [
        {
          kind: "struct",
          id: "vehicles/car.skir:Car",
          fields: [
            {
              name: "model",
              type: {
                kind: "primitive",
                value: "string",
              },
              number: 0,
            },
            {
              name: "purchase_time",
              type: {
                kind: "primitive",
                value: "timestamp",
              },
              number: 1,
            },
            {
              name: "owner",
              type: {
                kind: "record",
                value: "user.skir:User",
              },
              number: 2,
            },
            {
              name: "second_owner",
              type: {
                kind: "optional",
                value: {
                  kind: "record",
                  value: "user.skir:User",
                },
              },
              number: 3,
            },
          ],
        },
        {
          kind: "struct",
          id: "user.skir:User",
          fields: [
            {
              name: "user_id",
              type: {
                kind: "primitive",
                value: "int64",
              },
              number: 0,
            },
          ],
        },
      ],
    });
    new SerializerTester(
      Car.serializer,
    ).reserializeTypeAdapterAndAssertNoLoss();
  });

  it("reserialize", () => {
    const serializer = Car.serializer;
    const serializerTester = new SerializerTester(serializer);
    serializerTester.reserializeAndAssert(
      Car.create<"partial">({
        model: "Toyota Camry",
        owner: {
          userId: BigInt(123),
        },
        purchaseTime: Timestamp.fromUnixMillis(5000),
      }),
      {
        denseJson: ["Toyota Camry", 5000, [123]],
        readableJson: {
          model: "Toyota Camry",
          purchase_time: {
            unix_millis: 5000,
            formatted: "1970-01-01T00:00:05.000Z",
          },
          owner: {
            user_id: 123,
          },
        },
        bytesAsBase16: "f9f30c546f796f74612043616d7279ef8813000000000000f77b",
      },
    );
  });
});
