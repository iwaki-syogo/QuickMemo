import SwiftUI
import SwiftData

struct InputView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss
    @Environment(GitHubAccount.self) private var gitHubAccount
    @Environment(SyncService.self) private var syncService

    @State private var viewModel = InputViewModel()
    @FocusState private var isTitleFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            TextField("タイトル", text: $viewModel.title)
                .font(.headline)
                .padding(.horizontal)
                .padding(.top, 16)
                .padding(.bottom, 8)
                .focused($isTitleFocused)

            Divider()
                .padding(.horizontal)

            TextEditor(text: $viewModel.body)
                .font(.body)
                .frame(minHeight: 80)
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .scrollContentBackground(.hidden)

            Spacer()
        }
        .navigationTitle("新規メモ")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.setModelContext(modelContext)
            isTitleFocused = true
        }
        .onDisappear {
            viewModel.save()
            syncNewMemo()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .inactive || newPhase == .background {
                viewModel.save()
                syncNewMemo()
            }
        }
    }

    private func syncNewMemo() {
        guard let memo = viewModel.savedMemo,
              gitHubAccount.isLinked, gitHubAccount.hasRepository else { return }

        Task {
            await syncService.syncMemo(memo, account: gitHubAccount, context: modelContext)
        }
    }
}
