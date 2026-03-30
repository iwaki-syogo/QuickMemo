import Foundation
import SwiftData
import Observation

@MainActor
@Observable
class SyncService {
    private let apiClient = GitHubAPIClient()
    var isSyncing = false

    func syncMemo(_ memo: Memo, account: GitHubAccount, context: ModelContext) async {
        guard account.isLinked, account.hasRepository else { return }

        let owner = account.repositoryOwner
        let repo = account.repositoryName

        memo.syncStatus = .pending
        do { try context.save() } catch { print("[QuickMemo] Failed to save pending status: \(error)") }

        do {
            let labelNames = fetchLabelNames(for: memo, context: context)

            if let issueNumber = memo.githubIssueNumber {
                let state = memo.status == .open ? "open" : "closed"
                let issue = try await apiClient.updateIssue(
                    owner: owner,
                    repo: repo,
                    number: issueNumber,
                    title: memo.title,
                    body: memo.body,
                    state: state
                )
                memo.githubIssueURL = issue.htmlURL

                if !labelNames.isEmpty {
                    try await apiClient.setIssueLabels(
                        owner: owner,
                        repo: repo,
                        number: issueNumber,
                        labels: labelNames
                    )
                }
            } else {
                let issue = try await apiClient.createIssue(
                    owner: owner,
                    repo: repo,
                    title: memo.title,
                    body: memo.body,
                    labels: labelNames
                )
                memo.githubIssueNumber = issue.number
                memo.githubIssueURL = issue.htmlURL
            }

            memo.syncStatus = .synced
            memo.syncError = nil
            memo.lastSyncedAt = Date()
            do { try context.save() } catch { print("[QuickMemo] Failed to save synced status: \(error)") }
        } catch {
            memo.syncStatus = .failed
            memo.syncError = error.localizedDescription
            do { try context.save() } catch { print("[QuickMemo] Failed to save failed status: \(error)") }
        }
    }

    func retryFailedAndPending(account: GitHubAccount, context: ModelContext) async {
        guard account.isLinked, account.hasRepository else { return }
        guard !isSyncing else { return }

        isSyncing = true
        defer { isSyncing = false }

        let pendingRaw = SyncStatus.pending.rawValue
        let failedRaw = SyncStatus.failed.rawValue
        let descriptor = FetchDescriptor<Memo>(
            predicate: #Predicate<Memo> { memo in
                memo.syncStatusRaw == pendingRaw || memo.syncStatusRaw == failedRaw
            }
        )

        guard let memos = try? context.fetch(descriptor) else { return }

        for memo in memos {
            await syncMemo(memo, account: account, context: context)
        }
    }

    private func fetchLabelNames(for memo: Memo, context: ModelContext) -> [String] {
        guard !memo.labelIDs.isEmpty else { return [] }

        let descriptor = FetchDescriptor<Label>()
        guard let allLabels = try? context.fetch(descriptor) else { return [] }

        return allLabels
            .filter { memo.labelIDs.contains($0.id) }
            .map(\.name)
    }
}
