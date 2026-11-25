// Sends RPCs to a SkirRPC service.
// See start_service.dart for how to start one.
//
// Run:
//   dart run bin/call_service.dart

import 'package:skir_client/skir_client.dart' as skir;
import 'package:skir_dart_example/skirout/service.dart';
import 'package:skir_dart_example/skirout/user.dart';

void main() async {
  // Create a client pointing to the service's base URL.
  final serviceClient = skir.ServiceClient('http://localhost:8787/myapi');

  print('');
  print('About to add 2 users: John Doe and Tarzan');

  // Call the 'addUserMethod' RPC.
  await serviceClient.wrap(addUserMethod).invoke(
        AddUserRequest(
          user: User(
            userId: 42,
            name: 'John Doe',
            quote: '',
            pets: [],
            subscriptionStatus: SubscriptionStatus.unknown,
          ),
        ),
      );

  await serviceClient.wrap(addUserMethod).invoke(
    AddUserRequest(user: tarzan),
    headers: {'X-Foo': 'hi'},
  );

  // Note: The Dart ServiceClient API doesn't currently provide access to
  // response headers. This is a limitation compared to the Python version.

  print('Done');

  final foundUser = await serviceClient.wrap(getUserMethod).invoke(
        GetUserRequest(userId: 123),
      );

  print('Found user: $foundUser');

  serviceClient.close();
}
