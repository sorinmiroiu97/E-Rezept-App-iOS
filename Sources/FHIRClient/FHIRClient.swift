//
//  Copyright (c) 2021 gematik GmbH
//  
//  Licensed under the EUPL, Version 1.2 or – as soon they will be approved by
//  the European Commission - subsequent versions of the EUPL (the Licence);
//  You may not use this work except in compliance with the Licence.
//  You may obtain a copy of the Licence at:
//  
//      https://joinup.ec.europa.eu/software/page/eupl
//  
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the Licence is distributed on an "AS IS" basis,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the Licence for the specific language governing permissions and
//  limitations under the Licence.
//  
//

import Combine
import Foundation
import HTTPClient
import ModelsR4

extension FHIRClient {
    /// Error cases when using the `FHIRClient`
    public enum Error: Swift.Error, Equatable, CustomStringConvertible, LocalizedError {
        case internalError(String)
        case httpError(HTTPError)
        /// When the server returned a successful response with inconsistent response data.
        /// E.g. no task(s) found in a Fetch response where we normally would have expected a HTTP 404 instead.
        case inconsistentResponse
        case decoding(Swift.Error)
        case unknown(Swift.Error)

        public var description: String {
            switch self {
            case let .internalError(error): return error
            case let .httpError(error): return error.localizedDescription
            case .inconsistentResponse: return "inconsistent response error"
            case let .decoding(error): return error.localizedDescription
            case let .unknown(error): return error.localizedDescription
            }
        }

        public var errorDescription: String? {
            switch self {
            case let .internalError(error): return error
            case let .httpError(error): return error.localizedDescription
            case .inconsistentResponse: return "inconsistent response error"
            case let .decoding(error): return error.localizedDescription
            case let .unknown(error): return error.localizedDescription
            }
        }

        public static func ==(lhs: FHIRClient.Error, rhs: FHIRClient.Error) -> Bool {
            switch (lhs, rhs) {
            case let (internalError(lhsString), internalError(rhsString)): return lhsString == rhsString
            case let (httpError(lhsError), httpError(rhsError)): return lhsError == rhsError
            case (inconsistentResponse, inconsistentResponse): return true
            default: return false
            }
        }
    }
}

/// Lightweight client for FHIR communication. Can perform `FHIROperation`s.
public class FHIRClient {
    private var server: URL
    private var httpClient: HTTPClient

    /// Initialize with the service URL and an `HTTPClient`
    ///
    /// - Parameters:
    ///   - server: `URL` where the request will be sent to
    ///   - httpClient:  `HTTPClient` that will (alter and) perform the request resulting from a `FHIRClientOperation`
    public init(server: URL, httpClient: HTTPClient) {
        self.server = server
        self.httpClient = httpClient
    }

    /// Perform a request derived from a `FHIRClientOperation`.
    ///
    /// - Parameter operation: The request to be performed will be derived from this `FHIRClientOperation`.
    /// - Returns: `AnyPublisher` that emits a `FHIRClient.Response`
    public func execute<F: FHIRClientOperation>(operation: F) -> AnyPublisher<F.Value, FHIRClient.Error> {
        guard let targetUrl = URL(string: operation.path, relativeTo: server) else {
            return Fail(error: .internalError("Operation endpoint url could not be constructed")).eraseToAnyPublisher()
        }
        var request = URLRequest(url: targetUrl)
        request.allHTTPHeaderFields = operation.httpHeaders
        request.httpMethod = operation.httpMethod.rawValue
        if let bodyData = operation.httpBody {
            request.httpBody = bodyData
        }
        return httpClient.send(request: request)
            .tryMap { data, urlResponse, status in
                let response = FHIRClient.Response.from(response: urlResponse, status: status, data: data)

                guard response.status.isSuccessful else {
                    if let outcome = try? JSONDecoder().decode(ModelsR4.OperationOutcome.self, from: response.body) {
                        let urlError = URLError(URLError.Code(rawValue: response.status.rawValue),
                                                userInfo: ["body": outcome])
                        throw Error.httpError(.httpError(urlError))
                    } else {
                        let urlError = URLError(URLError.Code(rawValue: response.status.rawValue),
                                                userInfo: ["body": response.body])
                        throw Error.httpError(.httpError(urlError))
                    }
                }

                return try operation.handle(response: response)
            }
            .mapError { error in
                error.asFHIRClientError()
            }
            .eraseToAnyPublisher()
    }
}

extension FHIRClient {
    /// 'Anonymous-inner-class' for FHIRResponseHandler
    public class DefaultFHIRResponseHandler<Value>: FHIRResponseHandler {
        private let handler: (FHIRClient.Response) throws -> Value
        public var acceptFormat: FHIRAcceptFormat

        public init(acceptFormat: FHIRAcceptFormat = .fhirJson,
                    _ handler: @escaping (FHIRClient.Response) throws -> Value) {
            self.handler = handler
            self.acceptFormat = acceptFormat
        }

        public func handle(response: Response) throws -> Value {
            try handler(response)
        }
    }
}

extension Swift.Error {
    func asFHIRClientError() -> FHIRClient.Error {
        if let fhirClientError = self as? FHIRClient.Error {
            return fhirClientError
        }
        if let httpError = self as? HTTPError {
            return .httpError(httpError)
        }
        return .unknown(self)
    }
}

/// FHIRClientOperation that can be handled by the FHIRClient
public protocol FHIRClientOperation {
    /// The associated return type
    associatedtype Value

    /// Operation path - used to compose the endpoint
    var path: String { get }
    /// Operation HTTP-Headers
    var httpHeaders: [String: String] { get }
    /// Operation method
    var httpMethod: HTTPMethod { get }
    /// Operation HTTP-Body
    var httpBody: Data? { get }

    /// Handle the FHIRClient.Response and parse/format the return Value
    ///
    /// - Parameter response: the FHIR response from server
    /// - Returns: the parsed/formatted Value
    /// - Throws: an Error when parsing failed
    func handle(response: FHIRClient.Response) throws -> Value
}

extension FHIRClientOperation {
    var httpBody: Data? {
        nil
    }
}
