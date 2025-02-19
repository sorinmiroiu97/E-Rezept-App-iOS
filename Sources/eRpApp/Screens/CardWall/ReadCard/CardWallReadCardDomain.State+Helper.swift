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

import IDP
import SwiftUI

extension CardWallReadCardDomain.State {
    enum Error: Swift.Error {
        case idpError(IDPError)
        case inputError(InputError)
        case signChallengeError(NFCSignatureProviderError)
        case biometrieError(Swift.Error)

        enum InputError: Swift.Error {
            case missingPIN
            case missingCAN
        }
    }

    enum Output: Equatable {
        case idle
        case retrievingChallenge(StepState)
        case challengeLoaded(IDPChallengeSession)
        case signingChallenge(StepState)
        case verifying(StepState)
        case loggedIn

        var nextAction: CardWallReadCardDomain.Action {
            if self == .loggedIn {
                return .close
            }
            // Pop to correct screen if we have a card error a.k.a. wrong pin or wrong can
            if case let .signingChallenge(signingState) = self,
                case let .error(error) = signingState {
                switch error {
                case .signChallengeError(.wrongPin),
                     .inputError(.missingPIN):
                    return .wrongPIN
                case .signChallengeError(.wrongCAN),
                     .inputError(.missingCAN):
                    return .wrongCAN
                default: break
                }
            }
            if case let .challengeLoaded(challenge) = self {
                return .signChallenge(challenge)
            }
            return .getChallenge
        }

        var buttonTitle: LocalizedStringKey {
            switch self {
            case .signingChallenge(.error(.inputError(.missingCAN))),
                 .signingChallenge(.error(.signChallengeError(.wrongCAN))):
                return L10n.cdwBtnRcCorrectCan
            case .signingChallenge(.error(.inputError(.missingPIN))),
                 .signingChallenge(.error(.signChallengeError(.wrongPin))):
                return L10n.cdwBtnRcCorrectPin
            case .retrievingChallenge(.error), .signingChallenge(.error), .verifying(.error):
                return L10n.cdwBtnRcRetry
            case .retrievingChallenge(.loading), .signingChallenge(.loading), .verifying(.loading):
                return L10n.cdwBtnRcLoading
            case .loggedIn:
                return L10n.cdwBtnRcClose
            default:
                return L10n.cdwBtnRcNext
            }
        }

        var nextButtonEnabled: Bool {
            switch self {
            case .idle, // Continue with process
                 .challengeLoaded:
                return true
            case .signingChallenge(.error(.inputError(.missingCAN))),
                 .signingChallenge(.error(.inputError(.missingPIN))),
                 .signingChallenge(.error(.signChallengeError(.wrongCAN))),
                 .signingChallenge(.error(.signChallengeError(.wrongPin))):
                return true
            case .retrievingChallenge(.error), // enable button for retry
                 .verifying(.error),
                 .signingChallenge(.error):
                return true
            case .loggedIn:
                return true // close button
            case .retrievingChallenge(.loading),
                 .signingChallenge(.loading),
                 .verifying(.loading):
                return false
            }
        }

        var isLoading: Bool {
            switch self {
            case .retrievingChallenge(.loading), .signingChallenge(.loading), .verifying(.loading):
                return true
            default:
                return false
            }
        }

        var challengeProgressTileState: ProgressTile.State {
            switch self {
            case .idle:
                return .idle
            case let .retrievingChallenge(subState):
                return subState.progressTileState
            default:
                return .done
            }
        }

        var signingProgressTileState: ProgressTile.State {
            switch self {
            case .idle, .retrievingChallenge, .challengeLoaded:
                return .idle
            case let .signingChallenge(subState):
                return subState.progressTileState
            default:
                return .done
            }
        }

        var verifyProgressTileState: ProgressTile.State {
            switch self {
            case .idle, .retrievingChallenge, .challengeLoaded, .signingChallenge:
                return .idle
            case let .verifying(subState):
                return subState.progressTileState
            default:
                return .done
            }
        }

        enum StepState: Equatable {
            // swiftlint:disable:next operator_whitespace
            static func ==(
                lhs: CardWallReadCardDomain.State.Output.StepState,
                rhs: CardWallReadCardDomain.State.Output.StepState
            ) -> Bool {
                switch (lhs, rhs) {
                case (.loading, .loading),
                     (.error, .error):
                    return true
                default:
                    return false
                }
            }

            case loading
            case error(Error)

            var progressTileState: ProgressTile.State {
                switch self {
                case .loading:
                    return .loading
                case let .error(error):
                    return .error(title: error.localizedDescription, description: error.recoverySuggestion)
                }
            }
        }
    }
}

extension CardWallReadCardDomain.State.Error: CustomStringConvertible, LocalizedError {
    var description: String {
        switch self {
        case let .idpError(error):
            return "idpError: \(error.localizedDescription)"
        case let .signChallengeError(error):
            return "cardError: \(error.localizedDescription)"
        case let .inputError(error):
            return error.localizedDescription
        case let .biometrieError(error as LocalizedError):
            return error.localizedDescription
        case let .biometrieError(error):
            return "biometrie error \(error)"
        }
    }

    var errorDescription: String? {
        switch self {
        case let .idpError(error):
            return error.localizedDescription
        case let .signChallengeError(error):
            return error.localizedDescription
        case let .inputError(error):
            return error.localizedDescription
        case let .biometrieError(error as LocalizedError):
            return error.localizedDescription
        case let .biometrieError(error):
            return "biometrie error \(error)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case let .idpError(error as LocalizedError),
             let .signChallengeError(error as LocalizedError),
             let .inputError(error as LocalizedError),
             let .biometrieError(error as LocalizedError):
            return error.recoverySuggestion
        case let .biometrieError(error):
            return "biometrie error \(error)"
        }
    }
}

extension CardWallReadCardDomain.State.Error.InputError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .missingCAN:
            return NSLocalizedString("cdw_btn_rc_error_missing_can_error_description", comment: "")
        case .missingPIN:
            return NSLocalizedString("cdw_btn_rc_error_missing_pin_error_description", comment: "")
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .missingCAN:
            return NSLocalizedString("cdw_btn_rc_error_missing_can_recovery_suggestion", comment: "")
        case .missingPIN:
            return NSLocalizedString("cdw_btn_rc_error_missing_pin_recovery_suggestion", comment: "")
        }
    }
}
