# Sends RPCs to a SkirRPC service.
# See start_service.py for how to start one.
#
# Run with:
#   python call_service.py
import skir

from skirout import service_skir, user_skir

if __name__ == "__main__":
    service_client = skir.ServiceClient("http://localhost:8787/myapi")

    print()
    print("About to add 2 users: John Doe and Tarzan")

    service_client.invoke_remote(
        service_skir.AddUser,
        service_skir.AddUserRequest(
            user=user_skir.User.partial(user_id=42, name="John Doe")
        ),
    )

    service_client.invoke_remote(
        service_skir.AddUser,
        service_skir.AddUserRequest(user=user_skir.TARZAN),
        {"X-Foo": "hi"},
    )

    print("Done")

    found_user = service_client.invoke_remote(
        service_skir.GetUser,
        service_skir.GetUserRequest(user_id=123),
    )

    print(f"Found user: {found_user}")
