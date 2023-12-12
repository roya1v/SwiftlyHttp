//
//  SwiftlyHttp.swift
//  
//
//  Created by Mike Shevelinsky on 15/02/2023.
//

import Foundation
import Combine

public enum SwiftlyHttpError: Error {
    case badScheme
}

public class SwiftlyHttp {

    /// Represents possible authentication methods.
    ///
    ///   Authentication case | Description
    /// ---|---
    /// ``basic(login:password:)``| Basic authentication
    /// ``bearer(token:)``|Bearer authentication
    ///  ``notNeeded``| No authentication
    public enum Authentication {
        case basic(login: String, password: String)
        case bearer(token: String)
        case notNeeded
    }

    public enum Method {
        case post
        case get
        case delete
        case put
        case patch

        var stringValue: String {
            switch self {
            case .post:
                return "POST"
            case .get:
                return "GET"
            case .delete:
                return "DELETE"
            case .put:
                return "PUT"
            case .patch:
                return "PATCH"
            }
        }
    }

    var baseURL: URL
    var pathComponents = [String]()
    var auth: Authentication?
    var method: Method = .get
    var body: Data?
    var headers = [String: String]()
    var authFactory: (() async -> Authentication?)?
    var jsonEncoder: JSONEncoder = JSONEncoder()
    var urlSession = URLSession.shared

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

    /// Adds authentication to the request. Provided by the ``Authentication`` enum.
    ///  - Parameter auth: The authentication.
    public func authentication(_ auth: Authentication) -> Self {
        self.auth = auth
        return self
    }

    /// Adds an authentication factory the request.
    ///  - Parameter authFactory: A closure returning ``Authentication`` if it is needed.
    public func authentication(_ authFactory: @escaping () async -> (Authentication?)) -> Self {
        self.authFactory = authFactory
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
    
    /// Sets the request's body to the provided data.
    ///  - Parameter body: The body data.
    ///  - Note: Also sets the request's `Content-Type` to `application/json`
    public func body(_ body: Data) -> Self {
        self.body = body
        return self
    }

    /// Sets the request's header.
    /// - Parameter header: The header name.
    /// - Parameter value: The header value. If nil will remove the header.
    public func setHeader(_ header: String, to value: String?) -> Self {
        headers[header] = value
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
                                                authFactory: authFactory)
    }

    /// Creates a websocket request.
    ///  - Returns: An instance of ``SwiftlyWebSocketConnection``.
    public func websocket() async throws -> SwiftlyWebSocketConnection {
        let request = try await getRequest()
        // TODO: Add scheme check and/or change
        guard request.url?.scheme == "ws" || request.url?.scheme == "wss" else {
            throw SwiftlyHttpError.badScheme
        }
        return SwiftlyWebSocketConnection(task: URLSession.shared
            .webSocketTask(with: request))
    }

    /// Performs the request.
    ///  - Returns: A tuple of `Data` and `URLResponse`. Same way as an `URLRequest`.
    @discardableResult
    public func perform() async throws -> (Data, URLResponse) {
        try await urlSession.data(for: try await getRequest())
    }

    private func getRequest() async throws -> URLRequest {
        let url = URLComponents(url: baseURL, resolvingAgainstBaseURL: true)!
        var request = URLRequest(url: url.url!)

        if let auth = auth {
            addAuthenticationIfNeeded(to: &request, auth: auth)
        }

        if let authFactory,
           let auth = await authFactory() {

            addAuthenticationIfNeeded(to: &request, auth: auth)
        }

        request.httpMethod = method.stringValue
        request.httpBody = body
        headers.forEach { pair in
            request.setValue(pair.value, forHTTPHeaderField: pair.key)
        }
        return request
    }

    private func addAuthenticationIfNeeded(to request: inout URLRequest, auth: Authentication) {
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

/// A SwiftlyHttp request that decodes it's response body. Use ``SwiftlyHttp/SwiftlyHttp/decode(to:)`` on ``SwiftlyHttp/SwiftlyHttp`` to create.
public class SwiftlyHttpDecodedHttp<Response: Decodable>: SwiftlyHttp {

    var jsonDecoder: JSONDecoder = JSONDecoder()
    
    init(baseURL: URL,
         pathComponents: [String],
         auth: Authentication?,
         method: Method,
         body: Data?,
         headers: [String: String],
         authFactory: (() async -> Authentication?)?) {
        super.init(baseURL: baseURL)
        self.pathComponents = pathComponents
        self.auth = auth
        self.method = method
        self.body = body
        self.headers = headers
        self.authFactory = authFactory
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
        task.resume()
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
