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

struct SelectionCell: View {
    let text: LocalizedStringKey
    let description: LocalizedStringKey?
    let a11y: String
    var systemImage: String?
    @Binding var isOn: Bool

    var body: some View {
        Button(
            action: { isOn.toggle() },
            label: {
                HStack {
                    if let systemImage = systemImage {
                        Image(systemName: systemImage)
                            .font(Font.title.weight(.semibold))
                            .foregroundColor(Colors.primary500)
                            .padding(.trailing)
                    }

                    VStack(alignment: .leading) {
                        Text(text)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .font(.body)
                            .foregroundColor(Colors.text)

                        if let description = description {
                            Text(description)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .font(.subheadline)
                                .foregroundColor(Colors.systemLabelTertiary)
                                .fixedSize(horizontal: false,
                                           vertical: true)
                        }
                    }

                    Spacer()

                    Image(systemName: isOn ? SFSymbolName.checkmarkCircleFill : SFSymbolName.circle)
                        .resizable()
                        .frame(width: 30,
                               height: 30)
                        .foregroundColor(isOn ? Colors.primary500 : Colors.systemLabelTertiary)
                        .foregroundColor(Color(.tertiaryLabel))
                }
                .padding()
                .background(Color(.tertiarySystemBackground))
                .cornerRadius(16)
            }
        )
        .accessibility(identifier: a11y)
    }
}

struct SelectionCell_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            VStack {
                Spacer()
                SelectionCell(text: "Lorem ipsum dolor sit amet",
                              description: nil,
                              a11y: "dummy_a11y_1",
                              systemImage: SFSymbolName.cardIcon,
                              isOn: .constant(true))
                Spacer()
            }
            .background(Color.orange)

            VStack {
                Spacer()
                SelectionCell(text: "Lorem ipsum dolor sit amet",
                              description: """
                              Sed ut perspiciatis unde omnis\
                              iste natus error sit voluptatem\
                              accusantium doloremque laudantium.
                              """,
                              a11y: "dummy_a11y_2",
                              systemImage: SFSymbolName.bell,
                              isOn: .constant(false))
                Spacer()
            }
            .preferredColorScheme(.dark)
            .background(Color.orange)

            VStack {
                Spacer()
                SelectionCell(text: "Lorem ipsum dolor sit amet",
                              description: "Lorem ipsum dolor sit amet",
                              a11y: "dummy_a11y_3",
                              systemImage: SFSymbolName.exclamationMark,
                              isOn: .constant(true))
                Spacer()
            }
            .preferredColorScheme(.dark)
            .background(Color.orange)

            VStack {
                Spacer()
                SelectionCell(text: "Lorem ipsum dolor sit amet",
                              description: """
                              Sed ut perspiciatis unde omnis\
                              iste natus error sit voluptatem\
                              accusantium doloremque laudantium.
                              """,
                              a11y: "dummy_a11y_4",
                              isOn: .constant(false))
                Spacer()
            }
            .background(Color.orange)
        }
        .previewLayout(.fixed(width: 400.0,
                              height: 200.0))
    }
}
