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

/// Handles the chaining of `Interceptors`.
public protocol Chain {
    /// The request that the chain hold at the moment
    var request: URLRequest { get }

    /// Launch the chain processing of the given input.
    ///
    /// - Parameter request: the `URLRequest` to proceed
    /// - Returns: `AnyPublisher` that emits a response as `HTTPClient.Response`
    func proceed(request: URLRequest) -> AnyPublisher<HTTPResponse, HTTPError>
}
