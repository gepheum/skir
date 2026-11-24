// ignore_for_file: strict_raw_type, inference_failure_on_collection_literal
import 'package:test/test.dart';
import 'package:skir_client/skir_client.dart';

void main() {
  group('ServiceClient', () {
    test('constructor validates service URL', () {
      expect(
        () => ServiceClient('https://example.com?query=param'),
        throwsArgumentError,
      );
    });

    test('constructor accepts valid service URL', () {
      expect(() => ServiceClient('https://example.com/api'), returnsNormally);
    });

    test('close method works without throwing', () {
      final client = ServiceClient('https://example.com');
      expect(() => client.close(), returnsNormally);
    });
  });

  group('RpcException', () {
    test('constructor and toString work correctly', () {
      final exception = RpcException(404, 'Not found');
      expect(exception.statusCode, equals(404));
      expect(exception.message, equals('Not found'));
      expect(exception.toString(), equals('RpcException(404): Not found'));
    });
  });
}
