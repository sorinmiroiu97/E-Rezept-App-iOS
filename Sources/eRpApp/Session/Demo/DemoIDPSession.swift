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
import CombineSchedulers
import Foundation
import IDP

class DemoIDPSession: IDPSession {
    @Injected(\.schedulers) var schedulers: Schedulers
    private let storage: IDPStorage
    private var uiScheduler: AnySchedulerOf<DispatchQueue> {
        schedulers.main
    }

    var currentValue = CurrentValueSubject<IDPToken?, IDPError>(nil)

    var isLoggedIn: AnyPublisher<Bool, IDPError> {
        autoRefreshedToken.map { token in
            token != nil
        }
        .eraseToAnyPublisher()
    }

    var autoRefreshedToken: AnyPublisher<IDPToken?, IDPError> {
        storage.token
            .setFailureType(to: IDPError.self)
            .eraseToAnyPublisher()
    }

    init(storage: IDPStorage) {
        self.storage = storage
    }

    func invalidateAccessToken() {
        storage.set(token: nil)
        currentValue.value = nil
    }

    func requestChallenge() -> AnyPublisher<IDPChallengeSession, IDPError> {
        Future { promise in
            promise(Result {
                IDPChallengeSession(
                    challenge: try IDPChallenge(
                        challenge: JWT(header: JWT.Header(), payload: DemoPayload())
                    ),
                    verifierCode: "code_verifier",
                    state: "randomState",
                    nonce: "randomNonce"
                )
            })
        }
        .mapError { $0.asIDPError() }
        .delay(for: 0.5, scheduler: uiScheduler)
        .eraseToAnyPublisher()
    }

    func verify(_: SignedChallenge)
        -> AnyPublisher<IDPExchangeToken, IDPError> {
        Just(IDPExchangeToken(code: "SUPER_SECRET_AUTH_CODE", sso: nil, state: "state"))
            .setFailureType(to: IDPError.self)
            .delay(for: 1.5, scheduler: uiScheduler)
            .eraseToAnyPublisher()
    }

    func exchange(token _: IDPExchangeToken,
                  challengeSession _: IDPChallengeSession) -> AnyPublisher<IDPToken, IDPError> {
        currentValue.send(
            IDPToken(
                accessToken: "SECRET ACCESSTOKEN",
                expires: Date.distantFuture,
                idToken: "IDP TOKEN",
                ssoToken: "SSO TOKEN"
            )
        )
        return currentValue // swiftlint:disable:this trailing_closure
            .compactMap { $0 }
            .handleEvents(receiveOutput: { token in
                self.storage.set(token: token)
            })
            .eraseToAnyPublisher()
    }

    func refresh(token _: IDPToken) -> AnyPublisher<IDPToken, IDPError> {
        Just(IDPToken(
            accessToken: "SECRET ACCESSTOKEN",
            expires: Date.distantFuture,
            idToken: "IDP TOKEN",
            ssoToken: "SSO TOKEN"
        ))
            .setFailureType(to: IDPError.self)
            .delay(for: 1.5, scheduler: uiScheduler)
            .eraseToAnyPublisher()
    }

    func pairDevice(with _: RegistrationData, token _: IDPToken) -> AnyPublisher<PairingEntry, IDPError> {
        Fail(error: IDPError.internalError("not implemented for demo session"))
            .eraseToAnyPublisher()
    }

    func unregisterDevice(_: String) -> AnyPublisher<Bool, IDPError> {
        Fail(error: IDPError.internalError("not implemented for demo session"))
            .eraseToAnyPublisher()
    }

    func altVerify(_: SignedAuthenticationData) -> AnyPublisher<IDPExchangeToken, IDPError> {
        Fail(error: IDPError.internalError("not implemented for demo session"))
            .eraseToAnyPublisher()
    }
}

extension DemoIDPSession {
    struct DemoPayload: Claims {}
}
