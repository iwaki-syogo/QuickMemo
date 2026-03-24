import Foundation
import AuthenticationServices

// MARK: - GitHubAuthConfig

/// Configuration for GitHub OAuth credentials.
/// Values are loaded from Info.plist (GITHUB_CLIENT_ID, GITHUB_CLIENT_SECRET).
/// In production, token exchange should be performed via a server-side proxy
/// to avoid bundling client_secret in the app binary.
struct GitHubAuthConfig {
    let clientID: String
    let clientSecret: String

    static let `default`: GitHubAuthConfig = {
        let clientID = Bundle.main.object(forInfoDictionaryKey: "GITHUB_CLIENT_ID") as? String ?? ""
        let clientSecret = Bundle.main.object(forInfoDictionaryKey: "GITHUB_CLIENT_SECRET") as? String ?? ""
        return GitHubAuthConfig(clientID: clientID, clientSecret: clientSecret)
    }()
}

@Observable
class GitHubAuthService: NSObject {
    private let config: GitHubAuthConfig
    private static let callbackScheme = "quickmemo"
    private static let scope = "repo"

    init(config: GitHubAuthConfig = .default) {
        self.config = config
        super.init()
    }

    var isAuthenticating = false

    func authenticate() async throws -> String {
        let url = buildAuthorizeURL()

        let code = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: Self.callbackScheme
            ) { callbackURL, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let callbackURL,
                      let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
                      let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
                    continuation.resume(throwing: AuthError.invalidCallback)
                    return
                }

                continuation.resume(returning: code)
            }

            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false

            DispatchQueue.main.async {
                session.start()
            }
        }

        let token = try await exchangeCodeForToken(code)
        let saved = KeychainService.saveAccessToken(token)
        guard saved else { throw AuthError.keychainSaveFailed }

        return token
    }

    func logout() {
        KeychainService.deleteAccessToken()
    }

    var isLoggedIn: Bool {
        KeychainService.getAccessToken() != nil
    }

    private func buildAuthorizeURL() -> URL {
        var components = URLComponents(string: "https://github.com/login/oauth/authorize")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: config.clientID),
            URLQueryItem(name: "scope", value: Self.scope),
            URLQueryItem(name: "redirect_uri", value: "\(Self.callbackScheme)://github/callback")
        ]
        return components.url!
    }

    private func exchangeCodeForToken(_ code: String) async throws -> String {
        let url = URL(string: "https://github.com/login/oauth/access_token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let body: [String: String] = [
            "client_id": config.clientID,
            "client_secret": config.clientSecret,
            "code": code
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AuthError.tokenExchangeFailed
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let token = json?["access_token"] as? String else {
            throw AuthError.tokenExchangeFailed
        }

        return token
    }

    enum AuthError: LocalizedError {
        case invalidCallback
        case tokenExchangeFailed
        case keychainSaveFailed

        var errorDescription: String? {
            switch self {
            case .invalidCallback: "コールバックが無効です"
            case .tokenExchangeFailed: "アクセストークンの取得に失敗しました"
            case .keychainSaveFailed: "トークンの保存に失敗しました"
            }
        }
    }
}

extension GitHubAuthService: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        ASPresentationAnchor()
    }
}
