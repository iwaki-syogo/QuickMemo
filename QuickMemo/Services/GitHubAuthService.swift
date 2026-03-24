import Foundation

@MainActor
@Observable
class GitHubAuthService {

    func login(token: String) async throws {
        // Validate the token by calling GET /user
        guard let url = URL(string: "https://api.github.com/user") else {
            throw AuthError.invalidToken
        }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AuthError.invalidToken
        }

        let saved = KeychainService.saveAccessToken(token)
        guard saved else { throw AuthError.keychainSaveFailed }
    }

    func logout() {
        KeychainService.deleteAccessToken()
    }

    var isLoggedIn: Bool {
        KeychainService.getAccessToken() != nil
    }

    enum AuthError: LocalizedError {
        case invalidToken
        case keychainSaveFailed

        var errorDescription: String? {
            switch self {
            case .invalidToken: "トークンが無効です。repo スコープの Personal Access Token を入力してください"
            case .keychainSaveFailed: "トークンの保存に失敗しました"
            }
        }
    }
}
