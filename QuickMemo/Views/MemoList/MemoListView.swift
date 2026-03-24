import SwiftUI
import SwiftData

struct MemoListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(GitHubAccount.self) private var gitHubAccount
    @Environment(SyncService.self) private var syncService
    @State private var viewModel = MemoListViewModel()

    var body: some View {
        VStack(spacing: 0) {
            Group {
                if viewModel.pinnedMemos.isEmpty && viewModel.otherMemos.isEmpty &&
                    viewModel.openMemos.isEmpty && viewModel.closedMemos.isEmpty {
                    emptyStateView
                } else {
                    memoList
                }
            }
            AdBannerView()
        }
        .navigationTitle("QuickMemo")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink {
                    InputView()
                } label: {
                    Image(systemName: "square.and.pencil")
                        .foregroundStyle(Color.accentColor)
                }
            }
        }
        .onAppear {
            viewModel.setModelContext(modelContext)
            viewModel.fetchMemos(isGitHubLinked: gitHubAccount.isLinked)
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                viewModel.fetchMemos(isGitHubLinked: gitHubAccount.isLinked)
                Task {
                    await syncService.retryFailedAndPending(account: gitHubAccount, context: modelContext)
                    viewModel.fetchMemos(isGitHubLinked: gitHubAccount.isLinked)
                }
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "note.text")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("メモがありません")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("右上のボタンから新規メモを作成できます")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var memoList: some View {
        List {
            if !viewModel.pinnedMemos.isEmpty {
                Section("ピン留め") {
                    ForEach(viewModel.pinnedMemos, id: \.id) { memo in
                        memoNavigationLink(memo: memo, pinAction: "ピン解除", pinIcon: "pin.slash")
                    }
                }
            }

            if gitHubAccount.isLinked {
                if !viewModel.openMemos.isEmpty {
                    Section("Open") {
                        ForEach(viewModel.openMemos, id: \.id) { memo in
                            memoNavigationLink(memo: memo, pinAction: "ピン留め", pinIcon: "pin")
                        }
                    }
                }

                if !viewModel.closedMemos.isEmpty {
                    Section("Closed") {
                        ForEach(viewModel.closedMemos, id: \.id) { memo in
                            memoNavigationLink(memo: memo, pinAction: "ピン留め", pinIcon: "pin")
                        }
                    }
                }
            } else {
                if !viewModel.otherMemos.isEmpty {
                    Section {
                        ForEach(viewModel.otherMemos, id: \.id) { memo in
                            memoNavigationLink(memo: memo, pinAction: "ピン留め", pinIcon: "pin")
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func memoNavigationLink(memo: Memo, pinAction: String, pinIcon: String) -> some View {
        NavigationLink {
            MemoDetailView(memo: memo)
        } label: {
            HStack {
                MemoRowView(memo: memo)

                if memo.syncStatus == .failed {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
        .swipeActions(edge: .leading) {
            Button {
                viewModel.togglePin(memo)
                viewModel.fetchMemos(isGitHubLinked: gitHubAccount.isLinked)
            } label: {
                SwiftUI.Label(pinAction, systemImage: pinIcon)
            }
            .tint(.orange)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                viewModel.deleteMemo(memo)
                viewModel.fetchMemos(isGitHubLinked: gitHubAccount.isLinked)
            } label: {
                SwiftUI.Label("削除", systemImage: "trash")
            }

            if gitHubAccount.isLinked, memo.githubIssueURL != nil {
                Button {
                    openInGitHub(memo)
                } label: {
                    SwiftUI.Label("GitHubで開く", systemImage: "arrow.up.right")
                }
                .tint(.purple)
            }
        }
    }

    private func openInGitHub(_ memo: Memo) {
        guard let urlString = memo.githubIssueURL,
              let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url)
    }
}
