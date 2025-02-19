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
import GemCommonsKit
import Nimble
import TestUtils
@testable import VAUClient
import XCTest

final class VAUSessionTests: XCTestCase {
    func testSessionRetainsCurrentUserPseudonym() throws {
        // given
        let vauStorage = MemStorage()
        let url = URL(string: "http://some-service.com")!
        let sut = VAUSession(
                vauServer: url,
                vauAccessTokenProvider: VAUAccessTokenProviderMock(),
                vauCryptoProvider: VAUCryptoProviderMock(),
                vauStorage: vauStorage,
                trustStoreSession: TrustStoreSessionMock()
        )
        let request = URLRequest(url: URL(string: "http://www.url.com")!)
        let chain = PassThroughChain(request: request)
        let interceptor = sut.provideInterceptor()

        // helping subscriber
        var currentVauEndpoints: [URL?] = []
        let currentVauEndpointSubscriber = sut.vauEndpoint
                .sink(
                        receiveCompletion: { _ in },
                        receiveValue: { currentVauEndpoints.append($0) }
                )

        // If nothing was assigned, the VAU endpoint should default to ___/VAU/0
        expect(currentVauEndpoints.count) == 1
        expect(currentVauEndpoints[0]?.absoluteString) == "\(url)/VAU/0"

        // Mock first response containing a new user pseudonym for further use
        let userPseudonymHeaders1 = ["userpseudonym": "pseudo1"]
        let response1 = HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: "1/1",
                headerFields: userPseudonymHeaders1
        )!
        chain.response = response1
        interceptor.intercept(chain: chain)
                .test(expectations: { _ in
                    expect(currentVauEndpoints.count) == 2
                    expect(currentVauEndpoints[1]?.absoluteString) == "\(url)/VAU/pseudo1"
                })

        // Mock second response containing another user pseudonym for further use
        let userPseudonymHeaders2 = ["userpseudonym": "pseudo2"]
        let response2 = HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: "1/1",
                headerFields: userPseudonymHeaders2
        )!
        chain.response = response2
        interceptor.intercept(chain: chain)
                .test(expectations: { _ in
                    expect(currentVauEndpoints.count) == 3
                    expect(currentVauEndpoints[2]?.absoluteString) == "\(url)/VAU/pseudo2"
                })

        currentVauEndpointSubscriber.cancel()
    }
}
