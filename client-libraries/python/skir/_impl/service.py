import html
import inspect
import json
import logging
from collections.abc import Awaitable, Callable
from dataclasses import dataclass
from typing import Any, Final, Generic, Literal, TypeVar, Union, cast

from skir._impl.method import Method, Request, Response
from skir._impl.never import Never

_logger = logging.getLogger(__name__)

RequestMeta = TypeVar("RequestMeta")


# ==============================================================================
# Public API - Types and Exceptions
# ==============================================================================


@dataclass(frozen=True)
class RawServiceResponse:
    """Raw response returned by the server."""

    data: str
    status_code: int
    content_type: str


class ServiceError(Exception):
    """If this error is thrown from a method implementation, the specified
    status code and message will be returned in the HTTP response.

    If any other type of exception is thrown, the response status code will be
    500 (Internal Server Error).
    """

    _status_code: Final[int]
    _message: Final[str]

    def __init__(
        self,
        status_code: Literal[
            "400: Bad Request",
            "401: Unauthorized",
            "402: Payment Required",
            "403: Forbidden",
            "404: Not Found",
            "405: Method Not Allowed",
            "406: Not Acceptable",
            "407: Proxy Authentication Required",
            "408: Request Timeout",
            "409: Conflict",
            "410: Gone",
            "411: Length Required",
            "412: Precondition Failed",
            "413: Content Too Large",
            "414: URI Too Long",
            "415: Unsupported Media Type",
            "416: Range Not Satisfiable",
            "417: Expectation Failed",
            "418: I'm a teapot",
            "421: Misdirected Request",
            "422: Unprocessable Content",
            "423: Locked",
            "424: Failed Dependency",
            "425: Too Early",
            "426: Upgrade Required",
            "428: Precondition Required",
            "429: Too Many Requests",
            "431: Request Header Fields Too Large",
            "451: Unavailable For Legal Reasons",
            "500: Internal Server Error",
            "501: Not Implemented",
            "502: Bad Gateway",
            "503: Service Unavailable",
            "504: Gateway Timeout",
            "505: HTTP Version Not Supported",
            "506: Variant Also Negotiates",
            "507: Insufficient Storage",
            "508: Loop Detected",
            "510: Not Extended",
            "511: Network Authentication Required",
        ],
        message: str | None = None,
    ):
        parts = status_code.split(": ", 1)
        if len(parts) != 2:
            raise ValueError("Invalid status code format")
        self._status_code = int(parts[0])
        self._message = message or parts[1]
        super().__init__(message)

    def to_raw_response(self) -> RawServiceResponse:
        return _make_server_error_response(
            self._message,
            self._status_code,
        )


@dataclass(frozen=True)
class MethodErrorInfo(Generic[RequestMeta]):
    """Information about an error thrown during the execution of a method on
    the server side.
    """

    error: Exception
    """The exception that was thrown."""

    method: Method[Any, Any]
    """The method that was being executed when the error occurred."""

    request: Any
    """Parsed request passed to the method's implementation."""

    request_meta: RequestMeta
    """Metadata coming from the HTTP headers of the request."""


class ServiceOptions(Generic[RequestMeta]):
    keep_unrecognized_values = False
    """Whether to keep unrecognized values when deserializing requests.

    **WARNING:** Only enable this for data from trusted sources. Malicious
    actors could inject fields with IDs not yet defined in your schema. If you
    preserve this data and later define those IDs in a future schema version,
    the injected data could be deserialized as valid fields, leading to
    security vulnerabilities or data corruption.
    """

    can_send_unknown_error_message: Union[bool, Callable[[MethodErrorInfo], bool]] = (
        False
    )
    """Whether the message of an unknown error (i.e. not a ServiceError) can be
    sent to the client in the response body, which can help with debugging.

    By default, unknown errors are masked and the client receives a generic
    'server error' message with status 500. This is to prevent leaking
    sensitive information to the client.

    You can enable this if your server is internal or if you are sure that your
    error messages are safe to expose. By passing a predicate instead of true
    or false, you can control on a per-error basis whether to expose the error
    message; for example, you can send error messages only if the user is an
    admin.
    """

    error_logger: Callable[[MethodErrorInfo[RequestMeta]], None]
    """Callback invoked whenever an error is thrown during method execution.

    Use this to log errors for monitoring, debugging, or alerting purposes.

    Defaults to a function which logs the method name and error message using
    the logging module at ERROR level.
    """

    studio_app_js_url: str
    """URL to the JavaScript file for the Skir Studio app.

    Skir Studio is a web interface for exploring and testing your SkirRPC service.
    It is served when the service receives a request at '{serviceUrl}?studio'.
    """

    def __init__(self):
        def _default_error_logger(
            error_context: MethodErrorInfo[RequestMeta],
        ) -> None:
            method_name = error_context.method.name
            error = error_context.error
            _logger.error(f"Error in method {method_name}: {error}", exc_info=error)

        self.error_logger = _default_error_logger
        self.studio_app_js_url = (
            "https://cdn.jsdelivr.net/npm/skir-studio/dist/skir-studio-standalone.js"
        )

    def _resolve_can_send_unknown_error_message(
        self,
        error_info: MethodErrorInfo[Request],
    ) -> bool:
        if isinstance(self.can_send_unknown_error_message, bool):
            return self.can_send_unknown_error_message
        else:
            return self.can_send_unknown_error_message(error_info)


# ==============================================================================
# Public API - Main Classes
# ==============================================================================


class Service(Generic[RequestMeta]):
    """Wraps around the implementation of a SkirRPC service on the server side.

    Usage: call '.add_method()' to register method implementations, then call
    '.handle_request()' from the function called by your web framework when an
    HTTP request is received at your service's endpoint.

    The service can be configured by setting properties on the 'options'
    attribute (e.g., error_logger, studio_app_js_url, etc.).

    Example with Flask:

        from flask import Response, request
        from werkzeug.datastructures import Headers


        s = skir.Service[Headers]()
        s.add_method(...)
        s.add_method(...)

        @app.route("/myapi", methods=["GET", "POST"])
        def myapi():
            if request.method == "POST":
                req_body = request.get_data(as_text=True)
            else:
                query_string = request.query_string.decode("utf-8")
                req_body = urllib.parse.unquote(query_string)
            req_meta = request.headers
            raw_response = s.handle_request(req_body, req_meta)
            return Response(
                raw_response.data,
                status=raw_response.status_code,
                content_type=raw_response.content_type,
            )
    """

    _impl: "_ServiceImpl[RequestMeta]"
    options: Final[ServiceOptions[RequestMeta]]

    def __init__(self):
        self._impl = _ServiceImpl[RequestMeta]()
        self.options = ServiceOptions()

    def add_method(
        self,
        method: Method[Request, Response],
        impl: Union[
            Callable[[Request], Response],
            Callable[[Request, RequestMeta], Response],
        ],
    ) -> "Service[RequestMeta]":
        self._impl.add_method(method, impl)
        return self

    def handle_request(
        self,
        req_body: str,
        req_meta: RequestMeta,
    ) -> RawServiceResponse:
        return self._impl.handle_request(
            req_body,
            req_meta,
            self.options,
        )


class ServiceAsync(Generic[RequestMeta]):
    """Asynchronous version of Service.

    Usage: call '.add_method()' to register async method implementations, then
    call 'await .handle_request()' from the async function called by your web
    framework when an HTTP request is received at your service's endpoint.

    The service can be configured by setting properties on the 'options'
    attribute (e.g., error_logger, studio_app_js_url, etc.).

    Example with FastAPI:

        import urllib.parse

        from fastapi import FastAPI, Request, Response

        s = skir.ServiceAsync[dict[str, str]]()
        s.add_method(...)
        s.add_method(...)

        app = FastAPI()

        @app.api_route("/myapi", methods=["GET", "POST"])
        async def myapi(request: Request):
            if request.method == "POST":
                req_body = (await request.body()).decode("utf-8")
            else:
                req_body = urllib.parse.unquote(
                    request.url.query.encode("utf-8").decode("utf-8")
                )
            req_meta = dict(request.headers)
            raw_response = await s.handle_request(req_body, req_meta)
            return Response(
                content=raw_response.data,
                status_code=raw_response.status_code,
                media_type=raw_response.content_type,
            )

    Example with Litestar:

        import urllib.parse

        from litestar import Litestar, Request, Response, route

        s = skir.ServiceAsync[dict[str, str]]()
        s.add_method(...)
        s.add_method(...)

        @route("/myapi", http_method=["GET", "POST"])
        async def myapi(request: Request) -> Response:
            if request.method == "POST":
                req_body = (await request.body()).decode("utf-8")
            else:
                query_string = request.scope.get("query_string", b"").decode("utf-8")
                req_body = urllib.parse.unquote(query_string)
            req_meta = dict(request.headers)
            raw_response = await s.handle_request(req_body, req_meta)
            return Response(
                content=raw_response.data,
                status_code=raw_response.status_code,
                media_type=raw_response.content_type,
            )

        app = Litestar(route_handlers=[myapi])
    """

    _impl: "_ServiceImpl[RequestMeta]"
    options: Final[ServiceOptions[RequestMeta]]

    def __init__(self):
        self._impl = _ServiceImpl[RequestMeta]()
        self.options = ServiceOptions()

    def add_method(
        self,
        method: Method[Request, Response],
        impl: Union[
            # Sync
            Callable[[Request], Response],
            Callable[[Request, RequestMeta], Response],
            # Async
            Callable[[Request], Awaitable[Response]],
            Callable[[Request, RequestMeta], Awaitable[Response]],
        ],
    ) -> "ServiceAsync[RequestMeta]":
        self._impl.add_method(method, impl)
        return self

    async def handle_request(
        self,
        req_body: str,
        req_meta: RequestMeta,
    ) -> RawServiceResponse:
        return await self._impl.handle_request_async(
            req_body,
            req_meta,
            self.options,
        )


# ==============================================================================
# Private Implementation - Helper Functions
# ==============================================================================


def _make_ok_json_response(data: str) -> RawServiceResponse:
    return RawServiceResponse(
        data=data,
        status_code=200,
        content_type="application/json",
    )


def _make_ok_html_response(data: str) -> RawServiceResponse:
    return RawServiceResponse(
        data=data,
        status_code=200,
        content_type="text/html; charset=utf-8",
    )


def _make_bad_request_response(data: str) -> RawServiceResponse:
    return RawServiceResponse(
        data=data,
        status_code=400,
        content_type="text/plain; charset=utf-8",
    )


def _make_server_error_response(
    data: str, status_code: int = 500
) -> RawServiceResponse:
    return RawServiceResponse(
        data=data,
        status_code=status_code,
        content_type="text/plain; charset=utf-8",
    )


def _get_studio_html(studio_app_js_url: str) -> str:
    # Copied from
    #   https://github.com/gepheum/skir-studio/blob/main/index.jsdeliver.html
    escaped_url = html.escape(studio_app_js_url, quote=True)
    return f"""<!DOCTYPE html>

<html>
  <head>
    <meta charset="utf-8" />
    <title>RPC Studio</title>
    <link rel="icon" href="data:image/svg+xml,<svg xmlns=%22http://www.w3.org/2000/svg%22 viewBox=%220 0 100 100%22><text y=%22.9em%22 font-size=%2290%22>🐙</text></svg>">
    <script src="{escaped_url}"></script>
  </head>
  <body style="margin: 0; padding: 0;">
    <skir-studio-app></skir-studio-app>
  </body>
</html>
"""


# ==============================================================================
# Private Implementation - Core Classes
# ==============================================================================


@dataclass(frozen=True)
class _MethodImpl(Generic[Request, Response, RequestMeta]):
    method: Method[Request, Response]
    impl: Callable[
        # Parameters
        [Request, RequestMeta],
        # Return type
        Union[Response, Awaitable[Response]],
    ]


class _ServiceImpl(Generic[RequestMeta]):
    _number_to_method_impl: dict[int, _MethodImpl[Any, Any, RequestMeta]]

    def __init__(self):
        self._number_to_method_impl = {}

    def add_method(
        self,
        method: Method[Request, Response],
        impl: Union[
            # Sync
            Callable[[Request], Response],
            Callable[[Request, RequestMeta], Response],
            # Async
            Callable[[Request], Awaitable[Response]],
            Callable[[Request, RequestMeta], Awaitable[Response]],
        ],
    ) -> None:
        signature = inspect.Signature.from_callable(impl)
        num_positional_params = 0
        for param in signature.parameters.values():
            if param.kind in (
                inspect.Parameter.POSITIONAL_OR_KEYWORD,
                inspect.Parameter.POSITIONAL_ONLY,
            ):
                num_positional_params += 1
            if param.kind == inspect.Parameter.VAR_POSITIONAL:
                raise ValueError("Method implementation cannot accept *args")
        if num_positional_params not in range(1, 3):
            raise ValueError(
                "Method implementation must accept 1 or 2 positional parameters"
            )

        def resolved_impl(req: Request, req_meta: RequestMeta) -> Response:
            if num_positional_params == 1:
                return cast(Callable[[Request], Response], impl)(req)
            else:
                return cast(Callable[[Request, RequestMeta], Response], impl)(
                    req, req_meta
                )

        number = method.number
        if number in self._number_to_method_impl:
            raise ValueError(
                f"Method with the same number already registered ({number})"
            )
        self._number_to_method_impl[number] = _MethodImpl(
            method=method,
            impl=resolved_impl,
        )

    def handle_request(
        self,
        req_body: str,
        req_meta: RequestMeta,
        options: "ServiceOptions[RequestMeta]",
    ) -> RawServiceResponse:
        flow = _HandleRequestFlow(
            req_body=req_body,
            req_meta=req_meta,
            number_to_method_impl=self._number_to_method_impl,
            options=options,
        )
        return flow.run()

    async def handle_request_async(
        self,
        req_body: str,
        req_meta: RequestMeta,
        options: "ServiceOptions[RequestMeta]",
    ) -> RawServiceResponse:
        flow = _HandleRequestFlow(
            req_body=req_body,
            req_meta=req_meta,
            number_to_method_impl=self._number_to_method_impl,
            options=options,
        )
        return await flow.run_async()


@dataclass()
class _HandleRequestFlow(Generic[Request, Response, RequestMeta]):
    req_body: str
    req_meta: RequestMeta
    number_to_method_impl: dict[int, _MethodImpl[Any, Any, RequestMeta]]
    options: "ServiceOptions[RequestMeta]"
    _format: str = ""

    def run(self) -> RawServiceResponse:
        req_impl_pair_or_raw_response = self._parse_request()
        if isinstance(req_impl_pair_or_raw_response, RawServiceResponse):
            return req_impl_pair_or_raw_response
        req, method_impl = req_impl_pair_or_raw_response
        try:
            res = method_impl.impl(req, self.req_meta)
        except Exception as e:
            error_info = MethodErrorInfo(
                error=e,
                method=method_impl.method,
                request=req,
                request_meta=self.req_meta,
            )
            self.options.error_logger(error_info)
            if isinstance(e, ServiceError):
                return e.to_raw_response()
            else:
                message = (
                    f"server error: {e}"
                    if self.options._resolve_can_send_unknown_error_message(error_info)
                    else "server error"
                )
                return _make_server_error_response(message)
        if inspect.isawaitable(res):
            raise TypeError("Method implementation must be synchronous")
        return self._response_to_json(res, method_impl)

    async def run_async(self) -> RawServiceResponse:
        req_impl_pair_or_raw_response = self._parse_request()
        if isinstance(req_impl_pair_or_raw_response, RawServiceResponse):
            return req_impl_pair_or_raw_response
        req, method_impl = req_impl_pair_or_raw_response
        try:
            res: Any = method_impl.impl(req, cast(RequestMeta, self.req_meta))
            if inspect.isawaitable(res):
                res = await res
        except Exception as e:
            error_info = MethodErrorInfo[RequestMeta](
                error=e,
                method=method_impl.method,
                request=req,
                request_meta=self.req_meta,
            )
            self.options.error_logger(error_info)
            if isinstance(e, ServiceError):
                return e.to_raw_response()
            else:
                message = (
                    f"server error: {e}"
                    if self.options._resolve_can_send_unknown_error_message(error_info)
                    else "server error"
                )
                return _make_server_error_response(message)
        return self._response_to_json(res, method_impl)

    def _parse_request(
        self,
    ) -> Union[
        tuple[Any, _MethodImpl[Request, Response, RequestMeta]],
        RawServiceResponse,
    ]:
        if self.req_body == "list":
            return self._handle_list()

        if self.req_body in ("", "studio"):
            return self._handle_studio()

        # Method invokation
        method_name: str
        method_number: int | None
        format: str
        request_data: tuple[Literal["json-code"], str] | tuple[Literal["json"], Any]

        first_char = self.req_body[0]
        if first_char.isspace() or first_char == "{":
            # A JSON object
            try:
                req_body_json = json.loads(self.req_body)
            except json.JSONDecodeError:
                return _make_bad_request_response("bad request: invalid JSON")
            method = req_body_json.get("method", ())
            if method == ():
                return _make_bad_request_response(
                    "bad request: missing 'method' field in JSON"
                )
            if isinstance(method, str):
                method_name = method
                method_number = None
            elif isinstance(method, int):
                method_name = "?"
                method_number = method
            else:
                return _make_bad_request_response(
                    "bad request: 'method' field must be a string or an integer"
                )
            format = "readable"
            data = req_body_json.get("request", ())
            if data == ():
                return _make_bad_request_response(
                    "bad request: missing 'request' field in JSON"
                )
            request_data = ("json", data)
        else:
            # A colon-separated string
            parts = self.req_body.split(":", 3)
            if len(parts) != 4:
                return _make_bad_request_response("bad request: invalid request format")
            method_name = parts[0]
            method_number_str = parts[1]
            format = parts[2]
            request_data = ("json-code", parts[3])
            if method_number_str:
                try:
                    method_number = int(method_number_str)
                except Exception:
                    return _make_bad_request_response(
                        "bad request: can't parse method number"
                    )
            else:
                method_number = None
        self.format = format
        if method_number is None:
            # Try to get the method number by name
            all_methods = self.number_to_method_impl.values()
            name_matches = [m for m in all_methods if m.method.name == method_name]
            if not name_matches:
                return _make_bad_request_response(
                    f"bad request: method not found: {method_name}"
                )
            elif len(name_matches) != 1:
                return _make_bad_request_response(
                    f"bad request: method name '{method_name}' is ambiguous; "
                    "use method number instead"
                )
            method_number = name_matches[0].method.number
        method_impl = self.number_to_method_impl.get(method_number)
        if not method_impl:
            return _make_bad_request_response(
                f"bad request: method not found: {method_name}; number: {method_number}"
            )
        try:
            req: Any
            request_serializer = method_impl.method.request_serializer
            if request_data[0] == "json-code":
                req = request_serializer.from_json_code(
                    request_data[1],
                    keep_unrecognized_values=self.options.keep_unrecognized_values,
                )
            elif request_data[0] == "json":
                req = request_serializer.from_json(
                    request_data[1],
                    keep_unrecognized_values=self.options.keep_unrecognized_values,
                )
            else:
                _: Never = request_data[0]
                del _
                req = None  # To please the type checker
        except Exception as e:
            return _make_bad_request_response(f"bad request: can't parse JSON: {e}")
        return (req, method_impl)

    def _handle_list(self) -> RawServiceResponse:
        def method_to_json(method: Method) -> Any:
            return {
                "method": method.name,
                "number": method.number,
                "request": method.request_serializer.type_descriptor.as_json(),
                "response": method.response_serializer.type_descriptor.as_json(),
                "docs": method.doc,
            }

        json_code = json.dumps(
            {
                "methods": [
                    method_to_json(method_impl.method)
                    for method_impl in self.number_to_method_impl.values()
                ]
            },
            indent=2,
        )
        return _make_ok_json_response(json_code)

    def _handle_studio(self) -> RawServiceResponse:
        return _make_ok_html_response(_get_studio_html(self.options.studio_app_js_url))

    def _response_to_json(
        self,
        res: Response,
        method_impl: _MethodImpl[Request, Response, RequestMeta],
    ) -> RawServiceResponse:
        try:
            res_json = method_impl.method.response_serializer.to_json_code(
                res, readable=(self.format == "readable")
            )
        except Exception as e:
            return _make_server_error_response(
                f"server error: can't serialize response to JSON: {e}"
            )
        return _make_ok_json_response(res_json)
