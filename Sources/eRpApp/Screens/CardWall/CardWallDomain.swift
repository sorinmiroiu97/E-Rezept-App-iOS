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
import ComposableArchitecture
import IDP

enum CardWallDomain {
    typealias Store = ComposableArchitecture.Store<State, Action>
    typealias Reducer = ComposableArchitecture.Reducer<State, Action, Environment>

    /// Provides an Effect that need to run whenever the state of this Domain is reset to nil
    static func cleanup<T>() -> Effect<T, Never> {
        Effect.cancel(token: CardWallReadCardDomain.Token.self)
    }

    struct State: Equatable {
        var introAlreadyDisplayed: Bool

        /// App is only usable with NFC for now
        let isNFCReady: Bool

        /// iOS Version has to be equal or greater than 14 to support the app
        let isMinimalOS14: Bool

        var isCapable: Bool {
            isNFCReady && isMinimalOS14
        }

        var canAvailable: Bool {
            can == nil
        }

        // Sub states
        var can: CardWallCANDomain.State?
        var pin: CardWallPINDomain.State
        var loginOption: CardWallLoginOptionDomain.State
        var introduction = CardWallIntroductionDomain.State()
        var readCard: CardWallReadCardDomain.State?
    }

    enum Action: Equatable {
        case close

        case canAction(action: CardWallCANDomain.Action)
        case pinAction(action: CardWallPINDomain.Action)
        case loginOption(action: CardWallLoginOptionDomain.Action)
        case introduction(action: CardWallIntroductionDomain.Action)
        case readCard(action: CardWallReadCardDomain.Action)
    }

    struct Environment {
        var schedulers: Schedulers

        var userSession: UserSession
        let signatureProvider: SecureEnclaveSignatureProvider

        let accessibilityAnnouncementReceiver: (String) -> Void
    }

    static let domainReducer = Reducer { state, action, environment in
        switch action {
        case .close:
            // handled within parent view
            return .none
        case .introduction(.close),
             .canAction(action: .close),
             .pinAction(action: .close),
             .loginOption(action: .close),
             .readCard(action: .close):
            // closing a subscreen should close the whole stack -> forward to generic `.close`
            return Effect(value: .close)
        case .pinAction(action: .advance):
            if state.pin.showNextScreen {
                state.loginOption = CardWallLoginOptionDomain.State(
                    isDemoModus: environment.userSession.isDemoMode,
                    pin: state.pin.pin
                )
            }
            return .none
        case .loginOption(action: .advance):
            if state.loginOption.showNextScreen {
                let loginOption: LoginOption
                if state.loginOption.isDemoModus {
                    loginOption = .withoutBiometry
                } else {
                    loginOption = state.loginOption.selectedLoginOption
                }
                state.readCard = CardWallReadCardDomain.State(
                    isDemoModus: environment.userSession.isDemoMode,
                    pin: state.pin.pin,
                    loginOption: loginOption,
                    output: .idle
                )
            }
            return .none
        case .readCard(action: .wrongCAN):
            if state.can == nil {
                state.can = CardWallCANDomain.State(
                    isDemoModus: false,
                    can: ""
                )
            }
            state.can?.wrongCANEntered = true
            state.can?.showNextScreen = false
            state.pin.showNextScreen = false
            return .none
        case .readCard(action: .wrongPIN):
            state.pin.wrongPinEntered = true
            state.pin.showNextScreen = false
            return .none
        case .introduction,
             .canAction,
             .pinAction,
             .loginOption,
             .readCard:
            return .none
        }
    }

    static let introductionPullbackReducer: Reducer =
        CardWallIntroductionDomain.reducer.pullback(
            state: \.introduction,
            action: /Action.introduction(action:)
        ) { environment in
            CardWallIntroductionDomain.Environment(userSession: environment.userSession)
        }

    static let canPullbackReducer: Reducer =
        CardWallCANDomain.reducer.optional().pullback(
            state: \.can,
            action: /Action.canAction(action:)
        ) { environment in
            CardWallCANDomain.Environment(userSession: environment.userSession)
        }

    static let pinPullbackReducer: Reducer =
        CardWallPINDomain.reducer.pullback(
            state: \.pin,
            action: /Action.pinAction(action:)
        ) { environment in
            CardWallPINDomain.Environment(
                userSession: environment.userSession,
                accessibilityAnnouncementReceiver: environment.accessibilityAnnouncementReceiver
            )
        }

    static let loginOptionPullbackReducer: Reducer =
        CardWallLoginOptionDomain.reducer.pullback(
            state: \.loginOption,
            action: /Action.loginOption(action:)
        ) { environment in
            CardWallLoginOptionDomain.Environment(
                userSession: environment.userSession
            )
        }

    static let readCardPullbackReducer: Reducer =
        CardWallReadCardDomain.reducer.optional().pullback(
            state: \.readCard,
            action: /Action.readCard(action:)
        ) { environment in
            CardWallReadCardDomain.Environment(
                userSession: environment.userSession,
                schedulers: environment.schedulers,
                signatureProvider: environment.signatureProvider
            )
        }

    static let reducer = Reducer.combine(
        readCardPullbackReducer,
        introductionPullbackReducer,
        canPullbackReducer,
        pinPullbackReducer,
        loginOptionPullbackReducer,
        domainReducer
    )
}

extension CardWallDomain {
    enum Dummies {
        static let state = State(
            introAlreadyDisplayed: false,
            isNFCReady: true,
            isMinimalOS14: true,
            can: CardWallCANDomain.State(isDemoModus: false, can: ""),
            pin: CardWallPINDomain.State(isDemoModus: false, pin: ""),
            loginOption: CardWallLoginOptionDomain.State(isDemoModus: false)
        )
        static let environment = Environment(schedulers: Schedulers(),
                                             userSession: AppContainer.shared.userSessionSubject,
                                             signatureProvider: DummySecureEnclaveSignatureProvider()) { _ in }
        static let store = Store(
            initialState: state,
            reducer: reducer,
            environment: environment
        )
        static func storeFor(_ state: State) -> Store {
            Store(
                initialState: state,
                reducer: reducer,
                environment: environment
            )
        }
    }
}
