import { expect, is } from "buckwheat";
import { describe, it } from "mocha";
import * as skir from "skir-client";
import { JsonValue } from "../skirout/enums.js";
import {
  MyMethod,
  MyProcedure,
  MyRequest,
  MyResponse,
  WithExplicitNumber,
} from "../skirout/methods.js";
import { Point } from "../skirout/structs.js";

describe("methods", () => {
  describe("works", () => {
    it("#0", () => {
      const _: skir.Method<Point, JsonValue> = MyProcedure;
      expect(MyProcedure).toMatch({
        name: "MyProcedure",
        number: 674706602,
        requestSerializer: is(Point.serializer),
        responseSerializer: is(JsonValue.serializer),
      });
      expect(MyMethod).toMatch({
        name: "MyMethod",
        requestSerializer: is(MyRequest.serializer),
        responseSerializer: is(MyResponse.serializer),
      });
    });
    it("#1", () => {
      const _: skir.Method<
        ReadonlyArray<Point>,
        JsonValue | null
      > = WithExplicitNumber;
      expect(WithExplicitNumber).toMatch({
        name: "WithExplicitNumber",
        number: 3,
      });
    });
  });
});
