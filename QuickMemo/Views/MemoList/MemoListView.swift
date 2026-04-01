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
    private var otherMemos: [Memo] { allMemos.filter { !$0.isPinned } }

    // MARK: - Repository grouping

    private var repositoryDisplayNames: [String] {
        var seen = Set<String>()
        var result: [String] = []
        for memo in allMemos where !memo.isPinned {
            guard let owner = memo.repositoryOwner, !owner.isEmpty,
                  let name = memo.repositoryName, !name.isEmpty else { continue }
            let key = "\(owner)/\(name)"
            if seen.insert(key).inserted {
                result.append(key)
            }
        }
        return result.sorted()
    }

    private func memosForRepository(_ displayName: String) -> [Memo] {
        allMemos.filter {
            !$0.isPinned &&
            "\($0.repositoryOwner ?? "")/\($0.repositoryName ?? "")" == displayName
        }
    }

    private var localMemos: [Memo] {
        allMemos.filter {
            !$0.isPinned &&
            ($0.repositoryOwner == nil || $0.repositoryOwner?.isEmpty == true ||
             $0.repositoryName == nil || $0.repositoryName?.isEmpty == true)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Group {
                if allMemos.isEmpty {
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
                Task {
                    await syncService.fetchAndImportIssues(account: gitHubAccount, context: modelContext)
                }
            }
        }
        .onChange(of: gitHubAccount.repositoryName) { _, _ in
            if gitHubAccount.isLinked, gitHubAccount.hasRepository {
                Task {
                    await syncService.fetchAndImportIssues(account: gitHubAccount, context: modelContext)
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
                ForEach(repositoryDisplayNames, id: \.self) { repoName in
                    Section(repoName) {
                        ForEach(memosForRepository(repoName), id: \.id) { memo in
                            memoNavigationLink(memo: memo, pinAction: "ピン留め", pinIcon: "pin", showRepository: false)
                        }
                    }
                }

                if !localMemos.isEmpty {
                    Section("ローカル") {
                        ForEach(localMemos, id: \.id) { memo in
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
                await syncService.fetchAndImportIssues(account: gitHubAccount, context: modelContext)
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

    private func memoNavigationLink(memo: Memo, pinAction: String, pinIcon: String, showRepository: Bool = true) -> some View {
        NavigationLink {
            MemoDetailView(memo: memo)
        } label: {
            HStack {
                MemoRowView(memo: memo, labels: labelsForMemo(memo), showRepository: showRepository)

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
