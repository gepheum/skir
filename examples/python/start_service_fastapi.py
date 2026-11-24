# Starts a SkirRPC service on http://localhost:8787/?myapi
#
# Run with:
#   uvicorn start_service_fastapi:app --host localhost --port 8787
#
# Run call_service.py to call this service from another process.

import urllib.parse

import skir
from fastapi import FastAPI, Request, Response

from skirout import service_skir, user_skir

app = FastAPI()


class ServiceImpl:
    def __init__(self):
        self._id_to_user = {}

    async def get_user(
        self, request: service_skir.GetUserRequest
    ) -> service_skir.GetUserResponse:
        user_id = request.user_id
        user = self._id_to_user.get(user_id)
        return service_skir.GetUserResponse(user=user)

    async def add_user(
        self,
        request: service_skir.AddUserRequest,
        req_headers: dict[str, str],
    ) -> service_skir.AddUserResponse:
        user = request.user
        if user.user_id == 0:
            raise ValueError("invalid user id")
        print(f"Adding user: {user}")
        self._id_to_user[user.user_id] = user
        return service_skir.AddUserResponse()

    _id_to_user: dict[int, user_skir.User]


service_impl = ServiceImpl()

skir_service = skir.ServiceAsync[dict[str, str]]()
skir_service.add_method(service_skir.AddUser, service_impl.add_user)
skir_service.add_method(service_skir.GetUser, service_impl.get_user)

# Configure the service:
# skir_service.options.can_send_unknown_error_message = True
# skir_service.options.keep_unrecognized_values = True
# ...


@app.get("/")
async def hello_world():
    return "Hello, World!"


@app.api_route("/myapi", methods=["GET", "POST"])
async def myapi(request: Request):
    if request.method == "POST":
        req_body = (await request.body()).decode("utf-8")
    else:
        req_body = urllib.parse.unquote(
            request.url.query.encode("utf-8").decode("utf-8")
        )
    req_headers = dict(request.headers)
    raw_response = await skir_service.handle_request(req_body, req_headers)
    return Response(
        content=raw_response.data,
        status_code=raw_response.status_code,
        media_type=raw_response.content_type,
    )
