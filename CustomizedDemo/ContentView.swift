import SdkMobileIOSNative
import SwiftUI

struct ContentView: View {
    var nativeSDK: NativeSDK

    @State var loading: Bool = true
    @State var error: String?
    @ObservedObject var session: Session
    @ObservedObject var scrollManager = ScrollManager()
    @ObservedObject var focusManager = FocusManager()
    @ObservedObject var errorReportingService = ErrorReportingService()

    init() {
        nativeSDK = NativeSDK(
            issuer: URL(string: "https://example.org")!,
            clientId: "",
            redirectURI: URL(string: "strivacity.DemoMobileIOS://native-flow")!,
            postLogoutURI: URL(string: "strivacity.DemoMobileIOS://native-flow")!
        )

        session = nativeSDK.session
    }

    var body: some View {
        VStack {
            if loading {
                Text("loading...")
            } else {
                Text("Strivacity")
                    .padding(.top, 24)

                Login(nativeSDK: nativeSDK, error: error)
                    .environmentObject(session)
                    .environmentObject(scrollManager)
                    .environmentObject(focusManager)
                    .environmentObject(errorReportingService)

                Text("Footer")
            }
        }
        .modifier(ErrorReportingModifier(reporter: errorReportingService))
        .onAppear {
            Task {
                do {
                    try await nativeSDK.initializeSession()
                    loading = false
                } catch {
                    errorReportingService.handle(error: error)
                }
            }
        }
    }
}

class ErrorReportingService: ObservableObject {
    @Published private(set) var reportedError: Error?

    func handle(error: Error) {
        print(error)
        Task { @MainActor in
            self.reportedError = error
        }
    }

    func dismiss() {
        reportedError = nil
    }
}

struct ErrorReportingModifier: ViewModifier {

    @ObservedObject var reporter: ErrorReportingService

    func body(content: Content) -> some View {

        ZStack {
            content

            if let reportedError = reporter.reportedError {
                // The "Oops" Screen
                VStack(spacing: 20) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.orange)

                    Text("Ooops, something went wrong")
                        .font(.headline)

                    Text(reportedError.localizedDescription)
                        .multilineTextAlignment(.center)
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text("Tracking ID: \(UUID().uuidString)")
                        .font(.caption)

                    Button("Got it") {
                        reporter.dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(30)
                .background(.ultraThinMaterial)
                .cornerRadius(20)
                .shadow(radius: 10)
                .transition(.scale.combined(with: .opacity))
                .zIndex(1)
            }
        }
    }
}

#Preview {
    ContentView()
}
