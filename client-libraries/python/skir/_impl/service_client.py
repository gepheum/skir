import http.client
import re
from typing import Any, Final, Mapping, Protocol
from urllib.parse import urlparse

from skir._impl.method import Method, Request, Response


class ServiceClient:
    _scheme: Final[str]
    _host: Final[str]  # May include the port
    _path: Final[str]

    def __init__(self, url: str):
        parsed_url = urlparse(url)
        if parsed_url.query:
            raise ValueError("Service URL must not contain a query string")
        scheme = parsed_url.scheme
        if scheme not in ["http", "https"]:
            raise ValueError("Service URL must start with http:// or https://")
        self._scheme = scheme
        self._host = parsed_url.netloc
        self._path = parsed_url.path

    def invoke_remote(
        self,
        method: Method[Request, Response],
        request: Request,
        headers: Mapping[str, str] = {},
        *,
        timeout_secs: float | None = None,
    ) -> Response:
        """Invokes the given method on the remote server through an RPC."""

        request_json = method.request_serializer.to_json_code(request)
        body = ":".join(
            [
                method.name,
                str(method.number),
                "",
                request_json,
            ]
        )
        headers = {
            **headers,
            "Content-Type": "text/plain; charset=utf-8",
            "Content-Length": str(len(body)),
        }
        connection_options: dict[str, Any] = {}
        if timeout_secs is not None:
            connection_options["timeout"] = timeout_secs
        if self._scheme == "https":
            conn = http.client.HTTPSConnection(self._host, **connection_options)
        else:
            conn = http.client.HTTPConnection(self._host, **connection_options)
        try:
            conn.request(
                "POST",
                self._path,
                body=body,
                headers=headers,
            )
            response = conn.getresponse()
            status_code = response.status
            content_type = response.getheader("Content-Type") or ""
            response_data = response.read().decode("utf-8", errors="ignore")
        finally:
            conn.close()
        if status_code in range(200, 300):
            return method.response_serializer.from_json_code(response_data)
        else:
            message = f"HTTP status {status_code}"
            if re.match(r"text/plain\b", content_type):
                message = f"{message}: {response_data}"
            raise RuntimeError(message)

    async def invoke_remote_async(
        self,
        aiohttp_client_session: "_AiohttpClientSession",
        method: Method[Request, Response],
        request: Request,
        headers: Mapping[str, str] = {},
    ) -> Response:
        """
        Asynchronously invokes the given method on the remote server through an RPC.

        Usage:
            import aiohttp

            async with aiohttp.ClientSession() as session:
                response = await service_client.invoke_remote_async(
                    session,
                    method,
                    request,
                    headers,
                )

        With timeout:
            timeout = aiohttp.ClientTimeout(total=30)
            async with aiohttp.ClientSession(timeout=timeout) as session:
                response = await service_client.invoke_remote_async(
                    session,
                    method,
                    request,
                    headers,
                )
        """

        request_json = method.request_serializer.to_json_code(request)
        body = ":".join(
            [
                method.name,
                str(method.number),
                "",
                request_json,
            ]
        )

        request_headers = {
            **headers,
            "Content-Type": "text/plain; charset=utf-8",
            "Content-Length": str(len(body)),
        }

        # Build the URL
        url = f"{self._scheme}://{self._host}{self._path}"

        async with aiohttp_client_session.post(
            url,
            data=body,
            headers=request_headers,
        ) as response:
            status_code = response.status
            content_type = response.headers.get("Content-Type", "")
            response_data = await response.text(encoding="utf-8", errors="ignore")

        if status_code in range(200, 300):
            return method.response_serializer.from_json_code(response_data)
        else:
            message = f"HTTP status {status_code}"
            if re.match(r"text/plain\b", content_type):
                message = f"{message}: {response_data}"
            raise RuntimeError(message)


class _AiohttpClientSession(Protocol):
    def post(
        self,
        url: str,
        *,
        data: str,
        headers: Mapping[str, str],
    ) -> Any: ...
