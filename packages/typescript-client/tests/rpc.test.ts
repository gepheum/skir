import { describe, it } from "mocha";
import assert from "node:assert/strict";
import * as skir from "../src/skir-client.js";

const echo: skir.Method<string, string> = {
  name: "Echo",
  number: 7,
  requestSerializer: skir.primitiveSerializer("string"),
  responseSerializer: skir.primitiveSerializer("string"),
  doc: "",
};

describe("RPC module integration", () => {
  for (const httpMethod of ["GET", "POST"] as const) {
    it(`round trips ${httpMethod} requests through the client and service`, async () => {
      const service = new skir.Service<{ authorization: string }>();
      service.addMethod(echo, async (input, meta): Promise<string> => {
        assert.equal(meta.authorization, "Bearer test");
        return input + "!";
      });
      const originalFetch = globalThis.fetch;
      globalThis.fetch = async (input, init): Promise<Response> => {
        const url = new URL(String(input));
        const body =
          init?.method === "GET"
            ? decodeURIComponent(url.search.slice(1))
            : String(init?.body);
        const result = await service.handleRequest(body, {
          authorization: new Headers(init?.headers).get("Authorization")!,
        });
        return new Response(result.data, {
          status: result.statusCode,
          headers: { "Content-Type": result.contentType },
        });
      };
      try {
        const client = new skir.ServiceClient(
          "https://example.test/rpc",
          () => ({
            headers: { Authorization: "Bearer test" },
          }),
        );
        assert.equal(
          await client.invokeRemote(echo, "100%", httpMethod),
          "100%!",
        );
      } finally {
        globalThis.fetch = originalFetch;
      }
    });
  }

  it("returns explicit service errors and masks unexpected errors", async () => {
    const service = new skir.Service<undefined>({
      errorLogger: (): void => {},
    });
    service.addMethod(echo, async (input): Promise<string> => {
      if (input === "denied") {
        throw new skir.ServiceError({ statusCode: 403, desc: "Forbidden" });
      }
      throw new Error("private information");
    });
    const denied = await service.handleRequest('Echo:7::"denied"', undefined);
    assert.equal(denied.statusCode, 403);
    assert.equal(denied.data, "Forbidden");
    const unexpected = await service.handleRequest('Echo:7::"fail"', undefined);
    assert.equal(unexpected.statusCode, 500);
    assert.equal(unexpected.data, "server error");
  });
});
