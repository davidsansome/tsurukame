MockURLSession
===

[![Build Status](https://travis-ci.org/announce/MockURLSession.svg?branch=master)](https://travis-ci.org/announce/MockURLSession)
[![CocoaPods](https://img.shields.io/cocoapods/v/MockURLSession.svg)](https://cocoapods.org/pods/MockURLSession)

Are you a dependency injection devotee? Let's mock `URLSession` together.


## Features

* No need to modify production code to mock `URLSession`
* Customizable URL matching logic to mock responses
* Testable that the mocked responses are surely called


## Installation

#### CocoaPods (iOS 8+, OS X 10.9+)

You can use [Cocoapods](http://cocoapods.org/) to install `MockURLSession` by adding it to your `Podfile`:

```ruby
platform :ios, '8.0'
use_frameworks!

target 'MyAppTest' do
	pod 'MockURLSession'
end
```
Note that this requires CocoaPods version 36, and your iOS deployment target to be at least 8.0.


## Usage

#### Quick glance

Let's look through an example to test `MyApp` below.

```swift
class MyApp {
    static let apiUrl = URL(string: "https://example.com/foo/bar")!
    let session: URLSession
    var data: Data?
    var error: Error?
    init(session: URLSession = URLSession.shared) {
        self.session = session
    }
    func doSomething() {
        session.dataTask(with: MyApp.apiUrl) { (data, _, error) in
            self.data = data
            self.error = error
        }.resume()
    }
}
```

In the test code,

```swift
import MockURLSession
```

and write testing by any flamewrorks you prefer sush as XCTest (Written by `print` here).

```swift
// Initialization
let session = MockURLSession()
// Or, use shared instance as `URLSession` provides
// MockURLSession.sharedInstance

// Setup a mock response
let data = "Foo 123".data(using: .utf8)!
session.registerMockResponse(MyApp.apiUrl, data: data)

// Inject the session to the target app code and the response will be mocked like below
let app = MyApp(session: session)
app.doSomething()

print(String(data:app.data!, encoding: .utf8)!)  // Foo 123
print(app.error as Any)    // nil

// Make sure that the data task is resumed in the app code
print(session.resumedResponse(MyApp.apiUrl) != nil)  // true
```

#### URL matching customization

```swift
// Customize URL matching logic if you prefer
class Normalizer: MockURLSessionNormalizer {
    func normalize(url: URL) -> URL {
        // Fuzzy matching example
        var components = URLComponents()
        components.host = url.host
        components.path = url.path
        return components.url!
    }
}
// Note that you should setup the normalizer before registering mocked response
let data = NSKeyedArchiver.archivedData(withRootObject: ["username": "abc", "age": 20])
let session = MockURLSession()
session.normalizer = Normalizer()
session.registerMockResponse(MyApp.apiUrl, data: data)
```

## Disclosure

#### Inspirations

* This module is inspired from the entry [*Mocking Classes You Don't Own · Masilotti\.com*](http://masilotti.com/testing-nsurlsession-input/#comment-2493597339) and its comments.


## Contributing to MockURLSession

#### Prerequisite
* [Bundler](http://bundler.io/)

#### Get started
Run test on your environment:

```
bundle install --path vendor/bundle
bundle exec rake
```

#### A long way to bump up spec version

Here's the release flow:

1. Xcode: MockURLSession > Identity > Version
1. Pod: `s.version` in *MockURLSession.podspec*
1. Git: `git tag 2.x.x && git push origin --tag`
1. Release by `bundle exec pod trunk push MockURLSession.podspec`
