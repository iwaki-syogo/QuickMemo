import Foundation

/// Testable filtering logic extracted from MemoListView
enum MemoFilters {
    static func pinned(_ memos: [Memo]) -> [Memo] {
        memos.filter { $0.isPinned }
    }

    static func open(_ memos: [Memo]) -> [Memo] {
        memos.filter { !$0.isPinned && $0.status == .open }
    }

    static func merged(_ memos: [Memo]) -> [Memo] {
        memos.filter { !$0.isPinned && $0.status == .merged }
    }

    static func closed(_ memos: [Memo]) -> [Memo] {
        memos.filter { !$0.isPinned && $0.status == .closed }
    }

    static func scoped(_ memos: [Memo], owner: String, repository: String) -> [Memo] {
        memos.filter { memo in
            memo.repositoryOwner == nil ||
            (memo.repositoryOwner == owner && memo.repositoryName == repository)
        }
    }
}

/// Determines whether the unsynced indicator (blue dot) should be shown
enum SyncIndicator {
    static func shouldShow(syncStatus: SyncStatus, isGitHubLinked: Bool) -> Bool {
        guard isGitHubLinked else { return false }
        return syncStatus == .pending || syncStatus == .failed
    }
}
