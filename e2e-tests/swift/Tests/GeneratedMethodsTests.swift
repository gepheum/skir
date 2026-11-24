import SkirClient
import XCTest

@testable import e2e_test

final class GeneratedMethodsTests: XCTestCase {
  func testOneBool() {
    let method: SkirClient.Method<Structs_skir.Point, Enums_skir.JsonValue> = Methods_skir
      .MyProcedure
    XCTAssertEqual(method.number, 674_706_602)
    XCTAssertEqual(method.name, "MyProcedure")
    XCTAssertEqual(method.doc, "My procedure")
    let _: Serializer<Structs_skir.Point> = method.requestSerializer
    let _: Serializer<Enums_skir.JsonValue> = method.responseSerializer
  }
}
