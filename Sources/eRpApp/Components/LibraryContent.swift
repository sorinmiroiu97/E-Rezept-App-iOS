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

import SwiftUI

#if swift(>=5.3)
@available(iOS 14.0, *)
struct LibraryContent: LibraryContentProvider {
    @LibraryContentBuilder
    var views: [LibraryItem] {
        LibraryItem(PrimaryTextButton(text: "Primary Button Text", a11y: "Primary Button Text") {})
        LibraryItem(SecondaryTextButton(text: "Secondary Button Text", a11y: "") {})
        LibraryItem(TertiaryButton(text: "Tertiary Button Text") {})
        LibraryItem(TertiaryListButton(text: "Sticky Button Text", accessibilityIdentifier: "some") {})
    }
}
#endif
