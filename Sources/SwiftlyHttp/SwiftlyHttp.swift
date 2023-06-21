//
//  SwiftlyHttp.swift
//  
//
//  Created by Mike Shevelinsky on 15/02/2023.
//

import Foundation
import Combine

public class SwiftlyHttp {

    public enum Authorization {
        case basic(login: String, password: String)
        case bearer(token: String)
        case notNeeded
    }

    public enum Method {
        case post
        case get
        case delete

        var stringValue: String {
            switch self {
            case .post:
                return "POST"
            case .get:
                return "GET"
            case .delete:
                return "DELETE"
            }
        }
    }

    var baseURL: URL
    var pathComponents = [String]()
    var auth: Authorization?
    var method: Method = .get
    var body: Data?
    var headers = [String: String]()
    weak var authDelegate: AuthorizationDelegate?
    var jsonEncoder: JSONEncoder = JSONEncoder()

    /// Inits a request if provided a valid URL string
    ///  - Parameter baseURL: The base url of the request.
    public init?(baseURL: String) {
        if let url = URL(string: baseURL) {
            self.baseURL = url
        } else {
            return nil
        }
    }

    /// Inits a request using a `URL`.
    ///  - Parameter baseURL: The base url of the request.
    public init(baseURL: URL) {
        self.baseURL = baseURL
    }

    /// Adds a path component to the request's url.
    ///  - Parameter path: The path component.
    public func add(path: String) -> Self {
        if #available(iOS 16.0, *) {
            baseURL = baseURL.appending(path: path)
        } else {
            baseURL = baseURL.appendingPathComponent(path)
        }
        return self
    }

    /// Adds a query parameter to the request's url.
    ///  - Parameter queryParameter: The query parameter name.
    ///  - Parameter value: The query parameter value.
    @available(iOS 16.0, *)
    public func add(queryParameter: String, value: String) -> Self {
        baseURL.append(queryItems: [.init(name: queryParameter, value: value)])
        return self
    }

    /// Adds authorization to the request. Provided by the ``Authorization`` enum.
    ///  - Parameter auth: The authentication.
    public func authorization(_ auth: Authorization) -> Self {
        self.auth = auth
        return self
    }

    public func authorizationDelegate(_ delegate: AuthorizationDelegate) -> Self {
        authDelegate = delegate
        return self
    }

    /// Sets the request's method. Defualt is `.get` Provided by the ``Method`` enum.
    ///  - Parameter method: The method.
    public func method(_ method: Method) -> Self {
        self.method = method
        return self
    }

    /// Sets the request's body to an Encodable type.
    ///  - Parameter body: The body.
    ///  - Note: Also sets the request's `Content-Type` to `application/json`
    public func body(_ body: some Encodable) throws -> Self {
        self.body = try jsonEncoder.encode(body)
        headers["Content-Type"] = "application/json"
        return self
    }

    /// Sets a custom `JSONEncoder` for encoding the body.
    ///  - Parameter jsonEncoder: The encoder.
    ///  - Note: Needs to be called before ``body(_:)`` to take affect.
    public func set(jsonEncoder: JSONEncoder) -> Self {
        self.jsonEncoder = jsonEncoder
        return self
    }

    /// Sets the response to be decoded to a `Decodable` type.
    ///  - Parameter type: The type to which to encode the response.
    ///  - Returns: An instance of ``SwiftlyHttpDecodedHttp`` which inherits all settings.
    public func decode<Response: Decodable>(to type: Response.Type) -> SwiftlyHttpDecodedHttp<Response> {
        return SwiftlyHttpDecodedHttp<Response>(baseURL: baseURL,
                                                pathComponents: pathComponents,
                                                auth: auth,
                                                method: method,
                                                body: body,
                                                headers: headers,
                                                authDelegate: authDelegate)
    }

    public func websocket() -> SwiftlyWebSocketConnection {
        let url = URLComponents(url: baseURL, resolvingAgainstBaseURL: true)!
        return SwiftlyWebSocketConnection(task: URLSession.shared
            .webSocketTask(with: url.url!))
    }

    /// Performs the request.
    ///  - Returns: A tuple of `Data` and `URLResponse`. Same way as an `URLRequest`.
    @discardableResult
    public func perform() async throws -> (Data, URLResponse) {
        let url = URLComponents(url: baseURL, resolvingAgainstBaseURL: true)!
        var request = URLRequest(url: url.url!)

        if let delegate = authDelegate {
            let auth = try delegate.getAuthorization()
            addAuthorizationIfNeeded(to: &request, auth: auth)
        } else if let auth = auth {
            addAuthorizationIfNeeded(to: &request, auth: auth)
        }

        request.httpMethod = method.stringValue
        request.httpBody = body
        headers.forEach { pair in
            request.setValue(pair.value, forHTTPHeaderField: pair.key)
        }

        return try await URLSession.shared.data(for: request)
    }

    private func addAuthorizationIfNeeded(to request: inout URLRequest, auth: Authorization) {
        switch auth {
        case .basic(let login, let password):
            let token = String(format: "%@:%@", login, password).data(using: .utf8)!.base64EncodedData()
            request.setValue("Basic \(String(data: token, encoding: .utf8)!)", forHTTPHeaderField: "Authorization")
        case .bearer(let token):
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        case .notNeeded:
            return
        }
    }
}

public class SwiftlyHttpDecodedHttp<Response: Decodable>: SwiftlyHttp {

    var jsonDecoder: JSONDecoder = JSONDecoder()
    
    init(baseURL: URL,
         pathComponents: [String],
         auth: Authorization?,
         method: Method,
         body: Data?,
         headers: [String: String],
         authDelegate: AuthorizationDelegate?) {
        super.init(baseURL: baseURL)
        self.pathComponents = pathComponents
        self.auth = auth
        self.method = method
        self.body = body
        self.headers = headers
        self.authDelegate = authDelegate
    }

    /// Sets a custom `JSONDecoder` for encoding the body.
    ///  - Parameter jsonDecoder: The decoder.
    public func set(jsonDecoder: JSONDecoder) -> Self {
        self.jsonDecoder = jsonDecoder
        return self
    }

    /// Override of the ``perform()-641f5`` method of ``SwiftlyHttp``. Shouldn't  be used here.
    @_disfavoredOverload
    @discardableResult
    public override func perform() async throws -> (Data, URLResponse) {
        try await super.perform()
    }

    /// Performs the request.
    ///  - Returns: An instance of the type provided for decoding.
    @discardableResult
    public func perform() async throws -> Response {
        let response = try await super.perform()
        
        return try jsonDecoder.decode(Response.self, from: response.0)
    }
}

public class SwiftlyWebSocketConnection {
    private let task: URLSessionWebSocketTask
    private let messagePassthroughSubject = PassthroughSubject<URLSessionWebSocketTask.Message, Error>()

    public var messagePublisher: AnyPublisher<URLSessionWebSocketTask.Message, Error> {
        messagePassthroughSubject.eraseToAnyPublisher()
    }

    init(task: URLSessionWebSocketTask) {
        self.task = task
        receive()
    }

    public func send(message: URLSessionWebSocketTask.Message) async throws {
        try await task.send(message)
    }

    private func receive() {
        task.receive { result in
            switch result {
            case .success(let message):
                self.messagePassthroughSubject.send(message)
                self.receive()
            case .failure(let error):
                self.messagePassthroughSubject.send(completion: .failure(error))
            }
        }
    }
}

public protocol AuthorizationDelegate: AnyObject {
    func getAuthorization() throws -> SwiftlyHttp.Authorization
}
