import AuthenticationServices
#if os(macOS)
import FlutterMacOS
#else
import Flutter
#endif

enum WebAuthChannel {
    // Must be held for the session's lifetime.
    private static var session: ASWebAuthenticationSession?
    private static let presenter = PresentationContextProvider()

    static func register(messenger: FlutterBinaryMessenger, anchor: ASPresentationAnchor?) {
        presenter.anchor = anchor
        let channel = FlutterMethodChannel(name: "vpn/web_auth", binaryMessenger: messenger)
        channel.setMethodCallHandler { call, result in
            guard call.method == "start",
                  let args = call.arguments as? [String: Any],
                  let urlStr = args["url"] as? String,
                  let url = URL(string: urlStr),
                  let scheme = args["scheme"] as? String
            else {
                result(FlutterError(code: "bad_args", message: "url and scheme required", details: nil))
                return
            }

            let session = ASWebAuthenticationSession(url: url, callbackURLScheme: scheme) { callbackURL, error in
                if let error = error {
                    let nsErr = error as NSError
                    if nsErr.code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                        result(FlutterError(code: "cancelled", message: "user cancelled", details: nil))
                    } else {
                        result(FlutterError(code: "auth_failed", message: error.localizedDescription, details: nil))
                    }
                    return
                }
                result(callbackURL?.absoluteString)
            }
            session.presentationContextProvider = presenter
            // Shares the system login session; ephemeral would force a re-login every time.
            session.prefersEphemeralWebBrowserSession = false
            self.session = session
            if !session.start() {
                result(FlutterError(code: "start_failed", message: "could not start auth session", details: nil))
            }
        }
    }
}

private final class PresentationContextProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    weak var anchor: ASPresentationAnchor?
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return anchor ?? ASPresentationAnchor()
    }
}
