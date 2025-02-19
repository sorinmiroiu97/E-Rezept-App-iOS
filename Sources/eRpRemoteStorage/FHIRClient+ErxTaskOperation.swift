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
import eRpKit
import FHIRClient
import Foundation
import HTTPClient
import ModelsR4

extension FHIRClient {
    /// Convenience function for requesting a certain task by ID
    ///
    /// - Parameters:
    ///   - id: The ID of the task to be requested
    ///   - accessCode: code to access the given `id` or nil when not required due to (previous|other) authorization
    /// - Returns: `AnyPublisher` that emits the task or nil when not found
    public func fetchTask(by id: ErxTask.ID, // swiftlint:disable:this identifier_name
                          accessCode: String?) -> AnyPublisher<ErxTask?, FHIRClient.Error> {
        let handler = DefaultFHIRResponseHandler { (fhirResponse: FHIRClient.Response) -> ErxTask? in
            let decoder = JSONDecoder()
            let resource: ModelsR4.Bundle
            do {
                resource = try decoder.decode(ModelsR4.Bundle.self, from: fhirResponse.body)
            } catch {
                throw Error.decoding(error)
            }
            return try resource.parseErxTasks().first
        }

        return execute(operation: ErxTaskFHIROperation.taskBy(id: id, accessCode: accessCode, handler: handler))
    }

    /// Convenience function for requesting all task ids
    ///
    /// - Note: the simplifier (and the gematik specification) documentation is not clear as how to handle multiple
    ///         tasks in one bundle/requests
    ///
    /// - Returns: `AnyPublisher` that emits the ids for the found  tasks
    public func fetchAllTaskIDs() -> AnyPublisher<[String], FHIRClient.Error> {
        let handler = DefaultFHIRResponseHandler { (fhirResponse: FHIRClient.Response) -> [String] in
            let decoder = JSONDecoder()

            do {
                let resource = try decoder.decode(ModelsR4.Bundle.self, from: fhirResponse.body)
                return try resource.parseErxTaskIDs()
            } catch {
                throw Error.decoding(error)
            }
        }

        return execute(operation: ErxTaskFHIROperation.allTasks(handler: handler))
    }

    /// Convenience function for deleting a task
    ///
    /// - Parameters:
    ///   - id: The ID of the task to be requested
    ///   - accessCode: code to access the given `id` or nil when not required due to (previous|other) authorization
    /// - Returns: `AnyPublisher` that emits the task or nil when not found
    public func deleteTask(by id: ErxTask.ID, // swiftlint:disable:this identifier_name
                           accessCode: String?) -> AnyPublisher<Bool, FHIRClient.Error> {
        let handler = DefaultFHIRResponseHandler { (fhirResponse: FHIRClient.Response) -> Bool in
            let decoder = JSONDecoder()
            let resource: ModelsR4.Bundle
            if fhirResponse.status.isNoContent {
                // Successful delete is supposed to produces return code 204 and an empty body.
                // So we actually do not need to parse anything
                return true
            } else {
                do {
                    resource = try decoder.decode(ModelsR4.Bundle.self, from: fhirResponse.body)
                } catch {
                    throw Error.decoding(error)
                }
                return try resource.parseErxTasks().isEmpty
            }
        }

        return execute(operation: ErxTaskFHIROperation.deleteTask(id: id, accessCode: accessCode, handler: handler))
            .tryCatch { error -> AnyPublisher<Bool, FHIRClient.Error> in
                // When the server responds with 404 we handle this as a success case for
                // deletion. Obviously the server does not know the task which means we can
                // savely delete it locally as well. Hence we return true so the task is
                // subsequently also deleted locally on the device. Also see comments in ticket ERA-800.
                if case let FHIRClient.Error.httpError(HTTPError.httpError(wrappedHttpError)) = error,
                   wrappedHttpError.code.rawValue == 404 {
                    return Just(true).setFailureType(to: FHIRClient.Error.self).eraseToAnyPublisher()
                }
                throw error
            }
            .mapError { $0 as? FHIRClient.Error ?? FHIRClient.Error.internalError("Uknown error") }
            .eraseToAnyPublisher()
    }

    /// Convenience function for requesting a certain audit event by ID
    ///
    /// - Parameters:
    ///   - id: The ID of the audit event to be requested
    ///   - accessCode: code to access the given `id` or nil when not required due to (previous|other) authorization
    /// - Returns: `AnyPublisher` that emits the audit event or nil when not found
    public func fetchAuditEvent(by id: ErxAuditEvent.ID) -> AnyPublisher<ErxAuditEvent?, FHIRClient.Error> {
        // swiftlint:disable:previous identifier_name
        let handler = DefaultFHIRResponseHandler { (fhirResponse: FHIRClient.Response) -> ErxAuditEvent? in
            let decoder = JSONDecoder()
            let resource: ModelsR4.Bundle
            do {
                resource = try decoder.decode(ModelsR4.Bundle.self, from: fhirResponse.body)
            } catch {
                throw Error.decoding(error)
            }
            return try resource.parseErxAuditEvents().first
        }

        return execute(operation: ErxTaskFHIROperation.auditEventBy(id: id, handler: handler))
    }

    /// Convenience function for requesting audit events
    ///
    /// - Returns: `AnyPublisher` that emits the audit events
    public func fetchAllAuditEvents(after referenceDate: String? = nil,
                                    for locale: String? = nil) -> AnyPublisher<[ErxAuditEvent], FHIRClient.Error> {
        let handler = DefaultFHIRResponseHandler { (fhirResponse: FHIRClient.Response) -> [ErxAuditEvent] in
            let decoder = JSONDecoder()

            do {
                let resource = try decoder.decode(ModelsR4.Bundle.self, from: fhirResponse.body)
                return try resource.parseErxAuditEvents()
            } catch {
                throw Error.decoding(error)
            }
        }

        return execute(operation: ErxTaskFHIROperation.auditEvents(referenceDate: referenceDate,
                                                                   language: locale,
                                                                   handler: handler))
    }

    /// Convenience function for redeeming an `ErxTask` in a pharmacy
    /// - Parameter order: The informations relevant for placing the order
    /// - Returns: `true` if the server responds without error and parsing has been successful, otherwise  error
    public func redeem(order: ErxTaskOrder) -> AnyPublisher<Bool, FHIRClient.Error> {
        let handler = DefaultFHIRResponseHandler { (fhirResponse: FHIRClient.Response) -> Bool in
            let decoder = JSONDecoder()
            do {
                _ = try decoder.decode(ModelsR4.Communication.self, from: fhirResponse.body)
            } catch {
                throw Error.decoding(error)
            }

            return true
        }

        return execute(operation: ErxTaskFHIROperation.redeem(order: order, handler: handler))
    }

    /// Requests all communication Resources for the logged in user
    /// - Returns: Array of all loaded communication resources
    public func communicationResources() -> AnyPublisher<[ErxTask.Communication], FHIRClient.Error> {
        let handler = DefaultFHIRResponseHandler { (fhirResponse: FHIRClient.Response) -> [ErxTask.Communication] in
            let decoder = JSONDecoder()
            do {
                let resource = try decoder.decode(ModelsR4.Bundle.self, from: fhirResponse.body)
                return try resource.parseErxTaskCommunications()
            } catch {
                throw Error.decoding(error)
            }
        }

        return execute(operation: ErxTaskFHIROperation.communicationResource(handler: handler))
    }
}
