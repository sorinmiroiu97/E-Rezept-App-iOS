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

@testable import eRpApp
import SnapshotTesting
import SwiftUI
import XCTest

final class RedeemViewSnapshotTests: XCTestCase {
    override func setUp() {
        super.setUp()
        diffTool = "open"
    }

    func testRedeemViewSnapshot() {
        let sut = RedeemView(store: RedeemDomain.Dummies.store)

        assertSnapshots(matching: sut, as: snapshotModiOnDevices())
        assertSnapshots(matching: sut, as: snapshotModiOnDevicesWithAccessibility())
        assertSnapshots(matching: sut, as: snapshotModiOnDevicesWithTheming())
    }

    func testRedeemMatrixCodeViewSnapshot() {
        let sut = RedeemMatrixCodeView(
            store: RedeemMatrixCodeDomain.Dummies.storeFor(
                RedeemMatrixCodeDomain.State(
                    groupedPrescription: GroupedPrescription.Dummies.twoPrescriptions,
                    loadingState: .value(UIImage(testBundleNamed: "qrcode")!)
                )
            )
        )

        assertSnapshots(matching: sut, as: snapshotModiOnDevices())
        assertSnapshots(matching: sut, as: snapshotModiOnDevicesWithAccessibility())
        assertSnapshots(matching: sut, as: snapshotModiOnDevicesWithTheming())
    }
}
