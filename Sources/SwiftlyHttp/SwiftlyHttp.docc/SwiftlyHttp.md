# ``SwiftlyHttp``

An easy way to make HTTP requests in Swift.

## Overview

SwiftlyHttp provides a different way to structure HTTP requests in your app. The library provides a wrapper for `URLSession` that is based on the [Builder pattern](https://refactoring.guru/design-patterns/builder).

Create a ``SwiftlyHttp`` instance and call different methods on the instance to setup the request. Then call ``SwiftlyHttp/SwiftlyHttp/perform()`` to make the HTTP request.

```swift
let response = try await SwiftlyHttp(baseURL: "https://server.com")!
    .add(path: "path-component")
    .decode(to: DecodableResponseType.self)
    .perform()
```
