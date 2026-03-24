import SwiftUI

struct SettingsView: View {
    @Environment(GitHubAccount.self) private var gitHubAccount
    @Environment(StoreKitService.self) private var storeKitService
    @State private var authService = GitHubAuthService()
    @State private var tokenInput = ""
    @State private var isAuthenticating = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            List {
                gitHubSection

                adFreeSection

                appInfoSection
            }
            AdBannerView()
        }
        .navigationTitle("設定")
        .task {
            await storeKitService.loadProduct()
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    private var gitHubSection: some View {
        Section("GitHub連携") {
            if gitHubAccount.isLinked {
                HStack {
                    if let url = URL(string: gitHubAccount.avatarURL) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .clipShape(Circle())
                        } placeholder: {
                            Circle()
                                .fill(Color.secondary.opacity(0.3))
                        }
                        .frame(width: 32, height: 32)
                    }

                    Text(gitHubAccount.username)
                        .font(.body)
                }

                if gitHubAccount.hasRepository {
                    NavigationLink {
                        RepositoryPickerView()
                    } label: {
                        HStack {
                            Text("リポジトリ")
                                .foregroundStyle(.primary)
                            Spacer()
                            Text("\(gitHubAccount.repositoryOwner)/\(gitHubAccount.repositoryName)")
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                } else {
                    NavigationLink {
                        RepositoryPickerView()
                    } label: {
                        Text("リポジトリを選択")
                    }
                }

                Button("連携を解除", role: .destructive) {
                    authService.logout()
                    gitHubAccount.reset()
                }
            } else {
                SecureField("Personal Access Token を入力", text: $tokenInput)
                    .textContentType(.password)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)

                Text("GitHub Settings > Developer settings > Personal access tokens (classic) から repo スコープで作成")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button {
                    authenticateWithGitHub()
                } label: {
                    HStack {
                        if isAuthenticating {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text("連携する")
                    }
                }
                .disabled(tokenInput.isEmpty || isAuthenticating)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
    }

    private var adFreeSection: some View {
        Section("広告を非表示にする") {
            if storeKitService.isAdFree {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("購入済み")
                }
            } else {
                Button {
                    Task {
                        await storeKitService.purchase()
                    }
                } label: {
                    HStack {
                        Text("広告を非表示にする")
                        Spacer()
                        if storeKitService.isPurchasing {
                            ProgressView()
                                .controlSize(.small)
                        } else if let product = storeKitService.adFreeProduct {
                            Text(product.displayPrice)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .disabled(storeKitService.isPurchasing || storeKitService.adFreeProduct == nil)

                Button("購入を復元") {
                    Task {
                        await storeKitService.restore()
                    }
                }
            }

            if let error = storeKitService.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private var appInfoSection: some View {
        Section("アプリ情報") {
            HStack {
                Text("バージョン")
                Spacer()
                Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-")
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("ビルド")
                Spacer()
                Text(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "-")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func authenticateWithGitHub() {
        isAuthenticating = true
        errorMessage = nil
        Task {
            do {
                try await authService.login(token: tokenInput)
                let apiClient = GitHubAPIClient()
                let user = try await apiClient.fetchUser()
                gitHubAccount.username = user.login
                gitHubAccount.avatarURL = user.avatarURL
                gitHubAccount.isLinked = true
                tokenInput = ""
            } catch {
                errorMessage = error.localizedDescription
            }
            isAuthenticating = false
        }
    }
}
