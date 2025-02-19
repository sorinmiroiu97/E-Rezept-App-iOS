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
import Foundation
import ModelsR4
import Nimble
import XCTest

final class FHIRBundleTests: XCTestCase {
    func testParseErxTasks() throws {
        let gemFhirBundle: ModelsR4.Bundle = try Bundle(for: Self.self)
            .bundleFromResources(name: "FHIRExampleData.bundle")
            .decode(ModelsR4.Bundle.self,
                    from: "getTaskResponse_5e00e907-1e4f-11b2-80be-b806a73c0cd0.json")

        guard let task = try gemFhirBundle.parseErxTasks().first else {
            fail("Could not parse ModelsR4.Bundle into TaskBundle.")
            return
        }

        expect(task.id) == "5e00e907-1e4f-11b2-80be-b806a73c0cd0"
        expect(task.prescriptionId) == "160.000.711.572.601.54"
        expect(task.accessCode) == "9d6f58a2c5a89c0681f91cbd69dd666f365443e3ae114d7d9ca9162181f7d34d"
        expect(task.fullUrl).to(beNil())
        expect(task.medication?.name) == "Sumatriptan-1a Pharma 100 mg Tabletten"
        expect(task.authoredOn) == "2020-02-03T00:00:00+00:00"
        expect(task.expiresOn) == "2021-06-24"
        expect(task.author) == "Hausarztpraxis Dr. Topp-Glücklich"
        expect(task.dispenseValidityEnd).to(beNil())
        expect(task.medication?.dosageForm) == "TAB"
        expect(task.medication?.dose) == "N1"
        expect(task.medication?.pzn) == "06313728"
        expect(task.medication?.amount) == 12
        expect(task.medication?.dosageInstructions) == "1-0-1-0"
        expect(task.noctuFeeWaiver) == false
        expect(task.substitutionAllowed) == true
        expect(task.source) == .server
        expect(task.patient?.name) == "Ludger Ludger Königsstein"
        expect(task.patient?.address) == "Musterstr. 1\n10623 Berlin"
        expect(task.patient?.birthDate) == "1935-06-22"
        expect(task.patient?.phone).to(beNil())
        expect(task.patient?.status) == "1"
        expect(task.patient?.insurance) == "AOK Rheinland/Hamburg"
        expect(task.patient?.insuranceIdentifier) == "104212059"
        expect(task.practitioner?.lanr) == "838382202"
        expect(task.practitioner?.name) == "Hans Topp-Glücklich"
        expect(task.practitioner?.qualification) == "Hausarzt"
        expect(task.practitioner?.email).to(beNil())
        expect(task.practitioner?.address).to(beNil())
    }

    func testParseAuditEventsFromSamplePayload() throws {
        let gemFhirBundle: ModelsR4.Bundle = try Bundle(for: Self.self)
            .bundleFromResources(name: "FHIRExampleData.bundle")
            .decode(ModelsR4.Bundle.self,
                    from: "getAuditEventResponse_4_entries.json")

        let auditEvents = try gemFhirBundle.parseErxAuditEvents()

        expect(auditEvents.count) == 4

        expect(auditEvents[0].identifier) == "64c4f143-1de0-11b2-80eb-443cac489883"
        expect(auditEvents[0].timestamp) == "2021-04-29T16:02:39.475065591+00:00"
        expect(auditEvents[0].taskId) == "20544d02-1dd2-11b2-805e-443cac489883"

        expect(auditEvents[1].identifier) == "64c4f1af-1de0-11b2-80ec-443cac489883"
        expect(auditEvents[1].timestamp) == "2021-04-29T16:02:39.475074398+00:00"
        expect(auditEvents[1].taskId) == "23285587-1dd2-11b2-80a6-443cac489883"

        expect(auditEvents[2].identifier) == "64c4f1cc-1de0-11b2-80ed-443cac489883"
        expect(auditEvents[2].timestamp) == "2021-04-29T16:02:39.475077274+00:00"
        expect(auditEvents[2].taskId) == "234ec20e-1dd2-11b2-80aa-443cac489883"

        expect(auditEvents[3].identifier) == "64c4f1ea-1de0-11b2-80ee-443cac489883"
        expect(auditEvents[3].timestamp) == "2021-04-29T16:02:39.475080290+00:00"
        expect(auditEvents[3].taskId) == "22ff81be-1dd2-11b2-80a2-443cac489883"
    }

    func testParseErxTaskCommunicationReply() throws {
        let communicationBundle: ModelsR4.Bundle = try Bundle(for: Self.self)
            .bundleFromResources(name: "FHIRExampleData.bundle")
            .decode(ModelsR4.Bundle.self,
                    from: "erxCommunicationReplyResponse.json")

        let communications = try communicationBundle.parseErxTaskCommunications()
        expect(communications.count) == 4
        guard let first = communications.first else {
            fail("expected to have this communication")
            return
        }
        expect(first.identifier) == "9d533345-1e50-11b2-8115-dd3ddb83b539"
        expect(first.taskId) == "6550190f-1dd2-11b2-80e1-dd3ddb83b539"
        expect(first.profile) == .reply
        expect(first.timestamp) == "2021-05-26T10:59:37.098245933+00:00"
        expect(first.insuranceId) == "X234567890"
        expect(first.telematikId) == "3-09.2.S.10.743"

        // test payload parsing for all possible variations of payload
        expect(first.payloadJSON) == "{\"version\": \"1\",\"supplyOptionsType\": \"shipment\",\"info_text\": \"\"}"
    }

    func testParseErxTaskCommunicationDispReq() throws {
        let communicationBundle: ModelsR4.Bundle = try Bundle(for: Self.self)
            .bundleFromResources(name: "FHIRExampleData.bundle")
            .decode(ModelsR4.Bundle.self,
                    from: "erxCommunicationDispReqResponse.json")

        let communications = try communicationBundle.parseErxTaskCommunications()
        expect(communications.count) == 4
        guard let first = communications.first else {
            fail("expected to have this communication")
            return
        }
        expect(first.identifier) == "16d2cfc8-2023-11b2-81e1-783a425d8e87"
        expect(first.taskId) == "39c67d5b-1df3-11b2-80b4-783a425d8e87"
        expect(first.profile) == .dispReq
        expect(first.timestamp) == "2021-05-03T08:13:38.389015396+00:00"
        expect(first.insuranceId) == "X110461389"
        expect(first.telematikId) == "3-09.2.S.10.743"

        // test payload parsing for all possible variations of payload
        expect(first.payloadJSON) == "{do something}"
    }
}
