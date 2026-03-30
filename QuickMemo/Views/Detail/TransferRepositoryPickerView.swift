import SwiftUI

struct TransferRepositoryPickerView: View {
    let currentOwner: String?
    let currentRepo: String?
    let onTransfer: (String, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(GitHubAccount.self) private var gitHubAccount

    @State private var repositories: [GitHubRepository] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showConfirmAlert = false
    @State private var selectedRepo: GitHubRepository?

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
                    let isCurrent = repo.owner.login == currentOwner && repo.name == currentRepo
                    Button {
                        if !isCurrent {
                            selectedRepo = repo
                            showConfirmAlert = true
                        }
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(repo.fullName)
                                    .font(.body)
                                    .foregroundStyle(isCurrent ? .secondary : .primary)
                                if let description = repo.description {
                                    Text(description)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }

                            Spacer()

                            if isCurrent {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                    }
                    .disabled(isCurrent)
                }
            }
        }
        .navigationTitle("移動先リポジトリ")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("キャンセル") {
                    dismiss()
                }
            }
        }
        .onAppear {
            loadRepositories()
        }
        .alert("リポジトリを移動", isPresented: $showConfirmAlert) {
            Button("移動", role: .destructive) {
                if let repo = selectedRepo {
                    onTransfer(repo.owner.login, repo.name)
                    dismiss()
                }
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            if let repo = selectedRepo {
                Text("\(repo.fullName) に移動しますか？\n現在のリポジトリのIssueはクローズされ、新しいリポジトリにIssueが作成されます。")
            }
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
}
