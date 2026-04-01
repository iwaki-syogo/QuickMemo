import SwiftUI
import SwiftData

struct MemoListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(GitHubAccount.self) private var gitHubAccount
    @Environment(SyncService.self) private var syncService
    @Query(sort: \Memo.updatedAt, order: .reverse) private var allMemos: [Memo]
    @Query(sort: \QuickMemo.Label.name) private var allLabels: [QuickMemo.Label]

    // MARK: - Computed filters

    private var pinnedMemos: [Memo] { allMemos.filter { $0.isPinned } }
    private var openMemos: [Memo] { allMemos.filter { !$0.isPinned && $0.status == .open } }
    private var closedMemos: [Memo] { allMemos.filter { !$0.isPinned && $0.status == .closed } }
    private var otherMemos: [Memo] { allMemos.filter { !$0.isPinned } }

    var body: some View {
        VStack(spacing: 0) {
            Group {
                if pinnedMemos.isEmpty && otherMemos.isEmpty &&
                    openMemos.isEmpty && closedMemos.isEmpty {
                    emptyStateView
                } else {
                    memoList
                }
            }
            AdBannerView()
        }
        .navigationTitle("メモ")
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
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active, gitHubAccount.isLinked {
                Task {
                    await syncService.retryFailedAndPending(account: gitHubAccount, context: modelContext)
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
            Text("右上のボタンから新しいメモを作成できます")
                .font(.caption)
                .foregroundStyle(.tertiary)

        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var memoList: some View {
        List {
            if !pinnedMemos.isEmpty {
                Section("ピン留め") {
                    ForEach(pinnedMemos, id: \.id) { memo in
                        memoNavigationLink(memo: memo, pinAction: "ピン解除", pinIcon: "pin.slash")
                    }
                }
            }

            if gitHubAccount.isLinked {
                if !openMemos.isEmpty {
                    Section("オープン") {
                        ForEach(openMemos, id: \.id) { memo in
                            memoNavigationLink(memo: memo, pinAction: "ピン留め", pinIcon: "pin")
                        }
                    }
                }

                if !closedMemos.isEmpty {
                    Section("クローズ") {
                        ForEach(closedMemos, id: \.id) { memo in
                            memoNavigationLink(memo: memo, pinAction: "ピン留め", pinIcon: "pin")
                        }
                    }
                }
            } else {
                if !otherMemos.isEmpty {
                    Section {
                        ForEach(otherMemos, id: \.id) { memo in
                            memoNavigationLink(memo: memo, pinAction: "ピン留め", pinIcon: "pin")
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable {
            if gitHubAccount.isLinked {
                await syncService.importIssues(account: gitHubAccount, context: modelContext)
            }
        }
        .sheet(item: $labelPickerMemo) { memo in
            LabelPickerSheet(selectedLabelIDs: Binding(
                get: { memo.labelIDs },
                set: { newValue in
                    memo.labelIDs = newValue
                    try? modelContext.save()
                    if gitHubAccount.isLinked, gitHubAccount.hasRepository {
                        Task {
                            await syncService.syncMemo(memo, account: gitHubAccount, context: modelContext)
                        }
                    }
                }
            ))
        }
    }

    @State private var labelPickerMemo: Memo?

    private func memoNavigationLink(memo: Memo, pinAction: String, pinIcon: String) -> some View {
        NavigationLink {
            MemoDetailView(memo: memo)
        } label: {
            HStack {
                MemoRowView(memo: memo, labels: labelsForMemo(memo))

                if memo.syncStatus == .failed {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
        .swipeActions(edge: .leading) {
            Button {
                togglePin(memo)
            } label: {
                SwiftUI.Label(pinAction, systemImage: pinIcon)
            }
            .tint(.orange)

            if gitHubAccount.isLinked {
                Button {
                    labelPickerMemo = memo
                } label: {
                    SwiftUI.Label("ラベル", systemImage: "tag")
                }
                .tint(.purple)
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if memo.status == .open {
                Button {
                    toggleStatus(memo)
                    Task {
                        await syncService.syncMemo(memo, account: gitHubAccount, context: modelContext)
                    }
                } label: {
                    SwiftUI.Label("クローズ", systemImage: "checkmark.circle")
                }
                .tint(.green)
            } else {
                Button {
                    toggleStatus(memo)
                    Task {
                        await syncService.syncMemo(memo, account: gitHubAccount, context: modelContext)
                    }
                } label: {
                    SwiftUI.Label("再開", systemImage: "arrow.uturn.left")
                }
                .tint(.blue)
            }

            if memo.githubIssueURL != nil {
                Button {
                    openInGitHub(memo)
                } label: {
                    SwiftUI.Label("GitHub", systemImage: "safari")
                }
                .tint(.gray)
            }
        }
    }

    // MARK: - Actions

    private func togglePin(_ memo: Memo) {
        memo.isPinned.toggle()
        memo.updatedAt = Date()
        do {
            try modelContext.save()
        } catch {
            print("[QuickMemo] Failed to save after togglePin: \(error)")
        }
    }

    private func toggleStatus(_ memo: Memo) {
        memo.status = (memo.status == .open) ? .closed : .open
        memo.updatedAt = Date()
        do {
            try modelContext.save()
        } catch {
            print("[QuickMemo] Failed to save after toggleStatus: \(error)")
        }
    }

    private func openInGitHub(_ memo: Memo) {
        guard let urlString = memo.githubIssueURL,
              let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url)
    }

    private func labelsForMemo(_ memo: Memo) -> [QuickMemo.Label] {
        allLabels.filter { memo.labelIDs.contains($0.id) }
    }
}
