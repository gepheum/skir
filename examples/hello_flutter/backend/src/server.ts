// Starts a SkirRPC service at http://localhost:8080/api
//
// Run with:
//   bun run src/server.ts
//
// Visit http://localhost:8080/api?studio in your browser to test the service.

import { Service } from "skir-client";
import { Greet, GreetRequest, GreetResponse } from "../skirout/greet.js";

const PORT = 8080;

const service = new Service<undefined>().addMethod(
  Greet,
  async (req: GreetRequest): Promise<GreetResponse> => {
    return GreetResponse.create({ message: `Hello, ${req.name}!` });
  },
);

const server = Bun.serve({
  port: PORT,
  async fetch(req: Request): Promise<Response> {
    const url = new URL(req.url);

    // Handle CORS preflight
    if (req.method === "OPTIONS") {
      return new Response(null, {
        status: 204,
        headers: corsHeaders(),
      });
    }

    if (url.pathname === "/api") {
      let body: string;
      if (req.method === "POST") {
        body = await req.text();
      } else if (req.method === "GET") {
        body = decodeURIComponent(url.search.substring(1));
      } else {
        return new Response("Method Not Allowed", { status: 405 });
      }

      const rawResponse = await service.handleRequest(body, undefined);
      return new Response(rawResponse.data, {
        status: rawResponse.statusCode,
        headers: {
          "Content-Type": rawResponse.contentType,
          ...corsHeaders(),
        },
      });
    }

    return new Response("Not Found", { status: 404 });
  },
});

console.log(`Server running at http://localhost:${server.port}/`);
console.log(`RPC Studio: http://localhost:${server.port}/api?studio`);

function corsHeaders(): Record<string, string> {
  return {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type",
  };
}
