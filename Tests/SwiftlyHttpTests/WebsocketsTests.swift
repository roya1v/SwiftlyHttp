//
//  WebsocketsTests.swift
//
//
//  Created by Mike S. on 27/11/2023.
//

import XCTest
@testable import SwiftlyHttp
import Combine

final class WebsocketsTests: XCTestCase {

    private var cancellable = Set<AnyCancellable>()

    func testWithEchoServer() async {
        let request =
        try! await SwiftlyHttp(baseURL: "wss://socketsbay.com")!
            .add(path: "wss")
            .add(path: "v2")
            .add(path: "1")
            .add(path: "demo")
            .websocket()

        let expectation = XCTestExpectation()

        request.messagePublisher.sink { _ in

        } receiveValue: { _ in
            expectation.fulfill()
        }
        .store(in: &cancellable)
        await fulfillment(of: [expectation])
    }
}
