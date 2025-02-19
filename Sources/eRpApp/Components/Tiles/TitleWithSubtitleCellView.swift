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

struct TitleWithSubtitleCellView: View {
    var title: String
    var subtitle: String
    var isSelected: Bool
    var imageName: String = SFSymbolName.circle
    var selectedImageName: String = SFSymbolName.checkmarkCircleFill

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(Font.body.weight(.semibold))
                        .foregroundColor(Colors.systemLabel)
                    if !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundColor(Colors.systemLabelSecondary)
                    }
                }
                Spacer()
                if isSelected {
                    Image(systemName: selectedImageName)
                        .font(Font.title3)
                        .foregroundColor(Colors.primary600)
                } else {
                    Image(systemName: imageName)
                        .font(Font.title3)
                        .foregroundColor(Colors.systemLabelTertiary)
                }
            }.padding(.vertical)
            Divider()
        }
    }
}

struct TitleWithSubtitleCellView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            TitleWithSubtitleCellView(
                title: "Pantoprazol 1A Hermes 40 mg",
                subtitle: """
                Aufgrund von Vorgaben Ihrer Krankenkasse kann Ihnen
                hierfür ein Ersatzpäparat ausgehändigt werden.
                """,
                isSelected: true
            )

            TitleWithSubtitleCellView(
                title: "Pantoprazol 1A Hermes 40 mg",
                subtitle: "",
                isSelected: false
            )
        }
    }
}
