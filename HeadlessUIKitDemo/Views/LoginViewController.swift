import UIKit
import SdkMobileIOSNative

class LoginViewController: UIViewController, HeadlessAdapterDelegate {

    var nativeSDK: NativeSDK!
    var headlessAdapter: HeadlessAdapter!

    @IBOutlet weak var screenView: UIView!
    var screenViewController: ScreenViewController?

    override func viewDidLoad() {
        super.viewDidLoad()

        Task { @MainActor in
            await nativeSDK.login(
                parameters: LoginParameters(
                    scopes: ["openid", "profile", "email", "offline"],
                    prefersEphemeralWebBrowserSession: true
                ),
                onSuccess: {
                    let mainViewController = MainViewController(nibName: "MainViewController", bundle: nil)
                    mainViewController.nativeSDK = self.nativeSDK
                    
                    self.navigationController?.setViewControllers([mainViewController], animated: true)
                },
                onError: { err in
                    Task { @MainActor in
                        let landingViewController = LandingViewController(nibName: "LandingViewController", bundle: nil)
                        landingViewController.nativeSDK = self.nativeSDK
                        
                        landingViewController.loginError =
                        switch err {
                        case let NativeSDKError.oidcError(error: _, errorDescription: errorDescription):
                            errorDescription
                        case NativeSDKError.hostedFlowCanceled:
                            "Hosted login canceled"
                        case NativeSDKError.sessionExpired:
                            "Session expired"
                        default:
                            "N/A"
                        }
                        
                        self.navigationController?.setViewControllers([landingViewController], animated: true)
                    }
                }
            )

            // Check for fastpath login
            if (!nativeSDK.session.loginInProgress) {
                return
            }

            headlessAdapter = HeadlessAdapter(nativeSDK: nativeSDK, delegate: self)
            headlessAdapter.initialize()
        }

    }

    public func renderScreen(screen: Screen) {
        Task { @MainActor in
            print(screen.screen ?? "No Screen name")

            // Detach current screen
            if let current = screenViewController {
                current.willMove(toParent: nil)
                current.view.removeFromSuperview()
                current.removeFromParent()
            }

            var newScreenViewController: ScreenViewController!
            switch screen.screen {
            case "identification":
                newScreenViewController = IdentificationViewController(nibName: "IdentificationViewController", bundle: nil)
            case "password":
                newScreenViewController = PasswordViewController(nibName: "PasswordViewController", bundle: nil)
            case "registration":
                newScreenViewController = RegistrationViewController(nibName: "RegistrationViewController", bundle: nil)
            default:
                newScreenViewController = UnkownViewController(nibName: "UnkownViewController", bundle: nil)
            }

            newScreenViewController.headlessAdapter = headlessAdapter
            newScreenViewController.screen = screen

            // Activate screen
            addChild(newScreenViewController)
            newScreenViewController.view.frame = screenView.bounds
            newScreenViewController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            screenView.addSubview(newScreenViewController.view)
            newScreenViewController.didMove(toParent: self)

            screenViewController = newScreenViewController
        }
    }

    public func refreshScreen(screen: Screen) {
        Task { @MainActor in
            guard let current = screenViewController else {
                return
            }

            switch screen.messages {
            case .global(let message):
                let alert = UIAlertController(title: message.text, message: nil, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                present(alert, animated: true)
            default:
                break
            }

            current.screen = screen
            current.refreshScreen()
        }
    }

}
