import Foundation
import Observation

@Observable
class GitHubAccount {
    private static let usernameKey = "github_username"
    private static let avatarURLKey = "github_avatar_url"
    private static let repoOwnerKey = "github_repo_owner"
    private static let repoNameKey = "github_repo_name"
    private static let isLinkedKey = "github_is_linked"

    var username: String {
        didSet { UserDefaults.standard.set(username, forKey: Self.usernameKey) }
    }

    var avatarURL: String {
        didSet { UserDefaults.standard.set(avatarURL, forKey: Self.avatarURLKey) }
    }

    var repositoryOwner: String {
        didSet { UserDefaults.standard.set(repositoryOwner, forKey: Self.repoOwnerKey) }
    }

    var repositoryName: String {
        didSet { UserDefaults.standard.set(repositoryName, forKey: Self.repoNameKey) }
    }

    var isLinked: Bool {
        didSet { UserDefaults.standard.set(isLinked, forKey: Self.isLinkedKey) }
    }

    var hasRepository: Bool {
        !repositoryOwner.isEmpty && !repositoryName.isEmpty
    }

    init() {
        self.username = UserDefaults.standard.string(forKey: Self.usernameKey) ?? ""
        self.avatarURL = UserDefaults.standard.string(forKey: Self.avatarURLKey) ?? ""
        self.repositoryOwner = UserDefaults.standard.string(forKey: Self.repoOwnerKey) ?? ""
        self.repositoryName = UserDefaults.standard.string(forKey: Self.repoNameKey) ?? ""
        self.isLinked = UserDefaults.standard.bool(forKey: Self.isLinkedKey)
    }

    func reset() {
        username = ""
        avatarURL = ""
        repositoryOwner = ""
        repositoryName = ""
        isLinked = false
    }
}
