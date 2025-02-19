// swiftlint:disable file_length
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
import CryptoKit
import DataKit
import Foundation
@testable import IDP
import Nimble
import OpenSSL
import TestUtils
import TrustStore
import XCTest

final class DefaultIDPSessionTests: XCTestCase {
    var trustStoreSessionMock: TrustStoreSessionMock!

    override func setUp() {
        super.setUp()

        trustStoreSessionMock = TrustStoreSessionMock()
        trustStoreSessionMock.validateCertificateReturnValue = Just(true).setFailureType(to: TrustStoreError.self)
            .eraseToAnyPublisher()
    }

    private lazy var dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSSSZ"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        return dateFormatter
    }()

    private func discoveryDocument(createdOn: Date) -> DiscoveryDocument {
        guard let documentData = try? Bundle(for: Self.self)
            .path(forResource: "discovery-doc", ofType: "jwt", inDirectory: "JWT.bundle")?
            .readFileContents(),
            let documentJWT = try? JWT(from: documentData),
            let jwkData = try? Bundle(for: Self.self)
            .path(forResource: "jwk", ofType: "json", inDirectory: "JWT.bundle")?
            .readFileContents(),
            let jwk = try? JSONDecoder().decode(JWK.self, from: jwkData),
            let document = try? DiscoveryDocument(
                jwt: documentJWT,
                encryptPuks: jwk,
                signingPuks: jwk,
                createdOn: createdOn
            )
        else {
            fatalError("Could not load test discovery document")
        }
        return document
    }

    private lazy var challengeDocument: IDPChallenge = {
        guard let challengeData = try? Bundle(for: Self.self)
            .path(forResource: "challenge-2", ofType: "json", inDirectory: "JWT.bundle")?
            .readFileContents(),
            let challenge = try? JSONDecoder().decode(IDPChallenge.self, from: challengeData) else {
            fatalError("Could not load test idp challenge")
        }
        return challenge
    }()

    // [REQ:gemSpec_IDP_Frontend:A_20617-01]
    // [REQ:gemSpec_IDP_Frontend:A_20623]
    // [REQ:gemSpec_IDP_Frontend:A_20512]
    func testLoadDiscoveryDocumentFromStorageOnInitFailesWhenTrustStoreFailsValidation() {
        trustStoreSessionMock.validateCertificateReturnValue = Just(false).setFailureType(to: TrustStoreError.self)
            .eraseToAnyPublisher()
        let idpClientMock = IDPClientMock()
        idpClientMock.discoveryDocument = nil
        let storage = MemStorage()
        let issuedDate = dateFormatter.date(from: "2021-03-16 14:42:03.0000+0000")!
        storage.set(discovery: discoveryDocument(createdOn: issuedDate))

        // sut: IDPSession is not stored as we test its internals
        _ = DefaultIDPSession(
            client: idpClientMock,
            storage: storage,
            schedulers: TestSchedulers(),
            trustStoreSession: trustStoreSessionMock
        ) { issuedDate }

        expect(storage.discoveryDocumentState).to(beNil())
        expect(self.trustStoreSessionMock.validateCertificateCallsCount).to(equal(2))
    }

    // [REQ:gemSpec_IDP_Frontend:A_20617-01]
    // [REQ:gemSpec_IDP_Frontend:A_20623]
    // [REQ:gemSpec_IDP_Frontend:A_20512]
    func testLoadDiscoveryDocumentFromRemoteOnInitFailesWhenTrustStoreFailsValidation() {
        trustStoreSessionMock.validateCertificateReturnValue = Just(false).setFailureType(to: TrustStoreError.self)
            .eraseToAnyPublisher()
        let idpClientMock = IDPClientMock()
        let issuedDate = dateFormatter.date(from: "2021-03-16 14:42:03.0000+0000")!
        idpClientMock.discoveryDocument = discoveryDocument(createdOn: issuedDate)
        let storage = MemStorage()
        storage.set(discovery: nil)

        // sut: IDPSession is not stored as we test its internals
        _ = DefaultIDPSession(
            client: idpClientMock,
            storage: storage,
            schedulers: TestSchedulers(),
            trustStoreSession: trustStoreSessionMock
        ) { issuedDate }

        expect(storage.discoveryDocumentState).to(beNil())
        expect(self.trustStoreSessionMock.validateCertificateCallsCount).to(equal(2))
    }

    // [REQ:gemSpec_IDP_Frontend:A_20617-01]
    // [REQ:gemSpec_IDP_Frontend:A_20623]
    // [REQ:gemSpec_IDP_Frontend:A_20512]
    func testLoadDiscoveryDocumentFromStorageOnInitFailesWhenTrustStoreThrows() {
        trustStoreSessionMock.validateCertificateReturnValue = Fail(error: TrustStoreError.invalidOCSPResponse)
            .eraseToAnyPublisher()
        let idpClientMock = IDPClientMock()
        idpClientMock.discoveryDocument = nil
        let storage = MemStorage()
        let issuedDate = dateFormatter.date(from: "2021-03-16 14:42:03.0000+0000")!
        storage.set(discovery: discoveryDocument(createdOn: issuedDate))

        // sut: IDPSession is not stored as we test its internals
        _ = DefaultIDPSession(
            client: idpClientMock,
            storage: storage,
            schedulers: TestSchedulers(),
            trustStoreSession: trustStoreSessionMock
        ) { issuedDate }

        expect(storage.discoveryDocumentState).to(beNil())
        expect(self.trustStoreSessionMock.validateCertificateCallsCount).to(equal(2))
    }

    // [REQ:gemSpec_IDP_Frontend:A_20617-01]
    // [REQ:gemSpec_IDP_Frontend:A_20623]
    // [REQ:gemSpec_IDP_Frontend:A_20512]
    func testLoadDiscoveryDocumentFromRemoteOnInitFailesWhenTrustStoreThrows() {
        trustStoreSessionMock.validateCertificateReturnValue = Fail(error: TrustStoreError.invalidOCSPResponse)
            .eraseToAnyPublisher()
        let idpClientMock = IDPClientMock()
        let issuedDate = dateFormatter.date(from: "2021-03-16 14:42:03.0000+0000")!
        idpClientMock.discoveryDocument = discoveryDocument(createdOn: issuedDate)
        let storage = MemStorage()
        storage.set(discovery: nil)

        // sut: IDPSession is not stored as we test its internals
        _ = DefaultIDPSession(
            client: idpClientMock,
            storage: storage,
            schedulers: TestSchedulers(),
            trustStoreSession: trustStoreSessionMock
        ) { issuedDate }

        expect(storage.discoveryDocumentState).to(beNil())
        expect(self.trustStoreSessionMock.validateCertificateCallsCount).to(equal(2))
    }

    // [REQ:gemSpec_IDP_Frontend:A_20617-01]
    // [REQ:gemSpec_IDP_Frontend:A_20623]
    // [REQ:gemSpec_IDP_Frontend:A_20512]
    func testLoadDiscoveryDocumentFromStorageOnInit() {
        let idpClientMock = IDPClientMock()
        idpClientMock.discoveryDocument = nil
        let storage = MemStorage()
        let issuedDate = dateFormatter.date(from: "2021-03-16 14:42:03.0000+0000")!
        let discoveryDocument = self.discoveryDocument(createdOn: issuedDate)
       storage.set(discovery: discoveryDocument)

        // sut: IDPSession is not stored as we test its internals
        _ = DefaultIDPSession(
            client: idpClientMock,
            storage: storage,
            schedulers: TestSchedulers(),
            trustStoreSession: trustStoreSessionMock
        ) { issuedDate }

        expect(storage.discoveryDocumentState) == discoveryDocument
        expect(self.trustStoreSessionMock.validateCertificateCallsCount).to(equal(2))
    }

    // [REQ:gemSpec_IDP_Frontend:A_20617-01]
    // [REQ:gemSpec_IDP_Frontend:A_20623]
    // [REQ:gemSpec_IDP_Frontend:A_20512]
    func testLoadDiscoveryDocumentFromRemoteOnInit() {
        let idpClientMock = IDPClientMock()
        let issuedDate = dateFormatter.date(from: "2021-03-16 14:42:03.0000+0000")!
        let discoveryDocument = self.discoveryDocument(createdOn: issuedDate)
        idpClientMock.discoveryDocument = discoveryDocument
        let storage = MemStorage()
        storage.set(discovery: nil)

        // sut: IDPSession is not stored as we test its internals
        _ = DefaultIDPSession(
            client: idpClientMock,
            storage: storage,
            schedulers: TestSchedulers(),
            trustStoreSession: trustStoreSessionMock
        ) { issuedDate }

        expect(storage.discoveryDocumentState) == discoveryDocument
        expect(self.trustStoreSessionMock.validateCertificateCallsCount).to(equal(2))
    }

    func testInvalidateLoadDiscoveryDocumentOnInit() {
        let idpClientMock = IDPClientMock()
        let storage = MemStorage()
        storage.set(discovery: nil)

        // sut: IDPSession is not stored as we test its internals
        _ = DefaultIDPSession( // swiftlint:disable:this trailing_closure
            client: idpClientMock,
            storage: storage,
            schedulers: TestSchedulers(),
            trustStoreSession: trustStoreSessionMock,
            time: { Date.distantPast }
        )

        expect(storage.discoveryDocumentState).to(beNil())
    }

    func testInvalidationRemovesToken() throws {
        let currentDate = dateFormatter.date(from: "2021-03-18 08:51:16.0000+0000")!
        let token = IDPToken(
            accessToken: "access-token",
            expires: currentDate.advanced(by: 10),
            idToken: "id-token",
            ssoToken: "sso-token",
            tokenType: "Bearer"
        )
        let idpClientMock = IDPClientMock()
        let storage = MemStorage()
        storage.set(token: token)

        let dateProvider = {
            currentDate
        }
        let schedulers = TestSchedulers()

        let sut = DefaultIDPSession(client: idpClientMock,
                                    storage: storage,
                                    schedulers: schedulers,
                                    trustStoreSession: trustStoreSessionMock,
                                    time: dateProvider)

        storage.token.first().test(expectations: { token in
            expect(token).toNot(beNil())
        })

        sut.invalidateAccessToken()

        storage.token.first().test(expectations: { token in
            expect(token).to(beNil())
        })
    }

    func testInvalidateStoredDocumentWhenExpired() throws {
        let idpClientMock = IDPClientMock()
        // Date provider provides a date that should invalidate the DiscoveryDocument when reading from IDPStorage
        // But provide a date that would validate the (same) document when coming from the IDPClient
        let issuedDate = dateFormatter.date(from: "2021-03-18 08:51:16.0000+0000")!
        let discoveryDocument = self.discoveryDocument(createdOn: issuedDate)
        idpClientMock.discoveryDocument = discoveryDocument
        let storage = MemStorage()
        storage.set(discovery: discoveryDocument)

        var calls = 0
        let dateProvider: TimeProvider = { [weak self] in
            calls += 1
            if calls == 1 {
                return self!.dateFormatter.date(from: "2021-03-19 16:42:28.0000+0000")!
            } else {
                return issuedDate
            }
        }

        let schedulers = TestSchedulers()
        var receivedDocuments = [DiscoveryDocument?]()
        let storageCancellable = storage.discoveryDocument // swiftlint:disable:this trailing_closure
            .receive(on: DispatchQueue.immediate)
            .sink(receiveValue: { document in
                receivedDocuments.append(document)
            })

        // sut: IDPSession is not stored as we test its internals
        _ = DefaultIDPSession(client: idpClientMock,
                              storage: storage,
                              schedulers: schedulers,
                              trustStoreSession: trustStoreSessionMock,
                              time: dateProvider)

        expect(storage.discoveryDocumentState) == discoveryDocument
        expect(receivedDocuments) == [discoveryDocument, nil, discoveryDocument]
        expect(calls) == 3

        storageCancellable.cancel()
    }

    func testRequestChallenge() {
        let idpClientMock = IDPClientMock()
        idpClientMock.discoveryDocument = nil
        idpClientMock.requestChallenge_Publisher = Just(challengeDocument)
            .setFailureType(to: IDPError.self)
            .eraseToAnyPublisher()
        let storage = MemStorage()
        let issuedDate = dateFormatter.date(from: "2021-03-16 14:00:00.0000+0000")!
        let discoveryDocument = self.discoveryDocument(createdOn: issuedDate)
        storage.set(discovery: discoveryDocument)
		// must be between iat date and exp date from `challengeDocument`
        let nowDate = dateFormatter.date(from: "2021-03-16 14:56:38.0000+0000")!
		// must be exact exp date from `challengeDocument`
        let challengeExpirationDate = dateFormatter.date(from: "2021-03-16 14:58:38.0000+0000")!

        let codeVerifier = "very-random-string"
        let codeChallenge = codeVerifier.encodeBase64urlsafe().sha256().encodeBase64urlsafe().asciiString!
        var randomGeneratorCalls = 0
        var randomGeneratorParams = [Int]()
        let stateOrNonce = Data([0x1, 0x2, 0x3])
        let randomGeneratorFunc: Random<Data> = { length in
            randomGeneratorCalls += 1
            randomGeneratorParams.append(length)
            if randomGeneratorCalls == 1 || randomGeneratorCalls == 4 {
                return codeVerifier.data(using: .ascii)!
            } else {
                return stateOrNonce
            }
        }

        let timerScheduler = DispatchQueue.test
        let schedulers = TestSchedulers(compute: timerScheduler.eraseToAnyScheduler())
        let verifierLength = 13
        let nonceLength = 10
        let stateLength = 17
        let cryptoBox = IDPCrypto(verifierLength: 13,
                                  nonceLength: 10,
                                  stateLength: 17,
                                  randomGenerator: randomGeneratorFunc)
        let sut: IDPSession = DefaultIDPSession(
            client: idpClientMock,
            storage: storage,
            schedulers: schedulers,
            trustStoreSession: trustStoreSessionMock,
            time: { nowDate },
            idpCrypto: cryptoBox
        )

        var receivedChallenges = [IDPChallengeSession]()
        let cancellable = sut.requestChallenge()
            .receive(on: DispatchQueue.immediate)
            .sink(receiveCompletion: { completion in
                if case let .failure(error) = completion {
                    fail("Failed: \(error)")
                }
            }, receiveValue: { value in
                receivedChallenges.append(value)
            })

        expect(randomGeneratorCalls) == 3
		if randomGeneratorCalls == 3 {
			expect(randomGeneratorParams[0]) == verifierLength
			expect(randomGeneratorParams[1]) == stateLength
            expect(randomGeneratorParams[2]) == nonceLength
		} else {
			fail("unexpected calls count of randomGenerator")
		}
        expect(idpClientMock.requestChallenge_CallsCount) == 1
		if let firstCallArguments = idpClientMock.requestChallenge_ReceivedArguments.first {
			expect(firstCallArguments.codeChallenge) == codeChallenge
			expect(firstCallArguments.method) == IDPCodeChallengeMode.sha256
			expect(firstCallArguments.state) == stateOrNonce.hexString()
            expect(firstCallArguments.nonce) == stateOrNonce.hexString()
			expect(firstCallArguments.discovery) == discoveryDocument
		} else {
			fail("request challenge did not get called")
		}

        let expInterval = challengeExpirationDate.timeIntervalSince(nowDate)
        timerScheduler.advance(by: .init(floatLiteral: expInterval + 1))

        expect(randomGeneratorCalls) == 6
		if randomGeneratorCalls == 6 {
			expect(randomGeneratorParams[3]) == verifierLength
			expect(randomGeneratorParams[4]) == stateLength
            expect(randomGeneratorParams[5]) == nonceLength
		} else {
			fail("unexpected calls count of randomGenerator")
		}
        expect(idpClientMock.requestChallenge_CallsCount) == 2
		if idpClientMock.requestChallenge_CallsCount == 2 {
			let secondCallArguments = idpClientMock.requestChallenge_ReceivedArguments[1]
			expect(secondCallArguments.codeChallenge) == codeChallenge
			expect(secondCallArguments.method) == IDPCodeChallengeMode.sha256
			expect(secondCallArguments.state) == stateOrNonce.hexString()
			expect(secondCallArguments.discovery) == discoveryDocument
		} else {
			fail("request challenge did not get called for the second time")
		}

        cancellable.cancel()
    }

    func testVerifySignedChallenge() {
        let idpClientMock = IDPClientMock()
        // Date provider provides a date that should validate the DiscoveryDocument when reading from IDPStorage
        let issuedDate = dateFormatter.date(from: "2021-03-16 16:42:28.0000+0000")!
        let discoveryDocument = self.discoveryDocument(createdOn: issuedDate)
        idpClientMock.discoveryDocument = discoveryDocument
        let storage = MemStorage()
        storage.set(discovery: discoveryDocument)
        let dateProvider: TimeProvider = {
            issuedDate
        }
        let schedulers = TestSchedulers()
        let expectedToken = IDPExchangeToken(
            code: "exchange-token",
            sso: "sso-token",
            state: "1234567890"
        )
        idpClientMock.verify_Publisher = Just(expectedToken).setFailureType(to: IDPError.self).eraseToAnyPublisher()
        let signedJwt = try! JWT(from: Bundle(for: Self.self)
            .path(forResource: "signed-challenge-query-param", ofType: "jwt", inDirectory: "JWT.bundle")!
            .readFileContents())
        let challenge = try! IDPChallenge(
            challenge: JWT(header: JWT.Header(), payload: IDPChallenge.Claim())
        )
        let signedChallenge = SignedChallenge(
            originalChallenge: IDPChallengeSession(challenge: challenge,
                                                   verifierCode: "verifier",
                                                   state: "1234567890",
                                                   nonce: "1234567890"),
            signedChallenge: signedJwt
        )

        let sut = DefaultIDPSession(client: idpClientMock,
                                    storage: storage,
                                    schedulers: schedulers,
                                    trustStoreSession: trustStoreSessionMock,
                                    time: dateProvider)
        sut.verify(signedChallenge)
            .test(expectations: { token in
                expect(token) == expectedToken
            })

        expect(idpClientMock.verify_Called) == true
        expect(idpClientMock.verify_ReceivedArguments?.challenge).notTo(beNil())
        expect(idpClientMock.verify_ReceivedArguments?.document) == discoveryDocument
    }

    let cryptoBox: IDPCrypto = {
        let privateKey = try! BrainpoolP256r1.KeyExchange.generateKey(compactRepresentable: true)
        let nonce = try! IDPRandom.generateSecureRandom(length: 12)
        let aesKeyData = try! Data(hex: "668D155004E1110DB6914BA40346A302312FA3F1AB647EC79FA12F96793E5205")
        return IDPCrypto(randomGenerator: { _ in "UWWzuvaSG".data(using: .utf8)! },
                         brainpoolKeyPairGenerator: { privateKey },
                         aesNonceGenerator: { nonce },
                         aesKey: SymmetricKey(data: aesKeyData))
    }()

    let encryptedTokenPayload: TokenPayload = {
        let tokenPayloadPath = Bundle(for: DefaultIDPSessionTests.self)
            .path(forResource: "idp_token_encrypted", ofType: "json", inDirectory: "JWT.bundle")!
        let encryptedTokenData = try! tokenPayloadPath.readFileContents()
        return try! JSONDecoder().decode(TokenPayload.self, from: encryptedTokenData)
    }()

    let decryptedTokenPayload: TokenPayload = {
        let tokenPath = Bundle(for: DefaultIDPSessionTests.self)
            .path(forResource: "idp_token_decrypted", ofType: "json", inDirectory: "JWT.bundle")!
        let tokenData = try! tokenPath.readFileContents()
        return try! JSONDecoder().decode(TokenPayload.self, from: tokenData)
    }()

    func testExchangeToken() {
        let idpClientMock = IDPClientMock()
        // Date provider provides a date that should validate the DiscoveryDocument when reading from IDPStorage
        var issuedDate = dateFormatter.date(from: "2021-03-16 14:42:03.0000+0000")!
        let discoveryDocument = self.discoveryDocument(createdOn: issuedDate)
        idpClientMock.discoveryDocument = discoveryDocument
        let storage = MemStorage()
        storage.set(discovery: discoveryDocument)
        storage.set(token: nil)
        let dateProvider: TimeProvider = {
            issuedDate
        }
        let schedulers = TestSchedulers()
        let expirationInterval = 300

        // encrypted token payload (send by the client)
        idpClientMock.exchange_Publisher = Just(encryptedTokenPayload)
            .setFailureType(to: IDPError.self).eraseToAnyPublisher()

        let exchangeToken = IDPExchangeToken(code: "code", sso: "sso-token", state: "state")

        // expected (decrypted) token result
        let expectedToken = IDPToken(
            accessToken: decryptedTokenPayload.accessToken,
            expires: issuedDate.addingTimeInterval(TimeInterval(expirationInterval)),
            idToken: decryptedTokenPayload.idToken,
            ssoToken: exchangeToken.sso
        )

        var receivedTokens: [IDPToken?] = []
        let tokenSubscriber = storage.token
            .sink(receiveValue: { tokenValue in
                receivedTokens.append(tokenValue)
            })

        let sut = DefaultIDPSession(client: idpClientMock,
                                    storage: storage,
                                    schedulers: schedulers,
                                    trustStoreSession: trustStoreSessionMock,
                                    time: dateProvider,
                                    idpCrypto: cryptoBox)
        let originalChallenge = try! IDPChallenge(
            challenge: JWT(header: JWT.Header(), payload: IDPChallenge.Claim())
        )
        let challengeSession = IDPChallengeSession(
            challenge: originalChallenge,
            verifierCode: "verifier",
            state: "state",
            nonce: "5557577A7576615347" // nonce must be equal to the one in idToken
        )
        sut.exchange(token: exchangeToken, challengeSession: challengeSession)
            .test(expectations: { token in

                expect(token) == expectedToken
            })

        expect(idpClientMock.exchange_Called) == true
        expect(idpClientMock.exchange_ReceivedArguments?.token) == exchangeToken
        expect(idpClientMock.exchange_ReceivedArguments?.verifier) == challengeSession.verifierCode

        expect(receivedTokens.count) == 2 // one for subscription one for actual test
        expect(receivedTokens).to(equal([nil, expectedToken]))

        sut.autoRefreshedToken.first().test(expectations: { token in
            expect(token).toNot(beNil())
        })
        issuedDate = issuedDate.advanced(by: TimeInterval(expirationInterval + 1))
        sut.autoRefreshedToken.first().test(expectations: { token in
            expect(token).to(beNil())
        })

        tokenSubscriber.cancel()
    }

    func testUpdateWithSSOToken() {
        let idpClientMock = IDPClientMock()
        // Date provider provides a date that should validate the DiscoveryDocument when reading from IDPStorage
        let issuedDate = dateFormatter.date(from: "2021-03-16 14:42:03.0000+0000")!
        let discoveryDocument = self.discoveryDocument(createdOn: issuedDate.addingTimeInterval(TimeInterval(-10)))
        idpClientMock.discoveryDocument = discoveryDocument

        // 1 second before token expiration
        var dateProviderDate = issuedDate.addingTimeInterval(TimeInterval(-1))
        let dateProvider: TimeProvider = {
            dateProviderDate
        }

        let schedulers = TestSchedulers()
        let expirationInterval = 300
        let tokenPayload = TokenPayload(
            accessToken: encryptedTokenPayload.accessToken,
            expiresIn: expirationInterval,
            idToken: encryptedTokenPayload.idToken,
            ssoToken: "refreshed-sso-token",
            tokenType: "Bearer"
        )

        let expectedToken = IDPToken(
            accessToken: decryptedTokenPayload.accessToken,
            expires: issuedDate.addingTimeInterval(TimeInterval(expirationInterval * 2)),
            idToken: decryptedTokenPayload.idToken,
            ssoToken: "refreshed-sso-token",
            tokenType: "Bearer"
        )

        let initialToken = IDPToken(
            accessToken: "initial-access-token",
            expires: issuedDate,
            idToken: decryptedTokenPayload.idToken,
            ssoToken: "sso-token",
            tokenType: "Bearer"
        )

        // Set initial (valid) token
        let storage = MemStorage()
        storage.set(discovery: discoveryDocument)
        storage.set(token: initialToken)

        idpClientMock.requestChallenge_Publisher = Just(challengeDocument)
            .setFailureType(to: IDPError.self)
            .eraseToAnyPublisher()
        idpClientMock.exchange_Publisher = Just(tokenPayload).setFailureType(to: IDPError.self).eraseToAnyPublisher()
        idpClientMock.ssoLogin_Publisher =
            Just(IDPExchangeToken(code: "SUPER_SECRET_AUTH_CODE", sso: "refreshed-sso-token", state: "state"))
                .setFailureType(to: IDPError.self)
                .eraseToAnyPublisher()

        var receivedTokens: [IDPToken?] = []
        let tokenSubscriber = storage.token
            .sink(receiveValue: { tokenValue in
                receivedTokens.append(tokenValue)
            })

        let sut = DefaultIDPSession(
            client: idpClientMock,
            storage: storage,
            schedulers: schedulers,
            trustStoreSession: trustStoreSessionMock,
            time: dateProvider,
            idpCrypto: cryptoBox // the crypto box used is the one used to encrypt the example data
        )

        expect(idpClientMock.exchange_Called) == false

        sut.autoRefreshedToken.first().test(expectations: { token in
            expect(token).toNot(beNil())
        })
        // advancing invalidates the initialToken, as the expirationdate is hit
        dateProviderDate = dateProviderDate.advanced(by: TimeInterval(expirationInterval + 1))
        sut.autoRefreshedToken.first().test(expectations: { token in
            expect(token).to(equal(expectedToken))
        })

        expect(idpClientMock.ssoLogin_Called) == true
        expect(idpClientMock.exchange_Called) == true

        expect(receivedTokens.count) == 2
        expect(receivedTokens).to(equal([initialToken, expectedToken]))

        tokenSubscriber.cancel()
    }

    func testPair() throws {
        let idpClientMock = IDPClientMock()
        // Date provider provides a date that should validate the DiscoveryDocument when reading from IDPStorage
        let issuedDate = dateFormatter.date(from: "2021-03-16 14:42:03.0000+0000")!
        let discoveryDocument = self.discoveryDocument(createdOn: issuedDate.addingTimeInterval(TimeInterval(-10)))

        idpClientMock.discoveryDocument = discoveryDocument

        // 1 second before token expiration
        let dateProviderDate = issuedDate.addingTimeInterval(TimeInterval(-1))
        let dateProvider: TimeProvider = {
            dateProviderDate
        }

        let schedulers = TestSchedulers()

        let initialToken = IDPToken(
            // swiftlint:disable:next line_length
            accessToken: "eyJhbGciOiJCUDI1NlIxIiwidHlwIjoiYXQrSldUIiwia2lkIjoicHVrX2lkcF9zaWcifQ.eyJzdWIiOiJRWFkzUUx2dDhnX09BdVZkZldOM2xyVjBhNThISzRhMU1rSWJ2YlpkQm9BIiwicHJvZmVzc2lvbk9JRCI6IjEuMi4yNzYuMC43Ni40LjQ5Iiwib3JnYW5pemF0aW9uTmFtZSI6IlRlc3QgR0tWLVNWTk9ULVZBTElEIiwiaWROdW1tZXIiOiJYMTEwNDQzODc0IiwiYW1yIjpbIm1mYSIsInNjIiwicGluIl0sImlzcyI6Imh0dHBzOi8vaWRwLmRldi5nZW1hdGlrLnNvbHV0aW9ucyIsImdpdmVuX25hbWUiOiJIZWlueiBIaWxsYmVydCIsImNsaWVudF9pZCI6ImVSZXplcHRBcHAiLCJhY3IiOiJnZW1hdGlrLWVoZWFsdGgtbG9hLWhpZ2giLCJhdWQiOiJodHRwczovL2VycC10ZXN0LnplbnRyYWwuZXJwLnNwbGl0ZG5zLnRpLWRpZW5zdGUuZGUvIiwiYXpwIjoiZVJlemVwdEFwcCIsInNjb3BlIjoiZS1yZXplcHQgb3BlbmlkIiwiYXV0aF90aW1lIjoxNjE5NTE2OTk0LCJleHAiOjE2MTk1MTcyOTQsImZhbWlseV9uYW1lIjoiQ8O2cmRlcyIsImlhdCI6MTYxOTUxNjk5NCwianRpIjoiYjUzYTIwYzFmMzM1MTBlOCJ9.E9K6Wsjyxe-udXWgkk-pk6esZd2rw6UP5Ang_KV8-eBd0PvW663I-zcIcPVds2H939wBoRnPAzXmvipxxdnHPg",
            expires: issuedDate,
            idToken: decryptedTokenPayload.idToken,
            ssoToken: "sso-token",
            tokenType: "Bearer"
        )

        let storage = MemStorage()
        storage.set(discovery: discoveryDocument)

        let sut = DefaultIDPSession(
            client: idpClientMock,
            storage: storage,
            schedulers: schedulers,
            trustStoreSession: trustStoreSessionMock,
            time: dateProvider,
            idpCrypto: cryptoBox // the crypto box used is the one used to encrypt the example data
        )

        let deviceType = RegistrationData.DeviceInformation.DeviceType(
            product: "product",
            model: "model",
            os: "os",
            osVersion: "osVersion",
            manufacturer: "manufacturer"
        )

        let deviceInformation = RegistrationData.DeviceInformation(
            name: "name",
            deviceType: deviceType
        )

        let registrationData = RegistrationData(
            authCert: "DummyCert",
            signedParingData: "DummySignedParingData",
            deviceInformation: deviceInformation
        )

        let pairingEntry = PairingEntry(
            name: "PairingEntryName",
            signedPairingData: "DummySignedParingData",
            creationTime: Date()
        )

        idpClientMock.registerDevice_Publisher =
            Just(pairingEntry)
            .setFailureType(to: IDPError.self)
            .eraseToAnyPublisher()

        sut.pairDevice(with: registrationData, token: initialToken).test(
            failure: { error in
                fail("Received unexpected error '\(error)'")
            },
            expectations: { entry in
                expect(entry.name).to(equal("PairingEntryName"))
                expect(entry).to(equal(pairingEntry))
            }
        )

        let (_, _, resultDD) = idpClientMock.registerDevice_ReceivedArguments!

        expect(resultDD).to(equal(discoveryDocument))
    }

    func testAltVerify() throws {
        let idpClientMock = IDPClientMock()
        // Date provider provides a date that should validate the DiscoveryDocument when reading from IDPStorage
        let issuedDate = dateFormatter.date(from: "2021-03-16 14:42:03.0000+0000")!
        let discoveryDocument = self.discoveryDocument(createdOn: issuedDate.addingTimeInterval(TimeInterval(-10)))
        idpClientMock.discoveryDocument = discoveryDocument

        // 1 second before token expiration
        let dateProviderDate = issuedDate.addingTimeInterval(TimeInterval(-1))
        let dateProvider: TimeProvider = {
            dateProviderDate
        }

        let schedulers = TestSchedulers()

        let storage = MemStorage()
        storage.set(discovery: discoveryDocument)

        let sut = DefaultIDPSession(
            client: idpClientMock,
            storage: storage,
            schedulers: schedulers,
            trustStoreSession: trustStoreSessionMock,
            time: dateProvider,
            idpCrypto: cryptoBox // the crypto box used is the one used to encrypt the example data
        )

        let deviceType = RegistrationData.DeviceInformation.DeviceType(
            product: "product",
            model: "model",
            os: "os",
            osVersion: "osVersion",
            manufacturer: "manufacturer"
        )

        let deviceInformation = RegistrationData.DeviceInformation(
            name: "name",
            deviceType: deviceType
        )

        let idpExchangeToken = IDPExchangeToken(
            code: "exchange-token",
            sso: "sso-token",
            state: "1234567890"
        )

        idpClientMock.altVerify_Publisher =
            Just(idpExchangeToken)
            .setFailureType(to: IDPError.self)
            .eraseToAnyPublisher()

        let challenge = try! IDPChallenge(
            challenge: JWT(header: JWT.Header(), payload: IDPChallenge.Claim())
        )
        let idpChallengeSession = IDPChallengeSession(challenge: challenge,
                                                      verifierCode: "verifier",
                                                      state: "1234567890",
                                                      nonce: "1234567890")

        let authenticationData = AuthenticationData(
            authCert: "cert",
            challengeToken: "challengeToken",
            deviceInformation: deviceInformation,
            amr: ["amr"],
            keyIdentifier: "keyIdentifier",
            exp: 0
        )
        let header = JWT.Header(alg: .secp256r1)

        let jwt = try JWT(header: header, payload: authenticationData)

        let signedAuthenticationData = SignedAuthenticationData(
            originalChallenge: idpChallengeSession,
            signedAuthenticationData: jwt
        )

        sut.altVerify(signedAuthenticationData).test(
            failure: { error in
                fail("Received unexpected error '\(error)'")
            }, expectations: { token in
                expect(token).to(equal(idpExchangeToken))
            }
        )

        let (_, resultDD) = idpClientMock.altVerify_ReceivedArguments!

        expect(resultDD).to(equal(discoveryDocument))
    }
}

extension String {
    func encodeBase64urlsafe() -> Data {
        Base64.urlSafe.encode(data: data(using: .utf8) ?? Data(), with: .none)
    }
}
