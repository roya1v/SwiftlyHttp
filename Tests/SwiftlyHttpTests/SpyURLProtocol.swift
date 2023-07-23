//
//  SpyURLProtocol.swift
//  
//
//  Created by Mike S. on 23/07/2023.
//

import Foundation

final class SpyURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool {
        return true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    static var requestSpy: ((URLRequest) -> (HTTPURLResponse, Data?))?

    override func startLoading() {
        guard let handler = Self.requestSpy else {
            fatalError("Spy was not set")
        }

        let (response, data) = handler(request)

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)

        if let data = data {
            client?.urlProtocol(self, didLoad: data)
        }
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() { }
}
