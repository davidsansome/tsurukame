# Hippolyte

![Run tests](https://github.com/JanGorman/Hippolyte/workflows/CI/badge.svg)
[![codecov](https://codecov.io/gh/JanGorman/Hippolyte/branch/master/graph/badge.svg)](https://codecov.io/gh/JanGorman/Hippolyte)
[![Version](https://img.shields.io/cocoapods/v/Hippolyte.svg?style=flat)](http://cocoapods.org/pods/Hippolyte)
[![License](https://img.shields.io/cocoapods/l/Hippolyte.svg?style=flat)](http://cocoapods.org/pods/Hippolyte)
[![Platform](https://img.shields.io/cocoapods/p/Hippolyte.svg?style=flat)](http://cocoapods.org/pods/Hippolyte)

An HTTP stubbing library written in Swift.

## Requirements

- Swift 5
- iOS 12+
- macOS 10.13+

## Install

### Cocoapods

Hippolyte is available on [Cocoapods](http://cocoapods.org). Add it to your `Podfile`'s test target:

```ruby
pod 'Hippolyte'
```

### Carthage

Hippolyte is also available on [Carthage](https://github.com/Carthage/Carthage). Make the following entry in your Cartfile:

```ruby
github "JanGorman/Hippolyte"
```

Then run `carthage update`.

Add the Hippolyte.framework to the `Link Binary with Libraries`.

You'll need to go through some additional steps.
Please see [here](https://github.com/Carthage/Carthage#quick-start).

## Usage

To stub a request, first you need to create a `StubRequest` and `StubResponse`. You then register this stub with `Hippolyte` and tell it to intercept network requests by calling the `start()` method.

There are convenient Builder classes for both requests and responses:

```swift
func testStub() {
  // The stub response
  let response = StubResponse.Builder()
    .stubResponse(withStatusCode: 204)
    .addHeader(withKey: "X-Foo", value: "Bar")
    .build()
  // The request that will match this URL and return the stub response
  let request = StubRequest.Builder()
    .stubRequest(withMethod: .GET, url: URL(string: "http://www.apple.com")!)
    .addResponse(response)
    .build()
  // Register the request
  Hippolyte.shared.add(stubbedRequest: request)
  // And start intercepting requests by calling start
  Hippolyte.shared.start()
  …
}
```

Alternatively you can also construct them directly:

```swift
func testStub() {
  let url = URL(string: "http://www.apple.com")!
  var stub = StubRequest(method: .GET, url: url)
  var response = StubResponse()
  let body = "Hippolyte".data(using: .utf8)!
  response.body = body
  stub.response = response
  Hippolyte.shared.add(stubbedRequest: stub)
  Hippolyte.shared.start()

  let expectation = self.expectation(description: "Stubs network call")
  let task = URLSession.shared.dataTask(with: url) { data, _, _ in
    XCTAssertEqual(data, body)
    expectation.fulfill()
  }
  task.resume()

  wait(for: [expectation], timeout: 1)
}
```

It's also possible to configure a `StubRequest` to use a regular expression matcher to intercept URLs. The following example also shows a `StubResponse` that returns a certain status code:

```swift
func testStub() throws {
  let regex = try NSRegularExpression(pattern: "http://www.google.com/+", options: [])
  var stub = StubRequest(method: .GET, urlMatcher: RegexMatcher(regex: regex))
  stub.response = StubResponse(statusCode: 404)
  Hippolyte.shared.add(stubbedRequest: stub)
  Hippolyte.shared.start()

  myFictionalDataSource.get(URL(string: "http://www.google.com/foo.html")!) {
    …
  }
}
```

To match a POST request on the body that's sent, `Hippolyte` uses a `Matcher`. There is a ready made `DataMatcher` and `JSONMatcher` class available to use. Say you're POSTing a JSON to your server, you could make your stub match a particular value like this:

```swift
struct MyPostBody: Codable, Hashable {
  let id: Int
  let name: String
}

func testStub() throws {
  // The POST body that you want to match
  let body = MyPostbody(id: 100, name: "Tim")
  let matcher = JSONMatcher<MyPostBody>(object: body)
  // Construct your stub response
  let response = StubResponse.Builder()
    .stubResponse(withStatusCode: 204)
    .build()
  // The request that will match the URL and the body JSON
  let request = StubRequest.Builder()
    .stubRequest(withMethod: .POST, url: URL(string: "http://www.apple.com")!)
    .addMatcher(matcher)
    .addResponse(response)
    .build()
}
```

Remember to tear down stubbing in your tests:

```swift
override func tearDown() {
  Hippolyte.shared.stop()
  super.tearDown()
}
```

You can configure your stub response in a number of ways, such as having it return different HTTP status codes, headers, and errors.

## License

Hippolyte is released under the MIT license. See LICENSE for details
