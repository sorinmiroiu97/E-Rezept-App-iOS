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
import LocalAuthentication

// swiftlint:disable:next type_name
struct BiometricsAuthenticationChallengeProvider: AuthenticationChallengeProvider {
    func startAuthenticationChallenge() -> AnyPublisher<AppAuthenticationBiometricsDomain.AuthenticationResult, Never> {
        Deferred {
            Future { promise in
                startAuthenticationChallenge {
                    promise(.success($0))
                }
            }
        }
        .eraseToAnyPublisher()
    }

    private func startAuthenticationChallenge(completion: @escaping (AppAuthenticationBiometricsDomain
        .AuthenticationResult) -> Void) {
        var error: NSError?
        let authenticationContext = LAContext()

        guard authenticationContext.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics,
                                                      error: &error) else {
            completion(.failure(.cannotEvaluatePolicy(error)))
            return
        }

        var localizedReason = ""
        switch authenticationContext.biometryType {
        case .faceID:
            localizedReason = String(
                format: NSLocalizedString("auth_txt_biometrics_reason",
                                          comment: ""), "Face ID"
            )
        case .touchID:
            localizedReason = String(
                format: NSLocalizedString("auth_txt_biometrics_reason",
                                          comment: ""), "Touch ID"
            )
        default:
            break
        }

        authenticationContext.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics,
                                             localizedReason: localizedReason) { success, error in
            if success {
                completion(.success(true))
            } else {
                completion(.failure(.failedEvaluatingPolicy(error as NSError?)))
            }
        }
    }
}
