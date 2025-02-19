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

import BundleKit
import eRpKit
@testable import eRpRemoteStorage
import FHIRClient
import Foundation
import HTTPClient
import Nimble
import OHHTTPStubs
import OHHTTPStubsSwift
import XCTest

final class ErxTaskFHIRDataStoreTests: XCTestCase {
    var host: String!
    var url: URL!
    var fhirClient: FHIRClient!
    var sut: ErxTaskFHIRDataStore!

    override func setUpWithError() throws {
        try super.setUpWithError()
        host = "some-fhir-service.com"
        url = URL(string: "http://\(host ?? "")")!
        fhirClient = FHIRClient(server: url, httpClient: DefaultHTTPClient(urlSessionConfiguration: .default))
        sut = ErxTaskFHIRDataStore(fhirClient: fhirClient)
    }

    override func tearDownWithError() throws {
        fhirClient = nil
        sut = nil
        try super.tearDownWithError()
    }

	func testFetchTaskById() {
        let firstTaskResponse = load(resource: "getTaskResponse_61704e3f-1e4f-11b2-80f4-b806a73c0cd0")
		var counter = 0
		stub(condition: isHost(host) && isPath("/Task/61704e3f-1e4f-11b2-80f4-b806a73c0cd0")) { _ in
			counter += 1
			return fixture(filePath: firstTaskResponse, headers: ["Accept": "application/fhir+json"])
		}

        sut.fetchTask(by: "61704e3f-1e4f-11b2-80f4-b806a73c0cd0", accessCode: nil)
            .test(expectations: { erxTask in
                guard let erxTask = erxTask else {
                    fail("erxTask is expected to not be nil")
                    return
                }
                expect(erxTask.id) == "61704e3f-1e4f-11b2-80f4-b806a73c0cd0"
                expect(erxTask.accessCode) == "7eccd529292631f6a7cd120b57ded23062c35932cc721bfd32b08c5fb188b642"
                expect(erxTask.medication?.name).toNot(beNil())
                expect(erxTask.medication?.name) == "Sumatriptan-1a Pharma 100 mg Tabletten"
                expect(erxTask.authoredOn).toNot(beNil())
                expect(erxTask.authoredOn) == "2020-02-03T00:00:00+00:00"
                expect(erxTask.expiresOn) == "2021-06-24"
                expect(erxTask.author).toNot(beNil())
                expect(erxTask.author) == "Hausarztpraxis Dr. Topp-Glücklich"
                expect(erxTask.medication?.dosageForm).toNot(beNil())
                expect(erxTask.medication?.dosageForm) == "TAB"
                expect(erxTask.medication?.amount).toNot(beNil())
                expect(erxTask.medication?.amount) == 12
                expect(erxTask.medication?.dosageInstructions) == "1-0-1-0"
            })

		// test if sub has been called
		expect(counter) == 1
    }

	func testListAllTasks() {
		let taskIdsResponse = load(resource: "getTaskIdsWithTwoTasksResponse")
		var counter = 0
		stub(condition: isHost(host) && isPath("/Task")) { _ in
			counter += 1
			return fixture(filePath: taskIdsResponse, headers: ["Accept": "application/fhir+json"])
		}

		guard let firstTaskResponse = Bundle(for: Self.self).path(
		    forResource: "getTaskResponse_61704e3f-1e4f-11b2-80f4-b806a73c0cd0",
		    ofType: "json",
		    inDirectory: "FHIRExampleData.bundle"
		) else {
			fail("Bundle could not find resource getTaskIdsWithTwoTasksResponse")
			return
		}

		stub(condition: isHost(host) && isPath("/Task/61704e3f-1e4f-11b2-80f4-b806a73c0cd0")) { _ in
			counter += 1
			return fixture(filePath: firstTaskResponse, headers: ["Accept": "application/fhir+json"])
		}
        let secondTaskResponse = load(resource: "getTaskResponse_5e00e907-1e4f-11b2-80be-b806a73c0cd0")
        stub(condition: isHost(host) && isPath("/Task/5e00e907-1e4f-11b2-80be-b806a73c0cd0")) { _ in
			counter += 1
			return fixture(filePath: secondTaskResponse, headers: ["Accept": "application/fhir+json"])
        }
		sut.listAllTasks()
			.test(expectations: { erxTasks in
                expect(erxTasks.count).to(equal(2))
                let sortedIds = erxTasks.map(\.id).sorted()
                expect(sortedIds)
                    .to(equal(["5e00e907-1e4f-11b2-80be-b806a73c0cd0", "61704e3f-1e4f-11b2-80f4-b806a73c0cd0"]))
			})

		// test if all subs have been called
		expect(counter) == 3
	}

    func testListAllAuditEvents() {
        guard let firstTaskResponse = Bundle(for: Self.self).path(
            forResource: "getAuditEventResponse_4_entries",
            ofType: "json",
            inDirectory: "FHIRExampleData.bundle"
        ) else {
            fail("Bundle could not find resource getAuditEventResponse_4_entries")
            return
        }

        var counter = 0

        stub(condition: isHost(host) && isPath("/AuditEvent")) { _ in
            counter += 1
            return fixture(filePath: firstTaskResponse, headers: ["Accept": "application/fhir+json"])
        }

        sut.listAllAuditEvents()
            .test(expectations: { erxTasks in
                expect(erxTasks.count).to(equal(4))
                let sortedIds = erxTasks.map(\.id).sorted()
                expect(sortedIds)
                    .to(equal(["64c4f143-1de0-11b2-80eb-443cac489883",
                               "64c4f1af-1de0-11b2-80ec-443cac489883",
                               "64c4f1cc-1de0-11b2-80ed-443cac489883",
                               "64c4f1ea-1de0-11b2-80ee-443cac489883"]))
            })

        expect(counter) == 1
    }

    /// Tests a successful deletion of a task
    func testDeleteTasksSuccess() {
        let emptyResponse = load(resource: "emptyResponse")

        stub(condition: isHost(host) && pathEndsWith("$abort")) { _ in
            fixture(filePath: emptyResponse, status: 204, headers: ["Accept": "application/fhir+json"])
        }
        let erxTask = ErxTask(identifier: "1", accessCode: "12")
        sut.delete(tasks: [erxTask])
            .test(expectations: { response in
                expect(response) == true
            })
    }

    /// This tests if occuring errors are mapped to false for the result.
    func testDeleteTasksError() {
        stub(condition: isHost(host) && pathEndsWith("$abort")) { _ in
            let error = NSError(domain: self.host, code: -1, userInfo: [:])
            return HTTPStubsResponse(error: error)
        }

        let erxTask = ErxTask(identifier: "1", accessCode: "12")

        sut.delete(tasks: [erxTask])
            .test(failure: { error in
                let expectedError = ErxTaskFHIRDataStore
                    .Error.fhirClientError(.httpError(HTTPError.httpError(URLError(URLError.Code(rawValue: -1)))))
                expect(error.self) == expectedError.self
            })
    }

    func testRedeemOrderWithSuccess() {
        let redeemOrderResponse = load(resource: "redeemOrderResponse")

        var counter = 0
        stub(condition: isPath("/Communication")
                && isMethodPOST()
                && hasBody(expectedRequestBody)) { _ in
            counter += 1
            return fixture(filePath: redeemOrderResponse, headers: ["Content-Type": "application/json"])
        }

        sut.redeem(orders: [inputOrder, inputOrder])
            .test { error in
                fail("unexpected fail with error: \(error)")
            } expectations: { isSuccessful in
                expect(counter) == 2
                expect(isSuccessful).to(beTrue())
            }
    }

    func testRedeemTwoOrdersWithOneSuccessAndOneErrorToFail() {
        let expectedError = URLError(.notConnectedToInternet)
        let redeemOrderResponse = load(resource: "redeemOrderResponse")

        var counter = 0
        stub(condition: isPath("/Communication")
                && isMethodPOST()
                && hasBody(expectedRequestBody)) { _ in
            counter += 1
            if counter == 1 {
                return fixture(filePath: redeemOrderResponse, headers: ["Content-Type": "application/json"])
            } else {
                return HTTPStubsResponse(error: expectedError)
            }
        }

        sut.redeem(orders: [inputOrder, inputOrder])
            .test { error in
                expect(counter) == 2
                expect(error) == .fhirClientError(.httpError(.httpError(expectedError)))
            } expectations: { _ in
                fail("this test should rase an error instead")
            }
    }

    func testListAllCommunicationsWithSuccess() {
        let expectedResponse = load(resource: "erxCommunicationReplyResponse")
        var counter = 0

        stub(condition: isHost(host)
                && isMethodGET()
                && isPath("/Communication")) { _ in
            counter += 1
            return fixture(filePath: expectedResponse, headers: ["Accept": "application/fhir+json"])
        }

        sut.listAllCommunications(for: .reply)
            .test { error in
                fail("unexpected fail with error: \(error)")
            } expectations: { communications in
                expect(counter) == 1
                expect(communications.count) == 4
                let sortedIds = communications.map(\.identifier).sorted()
                expect(sortedIds.first) == "86aa9d40-1dd2-11b2-80e5-dd3ddb83b539"
                expect(sortedIds.last) == "c54ea762-1e50-11b2-8116-dd3ddb83b539"
            }
    }

    func testListAllCommunicationsWithFailure() {
        let expectedError = URLError(.notConnectedToInternet)

        var counter = 0
        stub(condition: isHost(host)
                && isPath("/Communication")
                && isMethodGET()) { _ in
            counter += 1
            return HTTPStubsResponse(error: expectedError)
        }

        sut.listAllCommunications(for: .reply)
            .test { error in
                expect(counter) == 1
                expect(error) == .fhirClientError(.httpError(.httpError(expectedError)))
            } expectations: { _ in
                fail("this test should rase an error instead")
            }
    }

    private var inputOrder: ErxTaskOrder = {
        let payload = ErxTaskOrder.Payload(supplyOptionsType: .shipment,
                                           name: "Graf Dracula",
                                           address: ["Schloss Bran",
                                                     "Strada General Traian Moșoiu 24",
                                                     "Bran 507025",
                                                     "Rumänien"],
                                           hint: "Nur bei Tageslicht liefern!",
                                           phone: "666 999 666")
        return ErxTaskOrder(erxTaskId: "39c67d5b-1df3-11b2-80b4-783a425d8e87",
                            accessCode: "777bea0e13cc9c42ceec14aec3ddee2263325dc2c6c699db115f58fe423607ea",
                            pharmacyTelematikId: "606358757",
                            payload: payload)
    }()

    // swiftlint:disable line_length
    private var expectedRequestBody: Data = {
        String(
            "{\"status\":\"unknown\",\"payload\":[{\"contentString\":\"{\\\"address\\\":[\\\"Schloss Bran\\\",\\\"Strada General Traian Moșoiu 24\\\",\\\"Bran 507025\\\",\\\"Rumänien\\\"],\\\"phone\\\":\\\"666 999 666\\\",\\\"supplyOptionsType\\\":\\\"shipment\\\",\\\"hint\\\":\\\"Nur bei Tageslicht liefern!\\\",\\\"name\\\":\\\"Graf Dracula\\\",\\\"version\\\":\\\"1\\\"}\"}],\"recipient\":[{\"identifier\":{\"system\":\"https:\\/\\/gematik.de\\/fhir\\/NamingSystem\\/TelematikID\",\"value\":\"606358757\"}}],\"meta\":{\"profile\":[\"https:\\/\\/gematik.de\\/fhir\\/StructureDefinition\\/ErxCommunicationDispReq\"]},\"resourceType\":\"Communication\",\"basedOn\":[{\"reference\":\"Task\\/39c67d5b-1df3-11b2-80b4-783a425d8e87\\/$accept?ac=777bea0e13cc9c42ceec14aec3ddee2263325dc2c6c699db115f58fe423607ea\"}]}"
        ).data(using: .utf8)!
    }()

    // swiftlint:enable line_length

    private func load(resource name: String) -> String {
        guard let resource = Bundle(for: Self.self).path(
            forResource: name,
            ofType: "json",
            inDirectory: "FHIRExampleData.bundle"
        ) else {
            fail("Bundle could not find resource \(name)")
            return ""
        }

        return resource
    }
}
