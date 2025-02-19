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
import ComposableCoreLocation
import eRpKit
import IDP
import SwiftUI

enum PrescriptionDetailDomain: Equatable {
    typealias Store = ComposableArchitecture.Store<State, Action>
    typealias Reducer = ComposableArchitecture.Reducer<State, Action, Environment>

    /// Provides an Effect that needs to run whenever the state of this Domain is reset to nil
    static func cleanup<T>() -> Effect<T, Never> {
        Effect.cancel(token: Token.self)
    }

    enum Token: CaseIterable, Hashable {
        case cancelMatrixCodeGeneration
        case deleteErxTask
        case saveErxTask
    }

    enum LoadingImageError: Error, Equatable, LocalizedError {
        case matrixCodeGenerationFailed
    }

    struct State: Equatable {
        var erxTask: ErxTask
        var loadingState: LoadingState<UIImage, LoadingImageError> = .idle
        var alertState: AlertState<Action>?
        var isRedeemed: Bool
        var isSubstitutionReadMorePresented = false
        // pharmacy state
        var pharmacySearchState: PharmacySearchDomain.State?

        var auditEventsLastUpdated: String? {
            erxTask.auditEvents.first?.timestamp
        }

        var auditEventsErrorText: String? {
            erxTask.auditEvents.isEmpty ? NSLocalizedString("prsc_fd_txt_protocol_download_error", comment: "") : nil
        }
    }

    enum Action: Equatable {
        /// Closes the details page
        case close
        /// starts generation of data matrix code
        case loadMatrixCodeImage(screenSize: CGSize)
        /// When a new data matrix code was generated
        case matrixCodeImageReceived(LoadingState<UIImage, LoadingImageError>)
        /// Initial delete action
        case delete
        /// User has confirmed to delete task
        case confirmedDelete
        /// When user chooses to not delete
        case cancelDelete
        /// Response when deletion was executed
        case taskDeletedReceived(Result<Bool, ErxTaskRepositoryError>)
        /// Sets the `alertState` back to nil (which hides the alert)
        case alertDismissButtonTapped
        /// Responds after save
        case redeemedOnSavedReceived(Bool)
        /// Toggle medication redeem state
        case toggleRedeemPrescription
        /// Open substitution info
        case openSubstitutionInfo
        /// Dismiss substitution info
        case dismissSubstitutionInfo
        /// Show pharmacy search view
        case showPharmacySearch
        /// Child view actions for the `PharmacySearch`
        case pharmacySearch(action: PharmacySearchDomain.Action)
        /// Dismiss pharmacy search domain
        case dismissPharmacySearch
    }

    struct Environment {
        var schedulers: Schedulers
        let locationManager: LocationManager
        var taskRepositoryAccess: ErxTaskRepositoryAccess
        let matrixCodeGenerator = DefaultErxTaskMatrixCodeGenerator()
        var fhirDateFormatter: FHIRDateFormatter
    }

    static let domainReducer = Reducer { state, action, environment in

        switch action {
        case .close:
            // Note: successfull deletion is handled in parent reducer!
            return cleanup()

        // Matrix Code
        case let .loadMatrixCodeImage(screenSize):
            return environment.matrixCodeGenerator.publishedMatrixCode(
                for: [state.erxTask],
                with: environment.calcMatrixCodeSize(screenSize: screenSize)
            )
            .mapError { _ in
                LoadingImageError.matrixCodeGenerationFailed
            }
            .catchToLoadingStateEffect()
            .map(PrescriptionDetailDomain.Action.matrixCodeImageReceived)
            .cancellable(id: Token.cancelMatrixCodeGeneration, cancelInFlight: true)
            .receive(on: environment.schedulers.main)
            .eraseToEffect()

        case let .matrixCodeImageReceived(loadingState):
            state.loadingState = loadingState
            return .none

        case .alertDismissButtonTapped:
            state.alertState = nil
            return .none

        // Delete
        // [REQ:gemSpec_eRp_FdV:A_19229]
        case .delete:
            state.alertState = confirmDeleteAlertState
            return .none
        case .cancelDelete:
            state.alertState = nil
            return .none
        // [REQ:gemSpec_eRp_FdV:A_19229]
        case .confirmedDelete:
            state.alertState = nil
            return environment.taskRepositoryAccess.delete([state.erxTask])
                .first()
                .receive(on: environment.schedulers.main)
                .catchToEffect()
                .map(Action.taskDeletedReceived)
                .cancellable(id: Token.deleteErxTask)
        case let .taskDeletedReceived(.failure(fail)):
            if case ErxTaskRepositoryError.local(.delete(IDPError.tokenUnavailable)) = fail {
                // Only show error message when token is not available
                state.alertState = deleteFailedAlertState(fail.localizedDescription)
            }
            return cleanup()
        case let .taskDeletedReceived(.success(success)):
            if success {
                return Effect(value: .close)
            }
            return .none

        // Redeem
        case .toggleRedeemPrescription:
            state.isRedeemed.toggle()
            if state.isRedeemed {
                state.erxTask.redeemedOn = environment.fhirDateFormatter.string(from: Date())
            } else {
                state.erxTask.redeemedOn = nil
            }
            return environment.saveErxTasks(erxTasks: [state.erxTask])
        case let .redeemedOnSavedReceived(success):
            if !success {
                state.isRedeemed.toggle()
            }
            return .none
        case .openSubstitutionInfo:
            state.isSubstitutionReadMorePresented = true
            return .none
        case .dismissSubstitutionInfo:
            state.isSubstitutionReadMorePresented = false
            return .none

        // Pharmacy
        case .showPharmacySearch:
            state.pharmacySearchState = PharmacySearchDomain.State(
                erxTasks: [state.erxTask],
                pharmacies: [],
                locationHintState: environment.shouldPresentLocationHint
            )
            return .none
        case .dismissPharmacySearch, .pharmacySearch(action: .close):
            state.pharmacySearchState = nil
            return PrescriptionDetailDomain.cleanup()
        case .pharmacySearch(action:):
            return .none
        }
    }

    static let reducer: Reducer = .combine(
        pharmacySearchPullbackReducer,
        domainReducer
    )

    static let pharmacySearchPullbackReducer: Reducer =
        PharmacySearchDomain.reducer.optional().pullback(
            state: \.pharmacySearchState,
            action: /PrescriptionDetailDomain.Action.pharmacySearch(action:)
        ) { environment in
            PharmacySearchDomain.Environment(
                schedulers: environment.schedulers,
                pharmacyRepository: AppContainer.shared.userSessionSubject.pharmacyRepository,
                locationManager: .live,
                fhirDateFormatter: environment.fhirDateFormatter,
                openHoursCalculator: PharmacyOpenHoursCalculator(),
                referenceDateForOpenHours: nil
            )
        }

    static var confirmDeleteAlertState: AlertState<Action> = {
        AlertState<Action>(
            title: TextState(L10n.dtlTxtDeleteAlertTitle),
            message: TextState(L10n.dtlTxtDeleteAlertMessage),
            primaryButton: .destructive(TextState(L10n.dtlTxtDeleteYes), send: .confirmedDelete),
            secondaryButton: .default(TextState(L10n.dtlTxtDeleteNo), send: .cancelDelete)
        )
    }()

    static func deleteFailedAlertState(_: String) -> AlertState<Action> {
        AlertState(
            title: TextState(L10n.dtlTxtDeleteMissingTokenAlertTitle),
            message: TextState(L10n.dtlTxtDeleteMissingTokenAlertMessage),
            dismissButton: .default(TextState(L10n.alertBtnOk), send: .alertDismissButtonTapped)
        )
    }
}

extension PrescriptionDetailDomain.Environment {
    // TODO: Same func is in RedeemMatrixCodeDomain. swiftlint:disable:this todo
    // Maybe find a way to have only one implementation!
    /// Will calculate the size for the matrix code based on current screen size
    func calcMatrixCodeSize(screenSize: CGSize) -> CGSize {
        let padding: CGFloat = 16
        let minScreenDimension = min(screenSize.width, screenSize.height)
        let pixelDimension = Int(minScreenDimension - 2 * padding)
        return CGSize(width: pixelDimension, height: pixelDimension)
    }

    func saveErxTasks(erxTasks: [ErxTask])
        -> Effect<PrescriptionDetailDomain.Action, Never> {
        taskRepositoryAccess.save(erxTasks)
            .first()
            .receive(on: schedulers.main)
            .replaceError(with: false)
            .map(PrescriptionDetailDomain.Action.redeemedOnSavedReceived)
            .eraseToEffect()
            .cancellable(id: PrescriptionDetailDomain.Token.saveErxTask)
    }

    var shouldPresentLocationHint: Bool {
        if locationManager.locationServicesEnabled(),
           locationManager.authorizationStatus() != CLAuthorizationStatus.notDetermined {
            return false
        } else {
            return true
        }
    }
}

extension PrescriptionDetailDomain {
    enum Dummies {
        static let demoSessionContainer = ChangeableUserSessionContainer(
            initialUserSession: DemoSessionContainer(),
            schedulers: Schedulers()
        )
        static let state = State(
            erxTask: ErxTask.Dummies.prescription,
            isRedeemed: false
        )
        static let environment = Environment(
            schedulers: Schedulers(),
            locationManager: .live,
            taskRepositoryAccess: demoSessionContainer.userSession.erxTaskRepository,
            fhirDateFormatter: FHIRDateFormatter.shared
        )
        static let store = Store(initialState: state,
                                 reducer: reducer,
                                 environment: environment)
        static func storeFor(_ state: State) -> Store {
            Store(initialState: state,
                  reducer: PrescriptionDetailDomain.Reducer.empty,
                  environment: environment)
        }
    }
}
