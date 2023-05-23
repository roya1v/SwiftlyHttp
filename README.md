# SwiftlyHttp

SwiftlyHttp is an easy way to make HTTP requests in Swift.

## Usage

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

Short docs can be found [here](https://roya1v.github.io/SwiftlyHttp/documentation/swiftlyhttp).

## Installation

### Swift Package Manager

The [Swift Package Manager](https://swift.org/package-manager/) is a tool for automating the distribution of Swift code and is integrated into the `swift` compiler. 

Once you have your Swift package set up, adding Alamofire as a dependency is as easy as adding it to the `dependencies` value of your `Package.swift`.

```swift
dependencies: [
    .package(url: "https://github.com/roya1v/SwiftlyHttp", branch: "main")
]
```
