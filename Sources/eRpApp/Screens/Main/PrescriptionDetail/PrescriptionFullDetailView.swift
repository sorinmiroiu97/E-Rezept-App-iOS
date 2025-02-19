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
import SwiftUI
import WebKit

struct PrescriptionFullDetailView: View {
    let store: PrescriptionDetailDomain.Store

    var body: some View {
        WithViewStore(store) { viewStore in
            EmptyView()
                .sheet(isPresented: viewStore.binding(
                    get: { $0.isSubstitutionReadMorePresented },
                    send: PrescriptionDetailDomain.Action.dismissSubstitutionInfo
                )) {
                    SubstitutionInfoWebView()
                }

            ScrollView(.vertical) {
                // Noctu fee waiver hint
                if viewStore.state.erxTask.noctuFeeWaiver {
                    HintView(
                        hint: Hint<PrescriptionDetailDomain.Action>(
                            id: A11y.prescriptionDetails.prscDtlHntNoctuFeeWaiver,
                            title: NSLocalizedString("prsc_fd_txt_noctu_title", comment: ""),
                            message: NSLocalizedString("prsc_fd_txt_noctu_description", comment: ""),
                            imageName: Asset.Illustrations.pharmacistf1.name,
                            style: .neutral,
                            buttonStyle: .tertiary,
                            imageStyle: .bottomAligned
                        ),
                        textAction: nil,
                        closeAction: nil
                    )
                        .padding([.top, .horizontal])
                }

                Group {
                    // QR Code
                    VStack {
                        if let image = viewStore.loadingState.value {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .padding()
                                .background(Colors.systemColorWhite) // No darkmode to get contrast
                                .accessibility(label: Text(L10n.rphTxtMatrixcodeHint))
                                .accessibility(identifier: A18n.redeem.matrixCode.rphImgMatrixcode)
                        }
                    }
                    .frame(minWidth: 0, maxWidth: .infinity)
                    .border(Colors.separator, width: 0.5, cornerRadius: 16)
                    .padding([.top, .horizontal])

                    // Medication name
                    MedicationNameView(medicationText: viewStore.state.erxTask.medication?.name,
                                       expirationDate: uiFormattedDate(dateString: viewStore.state.erxTask.expiresOn),
                                       redeemedOnDate: uiFormattedDate(dateString: viewStore.state.erxTask.redeemedOn))

                    if viewStore.state.erxTask.redeemedOn == nil {
                        NavigateToPharmacySearchView(store: store)
                            .padding([.leading, .trailing, .bottom])
                    }

                    // Substitution hint
                    if viewStore.state.erxTask.substitutionAllowed {
                        HintView(
                            hint: Hint(
                                id: A11y.prescriptionDetails.prscDtlHntSubstitution,
                                title: NSLocalizedString("prsc_fd_txt_substitution_title", comment: ""),
                                message: NSLocalizedString("prsc_fd_txt_substitution_description", comment: ""),
                                actionText: L10n.prscFdTxtSubstitutionReadFurther,
                                action: PrescriptionDetailDomain.Action.openSubstitutionInfo,
                                imageName: Asset.Illustrations.practitionerm1.name,
                                style: .neutral,
                                buttonStyle: .tertiary,
                                imageStyle: .topAligned
                            ),
                            textAction: { viewStore.send(PrescriptionDetailDomain.Action.openSubstitutionInfo) },
                            closeAction: nil
                        )
                            .padding(.horizontal)
                    }
                }

                Group {
                    // Medication details
                    MedicationDetailsView(
                        dosageForm: localizedStringForDosageFormKey(viewStore.state.erxTask.medication?.dosageForm),
                        dose: composedDoseInfoFrom(
                            doseKey: viewStore.state.erxTask.medication?.dose,
                            amount: viewStore.state.erxTask.medication?.amount,
                            dosageKey: viewStore.state.erxTask.medication?.dosageForm
                        ),
                        pzn: viewStore.state.erxTask.medication?.pzn
                    )

                    // Dosage instructions
                    Group {
                        SectionView(
                            text: L10n.prscFdTxtDosageInstructionsTitle,
                            a11y: A18n.prescriptionDetails.prscDtlTxtMedDosageInstructions
                        )
                        HintView(
                            hint: Hint<PrescriptionDetailDomain.Action>(
                                id: A11y.prescriptionDetails.prscDtlHntDosageInstructions,
                                message: viewStore.state.erxTask.medication?.dosageInstructions ?? NSLocalizedString(
                                    "prsc_fd_txt_dosage_instructions_na",
                                    comment: ""
                                ),
                                imageName: Asset.Illustrations.practitionerf1.name,
                                style: .neutral,
                                buttonStyle: .tertiary,
                                imageStyle: .topAligned
                            ),
                            textAction: nil,
                            closeAction: nil
                        )
                    }
                    .padding([.horizontal, .top])

                    // Patient details
                    MedicationPatientView(
                        name: viewStore.state.erxTask.patient?.name,
                        address: viewStore.state.erxTask.patient?.address,
                        dateOfBirth: uiFormattedDate(dateString: viewStore.state.erxTask.patient?.birthDate),
                        phone: viewStore.state.erxTask.patient?.phone,
                        healthInsurance: viewStore.state.erxTask.patient?.insurance,
                        healthInsuranceState: viewStore.state.erxTask.patient?.status,
                        healthInsuranceNumber: viewStore.state.erxTask.patient?.insuranceIdentifier
                    )

                    // Practitioner details
                    MedicationPractitionerView(
                        name: viewStore.state.erxTask.practitioner?.name,
                        medicalSpeciality: viewStore.state.erxTask.practitioner?.qualification,
                        lanr: viewStore.state.erxTask.practitioner?.lanr
                    )

                    // Organization details
                    MedicationOrganizationView(
                        name: viewStore.state.erxTask.organization?.name,
                        address: viewStore.state.erxTask.organization?.address,
                        bsnr: viewStore.state.erxTask.organization?.identifier,
                        phone: viewStore.state.erxTask.organization?.phone,
                        email: viewStore.state.erxTask.organization?.email
                    )

                    // Work-related accident details
                    MedicationWorkAccidentView(
                        accidentDate: uiFormattedDate(dateString: viewStore.state.erxTask.workRelatedAccident?.date),
                        number: viewStore.state.erxTask.workRelatedAccident?.workPlaceIdentifier
                    )

                    MedicationProtocolView(
                        protocolEvents: viewStore.state.erxTask.auditEvents.map {
                            ($0.text, uiFormattedDateTime(dateTimeString: $0.timestamp))
                        },
                        lastUpdated: uiFormattedDate(dateString: viewStore.state.auditEventsLastUpdated),
                        errorText: viewStore.state.auditEventsErrorText
                    )

                    // Task information details
                    MedicationInfoView(codeInfos: [
                        MedicationInfoView.CodeInfo(
                            code: viewStore.state.erxTask.accessCode,
                            codeTitle: L10n.dtlTxtAccessCode
                        ),
                        MedicationInfoView.CodeInfo(
                            code: viewStore.state.erxTask.id,
                            codeTitle: L10n.dtlTxtTaskId
                        ),
                    ])
                }

                // Task delete button
                MedicationRemoveButton {
                    viewStore.send(.delete)
                }
                .padding(.top, 16)
            }
            .alert(
                self.store.scope(state: \.alertState),
                dismiss: .alertDismissButtonTapped
            )
            .onAppear {
                viewStore.send(.loadMatrixCodeImage(screenSize: UIScreen.main.bounds.size))
            }
            .navigationBarTitle(Text(L10n.prscFdTxtNavigationTitle), displayMode: .inline)
        }
    }

    private struct NavigateToPharmacySearchView: View {
        let store: PrescriptionDetailDomain.Store

        var body: some View {
            WithViewStore(store) { viewStore in
                PrimaryTextButton(
                    text: L10n.dtlBtnPharmacySearch,
                    a11y: A11y.prescriptionDetails.prscDtlHntSubstitution
                ) {
                    viewStore.send(.showPharmacySearch)
                }
                .fullScreenCover(isPresented: viewStore.binding(
                    get: { $0.pharmacySearchState != nil },
                    send: PrescriptionDetailDomain.Action.dismissPharmacySearch
                )) {
                    IfLetStore(store.scope(
                        state: { $0.pharmacySearchState },
                        action: PrescriptionDetailDomain.Action.pharmacySearch(action:)
                    )) { scopedStore in
                        NavigationView {
                            PharmacySearchView(store: scopedStore)
                        }.navigationViewStyle(StackNavigationViewStyle())
                        .accentColor(Colors.primary700)
                    }
                }
            }
        }
    }

    private func localizedStringForDosageFormKey(_ key: String?) -> String? {
        guard let key = key,
              let string = PrescriptionKBVKeyMapping.localizedStringKeyForDosageFormKey(key) else { return nil }
        return NSLocalizedString(string, comment: "")
    }

    private func composedDoseInfoFrom(doseKey: String?,
                                      amount: Decimal?,
                                      dosageKey: String?) -> String? {
        guard let doseKey = doseKey,
              let amount = amount,
              let dosageKey = dosageKey,
              let dosageString = PrescriptionKBVKeyMapping.localizedStringKeyForDosageFormKey(dosageKey)
              else { return nil }
        return "\(doseKey) \(amount) \(NSLocalizedString(dosageString, comment: ""))"
    }

    private func uiFormattedDate(dateString: String?) -> String? {
        if let dateString = dateString,
           let date = AppContainer.shared.fhirDateFormatter.date(from: dateString,
                                                                 format: .yearMonthDay) {
            return AppContainer.shared.uiDateFormatter.string(from: date)
        }
        return dateString
    }

    private func uiFormattedDateTime(dateTimeString: String?) -> String? {
        if let dateTimeString = dateTimeString,
           let dateTime = AppContainer.shared.fhirDateFormatter.date(from: dateTimeString,
                                                                     format: .yearMonthDayTimeMilliSeconds) {
            return uiDateFormatter.string(from: dateTime)
        }
        return dateTimeString
    }

    var uiDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        formatter.doesRelativeDateFormatting = true
        return formatter
    }()

    private struct SubstitutionInfoWebView: View {
        var body: some View {
            WebView()
        }

        struct WebView: UIViewRepresentable {
            let navigationController = NoJSNavigationDelegate()

            func makeUIView(context _: Context) -> WKWebView {
                let wkWebView = WKWebView()
                wkWebView.configuration.defaultWebpagePreferences.allowsContentJavaScript = false

                if let url = URL(string: NSLocalizedString("prsc_fd_txt_substitution_read_further_link", comment: "")) {
                    wkWebView.load(URLRequest(url: url))
                }
                wkWebView.navigationDelegate = navigationController
                return wkWebView
            }

            func updateUIView(_: WKWebView, context _: UIViewRepresentableContext<WebView>) {}

            class NoJSNavigationDelegate: NSObject, WKNavigationDelegate {
                func webView(_ webView: WKWebView,
                             decidePolicyFor navigationAction: WKNavigationAction,
                             preferences _: WKWebpagePreferences,
                             decisionHandler: @escaping (WKNavigationActionPolicy, WKWebpagePreferences) -> Void) {
                    guard let url = navigationAction.request.url,
                          url.scheme?.lowercased() == "https" else {
                        decisionHandler(.cancel, webView.configuration.defaultWebpagePreferences)
                        return
                    }
                    decisionHandler(.allow, webView.configuration.defaultWebpagePreferences)
                }
            }
        }
    }
}

struct PrescriptionFullDetailView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            NavigationView {
                PrescriptionFullDetailView(store: PrescriptionDetailDomain.Dummies.store)
            }.previewLayout(.fixed(width: 480, height: 4000))
            NavigationView {
                PrescriptionFullDetailView(store: PrescriptionDetailDomain.Dummies.store)
            }.previewLayout(.fixed(width: 480, height: 4000))
            .preferredColorScheme(.dark)
        }
    }
}
