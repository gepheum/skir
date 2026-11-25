// Starts a SkirRPC service on http://localhost:8787/myapi
//
// Run with:
//   dart run bin/start_service.dart
//
// Run call_service.dart to call this service from another process.

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:skir_client/skir_client.dart' as skir;
import 'package:skir_dart_example/skirout/service.dart';
import 'package:skir_dart_example/skirout/user.dart';

/// Custom data class containing relevant information extracted from the HTTP
/// request headers.
class RequestMetadata {
  // Add fields here.

  RequestMetadata.fromRequest(Request request) {}
}

/// Implementation of the service methods.
///
/// This is where you write your business logic.
class ServiceImpl {
  /// Simple in-memory storage for users.
  final Map<int, User> _idToUser = {};

  Future<GetUserResponse> getUser(
    GetUserRequest request,
    RequestMetadata metadata,
  ) async {
    final userId = request.userId;
    final user = _idToUser[userId];
    return GetUserResponse(user: user);
  }

  Future<AddUserResponse> addUser(
    AddUserRequest request,
    RequestMetadata metadata,
  ) async {
    final user = request.user;
    if (user.userId == 0) {
      throw ArgumentError('invalid user id');
    }
    print('Adding user: $user');
    _idToUser[user.userId] = user;
    return AddUserResponse();
  }
}

/// Creates and configures the Skir service.
///
/// This function links the generated Skir method definitions to your
/// implementation logic in [ServiceImpl].
skir.Service<RequestMetadata> createSkirService() {
  final serviceImpl = ServiceImpl();

  final skirService = skir.Service<RequestMetadata>();
  skirService.addMethod(addUserMethod, serviceImpl.addUser);
  skirService.addMethod(getUserMethod, serviceImpl.getUser);

  // skirService.options.keepUnrecognizedValues = true;

  return skirService;
}

void main() async {
  final skirService = createSkirService();

  /// Adapts a Shelf [Request] to Skir's [handleRequest].
  ///
  /// This function extracts the request body and any necessary metadata (like
  /// headers) and passes them to the Skir service for processing.
  Future<Response> handleRequest(Request request) async {
    final requestBody = request.method == 'POST'
        ? await request.readAsString()
        : Uri.decodeComponent(request.url.query);

    final metadata = RequestMetadata.fromRequest(request);

    final rawResponse = await skirService.handleRequest(requestBody, metadata);

    return Response(
      rawResponse.statusCode,
      body: rawResponse.data,
      headers: {
        'content-type': rawResponse.contentType,
      },
    );
  }

  final handler =
      const Pipeline().addMiddleware(logRequests()).addHandler((request) async {
    if (request.url.path == '') {
      return Response.ok('Hello, World!');
    } else if (request.url.path == 'myapi') {
      return await handleRequest(request);
    } else {
      return Response.notFound('Not found');
    }
  });

  final server = await shelf_io.serve(handler, 'localhost', 8787);
  print('Serving at http://${server.address.host}:${server.port}');
}
