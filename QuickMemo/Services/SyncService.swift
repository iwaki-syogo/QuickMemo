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

        let owner = memo.repositoryOwner ?? account.repositoryOwner
        let repo = memo.repositoryName ?? account.repositoryName

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

                // Always sync labels (including empty array to clear all labels)
                try await apiClient.setIssueLabels(
                    owner: owner,
                    repo: repo,
                    number: issueNumber,
                    labels: labelNames
                )
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
            if memo.syncError?.hasPrefix("[transfer]") == true,
               let owner = memo.repositoryOwner,
               let repo = memo.repositoryName {
                await transferMemo(memo, toOwner: owner, repoName: repo, account: account, context: context)
            } else {
                await syncMemo(memo, account: account, context: context)
            }
        }
    }

    func transferMemo(_ memo: Memo, toOwner newOwner: String, repoName newRepo: String, account: GitHubAccount, context: ModelContext) async {
        let oldOwner = memo.repositoryOwner ?? account.repositoryOwner
        let oldRepo = memo.repositoryName ?? account.repositoryName

        memo.syncStatus = .pending
        do { try context.save() } catch { print("[QuickMemo] Failed to save pending status: \(error)") }

        do {
            let labelNames = fetchLabelNames(for: memo, context: context)
            let alreadySameRepo = memo.repositoryOwner == newOwner && memo.repositoryName == newRepo

            // Capture old issue info before intermediate state may clear them
            let oldIssueNumber = memo.githubIssueNumber
            let oldIssueURL = memo.githubIssueURL

            // Close old issue (skip if already pointing to the same repo)
            if !alreadySameRepo, let oldIssueNumber {
                let transferNote = "\n\n---\n> Transferred to [\(newOwner)/\(newRepo)](https://github.com/\(newOwner)/\(newRepo))"
                let oldBody = (memo.body ?? "") + transferNote
                _ = try await apiClient.updateIssue(
                    owner: oldOwner,
                    repo: oldRepo,
                    number: oldIssueNumber,
                    body: oldBody,
                    state: "closed"
                )

                // Persist intermediate state so retry skips the old close
                memo.repositoryOwner = newOwner
                memo.repositoryName = newRepo
                memo.githubIssueNumber = nil
                memo.githubIssueURL = nil
                do { try context.save() } catch {
                    print("[QuickMemo] Failed to save intermediate transfer state: \(error)")
                }
            }

            // Use captured old issue info for the cross-reference link
            let oldNumber = oldIssueNumber ?? 0
            let oldURL = oldIssueURL ?? "https://github.com/\(oldOwner)/\(oldRepo)"
            let originNote = "\n\n---\n> Transferred from [\(oldOwner)/\(oldRepo)#\(oldNumber)](\(oldURL))"
            let newBody = (memo.body ?? "") + originNote
            let newIssue = try await apiClient.createIssue(
                owner: newOwner,
                repo: newRepo,
                title: memo.title,
                body: newBody,
                labels: labelNames
            )

            // Update memo properties
            memo.githubIssueNumber = newIssue.number
            memo.githubIssueURL = newIssue.htmlURL
            memo.repositoryOwner = newOwner
            memo.repositoryName = newRepo
            memo.syncStatus = .synced
            memo.syncError = nil
            memo.lastSyncedAt = Date()

            // Best-effort label setting (including empty to clear labels)
            try? await apiClient.setIssueLabels(
                owner: newOwner,
                repo: newRepo,
                number: newIssue.number,
                labels: labelNames
            )

            do { try context.save() } catch { print("[QuickMemo] Failed to save after transfer: \(error)") }
        } catch {
            memo.syncStatus = .failed
            memo.syncError = "[transfer] " + error.localizedDescription
            do { try context.save() } catch { print("[QuickMemo] Failed to save failed status: \(error)") }
        }
    }

    func importIssues(account: GitHubAccount, context: ModelContext) async {
        guard account.isLinked, account.hasRepository else { return }
        guard !isSyncing else { return }

        isSyncing = true
        defer { isSyncing = false }

        let owner = account.repositoryOwner
        let repo = account.repositoryName

        do {
            // Fetch all issues (open + closed) to detect merged status
            let issues = try await apiClient.fetchIssues(owner: owner, repo: repo, state: "all")

            let descriptor = FetchDescriptor<Memo>()
            let existingMemos = (try? context.fetch(descriptor)) ?? []

            // Fetch all local labels for matching
            let labelDescriptor = FetchDescriptor<Label>()
            let allLabels = (try? context.fetch(labelDescriptor)) ?? []

            for issue in issues {
                // Skip pull requests (GitHub Issues API includes PRs — PRs have /pull/ in URL)
                guard issue.htmlURL.contains("/issues/") else { continue }

                let newStatus = memoStatus(from: issue)

                // Update existing memo's status
                if let existingMemo = existingMemos.first(where: { $0.githubIssueNumber == issue.number }) {
                    if existingMemo.status != newStatus {
                        existingMemo.status = newStatus
                        existingMemo.updatedAt = Date()
                    }
                    continue
                }

                // Only import new open issues (skip old closed/merged issues)
                guard issue.state == "open" else { continue }

                let memo = Memo(
                    title: issue.title,
                    body: issue.body,
                    status: newStatus,
                    githubIssueNumber: issue.number,
                    githubIssueURL: issue.htmlURL,
                    syncStatus: .synced,
                    lastSyncedAt: Date(),
                    repositoryOwner: owner,
                    repositoryName: repo
                )

                // Match labels by name
                if let issueLabels = issue.labels {
                    let matchedIDs = issueLabels.compactMap { ghLabel in
                        allLabels.first(where: { $0.name == ghLabel.name })?.id
                    }
                    memo.labelIDs = matchedIDs
                }

                context.insert(memo)
            }

            try context.save()
        } catch {
            print("[QuickMemo] Failed to import issues: \(error)")
        }
    }

    private func memoStatus(from issue: GitHubIssue) -> MemoStatus {
        if issue.state == "open" {
            return .open
        }
        if issue.stateReason == "completed" {
            return .merged
        }
        return .closed
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
