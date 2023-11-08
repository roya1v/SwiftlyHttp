# SwiftlyHttp

An easy way to make HTTP requests in Swift.

## Overview

SwiftlyHttp is a simple NSURLSession wrapper that uses the builder pattern.

## How to use?

```swift
let response = try await SwiftlyHttp(baseURL: "https://server.com")!
    .authorization(.bearer(token: "AnAuthToken")
    .add(path: "path-component")
    .add(path: "another-path-component")
    .method(.post)
    .body(encodableBody)
    .decode(to: DecodableResponseType.self)
    .perform()
```
