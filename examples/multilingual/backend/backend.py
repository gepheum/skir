import urllib.parse

from flask import Flask, Response, request
from flask_cors import CORS
from skirout.api_skir import Greet, GreetRequest, GreetResponse
from werkzeug.datastructures import Headers

from skir import Service


def greet_impl(req: GreetRequest) -> GreetResponse:
    message = f"Hello {req.name}!"
    if req.temperature_c in range(20, 25) and req.sunny:
        message += " What a lovely day, isn't it?"
    return GreetResponse(
        actions=[
            GreetResponse.Action.WAVE,
            GreetResponse.Action.wrap_say(message),
        ],
    )


app = Flask(__name__)
CORS(app)

# Create Skir Service
service = Service[Headers]()

# Register metadata and implementation
service.add_method(Greet, greet_impl)


@app.route("/", methods=["GET"])
def home():
    return "Skir Multilingual Flask Server Running"


@app.route("/skir", methods=["GET", "POST"])
def skir_endpoint():
    if request.method == "POST":
        req_body = request.get_data(as_text=True)
    else:
        req_body = urllib.parse.unquote(request.query_string.decode("utf-8"))
    req_headers = request.headers
    raw_response = service.handle_request(req_body, req_headers)
    return Response(
        raw_response.data,
        status=raw_response.status_code,
        content_type=raw_response.content_type,
    )


if __name__ == '__main__':
    print("Starting Flask backend server on port 8080...")
    app.run(host="localhost", port=8080, debug=True)
