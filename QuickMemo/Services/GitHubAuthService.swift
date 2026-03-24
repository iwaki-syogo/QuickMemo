import Foundation
import AuthenticationServices

@Observable
class GitHubAuthService: NSObject {
    private static let clientID = "YOUR_GITHUB_CLIENT_ID"
    private static let clientSecret = "YOUR_GITHUB_CLIENT_SECRET"
    private static let callbackScheme = "quickmemo"
    private static let scope = "repo"

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
            URLQueryItem(name: "client_id", value: Self.clientID),
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
            "client_id": Self.clientID,
            "client_secret": Self.clientSecret,
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
