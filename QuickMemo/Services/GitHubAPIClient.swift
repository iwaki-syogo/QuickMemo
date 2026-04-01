import Foundation

struct GitHubUser: Codable {
    let login: String
    let avatarURL: String

    enum CodingKeys: String, CodingKey {
        case login
        case avatarURL = "avatar_url"
    }
}

struct GitHubRepository: Codable, Identifiable {
    let id: Int
    let name: String
    let fullName: String
    let owner: GitHubOwner
    let isPrivate: Bool
    let description: String?

    enum CodingKeys: String, CodingKey {
        case id, name, owner, description
        case fullName = "full_name"
        case isPrivate = "private"
    }
}

struct GitHubOwner: Codable {
    let login: String
}

struct GitHubLabel: Codable, Identifiable {
    let id: Int
    let name: String
    let color: String
    let description: String?
}

struct GitHubIssue: Codable {
    let number: Int
    let htmlURL: String
    let state: String
    let stateReason: String?
    let title: String
    let body: String?
    let labels: [GitHubLabel]?

    enum CodingKeys: String, CodingKey {
        case number, state, title, body, labels
        case htmlURL = "html_url"
        case stateReason = "state_reason"
    }
}

struct GitHubIssueDetail: Codable {
    let number: Int
    let title: String
    let body: String?
    let state: String
    let stateReason: String?
    let htmlURL: String
    let createdAt: Date
    let updatedAt: Date
    let labels: [GitHubLabel]
    let pullRequest: PullRequestRef?

    struct PullRequestRef: Codable {}

    var isPullRequest: Bool { pullRequest != nil }

    enum CodingKeys: String, CodingKey {
        case number, title, body, state, labels
        case stateReason = "state_reason"
        case htmlURL = "html_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case pullRequest = "pull_request"
    }
}

struct GitHubAPIClient {
    private let baseURL = "https://api.github.com"

    private func makeRequest(_ path: String, method: String = "GET", body: [String: Any]? = nil) async throws -> (Data, HTTPURLResponse) {
        guard let token = KeychainService.getAccessToken() else {
            throw APIError.unauthorized
        }

        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw APIError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            return (data, httpResponse)
        case 401:
            throw APIError.unauthorized
        case 403:
            throw APIError.rateLimited
        default:
            throw APIError.httpError(httpResponse.statusCode)
        }
    }

    func fetchUser() async throws -> GitHubUser {
        let (data, _) = try await makeRequest("/user")
        return try JSONDecoder().decode(GitHubUser.self, from: data)
    }

    func fetchRepositories() async throws -> [GitHubRepository] {
        let (data, _) = try await makeRequest("/user/repos?sort=updated&per_page=100")
        return try JSONDecoder().decode([GitHubRepository].self, from: data)
    }

    func createIssue(owner: String, repo: String, title: String, body: String?, labels: [String]) async throws -> GitHubIssue {
        var issueBody: [String: Any] = ["title": title]
        if let body, !body.isEmpty {
            issueBody["body"] = body
        }
        if !labels.isEmpty {
            issueBody["labels"] = labels
        }

        let (data, _) = try await makeRequest("/repos/\(owner)/\(repo)/issues", method: "POST", body: issueBody)
        return try JSONDecoder().decode(GitHubIssue.self, from: data)
    }

    func updateIssue(owner: String, repo: String, number: Int, title: String? = nil, body: String? = nil, state: String? = nil) async throws -> GitHubIssue {
        var issueBody: [String: Any] = [:]
        if let title { issueBody["title"] = title }
        if let body { issueBody["body"] = body }
        if let state { issueBody["state"] = state }

        let (data, _) = try await makeRequest("/repos/\(owner)/\(repo)/issues/\(number)", method: "PATCH", body: issueBody)
        return try JSONDecoder().decode(GitHubIssue.self, from: data)
    }

    func setIssueLabels(owner: String, repo: String, number: Int, labels: [String]) async throws {
        let body: [String: Any] = ["labels": labels]
        _ = try await makeRequest("/repos/\(owner)/\(repo)/issues/\(number)/labels", method: "PUT", body: body)
    }

    func fetchIssues(owner: String, repo: String, state: String = "open", page: Int = 1) async throws -> [GitHubIssue] {
        let (data, _) = try await makeRequest("/repos/\(owner)/\(repo)/issues?state=\(state)&per_page=100&page=\(page)")
        return try JSONDecoder().decode([GitHubIssue].self, from: data)
    }

    func fetchLabels(owner: String, repo: String) async throws -> [GitHubLabel] {
        let (data, _) = try await makeRequest("/repos/\(owner)/\(repo)/labels?per_page=100")
        return try JSONDecoder().decode([GitHubLabel].self, from: data)
    }

    func fetchIssueDetails(owner: String, repo: String, state: String = "all", page: Int = 1) async throws -> [GitHubIssueDetail] {
        let (data, _) = try await makeRequest("/repos/\(owner)/\(repo)/issues?state=\(state)&per_page=100&page=\(page)")
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([GitHubIssueDetail].self, from: data)
    }

    enum APIError: LocalizedError {
        case unauthorized
        case rateLimited
        case invalidResponse
        case httpError(Int)

        var errorDescription: String? {
            switch self {
            case .unauthorized: "認証エラー。再ログインしてください"
            case .rateLimited: "APIレート制限に達しました。しばらく待ってから再試行してください"
            case .invalidResponse: "サーバーからの応答が不正です"
            case .httpError(let code): "HTTPエラー: \(code)"
            }
        }
    }
}
