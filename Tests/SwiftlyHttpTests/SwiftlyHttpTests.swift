import XCTest
@testable import SwiftlyHttp

final class SwiftlyHttpTests: XCTestCase {

    var request: SwiftlyHttp!

    var requestSpy: ((URLRequest) -> (HTTPURLResponse, Data?))? {
        get {
            SpyURLProtocol.requestSpy
        }
        set {
            SpyURLProtocol.requestSpy = newValue
        }
    }

    let emptyResponse: (HTTPURLResponse, Data?) = (.init(url: URL(string: "http://localhost")!,
                                                         statusCode: 200,
                                                         httpVersion: nil,
                                                         headerFields: nil)!, nil)

    override func setUp() {
        request = .init(baseURL: "http://localhost")
        let configuration = URLSessionConfiguration.default
        configuration.protocolClasses = [SpyURLProtocol.self]
        let urlSession = URLSession(configuration: configuration)
        request.urlSession = urlSession
    }

    func testSimpleCase() async throws {
        let sut = request
            .add(path: "test1")
            .add(path: "test2")
        let expectation = XCTestExpectation(description: "")

        requestSpy = { request in
            XCTAssertEqual(request.url?.lastPathComponent, "test2")
            expectation.fulfill()
            return self.emptyResponse
        }
        try await sut.perform()
        await fulfillment(of: [expectation])
    }

    func testAuthFactory() async throws {
        let expectation = XCTestExpectation(description: "")
        let sut = request
            .authentication {
                return .bearer(token: "mock-test")
            }

        requestSpy = { request in
            XCTAssertNotNil(request.value(forHTTPHeaderField: "Authorization"))
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer mock-test")
            expectation.fulfill()
            return self.emptyResponse
        }

        try await sut.perform()
        await fulfillment(of: [expectation])
    }
}
