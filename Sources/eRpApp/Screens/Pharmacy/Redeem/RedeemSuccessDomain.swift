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
import eRpKit

enum RedeemSuccessDomain {
    typealias Store = ComposableArchitecture.Store<State, Action>
    typealias Reducer = ComposableArchitecture.Reducer<State, Action, Environment>

    struct State: Equatable {
        var redeemOption: RedeemOption
    }

    enum Action: Equatable {
        case close
    }

    struct Environment {}

    static let reducer = Reducer { _, action, _ in
        switch action {
        case .close:
            return .none
        }
    }
}

extension RedeemSuccessDomain {
    enum Dummies {
        static let state = State(redeemOption: .delivery)
        static let environment = Environment()
        static let store = Store(initialState: state,
                                 reducer: reducer,
                                 environment: environment)
        static func store(with option: RedeemOption) -> Store {
            Store(initialState: State(redeemOption: option),
                  reducer: reducer,
                  environment: environment)
        }
    }
}
