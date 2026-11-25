import type {
  Express as ExpressApp,
  json as ExpressJson,
  Request as ExpressRequest,
  Response as ExpressResponse,
  text as ExpressText,
} from "express";
import type { Json, Serializer } from "./serializers/base.js";
import type { AnyRecord } from "./serializers/records.js";

/**
 * Identifies a procedure (the "P" in "RPC") on both the client side and the
 * server side.
 */
export interface Method<Request, Response> {
  /** Name of the procedure as specified in the '.skir' file. */
  name: string;
  /**
   * A number which uniquely identifies this procedure.
   * When it is not specified in the '.skir' file, it is obtained by hashing the
   * procedure name.
   */
  number: number;
  /** Serializer of request objects. */
  requestSerializer: Serializer<Request>;
  /** Serializer of response objects. */
  responseSerializer: Serializer<Response>;
  /**
   * Documentation for this procedure, specified as doc comments in the '.skir'
   * file. May be empty.
   */
  doc: string;
}

/** Metadata of an HTTP request sent by a service client. */
export type RequestMeta = Omit<RequestInit, "body" | "method">;

/** Sends RPCs to a SkirRPC service. */
export class ServiceClient {
  constructor(
    private readonly serviceUrl: string,
    private readonly getRequestMetadata: (
      m: Method<unknown, unknown>,
    ) => Promise<RequestMeta> | RequestMeta = (): RequestMeta => ({}),
  ) {
    const url = new URL(serviceUrl);
    if (url.search) {
      throw new Error("Service URL must not contain a query string");
    }
  }

  /** Invokes the given method on the remote server through an RPC. */
  async invokeRemote<Request, Response>(
    method: Method<Request, Response>,
    request: Request,
    httpMethod: "GET" | "POST" = "POST",
  ): Promise<Response> {
    const requestJson = method.requestSerializer.toJsonCode(request);
    const requestBody = [method.name, method.number, "", requestJson].join(":");
    const requestInit: RequestInit = {
      ...(await Promise.resolve(this.getRequestMetadata(method))),
    };
    const url = new URL(this.serviceUrl);
    requestInit.method = httpMethod;
    if (httpMethod === "POST") {
      requestInit.body = requestBody;
    } else {
      url.search = requestBody.replace(/%/g, "%25");
    }
    const httpResponse = await fetch(url, requestInit);
    const responseData = await httpResponse.blob();
    if (httpResponse.ok) {
      const jsonCode = await responseData.text();
      return method.responseSerializer.fromJsonCode(
        jsonCode,
        "keep-unrecognized-values",
      );
    } else {
      let message = "";
      if (/text\/plain\b/.test(responseData.type)) {
        message = `: ${await responseData.text()}`;
      }
      throw new Error(`HTTP status ${httpResponse.status}${message}`);
    }
  }
}

/** Raw response returned by the server. */
export interface RawResponse {
  readonly data: string;
  readonly statusCode: number;
  readonly contentType: string;
}

function makeOkJsonResponse(data: string): RawResponse {
  return {
    data: data,
    statusCode: 200,
    contentType: "application/json",
  };
}

function makeOkHtmlResponse(data: string): RawResponse {
  return {
    data: data,
    statusCode: 200,
    contentType: "text/html; charset=utf-8",
  };
}

function makeBadRequestResponse(data: string): RawResponse {
  return {
    data: data,
    statusCode: 400,
    contentType: "text/plain; charset=utf-8",
  };
}

function makeServerErrorResponse(data: string, statusCode = 500): RawResponse {
  return {
    data: data,
    statusCode: statusCode,
    contentType: "text/plain; charset=utf-8",
  };
}

function getStudioHtml(studioAppJsUrl: string): string {
  // Copied from
  //   https://github.com/gepheum/skir/blob/main/packages/studio/index.jsdeliver.html

  // 'studioAppJsUrl' is produced by new URL(...).toString() so it can't contain
  // any special characters that need escaping in HTML.
  return `<!DOCTYPE html>

<html>
  <head>
    <meta charset="utf-8" />
    <title>RPC Studio</title>
    <link rel="icon" href="data:image/svg+xml,<svg xmlns=%22http://www.w3.org/2000/svg%22 viewBox=%220 0 100 100%22><text y=%22.9em%22 font-size=%2290%22>🐙</text></svg>">
    <script src="${studioAppJsUrl}"></script>
  </head>
  <body style="margin: 0; padding: 0;">
    <skir-studio-app></skir-studio-app>
  </body>
</html>
`;
}

/**
 * If this error is thrown from a method implementation, the specified status
 * code and message will be returned in the HTTP response.
 *
 * If any other type of exception is thrown, the response status code will be
 * 500 (Internal Server Error).
 */
export class ServiceError extends Error {
  constructor(
    private readonly spec:
      | {
          statusCode: 400;
          desc: "Bad Request";
          message?: string;
        }
      | {
          statusCode: 401;
          desc: "Unauthorized";
          message?: string;
        }
      | {
          statusCode: 402;
          desc: "Payment Required";
          message?: string;
        }
      | {
          statusCode: 403;
          desc: "Forbidden";
          message?: string;
        }
      | {
          statusCode: 404;
          desc: "Not Found";
          message?: string;
        }
      | {
          statusCode: 405;
          desc: "Method Not Allowed";
          message?: string;
        }
      | {
          statusCode: 406;
          desc: "Not Acceptable";
          message?: string;
        }
      | {
          statusCode: 407;
          desc: "Proxy Authentication Required";
          message?: string;
        }
      | {
          statusCode: 408;
          desc: "Request Timeout";
          message?: string;
        }
      | {
          statusCode: 409;
          desc: "Conflict";
          message?: string;
        }
      | {
          statusCode: 410;
          desc: "Gone";
          message?: string;
        }
      | {
          statusCode: 411;
          desc: "Length Required";
          message?: string;
        }
      | {
          statusCode: 412;
          desc: "Precondition Failed";
          message?: string;
        }
      | {
          statusCode: 413;
          desc: "Content Too Large";
          message?: string;
        }
      | {
          statusCode: 414;
          desc: "URI Too Long";
          message?: string;
        }
      | {
          statusCode: 415;
          desc: "Unsupported Media Type";
          message?: string;
        }
      | {
          statusCode: 416;
          desc: "Range Not Satisfiable";
          message?: string;
        }
      | {
          statusCode: 417;
          desc: "Expectation Failed";
          message?: string;
        }
      | {
          statusCode: 418;
          desc: "I'm a teapot";
          message?: string;
        }
      | {
          statusCode: 421;
          desc: "Misdirected Request";
          message?: string;
        }
      | {
          statusCode: 422;
          desc: "Unprocessable Content";
          message?: string;
        }
      | {
          statusCode: 423;
          desc: "Locked";
          message?: string;
        }
      | {
          statusCode: 424;
          desc: "Failed Dependency";
          message?: string;
        }
      | {
          statusCode: 425;
          desc: "Too Early";
          message?: string;
        }
      | {
          statusCode: 426;
          desc: "Upgrade Required";
          message?: string;
        }
      | {
          statusCode: 428;
          desc: "Precondition Required";
          message?: string;
        }
      | {
          statusCode: 429;
          desc: "Too Many Requests";
          message?: string;
        }
      | {
          statusCode: 431;
          desc: "Request Header Fields Too Large";
          message?: string;
        }
      | {
          statusCode: 451;
          desc: "Unavailable For Legal Reasons";
          message?: string;
        }
      | {
          statusCode: 500;
          desc: "Internal Server Error";
          message?: string;
        }
      | {
          statusCode: 501;
          desc: "Not Implemented";
          message?: string;
        }
      | {
          statusCode: 502;
          desc: "Bad Gateway";
          message?: string;
        }
      | {
          statusCode: 503;
          desc: "Service Unavailable";
          message?: string;
        }
      | {
          statusCode: 504;
          desc: "Gateway Timeout";
          message?: string;
        }
      | {
          statusCode: 505;
          desc: "HTTP Version Not Supported";
          message?: string;
        }
      | {
          statusCode: 506;
          desc: "Variant Also Negotiates";
          message?: string;
        }
      | {
          statusCode: 507;
          desc: "Insufficient Storage";
          message?: string;
        }
      | {
          statusCode: 508;
          desc: "Loop Detected";
          message?: string;
        }
      | {
          statusCode: 510;
          desc: "Not Extended";
          message?: string;
        }
      | {
          statusCode: 511;
          desc: "Network Authentication Required";
          message?: string;
        },
  ) {
    super(spec.message ?? spec.desc);
  }

  toRawResponse(): RawResponse {
    return makeServerErrorResponse(
      this.spec.message ?? this.spec.desc,
      this.spec.statusCode,
    );
  }
}

export interface RequestHandler<RequestMeta = ExpressRequest> {
  /**
   * Parses the content of a user request and invokes the appropriate method.
   * If you are using ExpressJS as your web application framework, you don't
   * need to call this method, you can simply call the
   * `installServiceOnExpressApp()` top-level function.
   *
   * If the request is a GET request, pass in the decoded query string as the
   * request's body. The query string is the part of the URL after '?', and it
   * can be decoded with DecodeURIComponent.
   */
  handleRequest(reqBody: string, reqMeta: RequestMeta): Promise<RawResponse>;
}

/** Configuration options for a SkirRPC service. */
export interface ServiceOptions<RequestMeta = ExpressRequest> {
  /**
   * Whether to keep unrecognized values when deserializing requests.
   *
   * **WARNING:** Only enable this for data from trusted sources. Malicious
   * actors could inject fields with IDs not yet defined in your schema. If you
   * preserve this data and later define those IDs in a future schema version,
   * the injected data could be deserialized as valid fields, leading to
   * security vulnerabilities or data corruption.
   *
   * Defaults to `false`.
   */
  keepUnrecognizedValues: boolean;

  /**
   * Whether the message of an unknown error (i.e. not a `ServiceError`) can be
   * sent to the client in the response body, which can help with debugging.
   *
   * By default, unknown errors are masked and the client receives a generic
   * 'server error' message with status 500. This is to prevent leaking
   * sensitive information to the client.
   *
   * You can enable this if your server is internal or if you are sure that your
   * error messages are safe to expose. By passing a predicate instead of true
   * or false, you can control on a per-error basis whether to expose the error
   * message; for example, you can send error messages only if the user is an
   * admin.
   *
   * Defaults to `false`.
   */
  canSendUnknownErrorMessage:
    boolean | ((errorInfo: MethodErrorInfo<RequestMeta, unknown>) => boolean);

  /**
   * Callback invoked whenever an error is thrown during method execution.
   *
   * Use this to log errors for monitoring, debugging, or alerting purposes.
   *
   * Defaults to function which logs the method name and error message via
   * `console.error()`.
   */
  errorLogger: (errorInfo: MethodErrorInfo<RequestMeta, unknown>) => void;

  /**
   * URL to the JavaScript file for the Skir Studio app.
   *
   * Skir Studio is a web interface for exploring and testing your SkirRPC service.
   * It is served when the service receives a request at '${serviceUrl}?studio'.
   */
  studioAppJsUrl: string;
}

/**
 * Information about an error thrown during the execution of a method on the
 * server side.
 */
interface MethodErrorInfo<RequestMeta, Request> {
  /** The error thrown during the execution of the method. */
  readonly error: any;
  readonly method: Method<Request, unknown>;
  readonly request: Request;
  /**
   * Metadata coming from the HTTP headers of the request.
   * Undefined if the error was thrown in the execution of the function passed
   * to `withMetaTransformer()`.
   */
  readonly reqMeta: RequestMeta | undefined;
}

/**
 * Implementation of a SkirRPC service.
 *
 * Usage: call `.addMethod()` to register methods, then install the service on
 * an HTTP server either by:
 *   - calling the `installServiceOnExpressApp()` top-level function if you are
 *       using ExpressJS
 *   - writing your own implementation of `installServiceOn*()` which calls
 *       `.handleRequest()` if you are using another web application framework
 *
 * ## Handling Request Metadata
 *
 * The `RequestMeta` type parameter specifies what metadata (authentication,
 * headers, etc.) your method implementations receive. There are two approaches:
 *
 * ### Approach 1: Use the framework's request type directly
 *
 * Set `RequestMeta` to your framework's request type (e.g., `ExpressRequest`).
 * All method implementations will receive the full framework request object.
 *
 * ```typescript
 * const service = new Service<ExpressRequest>();
 * service.addMethod(myMethod, async (req, expressReq) => {
 *   const isAdmin = expressReq.user?.role === 'admin';
 *   // ...
 * });
 * installServiceOnExpressApp(app, '/api', service, text, json);
 * ```
 *
 * ### Approach 2: Use a simplified custom type
 *
 * Set `RequestMeta` to a minimal type containing only what your service needs.
 * Use `withMetaTransformer()` to extract this data from the framework request
 * when installing the service.
 *
 * ```typescript
 * const service = new Service<{ isAdmin: boolean }>();
 * service.addMethod(myMethod, async (req, { isAdmin }) => {
 *   // Implementation is framework-agnostic and easy to unit test
 *   if (!isAdmin) throw new ServiceError({ statusCode: 403, desc: "Forbidden" });
 *   // ...
 * });
 *
 * // Adapt to Express when installing
 * const handler = service.withMetaTransformer((req: ExpressRequest) => ({
 *   isAdmin: req.user?.role === 'admin'
 * }));
 * installServiceOnExpressApp(app, '/api', handler, text, json);
 * ```
 *
 * This approach decouples your service from the HTTP framework, making it easier
 * to test and clearer about what request data it actually uses.
 */
export class Service<
  RequestMeta = ExpressRequest,
> implements RequestHandler<RequestMeta> {
  constructor(options?: Partial<ServiceOptions<RequestMeta>>) {
    this.options = {
      keepUnrecognizedValues:
        options?.keepUnrecognizedValues ??
        DEFAULT_SERVICE_OPTIONS.keepUnrecognizedValues,
      canSendUnknownErrorMessage:
        options?.canSendUnknownErrorMessage ??
        DEFAULT_SERVICE_OPTIONS.canSendUnknownErrorMessage,
      errorLogger: options?.errorLogger ?? DEFAULT_SERVICE_OPTIONS.errorLogger,
      studioAppJsUrl: new URL(
        options?.studioAppJsUrl ?? DEFAULT_SERVICE_OPTIONS.studioAppJsUrl,
      ).toString(),
    };
  }

  addMethod<Request, Response>(
    method: Method<Request, Response>,
    impl: (req: Request, reqMeta: RequestMeta) => Promise<Response>,
  ): Service<RequestMeta> {
    const { number } = method;
    if (this.methodImpls[number]) {
      throw new Error(
        `Method with the same number already registered (${number})`,
      );
    }
    this.methodImpls[number] = {
      method: method,
      impl: impl,
    } as MethodImpl<unknown, unknown, RequestMeta>;
    return this;
  }

  async handleRequest(
    reqBody: string,
    reqMeta: RequestMeta,
  ): Promise<RawResponse> {
    return this.doHandleRequest(reqBody, reqMeta, (m) => m);
  }

  private async doHandleRequest<OriginalRequestMeta>(
    reqBody: string,
    originalReqMeta: OriginalRequestMeta,
    transformReqMeta: (
      m: OriginalRequestMeta,
    ) => RequestMeta | Promise<RequestMeta>,
  ): Promise<RawResponse> {
    if (reqBody === "list") {
      const json = {
        methods: Object.values(this.methodImpls).map((methodImpl) => ({
          method: methodImpl.method.name,
          number: methodImpl.method.name,
          request: methodImpl.method.requestSerializer.typeDescriptor.asJson(),
          response:
            methodImpl.method.responseSerializer.typeDescriptor.asJson(),
          doc: methodImpl.method.doc || undefined,
        })),
      };
      const jsonCode = JSON.stringify(json, undefined, "  ");
      return makeOkJsonResponse(jsonCode);
    } else if (reqBody === "" || reqBody === "studio") {
      const studioHtml = getStudioHtml(this.options.studioAppJsUrl);
      return makeOkHtmlResponse(studioHtml);
    }

    // Parse request
    let methodName: string;
    let methodNumber: number | undefined;
    let format: string;
    let requestData: ["json", Json] | ["json-code", string];

    const firstChar = reqBody.charAt(0);
    if (/\s/.test(firstChar) || firstChar === "{") {
      // A JSON object
      let reqBodyJson: Json;
      try {
        reqBodyJson = JSON.parse(reqBody);
      } catch (_e) {
        return makeBadRequestResponse("bad request: invalid JSON");
      }
      const methodField = (reqBodyJson as AnyRecord)["method"];
      if (methodField === undefined) {
        return makeBadRequestResponse(
          "bad request: missing 'method' field in JSON",
        );
      }
      if (typeof methodField === "string") {
        methodName = methodField;
        methodNumber = undefined;
      } else if (typeof methodField === "number") {
        methodName = "?";
        methodNumber = methodField;
      } else {
        return makeBadRequestResponse(
          "bad request: 'method' field must be a string or a number",
        );
      }
      format = "readable";
      const requestField = (reqBodyJson as AnyRecord)["request"];
      if (requestField === undefined) {
        return makeBadRequestResponse(
          "bad request: missing 'request' field in JSON",
        );
      }
      requestData = ["json", requestField as Json];
    } else {
      // A colon-separated string
      const match = reqBody.match(/^([^:]*):([^:]*):([^:]*):([\S\s]*)$/);
      if (!match) {
        return makeBadRequestResponse("bad request: invalid request format");
      }
      methodName = match[1]!;
      const methodNumberStr = match[2]!;
      format = match[3]!;
      requestData = ["json-code", match[4]!];

      if (methodNumberStr) {
        if (!/^-?[0-9]+$/.test(methodNumberStr)) {
          return makeBadRequestResponse(
            "bad request: can't parse method number",
          );
        }
        methodNumber = parseInt(methodNumberStr);
      } else {
        methodNumber = undefined;
      }
    }

    // Look up method by number or name
    if (methodNumber === undefined) {
      // Try to get the method number by name
      const allMethods = Object.values(this.methodImpls);
      const nameMatches = allMethods.filter(
        (m) => m.method.name === methodName,
      );
      if (nameMatches.length === 0) {
        return makeBadRequestResponse(
          `bad request: method not found: ${methodName}`,
        );
      } else if (nameMatches.length > 1) {
        return makeBadRequestResponse(
          `bad request: method name '${methodName}' is ambiguous; use method number instead`,
        );
      }
      methodNumber = nameMatches[0]!.method.number;
    }

    const methodImpl = this.methodImpls[methodNumber];
    if (!methodImpl) {
      return makeBadRequestResponse(
        `bad request: method not found: ${methodName}; number: ${methodNumber}`,
      );
    }

    let req: unknown;
    try {
      if (requestData[0] == "json") {
        req = methodImpl.method.requestSerializer.fromJson(
          requestData[1],
          this.options.keepUnrecognizedValues
            ? "keep-unrecognized-values"
            : undefined,
        );
      } else {
        req = methodImpl.method.requestSerializer.fromJsonCode(
          requestData[1],
          this.options.keepUnrecognizedValues
            ? "keep-unrecognized-values"
            : undefined,
        );
      }
    } catch (e) {
      return makeBadRequestResponse(`bad request: can't parse JSON: ${e}`);
    }

    let res: unknown;
    let reqMeta: RequestMeta | undefined;
    try {
      reqMeta = await Promise.resolve(transformReqMeta(originalReqMeta));
      res = await methodImpl.impl(req, reqMeta);
    } catch (e) {
      const errorInfo: MethodErrorInfo<RequestMeta, unknown> = {
        error: e,
        method: methodImpl.method,
        request: req,
        reqMeta: reqMeta,
      };
      this.options.errorLogger(errorInfo);
      if (e instanceof ServiceError) {
        return e.toRawResponse();
      } else {
        let { canSendUnknownErrorMessage } = this.options;
        if (typeof canSendUnknownErrorMessage !== "boolean") {
          canSendUnknownErrorMessage = canSendUnknownErrorMessage(errorInfo);
        }
        const message = canSendUnknownErrorMessage
          ? `server error: ${e}`
          : "server error";
        return makeServerErrorResponse(message);
      }
    }

    let resJson: string;
    try {
      const flavor = format === "readable" ? "readable" : "dense";
      resJson = methodImpl.method.responseSerializer.toJsonCode(res, flavor);
    } catch (e) {
      return makeServerErrorResponse(
        `server error: can't serialize response to JSON: ${e}`,
      );
    }

    return makeOkJsonResponse(resJson);
  }

  /**
   * Creates a request handler that extracts simplified request metadata from
   * framework-specific request objects before passing it to this service.
   *
   * This decouples your service implementation from the HTTP framework, making
   * it easier to unit test (tests don't need to mock framework objects) and
   * making the service implementation clearer by explicitly declaring exactly
   * what request data it needs.
   *
   * @param transformFn Function that extracts the necessary data from the
   *   framework-specific request object. Can be async or sync.
   * @returns A request handler that accepts the framework-specific request type.
   *
   * @example
   * ```typescript
   * // Define a service that only needs to know if the user is an admin
   *
   * const service = new Service<{ isAdmin: boolean }>();
   *
   * service.addMethod(myMethod, async (req, { isAdmin }) => {
   *   // Implementation is framework-agnostic and easy to test
   *   if (!isAdmin) throw new ServiceError({ statusCode: 403, desc: "Forbidden" });
   *   // ...
   * });
   *
   * // Adapt it to work with Express
   * const expressHandler = service.withMetaTransformer(
   *   (req: ExpressRequest) => ({
   *     isAdmin: req.user?.role === 'admin'
   *   })
   * );
   * installServiceOnExpressApp(app, '/api', expressHandler, text, json);
   * ```
   */
  withMetaTransformer<OriginalRequestMeta>(
    transformFn: (
      reqMeta: OriginalRequestMeta,
    ) => RequestMeta | Promise<RequestMeta>,
  ): RequestHandler<OriginalRequestMeta> {
    return {
      handleRequest: async (
        reqBody: string,
        reqMeta: OriginalRequestMeta,
      ): Promise<RawResponse> => {
        return this.doHandleRequest(reqBody, reqMeta, transformFn);
      },
    };
  }

  private readonly options: ServiceOptions<RequestMeta>;
  private readonly methodImpls: {
    [number: number]: MethodImpl<unknown, unknown, RequestMeta>;
  } = {};
}

const DEFAULT_SERVICE_OPTIONS: ServiceOptions<unknown> = {
  keepUnrecognizedValues: false,
  canSendUnknownErrorMessage: false,
  errorLogger: (errorInfo: MethodErrorInfo<unknown, unknown>) => {
    console.error(`Error in method ${errorInfo.method.name}:`, errorInfo.error);
  },
  studioAppJsUrl:
    "https://cdn.jsdelivr.net/npm/skir-studio/dist/skir-studio-standalone.js",
};

interface MethodImpl<Request, Response, RequestMeta> {
  method: Method<Request, Response>;
  impl: (req: Request, reqMeta: RequestMeta) => Promise<Response>;
}

export function installServiceOnExpressApp(
  app: ExpressApp,
  queryPath: string,
  service: RequestHandler<ExpressRequest>,
  text: typeof ExpressText,
  json: typeof ExpressJson,
): void {
  const callback = async (
    req: ExpressRequest,
    res: ExpressResponse,
  ): Promise<void> => {
    let body: string;
    const indexOfQuestionMark = req.originalUrl.indexOf("?");
    if (indexOfQuestionMark >= 0) {
      const queryString = req.originalUrl.substring(indexOfQuestionMark + 1);
      body = decodeURIComponent(queryString);
    } else {
      body =
        typeof req.body === "string"
          ? req.body
          : typeof req.body === "object"
            ? JSON.stringify(req.body)
            : "";
    }
    const rawResponse = await service.handleRequest(body, req);
    res
      .status(rawResponse.statusCode)
      .contentType(rawResponse.contentType)
      .send(rawResponse.data);
  };
  app.get(queryPath, callback);
  app.post(queryPath, text(), json(), callback);
}
