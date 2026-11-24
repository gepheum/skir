from dataclasses import dataclass
from typing import Generic, TypeVar

from skir._impl.serializer import Serializer

Request = TypeVar("Request")
Response = TypeVar("Response")


@dataclass(frozen=True)
class Method(Generic[Request, Response]):
    """Identifies a procedure (the "P" in "RPC") on both client side and server side."""

    name: str
    number: int
    request_serializer: Serializer[Request]
    response_serializer: Serializer[Response]
    doc: str
