import SdkMobileIOSNative
import SwiftUI

struct Login: View {
    var nativeSDK: NativeSDK
    @State var error: String?
    @EnvironmentObject var session: Session
    @EnvironmentObject var scrollManager: ScrollManager
    @EnvironmentObject var focusManager: FocusManager
    @EnvironmentObject var errorReporingService: ErrorReportingService

    @State private var audiences: String = ""

    public var body: some View {
        ScrollViewReader { proxy in
            GeometryReader { geometry in
                ScrollView(.vertical) {
                    VStack {
                        if let profile = session.profile {
                            Text("Authenticated: ")
                            Text(
                                profile.claims["given_name"] as? String ?? "N/A"
                            )
                            Button("Revoke") {
                                Task {
                                    try await nativeSDK.revoke()
                                }
                            }
                            Button("Logout") {
                                Task {
                                    try await nativeSDK.logout()
                                }
                            }
                        } else if session.loginInProgress {
                            LoginView(nativeSDK: nativeSDK) {
                                _,
                                screen,
                                forms,
                                layout in
                                WidgetHandler(
                                    screen: screen,
                                    forms: forms,
                                    layout: layout
                                )
                            }.padding()
                                .disabled(focusManager.isFocusDisabled)
                        } else {

                            CustomAudienceInput(audiences: $audiences)

                            Button("Login") {
                                Task {
                                    self.error = nil
                                    try? await nativeSDK.login(
                                        parameters: LoginParameters(
                                            audiences: audiences.split(
                                                separator: " ",
                                                omittingEmptySubsequences: true
                                            ).map(String.init)
                                        ),
                                        onSuccess: {},
                                        onError: { err in
                                            errorReporingService.handle(error: err)
                                            switch err {
                                            case NativeSDKError.oidcError(
                                                error: _,
                                                errorDescription: let
                                                    errorDescription
                                            ):
                                                self.error = errorDescription
                                            case NativeSDKError
                                                .hostedFlowCanceled:
                                                self.error =
                                                    "Hosted flow was cancelled"
                                            case NativeSDKError.sessionExpired:
                                                self.error =
                                                    "Login session expired"
                                            default:
                                                self.error = "N/A"
                                            }
                                        }
                                    )
                                }
                            }
                            if let error = error {
                                Text(error)
                                    .foregroundColor(Colors.red)
                            }
                        }
                    }  // center the scrollview content vertically
                    .frame(width: geometry.size.width)
                    .frame(minHeight: geometry.size.height)
                }
            }
            .onChange(of: scrollManager.errorFieldIds) {
                let ids = scrollManager.errorFieldIds
                if ids != [] {
                    withAnimation {
                        proxy.scrollTo(ids[0], anchor: .center)
                    }
                }
            }

            if session.loginInProgress {
                Button {
                    nativeSDK.cancelFlow()
                } label: {
                    Text("Cancel login")
                }.foregroundStyle(Colors.styPrimary)
            }
        }
    }
}

private struct CustomAudienceInput: View {
    
    @Binding var audiences: String
    
    public var body: some View {
        
        VStack(alignment: .leading) {
            HStack {
                TextField("Custom Audiences", text: $audiences)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                
                Button(action: {
                    if let url = URL(string: CustomAudienceInput.documentationUrl) {
                        UIApplication.shared.open(url)
                    }
                }) {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.secondary)
                }
            }
            
            Text("Audiences separated by space")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(8)
    }
    
    static private let documentationUrl : String = "https://docs.strivacity.com/docs/oauth2-oidc-properties-setup#allowed-custom-audiences"
}

#Preview {
    @State @Previewable var audiences: String = ""
    CustomAudienceInput(audiences: $audiences)
}
