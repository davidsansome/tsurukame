//
//  MockURLSession.swift
//  MockURLSession
//
//  Created by YAMAMOTOKenta on 8/24/16.
//  Copyright © 2016 ymkjp. All rights reserved.
//
import Foundation

public protocol MockURLSessionNormalizer {
    // Normalize URL to match resources
    func normalize(url: URL) -> URL
}

public class MockURLSession: URLSession {
    public typealias CompletionHandler = (Data?, URLResponse?, Error?) -> Void
    public typealias Response = (data: Data?, urlResponse: URLResponse?, error: Error?)
    public typealias HttpHeadersField = [String : String]
    
    public static let bundleId = Bundle(for: MockURLSession.self).bundleIdentifier ?? "Unknown Bundle ID"
    public static let sharedInstance = MockURLSession()
    
    public struct MockError: Error {
        static let Domain: String = MockURLSession.bundleId
        enum Code: Int {
            case NoResponseRegistered = 4000
        }
    }
    
    public var responses: [URL: Response] = [:]
    public var tasks: [URL: MockURLSessionDataTask] = [:]
    public var normalizer: MockURLSessionNormalizer = DefaultNormalizer()
    
    // MARK: - Mock methods
    public override func dataTask(with url: URL, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) -> URLSessionDataTask {
        let normalizedUrl = normalizer.normalize(url: url)
        let error = NSError(domain: MockError.Domain,
                            code: MockError.Code.NoResponseRegistered.rawValue,
                            userInfo: [NSLocalizedDescriptionKey: "No mocked response found by '\(normalizedUrl)'."])
        
        
        let response: Response = responses[normalizedUrl] ?? (
            data: nil,
            urlResponse: nil,
            error: error)
        let task = MockURLSessionDataTask(response: response,
                                          completionHandler: completionHandler)
        tasks[normalizedUrl] = task
        return task
    }
    
    public class MockURLSessionDataTask: URLSessionDataTask {
        public var mockResponse: Response
        fileprivate (set) var called: [String: Response] = [:]
        let handler: CompletionHandler?
        
        init(response: Response, completionHandler: CompletionHandler?) {
            self.mockResponse = response
            self.handler = completionHandler
        }
        
        public override func resume() {
            register(callee: mockResponse, name: "\(#function)")
            handler!(mockResponse.data, mockResponse.urlResponse, mockResponse.error)
        }
        
        public func register(callee value: Response, name: String) {
            return called[name] = value
        }
        
        public func callee(_ name: String) -> Response? {
            return called["\(name)()"]
        }
    }
    
    class DefaultNormalizer: MockURLSessionNormalizer {
        func normalize(url: URL) -> URL {
            return url
        }
    }
    
    // MARK: - Helpers
    @discardableResult
    public func registerMockResponse(_ url: URL,
                                     data: Data,
                                     statusCode: Int = 200,
                                     httpVersion: String? = nil,
                                     headerFields: HttpHeadersField? = nil,
                                     error: MockError? = nil) -> Response? {
        let urlResponse = HTTPURLResponse(url: url,
                                          statusCode: statusCode,
                                          httpVersion: httpVersion,
                                            headerFields: headerFields)
        return responses.updateValue((data: data, urlResponse: urlResponse, error: error),
                                     forKey: normalizer.normalize(url: url))
    }
    
    public func resumedResponse(_ url: URL, methodName: String = "resume") -> Response? {
        return tasks[normalizer.normalize(url: url)]?.callee(methodName)
    }
}
