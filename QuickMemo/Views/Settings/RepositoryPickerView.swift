import SwiftUI

struct RepositoryPickerView: View {
    @Environment(GitHubAccount.self) private var gitHubAccount
    @State private var repositories: [GitHubRepository] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 36))
                        .foregroundStyle(.secondary)
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("再読み込み") {
                        loadRepositories()
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(repositories) { repo in
                    Button {
                        selectRepository(repo)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(repo.fullName)
                                    .font(.body)
                                    .foregroundStyle(.primary)
                                if let description = repo.description {
                                    Text(description)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }

                            Spacer()

                            if repo.owner.login == gitHubAccount.repositoryOwner &&
                                repo.name == gitHubAccount.repositoryName {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("リポジトリ選択")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadRepositories()
        }
    }

    private func loadRepositories() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                let apiClient = GitHubAPIClient()
                repositories = try await apiClient.fetchRepositories()
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    private func selectRepository(_ repo: GitHubRepository) {
        gitHubAccount.repositoryOwner = repo.owner.login
        gitHubAccount.repositoryName = repo.name
    }
}
