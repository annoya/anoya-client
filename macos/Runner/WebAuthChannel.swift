import AuthenticationServices
import FlutterMacOS

/// WebAuthChannel bridges Flutter's OIDC flow to the system auth browser.
///   MethodChannel "vpn/web_auth": start({url, scheme}) -> callback URL string
///
/// ASWebAuthenticationSession is the Apple-blessed way to run an OAuth/OIDC
/// login: it opens a secure browser sheet, shares the system login session (so
/// a signed-in Google/Microsoft user isn't asked to re-enter credentials), and
/// hands back the redirect to our custom scheme (vpnclient://auth?code=...).
/// Same API on macOS and iOS.
enum WebAuthChannel {
    // Held for the session's lifetime; ASWebAuthenticationSession is released
    // once its completion handler fires.
    private static var session: ASWebAuthenticationSession?
    private static let presenter = PresentationContextProvider()

    static func register(messenger: FlutterBinaryMessenger, window: NSWindow) {
        presenter.window = window
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
            // Don't share cookies only if you want a forced re-login; sharing
            // (false) is what makes corporate SSO near-silent.
            session.prefersEphemeralWebBrowserSession = false
            self.session = session
            if !session.start() {
                result(FlutterError(code: "start_failed", message: "could not start auth session", details: nil))
            }
        }
    }
}

private final class PresentationContextProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    weak var window: NSWindow?
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return window ?? ASPresentationAnchor()
    }
}
