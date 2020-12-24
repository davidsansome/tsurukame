//
//  Copyright © 2017 Jan Gorman. All rights reserved.
//

import Foundation

public enum HippolyteError: Error {
  case unmatchedRequest
}

open class Hippolyte {

  public static var shared = Hippolyte()

  public private(set) var stubbedRequests: [StubRequest] = []
  public private(set) var isStarted = false

  private var hooks: [HTTPClientHook] = []

  private init() {
    registerHook(URLHook())
    registerHook(URLSessionHook())
  }

  /// The start method to call for Hippolyte to start intercepting and stubbing HTTP calls
  public func start() {
    if !isStarted {
      loadHooks()
      isStarted = true
    }
  }

  private func loadHooks() {
    hooks.forEach { $0.load() }
  }

  /// The resume method to tell Hippolyte to resume stubbing. This method has the same behaviour as start emthod and provided only for better readability
  public func resume() {
    start()
  }

  /// The pause method to tell Hippolyte to pause stubbing. This method is not destructive and it will not clear stubs
  public func pause() {
    if isStarted {
      unloadHooks()
      isStarted = false
    }
  }

  /// The stop method to tell Hippolyte to stop stubbing.
  public func stop() {
    clearStubs()
    if isStarted {
      unloadHooks()
      isStarted = false
    }
  }

  private func unloadHooks() {
    hooks.forEach { $0.unload() }
  }

  /// Add a stubbed request
  ///
  /// - Parameter stubbedRequest: A configured `StubRequest`
  public func add(stubbedRequest request: StubRequest) {
    if let idx = stubbedRequests.firstIndex(of: request) {
      stubbedRequests[idx] = request
      return
    }
    stubbedRequests.append(request)
  }

  /// Clear all stubs
  public func clearStubs() {
    stubbedRequests.removeAll()
  }

  /// Register a hook
  ///
  /// - Parameter hook: A configured `HTTPClientHook`
  public func registerHook(_ hook: HTTPClientHook) {
    if !isHookRegistered(hook) {
      hooks.append(hook)
    }
  }

  private func isHookRegistered(_ hook: HTTPClientHook) -> Bool {
    hooks.first(where: { $0 == hook }) != nil
  }

  /// Retrieve a stubbed response for an `HTTPRequest`
  /// - Parameter request: The request to retrieve a response for
  /// - Returns: A StubResponse
  /// - Throws: An `.unmatchedRequest` for requests that haven't been registered before
  public func response(for request: HTTPRequest) throws -> StubResponse {
    guard let response = stubbedRequests.first(where: { $0.matchesRequest(request) })?.response else {
      throw HippolyteError.unmatchedRequest
    }
    return response
  }

}
