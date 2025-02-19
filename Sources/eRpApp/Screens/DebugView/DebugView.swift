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
import eRpKit
import SwiftUI

#if ENABLE_DEBUG_VIEW

struct DebugView: View {
    let store: DebugDomain.Store

    var body: some View {
        WithViewStore(store) { viewStore in
            List {
                EnvironmentSection(store: store)
                TutorialSection(store: store)
                CardWallSection(store: store)
                LoginSection(store: store)
                LogSection(store: store)
            }
            .listStyle(GroupedListStyle())
            .respectKeyboardInsets()
            .background(Colors.backgroundSecondary)
            .onAppear { viewStore.send(.appear) }
            .alert(isPresented: viewStore.binding(
                get: \.showAlert,
                send: DebugDomain.Action.showAlert
            )) {
                Alert(title: Text("Oh no!"),
                      message: Text(viewStore.alertText ?? "Unknown"),
                      dismissButton: .default(Text("Ok")))
            }
        }.navigationTitle("Debug Settings")
    }
}

extension DebugView {
    // MARK: - screen related view

    private struct ResetButton: View {
        let text: String
        let action: () -> Void

        var body: some View {
                Button(text, action: action)
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
        }
    }

    private struct TutorialSection: View {
        let store: DebugDomain.Store

        var body: some View {
            WithViewStore(store) { viewStore in
                Section(header: Text("Tutorial/Onboarding")) {
                    VStack {
                        Toggle("Hide Onboarding", isOn: viewStore.binding(
                            get: \.hideOnboarding,
                            send: DebugDomain.Action.hideOnboardingToggleTapped
                        ))
                        FootnoteView(text: "Intro is only displayed once. Needs App restart.", a11y: "dummy_a11y_l")
                    }
                    DebugView.ResetButton(text: "Reset hint events") {
                        viewStore.send(.resetHintEvents)
                    }
                    Toggle("Tracking OptOut",
                           isOn: viewStore.binding(
                               get: { state in state.trackingOptOut },
                               send: DebugDomain.Action.toggleTrackingTapped
                           ))
                }
            }
        }
    }

    private struct CardWallSection: View {
        let store: DebugDomain.Store

        var body: some View {
            WithViewStore(store) { viewStore in
                Section(header: Text("Cardwall")) {
                    VStack {
                        Toggle("Hide Intro",
                               isOn: viewStore.binding(
                                   get: \.hideCardWallIntro,
                                   send: DebugDomain.Action.hideCardWallIntroToggleTapped
                               ))
                        FootnoteView(
                            text: "CardWall Intro is only displayed until accepted once.",
                            a11y: "dummy_a11y_e"
                        )
                            .font(.subheadline)
                    }
                    DebugView.ResetButton(text: "Reset CAN") {
                        viewStore.send(.resetCanButtonTapped)
                    }
                    DebugView.ResetButton(text: "reset eGK Certificate") {
                        viewStore.send(.resetEGKAuthCertButtonTapped)
                    }
                    Toggle("Fake Device Capabilities",
                           isOn: viewStore.binding(
                               get: \.useDebugDeviceCapabilities,
                               send: DebugDomain.Action.useDebugDeviceCapabilitiesToggleTapped
                           )
                           .animation())
                    if viewStore.useDebugDeviceCapabilities {
                        VStack {
                            Toggle("NFC ready", isOn: viewStore.binding(
                                get: \.isNFCReady,
                                send: DebugDomain.Action.nfcReadyToggleTapped
                            ))
                            Toggle("iOS 14", isOn: viewStore.binding(
                                get: \.isMinimumOS14,
                                send: DebugDomain.Action.isMinimumOS14ToggleTapped
                            ))
                        }
                        .padding(.leading, 16)
                    }
                }
            }
        }
    }

    private struct LoginSection: View {
        @Injected(\.fhirDateFormatter) var dateFormatter: FHIRDateFormatter
        let store: DebugDomain.Store

        var body: some View {
            WithViewStore(store) { viewStore in
                Section(header: Text("Login State")) {
                    HStack {
                        Text("Logged in:")
                        if viewStore.isAuthenticated ?? false {
                            Text("YES").bold().foregroundColor(.green)
                        } else {
                            Text("NO").bold().foregroundColor(.red)
                        }
                        Spacer()
                        Button("Logout") {
                            viewStore.send(.logoutButtonTapped)
                        }
                        .disabled(!(viewStore.isAuthenticated ?? false))
                        .foregroundColor((viewStore.isAuthenticated ?? false) ? .red : .gray)
                    }

                    SectionView(text: "Manual Login with Token:", a11y: "dummy_a11y_i")
                    TextEditor(text: viewStore.binding(
                        get: \.accessCodeText,
                        send: DebugDomain.Action.accessCodeTextReceived
                    ))
                    .frame(minHeight: 100, maxHeight: 100)
                    .background(Color(.systemGray5))
                    .foregroundColor(Colors.systemLabel)
                    .keyboardType(.default)
                    .disableAutocorrection(true)
                    FootnoteView(text: "Initial access token only for internal IDP", a11y: "")

                    Button("Login") {
                        withAnimation {
                            UIApplication.shared.dismissKeyboard()
                            viewStore.send(.setAccessCodeTextButtonTapped)
                        }
                    }
                    .foregroundColor((viewStore.isAuthenticated ?? false) ? .gray : .green)
                    .frame(maxWidth: .infinity)
                    .foregroundColor(.green)

                    SectionView(text: "Current access token", a11y: "dummy_a11y_i")
                    Text(viewStore.token?.accessToken ?? "*** No valid token available ***")
                        .contextMenu(ContextMenu {
                            Button("Copy") {
                                UIPasteboard.general.string = viewStore.token?.accessToken
                            }
                        })
                        .animation(.easeInOut)
                        .padding()
                        .frame(maxWidth: .infinity, minHeight: 0, maxHeight: 100)
                        .foregroundColor(Colors.systemGray)
                        .background(Color(.systemGray5))
                    if let date = viewStore.token?.expires,
                       let expires = dateFormatter.string(from: date) {
                        FootnoteView(
                            text: "Access token is valid until \(expires). Token can be copied with long touch.",
                            a11y: "dummy_a11y_i"
                        )
                    } else {
                        FootnoteView(text: "No valid access token available", a11y: "dummy_a11y_i")
                    }
                }
            }
        }
    }

    private struct LogSection: View {
        let store: DebugDomain.Store

        var body: some View {
            Section(header: Text("Login State")) {
                WithViewStore(store) { _ in
                    NavigationLink("Logs", destination: DebugLogsView(
                        store: store.scope(
                            state: \.logState,
                            action: DebugDomain.Action.logAction
                        )
                    ))
                }
            }
        }
    }

    private struct TechDetail: View {
        let text: LocalizedStringKey
        let value: String

        init(_ text: LocalizedStringKey, value: String) {
            self.text = text
            self.value = value
        }

        var body: some View {
            VStack(alignment: .leading, spacing: 4) {
                Text(text)
                Text(value).font(.system(.footnote, design: .monospaced))
            }.contextMenu {
                Button(
                    action: {
                        UIPasteboard.general.string = value
                    }, label: {
                        Label(L10n.dtlBtnCopyClipboard,
                              systemImage: SFSymbolName.copy)
                    }
                )
            }
        }
    }

    private struct EnvironmentSection: View {
        let store: DebugDomain.Store

        var body: some View {
            WithViewStore(store) { viewStore in
                Section(header: Text("Environment")) {
                    Picker("Environment",
                           selection: viewStore.binding(get: {
                            $0.selectedEnvironment?.name ?? "no selection"
                           },
                                                        send: { value in
                            DebugDomain.Action.setServerEnvironment(value)
                           })) {
                        ForEach(viewStore.availableEnvironments, id: \.id) { serverEnvironment in
                            Text(serverEnvironment.configuration.name).tag(serverEnvironment.name)
                        }
                    }

                    if let environment = viewStore.selectedEnvironment?.configuration {
                        HStack {
                            Text("Current")
                            Spacer()
                            Text(environment.name)
                        }
                        DebugView.TechDetail("IDP", value: environment.idp.absoluteString)
                        DebugView.TechDetail("FD", value: environment.erp.absoluteString)
                        DebugView.TechDetail("APO VZD", value: environment.apoVzd.absoluteString)
                    }

                    Button("Reset") {
                        viewStore.send(DebugDomain.Action.setServerEnvironment(nil))
                    }
                }
            }
        }
    }
}

struct DebugView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            DebugView(store: DebugDomain.Dummies.store)
        }
        .previewDevice("iPhone SE (2nd generation)")
    }
}

#endif
