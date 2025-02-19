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

import ComposableArchitecture
import eRpKit
import SwiftUI

struct RedeemSuccessView: View {
    let store: RedeemSuccessDomain.Store

    var body: some View {
        WithViewStore(store) { viewStore in
            VStack(spacing: 16) {
                if let url = videoURLforSource(viewStore.state.redeemOption) {
                    LoopingVideoPlayerContainerView(withURL: url)
                        .frame(width: 300, height: 300)
                        .clipShape(Circle())
                        .padding(.vertical, 8)
                }

                Text(titlelForSource(viewStore.state.redeemOption))
                    .font(Font.title3.bold())

                ContentView(option: viewStore.state.redeemOption)

                Spacer()

                LoadingPrimaryButton(text: L10n.rdmSccBtnReturnToMain,
                                     isLoading: false) {
                    viewStore.send(.close)
                }
                .accessibility(identifier: A11y.pharmacyRedeem.phaRedeemBtnRedeem)
            }
            .navigationBarBackButtonHidden(true)
            .navigationTitle(L10n.phaSuccessRedeemTitle)
            .navigationBarTitleDisplayMode(.inline)
            .padding()
        }
    }

    private func videoURLforSource(_ option: RedeemOption) -> URL? {
        var videoName = ""

        switch option {
        case .onPremise:
            videoName = "animation_reservierung"
        case .delivery:
            videoName = "animation_botendienst"
        case .shipment:
            videoName = "animation_versand"
        }

        guard let bundle = Bundle.main.path(forResource: videoName,
                                            ofType: "mp4") else {
            return nil
        }

        return URL(fileURLWithPath: bundle)
    }

    private func titlelForSource(_ option: RedeemOption) -> LocalizedStringKey {
        switch option {
        case .onPremise:
            return L10n.rdmSccTxtOnpremiseTitle
        case .delivery:
            return L10n.rdmSccTxtDeliveryTitle
        case .shipment:
            return L10n.rdmSccTxtShipmentTitle
        }
    }

    private struct ContentView: View {
        let option: RedeemOption
        var body: some View {
            switch option {
            case .delivery:
                Text(L10n.rdmSccTxtDeliveryContent)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            case .onPremise:
                Text(L10n.rdmSccTxtOnpremiseContent)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            case .shipment:
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .top, spacing: 16) {
                        Image(systemName: SFSymbolName.numbers1circleFill)
                            .foregroundColor(Colors.primary600)
                            .font(Font.title3.bold())
                        Text(L10n.rdmSccTxtShipmentContent1)
                    }
                    HStack(alignment: .top, spacing: 16) {
                        Image(systemName: SFSymbolName.numbers2circleFill)
                            .foregroundColor(Colors.primary600)
                            .font(Font.title3.bold())

                        Text(L10n.rdmSccTxtShipmentContent2)
                    }
                    HStack(alignment: .top, spacing: 16) {
                        Image(systemName: SFSymbolName.numbers3circleFill)
                            .foregroundColor(Colors.primary600)
                            .font(Font.title3.bold())
                        Text(L10n.rdmSccTxtShipmentContent3)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct RedeemSuccessView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            NavigationView {
                RedeemSuccessView(store: RedeemSuccessDomain.Dummies.store(with: .shipment))
            }

            NavigationView {
                RedeemSuccessView(store: RedeemSuccessDomain.Dummies.store(with: .shipment))
                    .preferredColorScheme(.dark)
            }
            .environment(\.sizeCategory, .extraExtraExtraLarge)

            NavigationView {
                RedeemSuccessView(store: RedeemSuccessDomain.Dummies.store(with: .delivery))
            }
            NavigationView {
                RedeemSuccessView(store: RedeemSuccessDomain.Dummies.store(with: .delivery))
                    .preferredColorScheme(.dark)
            }

            NavigationView {
                RedeemSuccessView(store: RedeemSuccessDomain.Dummies.store(with: .onPremise))
            }
            NavigationView {
                RedeemSuccessView(store: RedeemSuccessDomain.Dummies.store(with: .onPremise))
                    .preferredColorScheme(.dark)
            }
        }
    }
}
